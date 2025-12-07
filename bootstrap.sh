#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Configuration
REPO_URL="${DOTFILES_REPO_URL:-}" # Set this environment variable or update below
USERNAME="amoselmaliah"

main() {
    log_info "Starting macOS Development Environment Setup..."
    log_info "Target: Neovim 0.11.1 + LazyVim + Nix/Home Manager"
    echo

    # Check system requirements
    check_requirements
    
    # Install prerequisites
    install_xcode_tools
    
    # Install and configure Nix
    install_nix
    enable_nix_flakes
    
    # Get configuration files
    get_configurations
    
    # Activate Home Manager
    activate_home_manager
    
    # Bootstrap Neovim
    bootstrap_neovim
    
    # Verify installation
    verify_installation
    
    # Show completion message
    show_completion
}

check_requirements() {
    log_info "Checking system requirements..."
    
    # Check macOS version
    if ! sw_vers | grep -q "macOS"; then
        log_error "This script requires macOS"
        exit 1
    fi
    
    # Check architecture
    if [[ "$(uname -m)" != "arm64" ]]; then
        log_warning "This configuration is optimized for Apple Silicon (arm64)"
        log_warning "You're running on $(uname -m) - some packages may not be available"
    fi
    
    # Check free space (rough estimate)
    available_space=$(df -BG "$HOME" | tail -1 | awk '{print $4}' | sed 's/G//')
    if [[ $available_space -lt 3 ]]; then
        log_warning "Low disk space detected. Nix store and plugins require ~2GB"
    fi
    
    log_success "System requirements check completed"
}

install_xcode_tools() {
    log_info "Installing Xcode Command Line Tools..."
    
    if xcode-select -p >/dev/null 2>&1; then
        log_success "Xcode Command Line Tools already installed"
    else
        log_info "Installing Xcode Command Line Tools (this may take a while)..."
        xcode-select --install
        
        # Wait for installation to complete
        log_info "Waiting for Xcode Command Line Tools installation to complete..."
        until xcode-select -p >/dev/null 2>&1; do
            sleep 5
        done
        log_success "Xcode Command Line Tools installed successfully"
    fi
}

install_nix() {
    log_info "Installing Nix package manager..."
    
    if command -v nix >/dev/null 2>&1; then
        log_success "Nix already installed ($(nix --version))"
    else
        log_info "Downloading and installing Nix..."
        curl -L https://nixos.org/nix/install | sh
        
        # Source Nix in current shell
        if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
            . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        fi
        
        # Verify installation
        if command -v nix >/dev/null 2>&1; then
            log_success "Nix installed successfully ($(nix --version))"
        else
            log_error "Nix installation failed"
            exit 1
        fi
    fi
}

enable_nix_flakes() {
    log_info "Enabling Nix flakes..."
    
    mkdir -p ~/.config/nix
    
    if grep -q "experimental-features.*flakes" ~/.config/nix/nix.conf 2>/dev/null; then
        log_success "Nix flakes already enabled"
    else
        echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
        log_success "Nix flakes enabled"
    fi
}

get_configurations() {
    log_info "Getting configuration files..."
    
    if [[ -n "$REPO_URL" ]]; then
        # Clone from repository
        if [[ -d ~/.config/home-manager ]]; then
            log_info "Configuration directory exists, pulling latest changes..."
            cd ~/.config/home-manager
            git pull || log_warning "Failed to pull latest changes, continuing with existing config"
        else
            log_info "Cloning configuration repository..."
            git clone "$REPO_URL" ~/.config/home-manager
            log_success "Configuration repository cloned"
        fi
    else
        # Check if config already exists
        if [[ -d ~/.config/home-manager ]] && [[ -f ~/.config/home-manager/flake.nix ]]; then
            log_success "Configuration files already present"
        else
            log_error "Configuration files not found!"
            echo
            log_info "Please either:"
            log_info "1. Set DOTFILES_REPO_URL environment variable and re-run:"
            log_info "   export DOTFILES_REPO_URL='https://github.com/yourname/dotfiles.git'"
            log_info "   ./bootstrap.sh"
            echo
            log_info "2. Or manually copy configuration files:"
            log_info "   rsync -avz user@source-machine:~/.config/home-manager/ ~/.config/home-manager/"
            log_info "   rsync -avz user@source-machine:~/.config/nvim/ ~/.config/nvim/"
            exit 1
        fi
    fi
    
    # Verify essential files
    local required_files=(
        "~/.config/home-manager/flake.nix"
        "~/.config/home-manager/flake.lock"
        "~/.config/home-manager/home.nix"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f ${file/\~/$HOME} ]]; then
            log_error "Required file missing: $file"
            exit 1
        fi
    done
    
    log_success "All required configuration files present"
}

activate_home_manager() {
    log_info "Activating Home Manager configuration..."
    
    # First time setup may take a while
    log_info "This may take several minutes on first run as Nix downloads packages..."
    
    if nix run home-manager/master -- switch --flake ~/.config/home-manager#$USERNAME; then
        log_success "Home Manager activated successfully"
        
        # Verify Home Manager is working
        if command -v home-manager >/dev/null 2>&1; then
            log_success "Home Manager available ($(home-manager --version))"
        else
            log_warning "Home Manager command not found in PATH, but activation succeeded"
        fi
    else
        log_error "Home Manager activation failed"
        log_info "Common fixes:"
        log_info "- Ensure flake.nix has the correct username in homeConfigurations"
        log_info "- Check that all required files are present"
        log_info "- Try running: nix flake check ~/.config/home-manager"
        exit 1
    fi
}

