# Quick Installation Summary

## One-liner

```bash
cd ~/.config/home-manager && ./bootstrap.sh
```

## Manual install

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

## What this baseline provides

- `zsh` + `starship` + `direnv`
- `tmux`, `gh`, `delta`, `eza`, `bat`, `rg`, `fd`, `fzf`
- Neovim with LSP, Telescope, Gitsigns, Treesitter, Lualine, and Catppuccin
- language servers and formatters for common backend and infra work
- Codex repo guidance and the `home-manager-review` skill

## Daily commands

```bash
home-manager switch --flake ~/.config/home-manager#amoselmaliah
~/.config/home-manager/scripts/verify.sh
home-manager switch --rollback
```
