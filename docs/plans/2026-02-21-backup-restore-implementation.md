# Backup and Restore Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add backup.sh and restore.sh scripts to safely backup and restore dotfiles configurations alongside chezmoi.

**Architecture:** Two standalone bash scripts that create timestamped backup directories under ~/.dotfiles-backup/. backup.sh copies existing configs before chezmoi apply; restore.sh provides interactive restore with selection menu.

**Tech Stack:** Bash, standard Unix tools (cp, tar, ln), compatible with Linux and macOS

---

## Task 1: Create backup.sh Script

**Files:**
- Create: `scripts/backup.sh`

**Step 1: Create backup.sh with header and configuration**

```bash
#!/usr/bin/env bash
# Backup existing dotfiles configurations
# Usage: ./scripts/backup.sh [--dry-run]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="$HOME/.dotfiles-backup"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"
DRY_RUN=false

# Parse arguments
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# Paths to backup (relative to $HOME)
PATHS_TO_BACKUP=(
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
    ".bashrc"
    ".profile"
)
```

**Step 2: Add helper functions**

```bash
# Helper functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_dry() { echo -e "${BLUE}[DRY-RUN]${NC} $1"; }

backup_item() {
    local src="$1"
    local dest="$2"

    if [[ ! -e "$src" ]]; then
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry "Would backup: $src"
        return 0
    fi

    mkdir -p "$(dirname "$dest")"
    cp -r "$src" "$dest"
    return 0
}
```

**Step 3: Add main backup logic**

```bash
# Main backup function
main() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run mode - no changes will be made"
        echo ""
    fi

    log_info "Starting backup..."
    log_info "Backup location: $BACKUP_PATH"
    echo ""

    # Create backup directory
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$BACKUP_PATH"
    fi

    # Track what was backed up
    local backed_up=0
    local skipped=0

    # Backup each path
    for path in "${PATHS_TO_BACKUP[@]}"; do
        local src="$HOME/$path"
        local dest="$BACKUP_PATH/$path"

        if backup_item "$src" "$dest"; then
            ((backed_up++)) || true
        else
            ((skipped++)) || true
        fi
    done

    # Create latest symlink
    if [[ "$DRY_RUN" == "false" && "$backed_up" -gt 0 ]]; then
        rm -f "$BACKUP_DIR/latest" 2>/dev/null || true
        ln -s "$BACKUP_PATH" "$BACKUP_DIR/latest"
    fi

    # Summary
    echo ""
    log_info "Backup complete!"
    echo "  Backed up: $backed_up items"
    echo "  Skipped (not found): $skipped items"

    if [[ "$DRY_RUN" == "false" && "$backed_up" -gt 0 ]]; then
        echo ""
        log_info "Backup saved to: $BACKUP_PATH"
        log_info "Latest backup symlink: $BACKUP_DIR/latest"
    fi
}

main
```

**Step 4: Make script executable and test**

Run: `chmod +x scripts/backup.sh`
Run: `./scripts/backup.sh --dry-run`
Expected: Shows what would be backed up without making changes

**Step 5: Commit backup.sh**

```bash
git add scripts/backup.sh
git commit -m "feat: add backup.sh script for dotfiles backup"
```

---

## Task 2: Create restore.sh Script

**Files:**
- Create: `scripts/restore.sh`

**Step 1: Create restore.sh with header and configuration**

```bash
#!/usr/bin/env bash
# Restore dotfiles configurations from backup
# Usage: ./scripts/restore.sh [--dry-run|--latest|<backup_name>]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="$HOME/.dotfiles-backup"
DRY_RUN=false
RESTORE_LATEST=false
SELECTED_BACKUP=""

# Helper functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_dry() { echo -e "${BLUE}[DRY-RUN]${NC} $1"; }
```

**Step 2: Add backup listing function**

