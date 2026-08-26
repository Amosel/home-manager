{ config, lib, pkgs, hermes-agent, ... }:

let
  # Shared shell aliases for both zsh and bash
  commonShellAliases = {
    # lla base aliases (table view -T; lla shows dotfiles by default)
    ll   = "lla -T --no-dotfiles";                    # table view, hide dotfiles
    la   = "lla -T";                                  # table view, show all
    # Extra lla views
    lt   = "lla -t -d 2";                             # shallow tree
    ltt  = "lla -t -d 3";                             # deeper tree
    lS   = "lla -T -s size";                          # table, largest first
    lnew = "lla -T -s date";                          # table, newest first
    ld   = "lla -T --dirs-only";                      # table, directories only
    lf   = "lla -T --files-only";                     # table, files only
    # grep: color and show the line number for each match:
    grep="grep -n --color";
    # mkdir: create parent directories
    mkdir="mkdir -pv";
    # ping: stop after 5 pings
    ping="ping -c 5";
    # curl: only display HTTP header
    HEAD="curl -I";
    # Search through your command history and print the top 10 commands
    history-stat = "history 0 | awk '{print $2}' | sort | uniq -c | sort -n -r | head";
    # DAML SDK alias
    daml="~/.daml/bin/daml";
    # Use GNU sed instead of BSD sed (from Nix)
    sed="~/.nix-profile/bin/sed";
    # Security audit shortcuts
    scan-fast = "trivy repo .";
    scan-deep = "npx megalinter-runner --flavor security";
    scan-secrets = "trivy repo --scanners secret .";
  };

  # Shell functions that work in both zsh and bash
  shellFunctions = ''
    # Keep bare ls as the nicer lla view, but preserve normal ls flag behavior.
    ls() {
      if [ "$#" -eq 0 ]; then
        command lla -T --no-dotfiles
      else
        command /bin/ls "$@"
      fi
    }

    # Apply this repo's Home Manager flake config for the local user.
    hms() {
      command home-manager switch --flake "${config.home.homeDirectory}/.config/home-manager#amoselmaliah" "$@"
    }

    # Claude with container-use tools
    # Alternative versions
    ccu() {
      claude --allowedTools "$CONTAINER_USE_MCP" "$@"
    }
  '';

  whisperModelPath = "${config.home.homeDirectory}/.local/share/whisper-models/ggml-large-v3-turbo.bin";
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
in
{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "amoselmaliah";
  home.homeDirectory = "/Users/amoselmaliah";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.11"; # Please read the comment before changing.

  # Disable version mismatch warning between Home Manager and Nixpkgs
  home.enableNixpkgsReleaseCheck = false;

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
    nerd-fonts.fira-code
    yt-dlp
    ffmpeg_6-full
    whisper-cpp
    whisperConvert
    whisperFast
    whisperEvidence
    whisperTranscribe
    mob
    # go
    # zig
    fnm
    git
    git-lfs
    gh
    glab
    git-filter-repo
    tig
    wget
    # android-tools
    # swift-format
    gitui
    lazygit
    docker
    lazydocker
    watch
    jq
    yq-go
    helmfile
    kubernetes-helm
    fzf
    nixd
    sops
    k9s
    pipx
    uv
    httpie
    tree
    socat
    sox
    gawk        # GNU awk
    findutils   # GNU find
    gnused      # GNU sed
    protobuf    # Protocol Buffers
    protols     # Protocol Buffers language server
    buf         # Modern Protocol Buffers toolchain
    grpcurl
    # Language Servers (LSPs)
    lua-language-server
    nushell
    # Web Development LSPs
    typescript-language-server      # TypeScript/JavaScript
    nodePackages.vscode-langservers-extracted  # HTML, CSS, JSON, ESLint
    nodePackages.yaml-language-server          # YAML
    tailwindcss-language-server    # TailwindCSS

    # Systems Programming LSPs
    rust-analyzer                 # Rust
    gopls                         # Go

    # Python LSPs
    pyright                       # Python (Microsoft's type checker)
    # basedpyright                # Alternative Python LSP (uncomment if preferred)

    # Other Language LSPs
    java-language-server          # Java
    kotlin-language-server        # Kotlin
    bash-language-server          # Bash/Shell
    # dockerfile-language-server    # Docker (package not available)
    cmake-language-server         # CMake

    # Formatting and Linting
    stylua                        # Lua formatter
    ripgrep
    fd
    lla                                           # modern ls replacement (https://github.com/chaqchase/lla)
    # recoll - currently broken on macOS (v1.39.1 has build issues with X11/iconv)
    # Consider using Homebrew or waiting for a fixed version
    # recoll
    poppler
    ocrmypdf
    pandoc
    tika
    ncdu
    exiftool
    # Infrastructure and Automation
    ansible                       # IT automation
    go-task                       # Task runner (Taskfile)
    cue                           # CUE language CLI
    # nodePackages.ajv-cli          # JSON Schema validator CLI (removed from nixpkgs; install via npm if needed)
    shellcheck                    # Shell script linter
    bats                          # Bash Automated Testing System
    trivy                         # Security scanner

    # Optional: additional tools that work well with LazyVim
    tree-sitter
    nodejs  # Required for many LSPs and plugins
    hermes-agent.packages.${pkgs.system}.default

    # Create protobuf-language-server wrapper for Zed compatibility
    (pkgs.writeShellScriptBin "protobuf-language-server" ''
      exec ${pkgs.protols}/bin/protols "$@"
    '')

    # mlx-codex: start a local vllm-mlx inference server and launch Codex against it
    # Usage:
    #   mlx-codex run   [model]  — start server + open Codex
    #   mlx-codex serve [model]  — start server only (OpenAI-compatible endpoint)
    #   mlx-codex stop           — stop a running server
    #   mlx-codex logs           — tail server logs
    # Env: MLX_PORT (default 8000), MLX_MAX_TOKENS (default 32768)
    (pkgs.writeShellScriptBin "mlx-codex" ''
      VENV="${config.home.homeDirectory}/.venv-vllm-metal"
      PORT="''${MLX_PORT:-8000}"
      MAX_TOKENS="''${MLX_MAX_TOKENS:-32768}"
      LOG_FILE="/tmp/mlx-server.log"
      PID_FILE="/tmp/mlx-server.pid"
      DEFAULT_MODEL="mlx-community/gemma-4-31b-it-4bit"

      _start_server() {
        local model="$1"
        echo "Starting vllm-mlx server — model: $model | port: $PORT"
        "$VENV/bin/vllm-mlx" serve "$model" \
          --port "$PORT" \
          --host 127.0.0.1 \
          --max-tokens "$MAX_TOKENS" \
          --continuous-batching \
          &>"$LOG_FILE" &
        echo $! >"$PID_FILE"
        echo "PID: $(cat "$PID_FILE")  |  logs: tail -f $LOG_FILE"
      }

      _wait_ready() {
        echo -n "Waiting for server"
        for i in $(seq 1 60); do
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

      _stop_server() {
        if [ -f "$PID_FILE" ]; then
          local pid; pid=$(cat "$PID_FILE")
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
          _start_server "$MODEL"
          trap _stop_server EXIT INT TERM
          _wait_ready || exit 1
          OPENAI_BASE_URL="http://localhost:$PORT/v1" \
          OPENAI_API_KEY="local" \
            codex -c "model=\"$MODEL\""
          ;;
        serve)
          _start_server "$MODEL"
          trap _stop_server EXIT INT TERM
          _wait_ready || exit 1
          echo "Server at http://localhost:$PORT/v1  (Ctrl-C to stop)"
          wait
          ;;
        stop)
          _stop_server
          ;;
        logs)
          tail -f "$LOG_FILE"
          ;;
        *)
          echo "Usage: mlx-codex <command> [model]"
          echo ""
          echo "Commands:"
          echo "  run   [model]  Start server + launch Codex"
          echo "  serve [model]  Start server only"
          echo "  stop           Stop running server"
          echo "  logs           Tail server logs"
          echo ""
          echo "Default model: $DEFAULT_MODEL"
          echo "Env:  MLX_PORT (default 8000), MLX_MAX_TOKENS (default 32768)"
          ;;
      esac
    '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';

    # lla — declarative config (https://github.com/chaqchase/lla)
    ".config/lla/config.toml".text = ''
      default_sort = "name"
      default_format = "default"
      show_icons = true
      include_dirs = false
      permission_format = "symbolic"
      theme = "default"
      enabled_plugins = []
      plugins_dir = "~/.config/lla/plugins"
      default_depth = 3

      [sort]
      dirs_first = true
      case_sensitive = false
      natural = true

      [filter]
      case_sensitive = false
      no_dotfiles = false

      [formatters.tree]
      max_lines = 20000

      [formatters.grid]
      ignore_width = false
      max_width = 200

      [listers.recursive]
      max_entries = 20000

      [listers.fuzzy]
      ignore_patterns = ["node_modules", "target", ".git", ".idea", ".vscode"]
    '';

    ".local/share/whisper-models/ggml-large-v3-turbo.bin".source = whisperModel;
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. If you don't want to manage your shell through Home
  # Manager then you have to manually source 'hm-session-vars.sh' located at
  # either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/amoselmaliah/etc/profile.d/hm-session-vars.sh
  #

  home.sessionVariables = {
    JAVA_HOME = builtins.toPath "/Applications/Android Studio.app/Contents/jbr/Contents/Home";
    ANDROID_HOME = builtins.toPath "${config.home.homeDirectory}/Library/Android/sdk";
    GOPATH = builtins.toPath "${config.home.homeDirectory}/go";
    # barretenberg
    BB_HOME = "${config.home.homeDirectory}/.bb";
    NARGO_HOME = "${config.home.homeDirectory}/.nargo";
    NARGO_BIN_DIR = "${config.home.homeDirectory}/.nargo/bin";
    DENO_INSTALL = "${config.home.homeDirectory}/.deno";
    OLLAMA_MODELS = "${config.home.homeDirectory}/models";
    MODULAR_HOME = "${config.home.homeDirectory}/.modular";
    # DAML SDK and Canton paths
    DAML_SDK_HOME = "${config.home.homeDirectory}/.daml";
    CANTON_HOME = "/opt/canton";
    PATH = lib.concatStringsSep ":" [
      "/usr/local/bin"
      "${config.home.homeDirectory}/.opencode/bin"
      "${config.home.homeDirectory}/.bun/bin"
      "${config.home.homeDirectory}/.cargo/bin"
      "${config.home.homeDirectory}/.foundry/bin"
      "${config.home.sessionVariables.JAVA_HOME}"
      "${config.home.sessionVariables.JAVA_HOME}/bin"
      "${config.home.homeDirectory}/Library/Android/sdk"
      "${config.home.sessionVariables.ANDROID_HOME}"
      "${config.home.sessionVariables.ANDROID_HOME}/tools"
      "${config.home.sessionVariables.ANDROID_HOME}/platform-tools"
      "${config.home.sessionVariables.GOPATH}/bin"
      "${config.home.sessionVariables.BB_HOME}"
      "${config.home.sessionVariables.NARGO_BIN_DIR}"
      "${config.home.sessionVariables.DENO_INSTALL}/bin"
      "${config.home.sessionVariables.MODULAR_HOME}"
      "${config.home.sessionVariables.MODULAR_HOME}/bin"
      "${config.home.homeDirectory}/flutter/bin"
      "${config.home.homeDirectory}/.pub-cache/bin"
      "${config.home.sessionVariables.DAML_SDK_HOME}/bin"
      "${config.home.sessionVariables.CANTON_HOME}/bin"
      "$PATH"
    ];
    EDITOR = "nvim";
    # MCP - container-use tools
    CONTAINER_USE_MCP = lib.concatStringsSep "," [
      # Environment Lifecycle
      "mcp__container-use__environment_create"
      "mcp__container-use__environment_list"
      "mcp__container-use__environment_open"
      "mcp__container-use__environment_config"
      "mcp__container-use__environment_update_metadata"

      # File Operations (in environment)
      "mcp__container-use__environment_file_read"
      "mcp__container-use__environment_file_write"
      "mcp__container-use__environment_file_edit"
      "mcp__container-use__environment_file_delete"
      "mcp__container-use__environment_file_list"

      # Command Execution
      "mcp__container-use__environment_run_cmd"

      # Advanced Features
      "mcp__container-use__environment_add_service"
      "mcp__container-use__environment_checkpoint"
    ];
  };

  programs.home-manager.enable = true;
  programs.zsh = {
    enable = true;
    defaultKeymap = "emacs";
    # enableAutosuggestions = true;
    history = {
      size = 10000;
      save = 10000;
    };
    shellAliases = commonShellAliases;
    initExtra = ''
      eval "$(fnm env --use-on-cd --version-file-strategy=recursive)"
      eval "$(/opt/homebrew/bin/brew shellenv)"
      setopt INC_APPEND_HISTORY

      ${shellFunctions}
    '';
    # Hook that runs after all other zsh initialization
    loginExtra = ''
      # Force emacs mode (normal shell editing) instead of vi mode
      bindkey -e
    '';
  };
  programs.bash = {
    enable = true;
    shellAliases = commonShellAliases;
    initExtra = ''
      shopt -s histappend
      export HISTSIZE=10000
      export HISTFILESIZE=20000
      export HISTCONTROL=ignoreboth
      export HISTIGNORE="ls:bg:fg:exit"
      export HISTTIMEFORMAT="%F %T "
      PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
      eval "$(fnm env --use-on-cd --version-file-strategy=recursive)"
      eval "$(/opt/homebrew/bin/brew shellenv)"

      ${shellFunctions}
    '';
  };

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  # Neovim configuration
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    flags = [ "--disable-up-arrow" ];
    settings = {
      auto_sync = false;
      update_check = false;
      style = "compact";
      inline_height = 20;
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      # See docs here: https://starship.rs/config/
      # Symbols config configured in Flake.
      # preset = "tokyo-night";
      battery.display = [{
        threshold = 25; # display battery information if charge is <= 25%
      }];
    };
  };
  fonts.fontconfig.enable = true;

  programs.git = {
    enable = true;
    userName = "Amos Elmaliah";
    userEmail = "amosel@gmail.com";
    extraConfig = {
      init = {
        defaultBranch = "main";
      };
      alias = {
        b = "branch";
        bb = "for-each-ref --sort='-committerdate' --format='%(color:bold blue)%(refname:short)%(color:reset) - %(color:bold green)%(committerdate:relative)%(color:reset) - %(color:bold red)%(authorname)%(color:reset) (%(color:bold yellow)%(subject)%(color:reset))' refs/heads/ --count 10";
        s = "status";
        div = "!git log --left-right --graph --cherry-pick --oneline HEAD...origin/$(git rev-parse --abbrev-ref HEAD)";
        a = "!git add . && git status";
        au = "!git add -u . && git status";
        aa = "!git add . && git add -u . && git status";
        ac = "!git add . && git commit";
        acm = "!git add . && git commit -m";
        l = "log --graph --pretty=format':%C(yellow)%h%Cblue%d%Creset %s %C(white) %an, %ar%Creset'";
        la = "log --graph --all --pretty=format:'%C(yellow)%h%C(cyan)%d%Creset %s %C(white)- %an, %ar%Creset'";
        ll = "log --stat --abbrev-commit";
        authors = "git log --format='%aN' | sort | uniq -c | sort -rn";
        d = "diff --color-words";
        dt = "difftool";
        dh = "diff --color-words head";
      };
      core = {
        excludesfile = "/Users/amoselmaliah/.gitignore_global";
      };
      difftool = {
        Kaleidoscope = {
          cmd = "ksdiff --partial-changeset --relative-path \"$MERGED\" -- \"$LOCAL\" \"$REMOTE\"";
        };
        prompt = "false";
      };
      diff = {
        tool = "Kaleidoscope";
      };
      mergetool = {
        Kaleidoscope = {
          cmd = "ksdiff --merge --output \"$MERGED\" --base \"$BASE\" -- \"$LOCAL\" --snapshot \"$REMOTE\" --snapshot";
          trustExitCode = "true";
        };
        prompt = "false";
      };
      merge = {
        tool = "Kaleidoscope";
      };
      filter = {
        media = {
          required = "true";
          clean = "git media clean %f";
          smudge = "git media smudge %f";
        };
        hawser = {
          clean = "git hawser clean %f";
          smudge = "git hawser smudge %f";
          required = "true";
        };
        lfs = {
          clean = "git lfs clean %f";
          smudge = "git lfs smudge %f";
          required = "true";
        };
      };
      credential = {
        helper = [
          "osxkeychain"
          "!/Library/Java/JavaVirtualMachines/jdk1.8.0_92.jdk/Contents/Home/jre/bin/java -Ddebug=false -Djava.net.useSystemProxies=true -jar /usr/local/Cellar/git-credential-manager/1.6.0/libexec/git-credential-manager-1.6.0.jar"
        ];
      };
    };
  };
}
