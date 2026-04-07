# 🚀 Complete macOS Development Environment Setup

> **Reproducible Neovim + LazyVim + Nix/Home Manager configuration for macOS**

This repository contains a production-ready development environment that combines the power of Nix package management with modern Neovim configuration via LazyVim. Everything is declarative, version-controlled, and fully reproducible.

## 🎯 What You Get

- **Neovim 0.11.1** with LazyVim configuration framework
- **30+ modern plugins** with lazy loading for fast startup
- **Complete LSP setup** for TypeScript, Python, Go, Rust, Lua, and more
- **Beautiful UI** with Catppuccin theme and modern components
- **Cross-platform configs** for macOS, Linux, and Cloud VMs
- **Declarative package management** via Nix with exact version pinning
- **42+ generations** of battle-tested configuration evolution

### 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    DUAL MANAGEMENT SYSTEM                   │
├─────────────────────────┬───────────────────────────────────┤
│     NIX FOUNDATION      │        LAZYVIM EDITOR            │
│                         │                                  │
│ • Neovim binary         │ • Plugin management              │
│ • LSPs (gopls, pyright) │ • Themes & UI                    │
│ • System tools          │ • Keybindings                    │
│ • CLI utilities         │ • Editor experience              │
│ • Cross-platform deps   │ • Language features              │
└─────────────────────────┴───────────────────────────────────┘
```

## 📋 System Requirements

- **macOS 15.6.1+** (tested on Apple Silicon arm64)
- **Xcode Command Line Tools**
- **~2GB free space** for Nix store and plugins
- **Internet connection** for initial setup

## 🔧 Complete Installation Guide

### Step 0: Prerequisites

```bash
# Install Xcode Command Line Tools (required for compilation)
xcode-select --install
```

### Step 1: Install Nix Package Manager

```bash
# Install Nix (single-user installation)
curl -L https://nixos.org/nix/install | sh

# Activate Nix in current shell
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# Verify installation
nix --version  # Should show: nix (Nix) 2.28.3
```

### Step 2: Enable Nix Flakes

```bash
# Create Nix config directory
mkdir -p ~/.config/nix

# Enable experimental flakes feature (user-level)
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf

# Alternative: system-level (requires sudo)
# echo 'experimental-features = nix-command flakes' | sudo tee -a /etc/nix/nix.conf
```

### Step 3: Get Configuration Files

**Option A: Clone this repository**
```bash
git clone <your-repo-url> ~/.config/home-manager
```

**Option B: Copy from existing machine**
```bash
# From the source machine, copy the entire config
rsync -avz --progress user@source-machine:~/.config/home-manager/ ~/.config/home-manager/
rsync -avz --progress user@source-machine:~/.config/nvim/ ~/.config/nvim/
```

**Verify you have these files:**
```bash
ls ~/.config/home-manager/
# Should see: flake.nix, flake.lock, home.nix, nvim/default.nix, etc.
```

### Step 4: Activate Home Manager

```bash
# Build and switch to the exact pinned configuration
nix run home-manager/master -- switch --flake ~/.config/home-manager#amoselmaliah

# Verify Home Manager is active
home-manager --version  # Should show: 25.11-pre
```

### Step 5: Verify Core Installation

```bash
# Check that Nix-managed tools are available
which nvim && nvim --version | head -1  # NVIM v0.11.1
which vim && which vi                   # Should point to nvim
which gopls && which pyright            # LSPs should be available

# Verify PATH priority (Nix tools should come first)
echo $PATH | tr ':' '\n' | nl | head -10
# Should see ~/.nix-profile/bin early in the list
```

### Step 6: Bootstrap LazyVim

```bash
# First run will auto-install all plugins and dependencies
nvim

# Or run headless to skip the UI during setup
nvim +qall

# Verify plugins were installed
ls ~/.local/share/nvim/lazy/ | wc -l  # Should show 30+ directories
ls ~/.local/share/nvim/mason/packages/  # Mason-managed tools
```

## 📍 File Locations Reference

### Nix-Managed Components
```
~/.nix-profile/bin/
├── nvim              # Neovim 0.11.1
├── vi, vim          # Aliases to nvim
├── gopls            # Go Language Server
├── pyright          # Python Language Server
├── typescript-language-server  # TS/JS LSP
├── bash-language-server        # Bash LSP
├── lua-language-server         # Lua LSP (from Nix)
└── 100+ other tools  # All your CLI tools
```

### Configuration Files
```
~/.config/home-manager/
├── flake.nix         # Nix flake definition
├── flake.lock        # Exact version pins
├── home.nix          # Main macOS configuration
├── vm/flake.nix      # Linux VM Home Manager flake
└── nvim/default.nix  # Optional Nix neovim module

