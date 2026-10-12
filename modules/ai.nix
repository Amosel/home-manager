{ config, lib, pkgs, ... }:

let
  homeDir = config.home.homeDirectory;
  skillSourceRepo = "/Users/amoselmaliah/dev/scripts/skills";
  personaSkillSourceRepo = "/Users/amoselmaliah/dev/scripts/persona/personas/matt-pocock/skills";
  codexSkillsDir = "${homeDir}/.codex/skills";
  skillRegistryDir = "${homeDir}/.local/state/skill-manager/registry";
  skillArchiveDir = "${homeDir}/.local/state/skill-manager/archive";
  skillManagerScript = "${skillSourceRepo}/skill-manager/scripts/skill_manager.py";
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
  mlxCodex = pkgs.writeShellScriptBin "mlx-codex" ''
    set -euo pipefail

    VENV="${homeDir}/.venv-vllm-metal"
    PORT="''${MLX_PORT:-8000}"
    MAX_TOKENS="''${MLX_MAX_TOKENS:-32768}"
    LOG_FILE="/tmp/mlx-server.log"
    PID_FILE="/tmp/mlx-server.pid"
    DEFAULT_MODEL="mlx-community/gemma-4-31b-it-4bit"

    start_server() {
      local model="$1"
      echo "Starting vllm-mlx server - model: $model | port: $PORT"
      "$VENV/bin/vllm-mlx" serve "$model" \
        --port "$PORT" \
        --host 127.0.0.1 \
        --max-tokens "$MAX_TOKENS" \
        --continuous-batching \
        >"$LOG_FILE" 2>&1 &
      echo $! >"$PID_FILE"
      echo "PID: $(cat "$PID_FILE") | logs: tail -f $LOG_FILE"
    }

    wait_ready() {
      echo -n "Waiting for server"
      for _ in $(seq 1 60); do
        if curl -sf "http://localhost:$PORT/v1/models" >/dev/null 2>&1; then
          echo " ready"
          return 0
        fi
        printf "."
        sleep 2
      done
      echo " timed out"
      return 1
    }

    stop_server() {
      if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        echo "Stopping server (PID $pid)"
        kill "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
      fi
    }

    CMD="''${1:-help}"
    shift 2>/dev/null || true
    MODEL="''${1:-$DEFAULT_MODEL}"

    case "$CMD" in
      run)
        start_server "$MODEL"
        trap stop_server EXIT INT TERM
        wait_ready || exit 1
        OPENAI_BASE_URL="http://localhost:$PORT/v1" \
        OPENAI_API_KEY="local" \
          codex -c "model=\"$MODEL\""
        ;;
      serve)
        start_server "$MODEL"
        trap stop_server EXIT INT TERM
        wait_ready || exit 1
        echo "Server at http://localhost:$PORT/v1 (Ctrl-C to stop)"
        wait
        ;;
      stop)
        stop_server
        ;;
      logs)
        tail -f "$LOG_FILE"
        ;;
      *)
        echo "Usage: mlx-codex <command> [model]"
        echo
        echo "Commands:"
        echo "  run   [model]  Start server + launch Codex"
        echo "  serve [model]  Start server only"
        echo "  stop           Stop running server"
        echo "  logs           Tail server logs"
        echo
        echo "Default model: $DEFAULT_MODEL"
        echo "Env: MLX_PORT (default 8000), MLX_MAX_TOKENS (default 32768)"
        ;;
    esac
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
    SKILL_SOURCE_REPO = skillSourceRepo;
    SKILL_PERSONA_SOURCE_REPO = personaSkillSourceRepo;
    CODEX_SKILLS_DIR = codexSkillsDir;
    SKILL_REGISTRY_DIR = skillRegistryDir;
    SKILL_ARCHIVE_DIR = skillArchiveDir;
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
    ".codex/skills/home-manager-review".source = ../codex-skills/home-manager-review;
    ".local/share/whisper-models/ggml-large-v3-turbo.bin".source = whisperModel;
  };

  home.packages = [
    pkgs.whisper-cpp
    whisperConvert
    whisperFast
    whisperEvidence
    whisperTranscribe
    mlxCodex
    (pkgs.writeShellScriptBin "skill-audit" ''
      set -euo pipefail

      format="text"
      if [ "$#" -ge 2 ] && [ "$1" = "--format" ]; then
        format="$2"
        shift 2
      fi
      if [ "$#" -ne 0 ]; then
        echo "usage: skill-audit [--format text|json]" >&2
        exit 2
      fi

      script="${skillManagerScript}"
      runtime_dir="${codexSkillsDir}"
      registry_dir="${skillRegistryDir}"
      archive_dir="${skillArchiveDir}"
      primary_source="${skillSourceRepo}"
      persona_source="${personaSkillSourceRepo}"

      tmpdir="$(mktemp -d)"
      cleanup() {
        rm -rf "$tmpdir"
      }
      trap cleanup EXIT

      run_bundle() {
        local label="$1"
        local source_repo="$2"

        python3 "$script" check-readiness \
          --source-repo "$source_repo" \
          --runtime-dir "$runtime_dir" \
          --registry-dir "$registry_dir" \
          --archive-dir "$archive_dir" \
          --format json >"$tmpdir/$label-readiness.json"

        python3 "$script" inventory \
          --source-repo "$source_repo" \
          --runtime-dir "$runtime_dir" \
          --format json >"$tmpdir/$label-inventory.json"

        python3 "$script" audit \
          --source-repo "$source_repo" \
          --runtime-dir "$runtime_dir" \
          --registry-dir "$registry_dir" \
          --format json >"$tmpdir/$label-audit.json"
      }

      run_bundle "primary" "$primary_source"
      run_bundle "persona" "$persona_source"

      if [ "$format" = "json" ]; then
        ${pkgs.jq}/bin/jq -n \
          --arg runtime_dir "$runtime_dir" \
          --arg registry_dir "$registry_dir" \
          --arg archive_dir "$archive_dir" \
          --arg primary_source "$primary_source" \
          --arg persona_source "$persona_source" \
          --slurpfile primary_readiness "$tmpdir/primary-readiness.json" \
          --slurpfile primary_inventory "$tmpdir/primary-inventory.json" \
          --slurpfile primary_audit "$tmpdir/primary-audit.json" \
          --slurpfile persona_readiness "$tmpdir/persona-readiness.json" \
          --slurpfile persona_inventory "$tmpdir/persona-inventory.json" \
          --slurpfile persona_audit "$tmpdir/persona-audit.json" \
          '{
            summary: "Combined skill-manager audit across configured source libraries",
            runtime_dir: $runtime_dir,
            registry_dir: $registry_dir,
            archive_dir: $archive_dir,
            sources: {
              primary: {
                source_repo: $primary_source,
                readiness: $primary_readiness[0],
                inventory: $primary_inventory[0],
                audit: $primary_audit[0]
              },
              persona: {
                source_repo: $persona_source,
                readiness: $persona_readiness[0],
                inventory: $persona_inventory[0],
                audit: $persona_audit[0]
              }
            }
          }'
        exit 0
      fi

      echo "== primary source =="
      echo "$primary_source"
      ${pkgs.jq}/bin/jq -r '
        .summary,
        (.sections[] | "## " + .title, (.lines[]?))
      ' "$tmpdir/primary-audit.json"
      echo
      echo "== persona source =="
      echo "$persona_source"
      ${pkgs.jq}/bin/jq -r '
        .summary,
        (.sections[] | "## " + .title, (.lines[]?))
      ' "$tmpdir/persona-audit.json"
    '')
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
