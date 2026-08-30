# macOS Home Manager Dev Environment

Declarative daily-driver workstation config for macOS on Apple Silicon.

This repo owns a narrow baseline:
- shell and terminal ergonomics
- Git and GitHub CLI defaults
- Neovim with a reproducible plugin set
- Codex repo guidance and local skill wiring
- language servers, formatters, and core CLI tooling
- local media, transcription, document, and security tools

Secrets stay out of this repo. Home Manager is the Nix source of truth; `Brewfile` covers Homebrew taps, casks, services, and non-Nix fallback tooling.

## Architecture

```text
home.nix            # composition root
modules/packages.nix
modules/shell.nix
modules/git.nix
modules/editor.nix
modules/ai.nix
```

Each module owns one concern. The goal is readability and safe iteration, not abstraction.

## What the Environment Provides

- `zsh` and `bash` with completions, autosuggestions, syntax highlighting, `starship`, `fzf`, `zoxide`, `atuin`, and `lla` aliases
- CLI tools such as `bat`, `delta`, `just`, `tmux`, `gh`, `glab`, `rg`, `fd`, `jq`, `yq`, `httpie`, `docker`, `k9s`, `helm`, and `ansible`
- Neovim with Treesitter, LSP config, Telescope, Gitsigns, Lualine, and Catppuccin
- language tooling for Nix, Go, Python, TypeScript, Rust, Bash, YAML, CMake, Java, Kotlin, and Protobuf
- media/document tooling: `ffmpeg`, `whisper-cpp`, `whisper-transcribe`, `poppler`, `ocrmypdf`, `pandoc`, `tika`, and `exiftool`
- security tooling: `trivy`, `gitleaks`, `scan-secrets`, `shellcheck`, `hadolint`, `statix`, and `deadnix`
- agent tooling: Hermes flake package, OpenClaw config/bootstrap, Codex `home-manager-review` skill, and `skill-audit`

## Install

```bash
xcode-select --install
curl -L https://nixos.org/nix/install | sh
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

mkdir -p ~/.config
git clone <repo-url> ~/.config/home-manager

cd ~/.config/home-manager
nix run github:nix-community/home-manager -- switch --flake .#amoselmaliah
./scripts/verify.sh
```

`./bootstrap.sh` performs the same setup flow and runs `brew bundle` when `Brewfile` is present.

## Daily Commands

```bash
home-manager switch --flake ~/.config/home-manager#amoselmaliah
~/.config/home-manager/scripts/verify.sh

cd ~/.config/home-manager
nix flake update
home-manager switch --flake .#amoselmaliah
```

## Notes

- `nvim/default.nix` is a legacy compatibility stub; active editor config lives in `modules/editor.nix`.
- `scan-secrets` uses local `gitleaks` with redacted output.
- Whisper helpers use the pinned `large-v3-turbo` model at `~/.local/share/whisper-models/ggml-large-v3-turbo.bin`.
- OpenClaw activation may install `clawhub` into `~/.npm-global` if missing.
