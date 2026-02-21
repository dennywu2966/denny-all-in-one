# denny-all-in-one

> Personal development environment - dotfiles managed with chezmoi.

## Quick Start

```bash
# One-line bootstrap on a new machine
curl -fsSL https://raw.githubusercontent.com/dennywu2966/denny-all-in-one/master/scripts/bootstrap.sh | bash
```

Or manually:

```bash
# Clone this repo
git clone https://github.com/dennywu2966/denny-all-in-one.git
cd denny-all-in-one

# Backup existing configs (recommended)
./scripts/backup.sh

# Install chezmoi and apply dotfiles
./scripts/bootstrap.sh
```

## What's Included

### Claude Code
- **Settings**: `~/.claude/settings.json` - Hooks, plugins, MCP servers
- **Skills**: 20+ custom skills for validation, e2e testing, etc.
- **Scripts**: Custom utility scripts
- **Hooks**: Checkpoint system, status line
- **MCP**: Pre-configured servers (playwright, jina, etc.)

### Codex
- **Config**: `~/.codex/config.toml` - Codex CLI settings

### OpenCode
- **Config**: `~/.config/opencode/opencode.json` - OpenCode settings

### Development Tools
- **Neovim**: `~/.config/nvim/` - Neovim configuration
- **Git**: `~/.config/git/` - Git configuration
- **Go**: `~/.config/go/` - Go development config
- **UV**: `~/.config/uv/` - Python package manager config

### Shell
- **Bash**: `~/.bashrc`, `~/.profile`

### Cloud & Agents
- **Agents**: `~/.agents/skills/` - Agent skills
- **Scripts**: `~/.scripts/` - Utility scripts
- **Aliyun**: `~/.aliyun/` - Aliyun CLI config (template)
- **OSS**: `~/.oss/` - Aliyun OSS config (template)

## Structure

```
denny-all-in-one/
├── CLAUDE.md              # Project sync workflow docs
├── README.md              # This file
├── .chezmoi.toml.tmpl     # chezmoi configuration template
├── .chezmoiignore         # Files to exclude from sync
├── home/                  # Maps to ~ (home directory)
│   ├── .claude/          # Claude Code assets
│   ├── .codex/           # Codex config
│   ├── .agents/          # Agent skills
│   ├── .scripts/         # Utility scripts
│   ├── .aliyun/          # Aliyun CLI config (template)
│   ├── .oss/             # OSS config (template)
│   ├── .config/          # XDG configs (nvim, git, go, uv, opencode)
│   ├── .bashrc           # Bash configuration
│   └── .profile          # Shell profile
├── scripts/              # Utility scripts
│   ├── bootstrap.sh      # One-time setup script
│   ├── backup.sh         # Backup existing dotfiles
│   ├── restore.sh        # Restore from backup
│   ├── sync-from-home.sh # Sync configs from ~ to project
│   ├── docker-test-*.sh  # Docker testing scripts
│   └── doctor.sh         # System health check
└── docs/                 # Documentation
```

## Sync Workflow

### Sync FROM Home Directory (Update Project)

When you've updated configs on your main machine, sync them to this project:

```bash
./scripts/sync-from-home.sh
git add -A && git commit -m "Sync latest configs" && git push
```

### Sync TO Home Directory (Apply to Machine)

After pulling latest changes, apply them to your home:

```bash
# Option 1: Using chezmoi
chezmoi init --source=.
chezmoi apply

# Option 2: Using bootstrap (with backup)
./scripts/bootstrap.sh --backup
```

**Tip:** Always backup before applying to preserve your current configurations.

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

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `sync-from-home.sh` | Pull configs from ~ to project |
| `bootstrap.sh` | One-time setup on new machine |
| `backup.sh` | Backup existing dotfiles |
| `restore.sh` | Restore from backup |
| `docker-test-simple.sh` | Quick structure verification |
| `docker-test-full.sh` | Full deployment test |
| `doctor.sh` | System health check |

## Secrets Management

- **NEVER** commit API keys or tokens
- Secrets are auto-stripped from .bashrc during sync
- Store secrets in `~/.bashrc.local` (not tracked)
- Cloud credentials use chezmoi templates (`.aliyun/config.json.tmpl`, `.oss/credentials.json.tmpl`)

## Excluded Files

The following are never synced (see `.chezmoiignore`):

- **Claude Code state**: history, cache, projects, credentials
- **Codex state**: auth, history, models cache
- **Cloud credentials**: `.aliyun/config.json`, `.oss/credentials.json`
- **Local overrides**: `.bashrc.local`

## Testing

```bash
# Quick structure test
./scripts/docker-test-simple.sh

# Full deployment test (installs chezmoi, applies dotfiles)
./scripts/docker-test-full.sh

# Health check
./scripts/doctor.sh
```

## Troubleshooting

### chezmoi apply fails with conflicts

```bash
chezmoi merge      # Interactive merge
```

### View what would change without applying

```bash
chezmoi diff       # Show unapplied changes
```

### See which files are managed

```bash
chezmoi managed    # List tracked files
```

## License

MIT

## Credits

Built with [chezmoi](https://chezmoi.io/)
