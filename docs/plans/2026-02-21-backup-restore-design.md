# Backup and Restore Feature Design

**Date:** 2026-02-21
**Status:** Approved

## Overview

Add backup and restore scripts to the denny-all-in-one dotfiles repository. These scripts work alongside chezmoi to provide a safety net when applying new configurations.

## Problem Statement

When applying dotfiles to a new machine or updating configurations, users risk losing their existing configurations. chezmoi handles the apply process well, but doesn't provide a straightforward way to:
1. Backup existing configs before applying new ones
2. Restore previous configs if something goes wrong

## Solution

Add two standalone scripts:
- `backup.sh` - Creates timestamped backups of existing configurations
- `restore.sh` - Restores configurations from a backup

### Design Principles

1. **Non-destructive** - Never overwrite without backup
2. **Simple** - Plain tar archives, no special tools needed
3. **Portable** - Works on Linux and macOS
4. **Transparent** - Clear output showing what's being backed up/restored
5. **chezmoi-friendly** - Works alongside chezmoi, doesn't replace it

## Architecture

```
~/.dotfiles-backup/
├── 2026-02-21_14-30-00/
│   ├── .claude/
│   ├── .codex/
│   ├── .config/
│   │   ├── nvim/
│   │   ├── git/
│   │   └── opencode/
│   ├── .agents/
│   ├── .scripts/
│   ├── .bashrc
│   └── .profile
├── 2026-02-21_15-00-00/
│   └── ...
└── latest -> 2026-02-21_15-00-00/  # Symlink to most recent
```

## Scripts

### backup.sh

**Purpose:** Backup existing configurations before applying new ones

**Features:**
- Creates timestamped backup directory
- Backs up all managed paths (only if they exist)
- Creates `latest` symlink for easy access
- Shows summary of what was backed up
- Supports `--dry-run` flag

**Usage:**
```bash
./scripts/backup.sh              # Create backup
./scripts/backup.sh --dry-run    # Preview what would be backed up
```

**Paths to backup:**
- `~/.claude/`
- `~/.codex/`
- `~/.config/nvim/`
- `~/.config/git/`
- `~/.config/opencode/`
- `~/.config/go/`
- `~/.config/uv/`
- `~/.agents/`
- `~/.scripts/`
- `~/.aliyun/`
- `~/.oss/`
- `~/.bashrc`
- `~/.profile`

### restore.sh

**Purpose:** Restore configurations from a backup

**Features:**
- Lists available backups with timestamps
- Interactive selection menu
- Supports direct backup path argument
- Shows what will be restored before proceeding
- Supports `--dry-run` flag
- `--latest` flag to restore most recent backup

**Usage:**
```bash
./scripts/restore.sh             # Interactive selection
./scripts/restore.sh --latest    # Restore most recent
./scripts/restore.sh --dry-run   # Preview what would be restored
./scripts/restore.sh 2026-02-21_14-30-00  # Restore specific backup
```

### bootstrap.sh (Updates)

- Add `--backup` flag to automatically backup before applying
- Prompt user to backup if no backup exists

**Usage:**
```bash
./scripts/bootstrap.sh           # Standard bootstrap
./scripts/bootstrap.sh --backup  # Backup first, then bootstrap
```

## Error Handling

- Check for required disk space before backup
- Verify backup integrity after creation
- Handle partial restores gracefully
- Log all operations for debugging

## Testing

- Test on Linux (Debian/Ubuntu)
- Test on macOS
- Test with missing directories
- Test with symlinks
- Test restore from corrupted backup (error handling)

## Files Changed

| File | Action |
|------|--------|
| `scripts/backup.sh` | Create |
| `scripts/restore.sh` | Create |
| `scripts/bootstrap.sh` | Update (add --backup flag) |
| `README.md` | Update (document new scripts) |
| `CLAUDE.md` | Update (add backup/restore to sync workflow) |
