{
  config,
  lib,
  pkgs,
  ...
}: let
  homeDir = config.home.homeDirectory;
  whisperModelPath = "${homeDir}/.local/share/whisper-models/ggml-large-v3-turbo.bin";
  whisperModel = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin";
    hash = "sha256-H8cPd0046xaZk6w5Huo1fvR8iHV+9y7llDh5t+jivGk=";
  };
  whisperThreadCommand = "/usr/sbin/sysctl -n hw.perfcpu 2>/dev/null || /usr/sbin/sysctl -n hw.ncpu 2>/dev/null || echo 4";
  whisperConvert = pkgs.writeShellScriptBin "whisper-convert" ''
    set -euo pipefail
    if [ "$#" -ne 2 ]; then
      echo "Usage: whisper-convert <input_media> <output_audio.wav>" >&2
      exit 1
    fi

    ${lib.getExe pkgs.ffmpeg_6-full} -y -i "$1" -ar 16000 -ac 1 -c:a pcm_s16le -f wav "$2"

    if [ ! -s "$2" ]; then
      echo "Converted audio is empty: $2" >&2
      exit 1
    fi

    ${lib.getExe' pkgs.ffmpeg_6-full "ffprobe"} -v error -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 "$2" >/dev/null
  '';
  whisperFast = pkgs.writeShellScriptBin "whisper-fast" ''
    set -euo pipefail
    if [ "$#" -ne 1 ]; then
      echo "Usage: whisper-fast <audio_16khz.wav>" >&2
      exit 1
    fi
    if [ ! -r "${whisperModelPath}" ]; then
      echo "Missing model: ${whisperModelPath}" >&2
      exit 1
    fi

    THREADS=$(${whisperThreadCommand})
    AUDIO="$1"
    WHISPER_BIN="${lib.getExe pkgs.whisper-cpp}"

    run_gpu() {
      "$WHISPER_BIN" -m "${whisperModelPath}" -f "$1" -t "$THREADS" -pc -nt
    }

    run_cpu() {
      "$WHISPER_BIN" -m "${whisperModelPath}" -f "$1" -t "$THREADS" -pc -nt -ng
    }

    if [ "''${WHISPER_NO_GPU:-0}" = "1" ]; then
      run_cpu "$AUDIO"
      exit $?
    fi

    if run_gpu "$AUDIO"; then
      exit 0
    fi

    status=$?
    echo "GPU run failed with status $status; retrying with -ng" >&2
    run_cpu "$AUDIO"
  '';
  whisperEvidence = pkgs.writeShellScriptBin "whisper-evidence" ''
    set -euo pipefail
    if [ "$#" -ne 2 ]; then
      echo "Usage: whisper-evidence <audio_16khz.wav> <output_stem>" >&2
      exit 1
    fi
    if [ ! -r "${whisperModelPath}" ]; then
      echo "Missing model: ${whisperModelPath}" >&2
      exit 1
    fi

    OUT_DIR=$(/usr/bin/dirname "$2")
    if [ "$OUT_DIR" != "." ]; then
      mkdir -p "$OUT_DIR"
    fi

    THREADS=$(${whisperThreadCommand})
    AUDIO="$1"
    OUT_STEM="$2"
    WHISPER_BIN="${lib.getExe pkgs.whisper-cpp}"

    run_gpu() {
      "$WHISPER_BIN" -m "${whisperModelPath}" -f "$1" -t "$THREADS" -pc -otxt -osrt -ovtt -of "$2"
    }

    run_cpu() {
      "$WHISPER_BIN" -m "${whisperModelPath}" -f "$1" -t "$THREADS" -pc -otxt -osrt -ovtt -of "$2" -ng
    }

    if [ "''${WHISPER_NO_GPU:-0}" = "1" ]; then
      run_cpu "$AUDIO" "$OUT_STEM"
      exit $?
    fi

    if run_gpu "$AUDIO" "$OUT_STEM"; then
      exit 0
    fi

    status=$?
    echo "GPU run failed with status $status; retrying with -ng" >&2
    run_cpu "$AUDIO" "$OUT_STEM"
  '';
  whisperTranscribe = pkgs.writeShellScriptBin "whisper-transcribe" ''
    set -euo pipefail
    if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
      echo "Usage: whisper-transcribe <any_media_input> [output_stem]" >&2
      exit 1
    fi

    INPUT="$1"
    if [ "$#" -eq 2 ]; then
      OUT_STEM="$2"
    else
      OUT_STEM="''${INPUT%.*}"
    fi

    TMP_PARENT="''${TMPDIR:-/tmp}"
    TMPWAV=$(/usr/bin/mktemp "$TMP_PARENT/whisper_XXXXXX")
    trap 'rm -f "$TMPWAV"' EXIT INT TERM

    echo "Normalizing audio to 16kHz PCM WAV..." >&2
    whisper-convert "$INPUT" "$TMPWAV"

    echo "Transcribing with timestamps..." >&2
    whisper-evidence "$TMPWAV" "$OUT_STEM"
  '';
in {
  home.file.".local/share/whisper-models/ggml-large-v3-turbo.bin".source = whisperModel;

  home.packages = [
    pkgs.whisper-cpp
    whisperConvert
    whisperFast
    whisperEvidence
    whisperTranscribe
  ];
}
