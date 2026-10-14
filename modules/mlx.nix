{
  config,
  lib,
  pkgs,
  ...
}: let
  homeDir = config.home.homeDirectory;
  mlxCodex = pkgs.writeShellScriptBin "mlx-codex" ''
        set -euo pipefail

        VENV="''${MLX_VENV:-${homeDir}/.venv-vllm-mlx}"
        PORT="''${MLX_PORT:-8000}"
        MAX_REQUEST_TOKENS="''${MLX_MAX_REQUEST_TOKENS:-32768}"
        LOG_FILE="''${MLX_LOG_FILE:-/tmp/mlx-server.log}"
        PID_FILE="''${MLX_PID_FILE:-/tmp/mlx-server.pid}"
        DEFAULT_MODEL="''${MLX_CODEX_MODEL:-mlx-community/Qwen3.5-9B-MLX-4bit}"
        STRONG_MODEL="mlx-community/Qwen3.6-27B-4bit"
        PYTHON="${lib.getExe pkgs.python313}"
        UV="${lib.getExe pkgs.uv}"
        CURL="${lib.getExe pkgs.curl}"

        setup_backend() {
          echo "Creating vllm-mlx environment at $VENV"
      "$UV" venv --allow-existing --python "$PYTHON" "$VENV"
          "$UV" pip install --python "$VENV/bin/python" --upgrade \
            --refresh-package vllm-mlx --reinstall-package vllm-mlx \
            -r "${../config/local-llm/requirements.txt}"
      "$UV" pip show --python "$VENV/bin/python" vllm-mlx mlx mlx-lm \
        | awk '/^(Name|Version):/ {print $0}'
        }

        require_vllm_mlx() {
          if [ ! -x "$VENV/bin/vllm-mlx" ]; then
            echo "Missing vllm-mlx: $VENV/bin/vllm-mlx" >&2
            echo "Run: mlx-codex setup" >&2
            exit 127
          fi
        }

        endpoint_ready() {
          "$CURL" -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1
        }

        start_server() {
          local model="$1"
          require_vllm_mlx

          if endpoint_ready; then
            echo "Server already responds at http://127.0.0.1:$PORT/v1"
            return 0
          fi

          echo "Starting vllm-mlx server - model: $model | port: $PORT"
          "$VENV/bin/vllm-mlx" serve "$model" \
            --port "$PORT" \
            --host 127.0.0.1 \
            --max-request-tokens "$MAX_REQUEST_TOKENS" \
            --continuous-batching \
            >"$LOG_FILE" 2>&1 &
          echo $! >"$PID_FILE"
          echo "PID: $(cat "$PID_FILE") | logs: tail -f $LOG_FILE"
        }

        wait_ready() {
          echo -n "Waiting for server"
          for _ in $(seq 1 60); do
            if endpoint_ready; then
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
          else
            echo "No PID file at $PID_FILE"
          fi
        }

        doctor() {
          echo "mlx-codex doctor"
          echo "macOS: $(/usr/bin/sw_vers -productVersion) ($(/usr/bin/sw_vers -buildVersion))"
          echo "CPU: $(/usr/sbin/sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)"
      echo "Memory GB: $(/usr/sbin/sysctl -n hw.memsize | awk '{printf "%.1f", $1 / 1024 / 1024 / 1024}')"
          echo "Venv: $VENV"
          echo "Default model: $DEFAULT_MODEL"
          echo "Strong model: $STRONG_MODEL"
          echo "Port: $PORT"
          echo "Max request tokens: $MAX_REQUEST_TOKENS"
          echo "uv: $("$UV" --version)"
          if [ -x "$VENV/bin/vllm-mlx" ]; then
        echo "vllm-mlx: installed"
        "$UV" pip show --python "$VENV/bin/python" vllm-mlx mlx mlx-lm 2>/dev/null \
              | awk '/^(Name|Version):/ {print "  " $0}'
          else
            echo "vllm-mlx: missing; run mlx-codex setup"
          fi
          if endpoint_ready; then
            echo "Endpoint: http://127.0.0.1:$PORT/v1 ready"
          else
            echo "Endpoint: http://127.0.0.1:$PORT/v1 not responding"
          fi
        }

        CMD="''${1:-help}"
        shift 2>/dev/null || true
        MODEL="''${1:-$DEFAULT_MODEL}"

        case "$CMD" in
          setup)
            setup_backend
            ;;
          doctor)
            doctor
            ;;
          run)
            start_server "$MODEL"
            wait_ready || exit 1
            OPENAI_BASE_URL="http://127.0.0.1:$PORT/v1" \
            OPENAI_API_KEY="local" \
              codex -c "model=\"$MODEL\""
            ;;
          serve)
            start_server "$MODEL"
            wait_ready || exit 1
            echo "Server at http://127.0.0.1:$PORT/v1 (Ctrl-C to stop)"
            wait
            ;;
          stop)
            stop_server
            ;;
          logs)
            tail -f "$LOG_FILE"
            ;;
          *)
            cat <<USAGE
    Usage: mlx-codex <command> [model]

    Commands:
      setup          Create or refresh the unpinned upstream vllm-mlx backend
      doctor         Show local MLX backend status
      run   [model]  Start server + launch Codex
      serve [model]  Start server only
      stop           Stop server started by this wrapper
      logs           Tail server logs

    Default model: $DEFAULT_MODEL
    Stronger 32 GB test model: $STRONG_MODEL
    Env: MLX_VENV, MLX_CODEX_MODEL, MLX_PORT, MLX_MAX_REQUEST_TOKENS
    USAGE
            ;;
        esac
  '';
in {
  home.sessionVariables = {
    MLX_VENV = "${homeDir}/.venv-vllm-mlx";
    MLX_CODEX_MODEL = "mlx-community/Qwen3.5-9B-MLX-4bit";
    MLX_MAX_REQUEST_TOKENS = "32768";
  };

  home.packages = [
    mlxCodex
  ];
}