~/.config/nvim/
├── init.lua          # Main Neovim entry point
├── lazy-lock.json    # Plugin version lockfile
├── lazyvim.json      # LazyVim metadata
└── lua/
    ├── config/       # Core LazyVim configuration
    │   ├── lazy.lua     # Plugin manager setup
    │   ├── options.lua  # Editor options
    │   ├── keymaps.lua  # Keybindings
    │   └── autocmds.lua # Auto commands
    └── plugins/      # Custom plugin configurations
        └── example.lua  # Plugin examples (disabled)
```

### Plugin Storage
```
~/.local/share/nvim/
├── lazy/             # LazyVim plugin installations
│   ├── LazyVim/         # Core framework
│   ├── catppuccin/      # Color scheme
│   ├── blink.cmp/       # Ultra-fast completion
│   ├── nvim-treesitter/ # Syntax highlighting
│   ├── nvim-lspconfig/  # LSP configuration
│   ├── telescope.nvim/  # Fuzzy finder
│   ├── trouble.nvim/    # Diagnostics UI
│   └── ... (30+ more)
├── mason/            # Mason tool installations
│   ├── bin/             # Mason-managed binaries
│   └── packages/        # Individual packages
└── snacks/           # Snacks.nvim data
```

## 🔍 Verification Checklist

After installation, run these commands to verify everything works:

```bash
# ✅ Core versions
nix --version                # nix (Nix) 2.28.3
home-manager --version       # 25.11-pre
nvim --version | head -1     # NVIM v0.11.1

# ✅ PATH priority (Nix should come first)
echo $PATH | tr ':' '\n' | nl | grep nix-profile
# Should show ~/.nix-profile/bin at position 4 or earlier

# ✅ LSPs available
which gopls pyright typescript-language-server bash-language-server

# ✅ Neovim plugins installed
test -d ~/.local/share/nvim/lazy/LazyVim && echo "✅ LazyVim installed"
ls ~/.local/share/nvim/lazy | wc -l  # Should be 30+

# ✅ Mason tools available  
ls ~/.local/share/nvim/mason/bin  # stylua, shfmt, lua-language-server, etc.

# ✅ Shell integration
echo $EDITOR  # Should be "nvim"
```

## 🎨 Key Features Included

### 🚀 Performance
- **Blink.cmp** - Ultra-fast completion engine
- **Lazy loading** - Plugins load only when needed
- **Snacks.nvim** - Modern UI components with better performance
- **Tree-sitter** - Fast syntax highlighting with all grammars

### 🎯 Developer Experience
- **LSP Integration** - Full language server support
- **Mason** - Automatic tool installation and management
- **Telescope** - Powerful fuzzy finder with custom keybindings
- **Gitsigns** - Inline Git integration
- **Trouble** - Beautiful diagnostics and references
- **Flash** - Lightning-fast navigation

### 🎨 Beautiful UI
- **Catppuccin** - Gorgeous modern color scheme
- **Tokyo Night** - Alternative theme
- **Lualine** - Feature-rich status line
- **Bufferline** - Tab management
- **Noice** - Enhanced command line and notifications

### 🛠️ Language Support
- **TypeScript/JavaScript** - Full LSP + formatting
- **Python** - Pyright LSP + tools
- **Go** - gopls + comprehensive tooling  
- **Rust** - rust-analyzer + cargo integration
- **Lua** - Optimized for Neovim development
- **Bash/Shell** - Scripting support
- **JSON/YAML** - Configuration file support
- **Protocol Buffers** - Modern API development

## 🔄 Update Process

### Update Nix Packages
```bash
cd ~/.config/home-manager
nix flake update          # Updates flake.lock
home-manager switch       # Applies updates
```

### Update LazyVim Plugins
```bash
# Inside Neovim
:Lazy update

