{ config, lib, pkgs, ... }:

let
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
  # Declaratively managed subset of ~/.openclaw/openclaw.json.
  # Runtime-written keys (wizard, meta, gateway.auth) are preserved on merge.
  openclawConfig = builtins.toJSON {
    agents = {
      defaults = {
        workspace = "~/.openclaw/workspace";
      };
    };
    gateway = {
      mode = "local";
      port = 18789;
      bind = "loopback";
    };
  };

  openclawConfigFile = pkgs.writeText "openclaw-managed.json" openclawConfig;
in
{
  home.sessionVariables = {
    CONTAINER_USE_MCP = lib.concatStringsSep "," [
      "mcp__container-use__environment_create"
      "mcp__container-use__environment_list"
      "mcp__container-use__environment_open"
      "mcp__container-use__environment_config"
      "mcp__container-use__environment_update_metadata"
      "mcp__container-use__environment_file_read"
      "mcp__container-use__environment_file_write"
      "mcp__container-use__environment_file_edit"
      "mcp__container-use__environment_file_delete"
      "mcp__container-use__environment_file_list"
      "mcp__container-use__environment_run_cmd"
      "mcp__container-use__environment_add_service"
      "mcp__container-use__environment_checkpoint"
    ];
  };

  home.file = {
    ".local/share/whisper-models/ggml-large-v3-turbo.bin".source = whisperModel;
  };

  home.packages = [
    pkgs.whisper-cpp
    whisperConvert
    whisperFast
    whisperEvidence
    whisperTranscribe
  ];

  # Merge managed config into the live openclaw.json on each activation.
  # Existing runtime keys (gateway.auth, wizard, meta) survive the merge;
  # managed keys always win so the Nix definition stays the source of truth.
  home.activation.openclawConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    config_dir="$HOME/.openclaw"
    config_file="$config_dir/openclaw.json"
    mkdir -p "$config_dir"

    if [ -f "$config_file" ]; then
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
        "$config_file" \
        ${openclawConfigFile} \
        > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
    else
      cp ${openclawConfigFile} "$config_file"
    fi
    chmod 600 "$config_file"
  '';

  home.activation.openclawClawhub = lib.hm.dag.entryAfter [ "openclawConfig" ] ''
    npm_prefix="$HOME/.npm-global"
    clawhub_bin="$npm_prefix/bin/clawhub"

    mkdir -p "$npm_prefix"

    if [ ! -x "$clawhub_bin" ]; then
      echo "Installing clawhub into $npm_prefix ..."
      ${pkgs.nodejs}/bin/npm install --global --prefix "$npm_prefix" clawhub
    fi
  '';
}
