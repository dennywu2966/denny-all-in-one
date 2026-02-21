#!/usr/bin/env bash
# Backup dotfiles before applying new configs
# Usage: ./scripts/backup.sh [--dry-run]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKUP_BASE="$HOME/.dotfiles-backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DRY_RUN=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run]"
            echo ""
            echo "Options:"
            echo "  --dry-run, -n    Preview backup without making changes"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
    esac
done

# Log functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_dry() { echo -e "${BLUE}[DRY-RUN]${NC} $1"; }

# Backup item function
backup_item() {
    local src="$1"
    local dest_dir="$2"
    local name="$3"

    if [ -e "$src" ]; then
        if [ "$DRY_RUN" = true ]; then
            if [ -d "$src" ]; then
                log_dry "Would backup directory: $name ($(du -sh "$src" 2>/dev/null | cut -f1))"
            else
                log_dry "Would backup file: $name"
            fi
            echo "  $src -> $dest_dir/$name"
            return 0
        else
            mkdir -p "$dest_dir"
            cp -r "$src" "$dest_dir/$name"
            if [ -d "$src" ]; then
                log_info "Backed up directory: $name ($(du -sh "$dest_dir/$name" 2>/dev/null | cut -f1))"
            else
                log_info "Backed up file: $name"
            fi
            return 0
        fi
    else
        log_warn "Skipped (not found): $name"
        return 1
    fi
}

# Paths to backup (relative to $HOME)
BACKUP_PATHS=(
    ".claude"
    ".codex"
    ".config/nvim"
    ".config/git"
    ".config/opencode"
    ".config/go"
    ".config/uv"
    ".agents"
    ".scripts"
    ".aliyun"
    ".oss"
    ".ssh"
    ".bashrc"
    ".profile"
)

echo "=== Dotfiles Backup ==="
echo ""

if [ "$DRY_RUN" = true ]; then
    log_dry "Dry-run mode - no changes will be made"
    echo ""
fi

BACKUP_DIR="$BACKUP_BASE/$TIMESTAMP"

if [ "$DRY_RUN" = false ]; then
    mkdir -p "$BACKUP_DIR"
    log_info "Created backup directory: $BACKUP_DIR"
fi

# Counters
backed_up=0
skipped=0

echo ""
echo "Backing up dotfiles..."
echo ""

for path in "${BACKUP_PATHS[@]}"; do
    src="$HOME/$path"
    if backup_item "$src" "$BACKUP_DIR" "$(basename "$path")"; then
        ((backed_up++)) || true
    else
        ((skipped++)) || true
    fi
done

echo ""

if [ "$DRY_RUN" = false ]; then
    # Create/update 'latest' symlink
    LATEST_LINK="$BACKUP_BASE/latest"
    if [ -L "$LATEST_LINK" ] || [ -e "$LATEST_LINK" ]; then
        rm -f "$LATEST_LINK"
    fi
    ln -s "$BACKUP_DIR" "$LATEST_LINK"
    log_info "Updated 'latest' symlink"
fi

# Summary
echo "=== Summary ==="
if [ "$DRY_RUN" = true ]; then
    log_dry "Would backup: $backed_up items"
    log_dry "Would skip: $skipped items (not found)"
else
    log_info "Backed up: $backed_up items"
    log_warn "Skipped: $skipped items (not found)"
    echo ""
    log_info "Backup location: $BACKUP_DIR"
    log_info "Latest backup symlink: $BACKUP_BASE/latest"
fi

echo ""
if [ "$DRY_RUN" = false ]; then
    echo "To restore from backup:"
    echo "  cp -r $BACKUP_BASE/latest/* \$HOME/"
fi
