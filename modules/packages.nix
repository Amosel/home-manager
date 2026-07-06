{
  lib,
  pkgs,
  ...
}: let
  chatgptExportPath = "/Users/amoselmaliah/dev/scripts/chatgpt-export-workspaces.sh";
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

      ripgrep
      fd
      fzf
      jq
      yq-go
      eza
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
      ncdu
      tree-sitter

      gitui
      lazygit
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
      tika
      sops
      gitleaks
      nixd

      lua-language-server
      nodePackages.prettier
      typescript-language-server
      nodePackages.vscode-langservers-extracted
      nodePackages.yaml-language-server
      tailwindcss-language-server
      rust-analyzer
      gopls
      pyright
      bash-language-server
      cmake-language-server
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

      gawk
      findutils
      gnused

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
