#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}INFO $1${NC}"; }
log_success() { echo -e "${GREEN}OK $1${NC}"; }
log_warning() { echo -e "${YELLOW}WARN $1${NC}"; }
log_error() { echo -e "${RED}ERR $1${NC}"; }

run_with_timeout() {
    local seconds="$1"
    shift

    if command -v timeout >/dev/null 2>&1; then
        timeout "$seconds" "$@"
        return $?
    fi

    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$seconds" "$@"
        return $?
    fi

    "$@" &
    local cmd_pid=$!
    (
        sleep "$seconds"
        kill "$cmd_pid" >/dev/null 2>&1 || true
    ) &
    local timer_pid=$!

    wait "$cmd_pid"
    local cmd_status=$?
    kill "$timer_pid" >/dev/null 2>&1 || true
    wait "$timer_pid" 2>/dev/null || true
    return "$cmd_status"
}

REPO_URL="${DOTFILES_REPO_URL:-}"
USERNAME="amoselmaliah"

main() {
    log_info "Starting macOS Development Environment Setup..."
    log_info "Target: modular Home Manager baseline for daily development work"
    echo

    check_requirements
    install_xcode_tools
    install_nix
    enable_nix_flakes
    get_configurations
    install_homebrew
    activate_home_manager
    verify_installation
    show_completion
}

check_requirements() {
    log_info "Checking system requirements..."

    if ! sw_vers | grep -q "macOS"; then
        log_error "This script requires macOS"
        exit 1
    fi

    if [[ "$(uname -m)" != "arm64" ]]; then
        log_warning "This configuration is optimized for Apple Silicon (arm64)"
        log_warning "Current architecture: $(uname -m)"
    fi

    available_space=$(df -g "$HOME" | awk 'NR==2 {print $4}')
    if [[ -n "$available_space" && "$available_space" -lt 3 ]]; then
        log_warning "Low disk space detected. Nix store and tools require several GB."
    fi

    log_success "System requirements check completed"
}

install_xcode_tools() {
    log_info "Installing Xcode Command Line Tools..."

    if xcode-select -p >/dev/null 2>&1; then
        log_success "Xcode Command Line Tools already installed"
    else
        log_info "Installing Xcode Command Line Tools. Complete the macOS prompt."
        xcode-select --install

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

        if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
            . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        fi

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
        if [[ -d ~/.config/home-manager ]] && [[ -f ~/.config/home-manager/flake.nix ]]; then
            log_success "Configuration files already present"
        else
            log_error "Configuration files not found"
            echo
            log_info "Set DOTFILES_REPO_URL and rerun:"
            log_info "  export DOTFILES_REPO_URL='https://github.com/yourname/dotfiles.git'"
            log_info "  ./bootstrap.sh"
            echo
            log_info "Or manually place this repo at ~/.config/home-manager/"
            exit 1
        fi
    fi

    local required_files=(
        "~/.config/home-manager/flake.nix"
        "~/.config/home-manager/flake.lock"
        "~/.config/home-manager/home.nix"
        "~/.config/home-manager/modules/packages.nix"
        "~/.config/home-manager/modules/shell.nix"
        "~/.config/home-manager/modules/git.nix"
        "~/.config/home-manager/modules/editor.nix"
        "~/.config/home-manager/modules/ai.nix"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f ${file/\~/$HOME} ]]; then
            log_error "Required file missing: $file"
            exit 1
        fi
    done

    log_success "All required configuration files present"
}

install_homebrew() {
    log_info "Installing Homebrew..."

    if command -v brew >/dev/null 2>&1; then
        log_success "Homebrew already installed ($(brew --version | head -1))"
    else
        log_info "Downloading and installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
        log_success "Homebrew installed successfully"
    fi

    local brewfile="$HOME/.config/home-manager/Brewfile"
    if [[ -f "$brewfile" ]]; then
        log_info "Installing Homebrew packages from Brewfile..."
        if brew bundle --file="$brewfile" --no-lock; then
            log_success "Homebrew packages installed"
        else
            log_warning "Some Brewfile entries failed; review brew output"
        fi
    else
        log_warning "No Brewfile found at $brewfile, skipping brew bundle"
    fi
}

activate_home_manager() {
    log_info "Activating Home Manager configuration..."
    log_info "This may take several minutes on first run as Nix downloads packages..."

    if nix run github:nix-community/home-manager -- switch --flake ~/.config/home-manager#$USERNAME; then
        log_success "Home Manager activated successfully"

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

verify_installation() {
    log_info "Verifying installation..."
    echo

    if ! run_with_timeout 300 ~/.config/home-manager/scripts/verify.sh; then
        log_warning "Verification reported issues; review output above"
    fi
}

show_completion() {
    echo
    log_success "Installation completed"
    echo
    echo "Quick Start:"
    echo "  - Launch Neovim: nvim"
    echo "  - Review this config: nvim ~/.config/home-manager/home.nix"
    echo "  - Verify the machine: ~/.config/home-manager/scripts/verify.sh"
    echo "  - Update packages: home-manager switch --flake ~/.config/home-manager#${USERNAME}"
    echo
    echo "Verification commands:"
    echo "  - nix --version"
    echo "  - home-manager --version"
    echo "  - nvim --version"
    echo "  - gh auth status"
    echo
    echo "Need help?"
    echo "  - Check README.md in ~/.config/home-manager/"
    echo "  - Rollback if needed: home-manager switch --rollback"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
