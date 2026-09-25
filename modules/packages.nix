{
  hermes-agent,
  lib,
  pkgs,
  ...
}: let
  chatgptExportPath = "/Users/amoselmaliah/dev/scripts/chatgpt-export-workspaces.sh";
  # Match the existing CLI without updating the workstation-wide nixpkgs pin.
  # Keep the complete upstream layout: code-mode, voice, shell, and rg resources.
  codexCli = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "codex";
    version = "0.157.0";
    src = pkgs.fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-aarch64-apple-darwin.tar.gz";
      hash = "sha256-l4Cfkcs1XlVIDNehJvmtJLt7FiIiUV4wKGvKxvupSs0=";
    };
    sourceRoot = ".";
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -R bin codex-package.json codex-path codex-resources "$out/"
      runHook postInstall
    '';
    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      test "$("$out/bin/codex" --version)" = "codex-cli ${version}"
      test -x "$out/bin/codex-code-mode-host"
      test -x "$out/codex-path/rg"
      runHook postInstallCheck
    '';
    meta = {
      description = "OpenAI Codex CLI, complete upstream release package";
      homepage = "https://github.com/openai/codex";
      license = lib.licenses.asl20;
      platforms = [ "aarch64-darwin" ];
      mainProgram = "codex";
    };
  };
  xurlCli = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "xurl";
    version = "1.3.2";
    src = pkgs.fetchurl {
      url = "https://github.com/xdevplatform/xurl/releases/download/v${version}/xurl_Darwin_arm64.tar.gz";
      # Published by xdevplatform/homebrew-tap for Darwin arm64.
      sha256 = "08fa0a17a7357ffaddf55a108d9ab415600c651479a18c49eac54c1136e457e8";
    };
    sourceRoot = ".";
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 xurl "$out/bin/xurl"
      runHook postInstall
    '';
    meta = {
      description = "Official authenticated CLI for the X API";
      homepage = "https://github.com/xdevplatform/xurl";
      license = lib.licenses.mit;
      platforms = [ "aarch64-darwin" ];
      mainProgram = "xurl";
    };
  };
  searchCli = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "search-cli";
    version = "0.9.0";
    src = pkgs.fetchurl {
      url = "https://github.com/paperfoot/search-cli/releases/download/v${version}/search-aarch64-apple-darwin.tar.gz";
      # Published by paperfoot/homebrew-tap.
      sha256 = "349db03ab8dcc376a1ca09ef67fe6868fb0ee826db39a2b56f29fe3ba91a9ac7";
    };
    sourceRoot = ".";
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 search "$out/bin/search"
      runHook postInstall
    '';
    meta = {
      description = "Multi-provider web search CLI for AI agents";
      homepage = "https://github.com/paperfoot/search-cli";
      license = lib.licenses.mit;
      platforms = [ "aarch64-darwin" ];
      mainProgram = "search";
    };
  };
in {
  home.packages = with pkgs;
    [
      nerd-fonts.fira-code

      git
      git-lfs
      gh

      fnm
      uv
      pipx
      nodejs
      nushell
      codexCli

      ripgrep
      fd
      fzf
      jq
      yq-go
      eza
      lla
      bat
      zoxide
      delta
      just
      tmux
      btop
      watch
      wget
      unzip
      httpie
      searchCli
      xurlCli
      ncdu
      tree
      tree-sitter

      gitui
      lazygit
      glab
      git-filter-repo
      tig
      docker
      lazydocker
      k9s
      helmfile
      kubernetes-helm
      ansible
      yt-dlp
      ffmpeg_6-full
      mob
      protobuf
      protols
      buf
      grpcurl
      tika
      poppler
      ocrmypdf
      pandoc
      exiftool
      sops
      gitleaks
      trivy
      nixd

      lua-language-server
      prettier
      typescript-language-server
      vscode-langservers-extracted
      yaml-language-server
      tailwindcss-language-server
      rust-analyzer
      gopls
      pyright
      bash-language-server
      cmake-language-server
      java-language-server
      kotlin-language-server
      nil

      stylua
      shfmt
      alejandra
      black
      isort
      ruff
      hadolint
      shellcheck
      yamllint
      statix
      deadnix
      go-task
      cue
      bats

      gawk
      findutils
      gnused

      hermes-agent.packages.${pkgs.system}.default

      (pkgs.writeShellScriptBin "protobuf-language-server" ''
        exec ${pkgs.protols}/bin/protols "$@"
      '')

      (pkgs.writeShellScriptBin "scan-secrets" ''
                set -euo pipefail

                usage() {
                  cat <<'USAGE'
        Usage: scan-secrets [--all|--history|--env] [path]

        Runs local gitleaks scans with redacted findings.

          scan-secrets           scan the current working tree, excluding git history
          scan-secrets --history scan the current repo including git history
          scan-secrets --env     scan current environment variables from stdin
          scan-secrets --all     run working tree, history, and environment scans
        USAGE
                }

                mode="worktree"
                target="."

                case "''${1:-}" in
                  --all|--history|--env)
                    mode="''${1#--}"
                    shift
                    ;;
                  -h|--help)
                    usage
                    exit 0
                    ;;
                esac

                if [ "''${1:-}" != "" ]; then
                  target="$1"
                fi

                run_worktree() {
                  ${pkgs.gitleaks}/bin/gitleaks detect --source "$target" --no-git --redact
                }

                run_history() {
                  ${pkgs.gitleaks}/bin/gitleaks detect --source "$target" --redact
                }

                run_env() {
                  env | ${pkgs.gitleaks}/bin/gitleaks stdin --redact
                }

                case "$mode" in
                  worktree) run_worktree ;;
                  history) run_history ;;
                  env) run_env ;;
                  all)
                    run_worktree
                    run_history
                    run_env
                    ;;
                  *)
                    usage >&2
                    exit 2
                    ;;
                esac
      '')
    ]
    ++ lib.optional (builtins.pathExists chatgptExportPath)
    (pkgs.writeShellScriptBin "chatgpt-export-workspaces"
      (builtins.readFile chatgptExportPath));

  fonts.fontconfig.enable = true;
}