```bash
# List available backups
list_backups() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_error "No backups found. Backup directory does not exist: $BACKUP_DIR"
        exit 1
    fi

    local backups=()
    while IFS= read -r -d '' backup; do
        backups+=("$(basename "$backup")")
    done < <(find "$BACKUP_DIR" -maxdepth 1 -type d -name "2*" -print0 | sort -rz)

    if [[ ${#backups[@]} -eq 0 ]]; then
        log_error "No backups found in $BACKUP_DIR"
        exit 1
    fi

    echo "${backups[@]}"
}

# Display backups with numbers
display_backups() {
    local backups=("$@")
    echo "Available backups:"
    echo ""
    local i=1
    for backup in "${backups[@]}"; do
        # Format timestamp for display
        local display_name=$(echo "$backup" | sed 's/_/ /' | sed 's/-/:/4')
        echo "  [$i] $backup"
        ((i++)) || true
    done
    echo ""
}
```

**Step 3: Add restore function**

```bash
# Restore from backup
restore_backup() {
    local backup_path="$1"

    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup not found: $backup_path"
        exit 1
    fi

    log_info "Restoring from: $backup_path"
    echo ""

    # Find what's in the backup
    local items=()
    while IFS= read -r -d '' item; do
        items+=("$(basename "$item")")
    done < <(find "$backup_path" -maxdepth 1 -print0 | tail -n +2)

    if [[ ${#items[@]} -eq 0 ]]; then
        log_error "Backup is empty: $backup_path"
        exit 1
    fi

    # Show what will be restored
    log_info "Items to restore:"
    for item in "${items[@]}"; do
        echo "  - $item"
    done
    echo ""

    # Confirm restore
    if [[ "$DRY_RUN" == "false" ]]; then
        read -p "Continue with restore? [y/N] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Restore cancelled"
            exit 0
        fi
    fi

    # Perform restore
    local restored=0
    for item in "${items[@]}"; do
        local src="$backup_path/$item"
        local dest="$HOME/$item"

        if [[ "$DRY_RUN" == "true" ]]; then
            log_dry "Would restore: $src -> $dest"
        else
            # Remove existing
            rm -rf "$dest" 2>/dev/null || true
            # Copy from backup
            cp -r "$src" "$dest"
            log_info "Restored: $item"
        fi
        ((restored++)) || true
    done

    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run complete. $restored items would be restored."
    else
        log_info "Restore complete! $restored items restored."
    fi
}
```

**Step 4: Add main function and argument parsing**

```bash
# Main function
main() {
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --dry-run)
                DRY_RUN=true
                ;;
            --latest)
                RESTORE_LATEST=true
                ;;
            2*)
                SELECTED_BACKUP="$arg"
                ;;
        esac
    done

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run mode - no changes will be made"
        echo ""
    fi

    # Determine which backup to restore
    local backup_path=""

    if [[ -n "$SELECTED_BACKUP" ]]; then
        backup_path="$BACKUP_DIR/$SELECTED_BACKUP"
    elif [[ "$RESTORE_LATEST" == "true" ]]; then
        backup_path="$BACKUP_DIR/latest"
        if [[ ! -L "$backup_path" ]]; then
            log_error "No latest backup symlink found"
            exit 1
        fi
        backup_path=$(readlink -f "$backup_path" 2>/dev/null || greadlink -f "$backup_path" 2>/dev/null)
    else
        # Interactive selection
        local backups_str=$(list_backups)
        read -ra backups <<< "$backups_str"
        display_backups "${backups[@]}"

        read -p "Select backup to restore [1-${#backups[@]}]: " selection

        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt ${#backups[@]} ]]; then
            log_error "Invalid selection"
            exit 1
        fi

        SELECTED_BACKUP="${backups[$((selection-1))]}"
        backup_path="$BACKUP_DIR/$SELECTED_BACKUP"
    fi

    restore_backup "$backup_path"
}

main "$@"
```

**Step 5: Make script executable and test**

Run: `chmod +x scripts/restore.sh`
Run: `./scripts/restore.sh --dry-run --latest`
Expected: Shows what would be restored from latest backup

**Step 6: Commit restore.sh**

```bash
git add scripts/restore.sh
git commit -m "feat: add restore.sh script for dotfiles restore"
```

---

## Task 3: Update bootstrap.sh with --backup Flag

**Files:**
- Modify: `scripts/bootstrap.sh`

**Step 1: Add --backup flag parsing**

Add after line 6 (`set -euo pipefail`):

```bash
# Parse arguments
BACKUP_FIRST=false
for arg in "$@"; do
    case "$arg" in
        --backup)
            BACKUP_FIRST=true
            shift
            ;;
    esac
done
```

