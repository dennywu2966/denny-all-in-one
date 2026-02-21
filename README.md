# denny-all-in-one

> My personal development environment - dotfiles managed with chezmoi.

## Quick Start

```bash
# One-line bootstrap on a new machine
curl -fsSL https://raw.githubusercontent.com/dennybritz/denny-all-in-one/main/scripts/bootstrap.sh | bash
```

Or manually:

```bash
# Install chezmoi
curl -fsSL https://chezmoi.io/get | bash

# Clone this repo
git clone https://github.com/dennybritz/denny-all-in-one.git ~/.local/share/denny-all-in-one

# Apply dotfiles
chezmoi init --source=~/.local/share/denny-all-in-one
chezmoi apply
```

## What's Included

### Claude Code
- **Settings**: `~/.claude/settings.json` - Hooks, plugins, MCP servers
- **Skills**: 20+ custom skills for validation, e2e testing, etc.
- **Commands**: Custom slash commands
- **Hooks**: Checkpoint system, status line
- **MCP**: Pre-configured servers (playwright, jina, etc.)

### Codex
- **Config**: `~/.codex/config.toml` - Codex settings

### Development Tools
- **Neovim**: `~/.config/nvim/` - Neovim configuration
- **Git**: `~/.config/git/` - Git configuration
- **Go**: `~/.config/go/` - Go development config
- **UV**: `~/.config/uv/` - Python package manager config

### Shell
- **Bash**: `~/.bashrc`, `~/.bashrc.d/`, `~/.profile`

## Structure

```
denny-all-in-one/
├── .chezmoi.toml.tmpl    # chezmoi configuration template
├── .chezmoiignore         # Files to exclude from sync
├── home/                  # Maps to ~ (home directory)
│   ├── .claude/          # Claude Code assets
│   ├── .codex/           # Codex config
│   ├── .cargo/           # Cargo/Rust config
│   ├── .config/          # Config files (nvim, git, go, uv)
│   ├── .bashrc           # Bash configuration
│   └── .profile          # Shell profile
├── scripts/              # Utility scripts
│   ├── bootstrap.sh      # One-time setup script
│   ├── backup.sh         # Backup existing dotfiles
│   ├── restore.sh        # Restore from backup
│   └── doctor.sh         # System health check
└── docs/                 # Documentation
```

## Daily Usage

### Update dotfiles from current machine

```bash
# Edit your config files normally in ~
# When ready to sync:

chezmoi add ~/.claude/settings.json  # Add new file to tracking
chezmoi update                       # Pull latest from remote
git -C ~/.local/share/denny-all-in-one add -A
git -C ~/.local/share/denny-all-in-one commit -m "Update settings"
git -C ~/.local/share/denny-all-in-one push
```

### Apply on another machine

```bash
chezmoi update    # Pull latest changes
chezmoi apply     # Apply changes to home directory
```

### Check system health

```bash
~/.local/share/denny-all-in-one/scripts/doctor.sh
```

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

## Machine-Specific Configuration

Use chezmoi templates for machine differences:

```bash
# chezmoi will automatically populate these:
{{ .hostname }}  # System hostname
{{ .username }}  # Current username
{{ .email }}     # Git email (passed via --data)
```

Example: `.chezmoi.toml.tmpl`

```toml
[data]
  hostname = "{{ .hostname }}"
  email = "{{ .email }}"
```

## Secrets Management

This repo uses **chezmoi's built-in encryption** for secrets:

```bash
# Encrypt a file
chezmoi secret encrypt --recipient <key-id> secret.txt > secret.txt.age

# Use in templates
{{ .chezmoi.homeDir }}/.secret/config.age
```

## Excluded Files

The following are never synced (see `.chezmoiignore`):

- **Claude Code state**: `.claude.json`, history, cache, projects
- **Codex state**: auth, history, models cache
- **Local overrides**: `local_*.tmpl`

## Troubleshooting

 chezmoi apply fails with conflicts

```bash
chezmoi merge      # Interactive merge
```

View what would change without applying

```bash
chezmoi diff       # Show unapplied changes
```

See which files are managed

```bash
chezmoi managed    # List tracked files
```

## License

MIT

## Credits

Built with [chezmoi](https://chezmoi.io/)
