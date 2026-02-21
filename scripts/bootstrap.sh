#!/usr/bin/env bash
# Bootstrap script for denny-all-in-one dotfiles
# Usage: curl -fsSL https://raw.githubusercontent.com/dennywu2966/denny-all-in-one/master/scripts/bootstrap.sh | bash

set -euo pipefail

# Parse arguments
BACKUP_FIRST=false
for arg in "$@"; do
    case "$arg" in
        --backup)
            BACKUP_FIRST=true
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Detect OS
detect_os() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
  else
    log_error "Unsupported OS: $OSTYPE"
    exit 1
  fi
  log_info "Detected OS: $OS"
}

# Install chezmoi if not present
install_chezmoi() {
  if command -v chezmoi &>/dev/null; then
    log_info "chezmoi already installed: $(chezmoi --version)"
    return
  fi

  log_info "Installing chezmoi..."
  if [[ "$OS" == "linux" ]]; then
    curl -fsSL https://chezmoi.io/get | bash
  elif [[ "$OS" == "macos" ]]; then
    if command -v brew &>/dev/null; then
      brew install chezmoi
    else
      curl -fsSL https://chezmoi.io/get | bash
    fi
  fi
}

# Clone or update dotfiles repo
setup_dotfiles() {
  local REPO_URL="${1:-https://github.com/dennywu2966/denny-all-in-one.git}"
  local REPO_DIR="$HOME/.local/share/denny-all-in-one"

  if [[ -d "$REPO_DIR" ]]; then
    log_info "Updating existing dotfiles..."
    cd "$REPO_DIR"
    git pull
  else
    log_info "Cloning dotfiles repository..."
    mkdir -p "$HOME/.local/share"
    git clone "$REPO_URL" "$REPO_DIR"
  fi
}

# Initialize chezmoi with the repo
init_chezmoi() {
  local REPO_DIR="$HOME/.local/share/denny-all-in-one"

  log_info "Initializing chezmoi..."
  chezmoi init --source="$REPO_DIR"

  # Prompt for user-specific data
  log_info "Enter optional configuration (press Enter to skip):"
  read -rp "Git email [optional]: " EMAIL
  read -rp "Default editor [vim]: " EDITOR

  # Apply with optional data
  if [[ -n "$EMAIL" ]]; then
    chezmoi apply --source="$REPO_DIR" --prompt --data email="$EMAIL" --data editor="${EDITOR:-vim}"
  else
    chezmoi apply --source="$REPO_DIR" --prompt --data editor="${EDITOR:-vim}"
  fi
}

# Run post-apply checks
post_apply() {
  log_info "Running post-apply checks..."

  # Check if Claude Code is configured
  if [[ -f "$HOME/.claude/settings.json" ]]; then
    log_info "✓ Claude Code settings applied"
  else
    log_warn "✗ Claude Code settings not found"
  fi

  # Check if Codex is configured
  if [[ -f "$HOME/.codex/config.toml" ]]; then
    log_info "✓ Codex config applied"
  else
    log_warn "✗ Codex config not found"
  fi

  # Check if nvim is configured
  if [[ -d "$HOME/.config/nvim" ]]; then
    log_info "✓ Neovim config applied"
  else
    log_warn "✗ Neovim config not found"
  fi
}

# Run backup if requested
run_backup() {
  if [[ "$BACKUP_FIRST" == "true" ]]; then
    log_info "Creating backup before applying dotfiles..."
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    bash "$SCRIPT_DIR/backup.sh"
    echo ""
  fi
}

# Main execution
main() {
  log_info "Starting denny-all-in-one bootstrap..."
  detect_os
  run_backup
  install_chezmoi
  setup_dotfiles "$@"
  init_chezmoi
  post_apply

  log_info "Bootstrap complete! Restart your shell or run: source ~/.bashrc"
}

# Run main with any arguments (e.g., custom repo URL)
main "$@"
