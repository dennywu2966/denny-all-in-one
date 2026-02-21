#!/usr/bin/env bash
# Bootstrap script for denny-all-in-one dotfiles
# Usage: curl -fsSL https://raw.githubusercontent.com/dennywu2966/denny-all-in-one/master/scripts/bootstrap.sh | bash

set -euo pipefail

# Ensure ~/bin is in PATH (chezmoi installs here)
export PATH="$HOME/bin:$PATH"

# Parse arguments
BACKUP_FIRST=""
LOCAL_MODE=false
REPO_URL="https://github.com/dennywu2966/denny-all-in-one.git"
for arg in "$@"; do
    case "$arg" in
        --backup)
            BACKUP_FIRST="yes"
            ;;
        --no-backup)
            BACKUP_FIRST="no"
            ;;
        --local)
            LOCAL_MODE=true
            ;;
        *)
            # Assume it's a repo URL
            REPO_URL="$arg"
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

  # Check if chezmoi was installed to ~/bin but not in PATH
  if [[ -x "$HOME/bin/chezmoi" ]]; then
    export PATH="$HOME/bin:$PATH"
    log_info "chezmoi already installed: $(chezmoi --version)"
    return
  fi

  # Check if chezmoi was installed to /usr/bin (root installation)
  if [[ -x "/usr/bin/chezmoi" ]]; then
    log_info "chezmoi already installed: $(/usr/bin/chezmoi --version)"
    return
  fi

  log_info "Installing chezmoi..."
  # Change to home directory to avoid permission issues with read-only mounts
  local ORIGINAL_DIR="$(pwd)"
  cd "$HOME"

  if [[ "$OS" == "linux" ]]; then
    curl -fsSL https://chezmoi.io/get | bash
    export PATH="$HOME/bin:$PATH"
  elif [[ "$OS" == "macos" ]]; then
    if command -v brew &>/dev/null; then
      brew install chezmoi
    else
      curl -fsSL https://chezmoi.io/get | bash
      export PATH="$HOME/bin:$PATH"
    fi
  fi

  cd "$ORIGINAL_DIR"
}

# Clone or update dotfiles repo (optional - chezmoi can do this directly)
setup_dotfiles() {
  # This function is now optional - chezmoi init can clone directly
  # Keeping for backwards compatibility
  local REPO_URL="${1:-https://github.com/dennywu2966/denny-all-in-one.git}"
  log_info "Will use chezmoi to clone: $REPO_URL"
}

# Initialize chezmoi with the repo
init_chezmoi() {
  # Find chezmoi binary (check common locations)
  local CHEZMOI=""
  if [[ -x "$HOME/bin/chezmoi" ]]; then
    CHEZMOI="$HOME/bin/chezmoi"
  elif [[ -x "/usr/bin/chezmoi" ]]; then
    CHEZMOI="/usr/bin/chezmoi"
  elif [[ -x "/usr/local/bin/chezmoi" ]]; then
    CHEZMOI="/usr/local/bin/chezmoi"
  elif command -v chezmoi &>/dev/null; then
    CHEZMOI="chezmoi"
  else
    log_error "chezmoi not found. Please install it manually."
    exit 1
  fi

  log_info "Initializing chezmoi with: $CHEZMOI"

  if [[ "$LOCAL_MODE" == "true" ]]; then
    # Local mode: copy from mounted directory
    local SOURCE_DIR="/dotfiles"
    if [[ ! -d "$SOURCE_DIR" ]]; then
      log_error "Local mode requires /dotfiles mount"
      exit 1
    fi
    log_info "Using local source: $SOURCE_DIR"

    # Create chezmoi source directory
    mkdir -p "$HOME/.local/share/chezmoi"

    # Copy all files from source to chezmoi directory
    # Skip .git directory to save space
    cp -r "$SOURCE_DIR"/* "$HOME/.local/share/chezmoi/"
    cp "$SOURCE_DIR"/.chezmoi* "$HOME/.local/share/chezmoi/" 2>/dev/null || true
    cp "$SOURCE_DIR"/.gitignore "$HOME/.local/share/chezmoi/" 2>/dev/null || true

    # Initialize chezmoi config
    $CHEZMOI init
  else
    # Remote mode: clone from git
    log_info "Cloning dotfiles from: $REPO_URL"
    $CHEZMOI init "$REPO_URL"
  fi

  # Apply the dotfiles
  log_info "Applying dotfiles..."
  $CHEZMOI apply -v
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
  # If --backup was explicitly passed, run backup without prompting
  if [[ "$BACKUP_FIRST" == "yes" ]]; then
    log_info "Creating backup before applying dotfiles..."
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    bash "$SCRIPT_DIR/backup.sh"
    echo ""
    return
  fi

  # If --no-backup was passed, skip backup
  if [[ "$BACKUP_FIRST" == "no" ]]; then
    log_info "Skipping backup (--no-backup specified)"
    return
  fi

  # Check if running interactively
  if [[ ! -t 0 ]]; then
    log_info "Non-interactive mode - skipping backup (use --backup to force)"
    return
  fi

  # Prompt user for backup
  echo ""
  log_warn "About to apply dotfiles which may overwrite existing configurations."
  echo ""
  read -rp "Create a backup first? [Y/n]: " response
  case "$response" in
    [nN][oO]|[nN])
      log_info "Skipping backup..."
      ;;
    *)
      log_info "Creating backup before applying dotfiles..."
      local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
      bash "$SCRIPT_DIR/backup.sh"
      echo ""
      ;;
  esac
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
