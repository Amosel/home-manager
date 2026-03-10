# macOS Home Manager Dev Environment

Declarative daily-driver workstation config for macOS on Apple Silicon.

This repo owns a narrow, low-drift baseline:
- shell and terminal ergonomics
- Git and GitHub CLI defaults
- Neovim with a small reproducible plugin set
- Codex repo guidance and local skill wiring
- language servers, formatters, and core CLI tooling

It does not manage secrets, external GUI app configuration, or a large plugin-framework editor setup.

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

- `zsh` as the primary shell with completions, autosuggestions, syntax highlighting, `starship`, `fzf`, and `zoxide`
- modern CLI tools such as `eza`, `bat`, `delta`, `just`, `tmux`, `gh`, `rg`, `fd`, `jq`, `yq`, and `httpie`
- Neovim with Treesitter, LSP config, Telescope, Gitsigns, Lualine, and Catppuccin
- Git defaults tuned for normal daily work, with GitHub CLI enabled
- Codex repo guidance through `AGENTS.md` and a reusable `home-manager-review` skill
- declarative language tooling for Nix, Go, Python, TypeScript, Rust, Bash, YAML, CMake, and Protobuf

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

## Daily Commands

```bash
# Apply changes
home-manager switch --flake ~/.config/home-manager#amoselmaliah

# Verify the environment
~/.config/home-manager/scripts/verify.sh

# Update locked inputs
cd ~/.config/home-manager
nix flake update
home-manager switch --flake .#amoselmaliah
```

## Notes

- Homebrew is supported opportunistically if it exists at `/opt/homebrew/bin/brew`; it is not required for shell startup.
- Secrets stay out of this repo.
- `nvim/default.nix` is now only a legacy compatibility stub; the active editor baseline lives in `modules/editor.nix`.
