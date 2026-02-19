# denny-all-in-one - Dotfiles Repository

> Personal development environment managed with chezmoi.

## Quick Start

```bash
# One-line bootstrap on a new machine
curl -fsSL https://raw.githubusercontent.com/dennywu2966/denny-all-in-one/main/scripts/bootstrap.sh | bash
```

## Sync Workflow

### Sync FROM Home Directory (Update Project)

When you've updated configs on your main machine, sync them to this project:

```bash
./scripts/sync-from-home.sh
git add -A && git commit -m "Sync latest configs" && git push
```

**What it syncs:**
- Claude Code: settings.json, CLAUDE.md, skills/, scripts/, hooks/
- Codex CLI: config.toml
- OpenCode: opencode.json
- Neovim: init.vim, lazy-lock.json
- Shell: .bashrc (secrets auto-stripped), .profile

### Sync TO Home Directory (Apply to Machine)

After pulling latest changes, apply them to your home:

```bash
# Option 1: Using chezmoi
chezmoi init --source=.
chezmoi apply

# Option 2: Using bootstrap
./scripts/bootstrap.sh
```

## IMPORTANT: Keep Sync Scripts Updated

**When adding new config files or directories:**

1. **Update `scripts/sync-from-home.sh`** - Add the new config to the sync list
2. **Update `scripts/bootstrap.sh`** - Ensure new configs are applied correctly
3. **Update `.chezmoiignore`** - Add any state/cache files to exclude
4. **Test with Docker**: `./scripts/docker-test-full.sh`

**Example - Adding a new tool (e.g., tmux):**

```bash
# 1. Add to sync-from-home.sh
echo ""
echo "10. Syncing tmux config..."
sync_item "$HOME_DIR/.config/tmux/tmux.conf" "$PROJECT_DIR/home/.config/tmux/tmux.conf" "tmux.conf"

# 2. The file will be automatically tracked by chezmoi in home/.config/tmux/
```

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `sync-from-home.sh` | Pull configs from ~ to project |
| `bootstrap.sh` | One-time setup on new machine |
| `docker-test-simple.sh` | Quick structure verification |
| `docker-test-full.sh` | Full deployment test |
| `doctor.sh` | System health check |

## Secrets Management

- **NEVER** commit API keys or tokens
- Secrets are auto-stripped from .bashrc during sync
- Store secrets in `~/.bashrc.local` (not tracked)
- For encrypted secrets, use chezmoi's `age` encryption

## File Structure

```
home/                  # chezmoi source (maps to ~/)
├── .claude/          # Claude Code assets
├── .codex/           # Codex CLI config
├── .config/          # XDG configs (nvim, opencode, git)
├── .bashrc           # Shell config (secrets stripped)
└── .profile          # Login shell profile
```

## Testing

```bash
# Quick structure test
./scripts/docker-test-simple.sh

# Full deployment test (installs chezmoi, applies dotfiles)
./scripts/docker-test-full.sh

# Health check
./scripts/doctor.sh
```