bootstrap_neovim() {
    log_info "Bootstrapping Neovim and LazyVim..."
    
    # Check if nvim config exists, if not copy it
    if [[ ! -d ~/.config/nvim ]]; then
        if [[ -n "$REPO_URL" ]] && [[ -d ~/.config/home-manager/nvim-config ]]; then
            log_info "Copying Neovim configuration from repository..."
            cp -r ~/.config/home-manager/nvim-config ~/.config/nvim
        else
            log_warning "Neovim configuration not found at ~/.config/nvim"
            log_info "LazyVim will use default configuration"
        fi
    fi
    
    # Bootstrap LazyVim (headless installation)
    log_info "Installing LazyVim plugins (this may take a few minutes)..."
    
    if timeout 300 nvim --headless "+Lazy! sync" +qa 2>/dev/null; then
        log_success "LazyVim plugins installed successfully"
    else
        log_warning "LazyVim plugin installation may have failed or timed out"
        log_info "You can manually run ':Lazy sync' inside Neovim later"
    fi
    
    # Verify plugin installation
    if [[ -d ~/.local/share/nvim/lazy ]] && [[ $(ls ~/.local/share/nvim/lazy | wc -l) -gt 20 ]]; then
        plugin_count=$(ls ~/.local/share/nvim/lazy | wc -l)
        log_success "LazyVim plugins installed: $plugin_count plugins"
    else
        log_warning "Plugin installation verification failed"
    fi
}

verify_installation() {
    log_info "Verifying installation..."
    echo
    
    # Check core tools
    echo "📋 Core Tools:"
    for cmd in nix home-manager nvim; do
        if command -v "$cmd" >/dev/null 2>&1; then
            version=$($cmd --version 2>/dev/null | head -1 || echo "unknown")
            printf "  ✅ %-15s %s\n" "$cmd" "$version"
        else
            printf "  ❌ %-15s %s\n" "$cmd" "not found"
        fi
    done
    echo
    
    # Check LSPs
    echo "🔧 Language Servers:"
    for lsp in gopls pyright typescript-language-server bash-language-server lua-language-server; do
        if command -v "$lsp" >/dev/null 2>&1; then
            printf "  ✅ %-25s available\n" "$lsp"
        else
            printf "  ⚠️  %-25s not found\n" "$lsp"
        fi
    done
    echo
    
    # Check PATH priority
    echo "🛤️  PATH Priority:"
    nix_profile_pos=$(echo "$PATH" | tr ':' '\n' | nl | grep nix-profile | head -1 | awk '{print $1}')
    if [[ -n "$nix_profile_pos" ]] && [[ "$nix_profile_pos" -le 5 ]]; then
        printf "  ✅ ~/.nix-profile/bin at position %d (good)\n" "$nix_profile_pos"
    else
        printf "  ⚠️  ~/.nix-profile/bin not found in early PATH positions\n"
    fi
    echo
    
    # Check Neovim setup
    echo "⚡ Neovim Setup:"
    if [[ "$EDITOR" == "nvim" ]]; then
        printf "  ✅ %-20s %s\n" "EDITOR" "$EDITOR"
    else
        printf "  ⚠️  %-20s %s (expected: nvim)\n" "EDITOR" "${EDITOR:-not set}"
    fi
    
    if [[ -d ~/.local/share/nvim/lazy/LazyVim ]]; then
        printf "  ✅ %-20s installed\n" "LazyVim"
    else
        printf "  ❌ %-20s not found\n" "LazyVim"
    fi
    
    if [[ -d ~/.local/share/nvim/mason/bin ]] && [[ $(ls ~/.local/share/nvim/mason/bin | wc -l) -gt 0 ]]; then
        mason_tools=$(ls ~/.local/share/nvim/mason/bin | wc -l)
        printf "  ✅ %-20s %d tools\n" "Mason tools" "$mason_tools"
    else
        printf "  ⚠️  %-20s no tools found\n" "Mason tools"
    fi
}

show_completion() {
    echo
    log_success "🎉 Installation completed!"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "🚀 Your development environment is ready!"
    echo
    echo "📝 Quick Start:"
    echo "  • Launch Neovim: nvim"
    echo "  • Edit this config: nvim ~/.config/nvim/init.lua"
    echo "  • Manage plugins: :Lazy (inside Neovim)"
    echo "  • Update packages: home-manager switch"
    echo
    echo "🔍 Verification commands:"
    echo "  • nix --version"
    echo "  • home-manager --version"
    echo "  • nvim --version"
    echo
    echo "🆘 Need help?"
    echo "  • Check README.md in ~/.config/home-manager/"
    echo "  • View LazyVim docs: https://lazyvim.github.io/"
    echo "  • Rollback if needed: home-manager switch --rollback"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    log_info "Enjoy your new development environment! 🎯"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi