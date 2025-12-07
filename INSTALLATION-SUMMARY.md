# 🚀 Quick Installation Summary

> **TL;DR: Complete reproduction guide for your awesome Neovim setup**

## ⚡ One-Line Installation

**If you have this repo cloned/copied to the target machine:**

```bash
cd ~/.config/home-manager && ./bootstrap.sh
```

## 📋 Manual Step-by-Step

```bash
# 1. Prerequisites
xcode-select --install

# 2. Install Nix
curl -L https://nixos.org/nix/install | sh
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# 3. Enable flakes
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf

# 4. Get configs (choose one method)
# Method A: Clone your repo
git clone <your-repo-url> ~/.config/home-manager

# Method B: Copy from existing machine
rsync -avz user@source:~/.config/home-manager/ ~/.config/home-manager/
rsync -avz user@source:~/.config/nvim/ ~/.config/nvim/

# 5. Activate Home Manager
nix run home-manager/master -- switch --flake ~/.config/home-manager#amoselmaliah

# 6. Bootstrap Neovim
nvim --headless "+Lazy! sync" +qa
```

## 🔍 Verification Commands

```bash
nix --version                # nix (Nix) 2.28.3
home-manager --version       # 25.11-pre
nvim --version | head -1     # NVIM v0.11.1
which gopls pyright         # LSPs should be available
ls ~/.local/share/nvim/lazy | wc -l  # Should show 30+ plugins
```

## 🎯 What You Get

- **Neovim 0.11.1** with 30+ plugins
- **LazyVim** configuration framework  
- **Complete LSP setup** for TypeScript, Python, Go, Rust, Lua, Bash
- **Catppuccin theme** with modern UI components
- **Nix package management** with exact version pinning
- **Cross-platform configs** (macOS, Linux, Cloud VMs)

## 📁 Key File Locations

```
~/.config/home-manager/       # Nix configuration
~/.config/nvim/              # Neovim configuration  
~/.nix-profile/bin/          # Nix-managed binaries
~/.local/share/nvim/lazy/    # LazyVim plugins
~/.local/share/nvim/mason/   # Mason tools
```

## 🔧 Essential Commands

```bash
# Update everything
cd ~/.config/home-manager && home-manager switch

# Update plugins (inside nvim)
:Lazy update

# Rollback if something breaks
home-manager switch --rollback

# Check what's installed
home-manager generations
```

## 🐛 Common Issues

**Flakes disabled:**
```bash
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

**Wrong architecture:**
```bash
uname -m  # Should be arm64 for Apple Silicon
```

**Neovim won't start:**
```bash
nvim --headless "+Lazy! sync" +qa
```

**LSPs missing:**
```bash
which gopls pyright  # Should find them in ~/.nix-profile/bin/
```

## 🎨 Architecture

```
┌────────────────┬─────────────────────┐
│ NIX FOUNDATION │ LAZYVIM EDITOR      │
├────────────────┼─────────────────────┤
│ • Neovim       │ • Plugins           │
│ • LSPs         │ • Themes            │  
│ • CLI tools    │ • Keybindings       │
│ • Dependencies │ • UI components     │
└────────────────┴─────────────────────┘
```

**Versions preserved by:**
- `flake.lock` → Nix packages
- `lazy-lock.json` → LazyVim plugins

---

**Built with ❤️ using Nix, LazyVim, and 42 generations of refinement**