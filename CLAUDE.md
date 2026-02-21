# denny-all-in-one - Dotfiles Repository

> Personal development environment managed with chezmoi and Bitwarden.

## Quick Start

```bash
# One-line bootstrap on a new machine (with Bitwarden for secrets)
curl -fsSL https://raw.githubusercontent.com/dennywu2966/denny-all-in-one/main/scripts/bootstrap.sh | bash

# Bootstrap without Bitwarden (secrets will have placeholder values)
curl -fsSL https://raw.githubusercontent.com/dennywu2966/denny-all-in-one/main/scripts/bootstrap.sh | bash -s -- --skip-bitwarden
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
- Aliyun/OSS: Templates only (secrets from Bitwarden)

### Sync TO Home Directory (Apply to Machine)

After pulling latest changes, apply them to your home:

```bash
# Option 1: Using bootstrap (recommended - includes Bitwarden)
./scripts/bootstrap.sh

# Option 2: With backup first
./scripts/bootstrap.sh --backup

# Option 3: Using chezmoi directly (requires Bitwarden session)
bw unlock
export BW_SESSION="<session-from-output>"
chezmoi init https://github.com/dennywu2966/denny-all-in-one.git
chezmoi apply
```

**Tip:** Always backup before applying to preserve your current configurations.

## Secrets Management with Bitwarden

All API keys, tokens, and credentials are stored in Bitwarden and referenced via chezmoi templates.

### Setup Bitwarden

```bash
# 1. Install Bitwarden CLI
npm install -g @bitwarden/cli

# 2. Create account at https://vault.bitwarden.com (if needed)

# 3. Login
bw login your-email@example.com

# 4. Unlock vault (do this before running chezmoi)
bw unlock
export BW_SESSION="<session-key-from-output>"

# 5. Import API keys from ~/.bashrc.local
./scripts/bw-import-keys.sh
```

### Available Scripts

| Script | Purpose |
|--------|---------|
| `bw-manage.sh` | Bitwarden CLI helper (login, unlock, list, create) |
| `bw-import-keys.sh` | Import API keys from ~/.bashrc.local to Bitwarden |

### Using Secrets in Templates

Chezmoi templates can reference Bitwarden items:

```go
{{ (bitwarden "item" "aliyun-access-key").login.username }}  # Access Key ID
{{ (bitwarden "item" "aliyun-access-key").login.password }}  # Access Key Secret
```

### Getting Secrets on Another Machine

```bash
# Login and unlock
bw login your-email@example.com
bw unlock

# Get a specific secret
bw get item "aliyun-ram-key" | jq -r '.login.username'  # Access Key ID
bw get item "aliyun-ram-key" | jq -r '.login.password'  # Secret

# List all items
bw list items | jq -r '.[].name'
```

## Bootstrap Options

```bash
./scripts/bootstrap.sh [OPTIONS]

Options:
  --backup          Force backup before applying
  --no-backup       Skip backup prompt
  --local           Use local files (for testing)
  --skip-bitwarden  Skip Bitwarden setup (secrets won't be rendered)
  --bw-password     Bitwarden password (for non-interactive use)
```

## IMPORTANT: Keep Sync Scripts Updated

**When adding new config files or directories:**

1. **Update `scripts/sync-from-home.sh`** - Add the new config to the sync list
2. **Update `scripts/bootstrap.sh`** - Ensure new configs are applied correctly
3. **Update `.chezmoiignore`** - Add any state/cache files to exclude
4. **Test with Docker**: `./scripts/validate-bootstrap.sh --local`

**Example - Adding a new tool (e.g., tmux):**

```bash
# 1. Add to sync-from-home.sh
echo ""
echo "14. Syncing tmux config..."
sync_item "$HOME_DIR/.config/tmux/tmux.conf" "$PROJECT_DIR/dot_config/tmux/tmux.conf" "tmux.conf"
```

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `sync-from-home.sh` | Pull configs from ~ to project |
| `bootstrap.sh` | One-time setup on new machine (includes Bitwarden) |
| `backup.sh` | Backup existing dotfiles |
| `restore.sh` | Restore from backup |
| `bw-manage.sh` | Bitwarden CLI helper |
| `bw-import-keys.sh` | Import API keys to Bitwarden |
| `validate-bootstrap.sh` | Docker-based validation test |

## File Structure

```
dot_claude/           # Claude Code assets (~/.claude)
dot_codex/            # Codex CLI config (~/.codex)
dot_config/           # XDG configs (~/.config)
dot_aliyun/           # Aliyun CLI config (template with Bitwarden)
dot_oss/              # OSS credentials (template with Bitwarden)
dot_bashrc            # Shell config (secrets stripped)
dot_profile           # Login shell profile
.chezmoi.toml.tmpl    # Chezmoi config template
.chezmoiignore        # Files to exclude from chezmoi
```

## Testing

```bash
# Quick local test (without Bitwarden)
./scripts/validate-bootstrap.sh --local

# Full test with Bitwarden (requires credentials)
BW_EMAIL=your@email.com BW_PASSWORD=yourpassword ./scripts/validate-bootstrap.sh --local --with-bitwarden

# Test from GitHub (production validation)
./scripts/validate-bootstrap.sh
```

## Secrets Checklist

- [ ] API keys stored in Bitwarden (not in ~/.bashrc.local)
- [ ] Templates use `{{ (bitwarden "item" "name")... }}` syntax
- [ ] Bootstrap script unlocks Bitwarden before chezmoi apply
- [ ] Validation script tests Bitwarden integration