**Step 2: Add backup step before chezmoi init**

Add before `# Main execution` section:

```bash
# Run backup if requested
run_backup() {
    if [[ "$BACKUP_FIRST" == "true" ]]; then
        log_info "Creating backup before applying dotfiles..."
        local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        bash "$SCRIPT_DIR/backup.sh"
        echo ""
    fi
}
```

**Step 3: Add backup call to main function**

Modify the main function to call run_backup:

```bash
# Main execution
main() {
    log_info "Starting denny-all-in-one bootstrap..."
    detect_os
    run_backup  # Add this line
    install_chezmoi
    setup_dotfiles "$@"
    init_chezmoi
    post_apply

    log_info "Bootstrap complete! Restart your shell or run: source ~/.bashrc"
}
```

**Step 4: Test bootstrap with backup**

Run: `./scripts/bootstrap.sh --help` or check `--backup` is recognized
Expected: Script runs with backup flag support

**Step 5: Commit bootstrap.sh update**

```bash
git add scripts/bootstrap.sh
git commit -m "feat: add --backup flag to bootstrap.sh"
```

---

## Task 4: Update README.md

**Files:**
- Modify: `README.md`

**Step 1: Add backup/restore section to README**

Add after the "Sync Workflow" section:

```markdown
## Backup and Restore

### Before Applying (Recommended)

Always backup your existing configurations before applying new dotfiles:

```bash
./scripts/backup.sh              # Create backup
./scripts/backup.sh --dry-run    # Preview what would be backed up
```

### Bootstrap with Backup

```bash
./scripts/bootstrap.sh --backup  # Backup first, then apply
```

### Restore from Backup

If something goes wrong, restore your previous configurations:

```bash
./scripts/restore.sh             # Interactive selection
./scripts/restore.sh --latest    # Restore most recent backup
./scripts/restore.sh --dry-run   # Preview restore
```

### Backup Location

Backups are stored in `~/.dotfiles-backup/` with timestamped directories:

```
~/.dotfiles-backup/
├── 2026-02-21_14-30-00/
├── 2026-02-21_15-00-00/
└── latest -> 2026-02-21_15-00-00/
```
```

**Step 2: Update Scripts Reference table**

Add backup.sh and restore.sh to the Scripts Reference table:

```markdown
| `backup.sh` | Backup existing configs |
| `restore.sh` | Restore from backup |
```

**Step 3: Commit README update**

```bash
git add README.md
git commit -m "docs: add backup and restore documentation to README"
```

---

## Task 5: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Add backup/restore to scripts reference**

Update the Scripts Reference table to include:

```markdown
| `backup.sh` | Backup existing configs before apply |
| `restore.sh` | Restore configs from backup |
```

**Step 2: Add backup recommendation to sync workflow**

Add note about backup before sync:

```markdown
### Sync TO Home Directory (Apply to Machine)

After pulling latest changes, apply them to your home:

```bash
# Recommended: Backup first
./scripts/backup.sh

# Option 1: Using chezmoi
chezmoi init --source=.
chezmoi apply

# Option 2: Using bootstrap (includes backup option)
./scripts/bootstrap.sh --backup
```
```

**Step 3: Commit CLAUDE.md update**

```bash
git add CLAUDE.md
git commit -m "docs: add backup/restore to CLAUDE.md sync workflow"
```

---

## Task 6: Final Testing

**Step 1: Test backup.sh**

Run: `./scripts/backup.sh --dry-run`
Expected: Shows what would be backed up

Run: `./scripts/backup.sh`
Expected: Creates backup in ~/.dotfiles-backup/

**Step 2: Test restore.sh**

Run: `./scripts/restore.sh --dry-run --latest`
Expected: Shows what would be restored

**Step 3: Test bootstrap.sh --backup**

Run: `./scripts/bootstrap.sh --help` or verify flag works
Expected: --backup flag is recognized

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete backup and restore feature implementation"
git push
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Create backup.sh | scripts/backup.sh |
| 2 | Create restore.sh | scripts/restore.sh |
| 3 | Update bootstrap.sh | scripts/bootstrap.sh |
| 4 | Update README.md | README.md |
| 5 | Update CLAUDE.md | CLAUDE.md |
| 6 | Final testing | All scripts |
