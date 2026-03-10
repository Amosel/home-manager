#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { printf "  ${GREEN}OK %-24s${NC} %s\n" "$1" "$2"; }
warn() { printf "  ${YELLOW}!! %-24s${NC} %s\n" "$1" "$2"; WARNINGS=$((WARNINGS + 1)); }
fail() { printf "  ${RED}XX %-24s${NC} %s\n" "$1" "$2"; ERRORS=$((ERRORS + 1)); }

ERRORS=0
WARNINGS=0

section() { printf "\n%s\n" "$1"; }

check_cmd() {
    local label="$1"
    local bin="$2"
    if command -v "$bin" >/dev/null 2>&1; then
        ok "$label" "$(command -v "$bin")"
    else
        fail "$label" "not found"
    fi
}

check_optional_cmd() {
    local label="$1"
    local bin="$2"
    if command -v "$bin" >/dev/null 2>&1; then
        ok "$label" "$(command -v "$bin")"
    else
        warn "$label" "not found"
    fi
}

section "Core"
for cmd in nix home-manager nvim git gh tmux; do
    check_cmd "$cmd" "$cmd"
done

section "Repo"
for f in flake.nix flake.lock home.nix modules packages.nix; do
    case "$f" in
        packages.nix)
            path="$HOME/.config/home-manager/modules/packages.nix"
            ;;
        *)
            path="$HOME/.config/home-manager/$f"
            ;;
    esac

    if [[ -e "$path" ]]; then
        ok "$f" "present"
    else
        fail "$f" "missing"
    fi
done

section "Shell"
for cmd in zsh bash starship eza bat zoxide just delta fzf rg fd; do
    check_cmd "$cmd" "$cmd"
done

if [[ "${EDITOR:-}" == "nvim" ]]; then
    ok "EDITOR" "nvim"
else
    warn "EDITOR" "${EDITOR:-not set}"
fi

section "Language Tools"
for cmd in nixd nil gopls pyright typescript-language-server bash-language-server lua-language-server rust-analyzer yaml-language-server protobuf-language-server stylua shfmt alejandra; do
    check_optional_cmd "$cmd" "$cmd"
done

section "Codex"
if [[ -f "$HOME/.codex/skills/home-manager-review/SKILL.md" ]]; then
    ok "home-manager-review" "installed"
else
    warn "home-manager-review" "run home-manager switch to install"
fi

section "Neovim"
if nvim --headless +qall >/dev/null 2>&1; then
    ok "headless start" "ok"
else
    fail "headless start" "nvim failed to start"
fi

section "Summary"
if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
    printf "${GREEN}All checks passed.${NC}\n"
elif [[ $ERRORS -eq 0 ]]; then
    printf "${YELLOW}%s warning(s), no errors.${NC}\n" "$WARNINGS"
else
    printf "${RED}%s error(s), %s warning(s).${NC}\n" "$ERRORS" "$WARNINGS"
    exit 1
fi
