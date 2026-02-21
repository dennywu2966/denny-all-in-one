#!/usr/bin/env bash
# Restore dotfiles from backup
# Usage: ./scripts/restore.sh [--dry-run] [--latest] [<backup_name>]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
BACKUP_BASE="$HOME/.dotfiles-backup"
DRY_RUN=false
USE_LATEST=false
BACKUP_NAME=""

# Log functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_dry() { echo -e "${BLUE}[DRY-RUN]${NC} $1"; }

# Resolve path (compatible with Linux and macOS)
resolve_path() {
    local path="$1"
    if command -v readlink &> /dev/null; then
        # Linux readlink supports -f, macOS doesn't
        if readlink -f /dev/null &> /dev/null 2>&1; then
            readlink -f "$path"
        elif command -v greadlink &> /dev/null; then
            # macOS with coreutils installed
            greadlink -f "$path"
        else
            # Fallback using python
            python3 -c "import os; print(os.path.realpath('$path'))" 2>/dev/null || echo "$path"
        fi
    else
        echo "$path"
    fi
}

# List available backups
list_backups() {
    local backups=()
    if [ -d "$BACKUP_BASE" ]; then
        for dir in "$BACKUP_BASE"/*/; do
            if [ -d "$dir" ]; then
                local name=$(basename "$dir")
                if [ "$name" != "latest" ]; then
                    backups+=("$name")
                fi
            fi
        done
    fi
    printf '%s\n' "${backups[@]}"
}

# Display backups as numbered list
display_backups() {
    local backups=("$@")
    if [ ${#backups[@]} -eq 0 ]; then
        log_error "No backups found in $BACKUP_BASE"
        echo ""
        echo "Create a backup first with:"
        echo "  ./scripts/backup.sh"
        exit 1
    fi

    echo "Available backups:"
    echo ""
    local i=1
    for backup in "${backups[@]}"; do
        local backup_path="$BACKUP_BASE/$backup"
        local size=$(du -sh "$backup_path" 2>/dev/null | cut -f1)
        local date_str=""
        # Try to parse timestamp from backup name (YYYYMMDD_HHMMSS)
        if [[ "$backup" =~ ^([0-9]{8})_([0-9]{6})$ ]]; then
            local date_part="${BASH_REMATCH[1]}"
            local time_part="${BASH_REMATCH[2]}"
            date_str=" (created: ${date_part:0:4}-${date_part:4:2}-${date_part:6:2} ${time_part:0:2}:${time_part:2:2}:${time_part:4:2})"
        fi
        echo -e "  ${CYAN}$i)${NC} $backup${date_str} [${size}]"
        ((i++))
    done
    echo ""
}

# Get user selection
get_selection() {
    local backups=("$@")
    local count=${#backups[@]}

    while true; do
        echo -n "Select backup to restore (1-$count) or 'q' to quit: "
        read -r selection

        if [ "$selection" = "q" ] || [ "$selection" = "Q" ]; then
            log_info "Restore cancelled by user"
            exit 0
        fi

        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "$count" ]; then
            echo "${backups[$((selection-1))]}"
            return 0
        fi

        log_error "Invalid selection. Please enter a number between 1 and $count"
    done
}

# Items to restore (must match backup.sh)
RESTORE_ITEMS=(
    ".claude"
    ".codex"
    "nvim"
    "git"
    "opencode"
    "go"
    "uv"
    ".agents"
    ".scripts"
    ".aliyun"
    ".oss"
    ".bashrc"
    ".profile"
)

# Restore a single item
restore_item() {
    local src="$1"
    local dest="$2"
    local name="$3"

    if [ ! -e "$src" ]; then
        log_warn "Skipped (not in backup): $name"
        return 1
    fi

    if [ "$DRY_RUN" = true ]; then
        if [ -d "$src" ]; then
            log_dry "Would restore directory: $name"
        else
            log_dry "Would restore file: $name"
        fi
        echo "  $src -> $dest"
        return 0
    fi

    # Remove existing file/directory
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        rm -rf "$dest"
    fi

    # Copy from backup
    cp -r "$src" "$dest"

    if [ -d "$dest" ]; then
        log_info "Restored directory: $name"
    else
        log_info "Restored file: $name"
    fi
    return 0
}

# Perform restore
restore_backup() {
    local backup_dir="$1"

    if [ ! -d "$backup_dir" ]; then
        log_error "Backup directory not found: $backup_dir"
        exit 1
    fi

    # Check if backup is empty
    local item_count=$(find "$backup_dir" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
    if [ "$item_count" -eq 0 ]; then
        log_error "Backup directory is empty: $backup_dir"
        exit 1
    fi

    echo ""
    echo "=== Backup Contents ==="
    echo ""

    # Show what will be restored
    local items_to_restore=()
    for item in "${RESTORE_ITEMS[@]}"; do
        local backup_item="$backup_dir/$item"
        if [ -e "$backup_item" ]; then
            local dest_path=""
            case "$item" in
                nvim|git|opencode|go|uv)
                    dest_path="$HOME/.config/$item"
                    ;;
                *)
                    dest_path="$HOME/$item"
                    ;;
            esac
            items_to_restore+=("$item|$backup_item|$dest_path")

            local size=$(du -sh "$backup_item" 2>/dev/null | cut -f1)
            if [ -d "$backup_item" ]; then
                echo "  [DIR]  $item ($size)"
            else
                echo "  [FILE] $item"
            fi
        fi
    done

    if [ ${#items_to_restore[@]} -eq 0 ]; then
        log_error "No valid items found in backup"
        exit 1
    fi

    echo ""
    echo "This will restore ${#items_to_restore[@]} items to your home directory."

    if [ "$DRY_RUN" = true ]; then
        log_dry "Dry-run mode - no changes will be made"
        CONFIRM="y"
    else
        echo ""
        echo -e "${YELLOW}WARNING: This will replace existing files!${NC}"
        echo -n "Continue? (y/N): "
        read -r CONFIRM
    fi

    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        log_info "Restore cancelled by user"
        exit 0
    fi

    echo ""
    echo "Restoring dotfiles..."
    echo ""

    local restored=0
    local skipped=0

    for item_path in "${items_to_restore[@]}"; do
        IFS='|' read -r item src dest <<< "$item_path"
        if restore_item "$src" "$dest" "$item"; then
            ((restored++)) || true
        else
            ((skipped++)) || true
        fi
    done

    echo ""
    echo "=== Summary ==="

    if [ "$DRY_RUN" = true ]; then
        log_dry "Would restore: $restored items"
        log_dry "Would skip: $skipped items"
    else
        log_info "Restored: $restored items"
        log_warn "Skipped: $skipped items"
        echo ""
        log_info "Restore complete!"
    fi
}

# Main function
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run|-n)
                DRY_RUN=true
                shift
                ;;
            --latest|-l)
                USE_LATEST=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS] [<backup_name>]"
                echo ""
                echo "Options:"
                echo "  --dry-run, -n    Preview restore without making changes"
                echo "  --latest, -l     Restore from most recent backup (via 'latest' symlink)"
                echo "  --help, -h       Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                          # Interactive selection"
                echo "  $0 --latest                 # Restore from latest backup"
                echo "  $0 --dry-run --latest       # Preview latest restore"
                echo "  $0 20250121_143022          # Restore specific backup"
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                # Positional argument - backup name
                BACKUP_NAME="$1"
                shift
                ;;
        esac
    done

    echo "=== Dotfiles Restore ==="
    echo ""

    if [ "$DRY_RUN" = true ]; then
        log_dry "Dry-run mode - no changes will be made"
        echo ""
    fi

    # Check if backup directory exists
    if [ ! -d "$BACKUP_BASE" ]; then
        log_error "Backup directory not found: $BACKUP_BASE"
        echo ""
        echo "Create a backup first with:"
        echo "  ./scripts/backup.sh"
        exit 1
    fi

    local backup_dir=""

    # Determine which backup to use
    if [ -n "$BACKUP_NAME" ]; then
        # Specific backup provided
        backup_dir="$BACKUP_BASE/$BACKUP_NAME"
        if [ ! -d "$backup_dir" ]; then
            log_error "Backup not found: $BACKUP_NAME"
            echo ""
            echo "Available backups:"
            list_backups | while read -r line; do
                echo "  $line"
            done
            exit 1
        fi
        log_info "Using specified backup: $BACKUP_NAME"
    elif [ "$USE_LATEST" = true ]; then
        # Use latest symlink
        local latest_link="$BACKUP_BASE/latest"
        if [ ! -L "$latest_link" ] && [ ! -d "$latest_link" ]; then
            log_error "No 'latest' symlink found"
            echo ""
            echo "Create a backup first with:"
            echo "  ./scripts/backup.sh"
            exit 1
        fi
        backup_dir=$(resolve_path "$latest_link")
        log_info "Using latest backup: $(basename "$backup_dir")"
    else
        # Interactive selection
        mapfile -t backups < <(list_backups | sort -r)  # Sort newest first

        if [ ${#backups[@]} -eq 0 ]; then
            log_error "No backups found"
            echo ""
            echo "Create a backup first with:"
            echo "  ./scripts/backup.sh"
            exit 1
        fi

        display_backups "${backups[@]}"
        local selected=$(get_selection "${backups[@]}")
        backup_dir="$BACKUP_BASE/$selected"
        log_info "Selected backup: $selected"
    fi

    # Perform the restore
    restore_backup "$backup_dir"
}

main "$@"