# Or check status
:Lazy
```

### Rollback if Needed
```bash
# List available generations
home-manager generations

# Rollback to previous generation
/nix/store/xxx-home-manager-generation/activate

# Or rollback by number
home-manager switch --rollback
```

## 🐛 Troubleshooting

### Common Issues

**1. Flakes not enabled**
```
error: experimental Nix feature 'flakes' is disabled
```
**Fix:**
```bash
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

**2. Architecture mismatch**
```
error: unable to download 'https://...' : Unsupported platform
```
**Fix:** Ensure you're on Apple Silicon:
```bash
uname -m  # Should show: arm64
```

**3. Neovim doesn't start**
**Fix:** Check LazyVim installation:
```bash
nvim --headless "+Lazy! sync" +qa
```

**4. LSPs not working**
**Fix:** Verify PATH and restart Neovim:
```bash
which gopls pyright typescript-language-server
# Inside nvim: :LspInfo
```

**5. Permission denied on macOS**
**Fix:** Grant Full Disk Access to Terminal in System Preferences

## 🔗 Cross-Platform Support

This configuration supports multiple environments:

- **macOS** (primary) - `home.nix`
- **Linux servers** - `home-linux.nix`  
- **Google Cloud VMs** - `gcloud-vm.nix`

Switch configurations:
```bash
# For Linux
home-manager switch --flake ~/.config/home-manager#linux

# For GCloud VM  
home-manager switch --flake ~/.config/home-manager#gcloud-vm
```

## 🏗️ Customization

### Adding New Packages
Edit `home.nix` and add to the `home.packages` list:
```nix
home.packages = with pkgs; [
  # Add your package here
  ripgrep
  fd
];
```

### Adding LazyVim Plugins
Create files in `~/.config/nvim/lua/plugins/`:
```lua
-- ~/.config/nvim/lua/plugins/my-plugin.lua
return {
  "author/plugin-name",
  config = function()
    -- Plugin configuration
  end,
}
```

### Environment Variables
Edit `home.nix` and modify `home.sessionVariables`:
```nix
home.sessionVariables = {
  EDITOR = "nvim";
  MY_VAR = "my_value";
};
```

## 🎯 One-Shot Bootstrap Script

Save as `bootstrap.sh` for future installations:

```bash
#!/bin/bash
set -euo pipefail

echo "🚀 Starting macOS Development Environment Setup..."

# Prerequisites
echo "📋 Installing Xcode Command Line Tools..."
xcode-select --install 2>/dev/null || echo "Already installed"

# Install Nix
if ! command -v nix >/dev/null 2>&1; then
    echo "📦 Installing Nix..."
    curl -L https://nixos.org/nix/install | sh
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# Enable flakes
echo "🔧 Enabling Nix flakes..."
mkdir -p ~/.config/nix
if ! grep -q 'flakes' ~/.config/nix/nix.conf 2>/dev/null; then
    echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
fi

# Get configs (update this with your repo URL)
echo "📥 Getting configuration files..."
if [ ! -d ~/.config/home-manager ]; then
    echo "Please clone your dotfiles repo to ~/.config/home-manager"
    exit 1
fi

# Activate Home Manager
echo "🏠 Activating Home Manager..."
nix run home-manager/master -- switch --flake ~/.config/home-manager#amoselmaliah

# Bootstrap Neovim
echo "⚡ Bootstrapping Neovim..."
nvim --headless "+Lazy! sync" +qa 2>/dev/null || true

echo "✅ Setup complete!"
echo ""
echo "🔍 Verification commands:"
echo "  nix --version"
echo "  home-manager --version" 
echo "  nvim --version"
echo ""
echo "🎯 Try: nvim ~/.config/nvim/init.lua"
```

## 📚 Resources

- [LazyVim Documentation](https://lazyvim.github.io/LazyVim/)
- [Nix Package Manager](https://nixos.org/manual/nix/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Neovim Documentation](https://neovim.io/doc/)

## 🤝 Contributing

This configuration has evolved through 42+ generations. To contribute:

1. Test changes in a VM or separate profile
2. Update relevant documentation
3. Ensure cross-platform compatibility
4. Submit PRs with clear descriptions

---

**Built with ❤️ using Nix, LazyVim, and 42 generations of refinement**

*Last updated: 2025-01-07*
