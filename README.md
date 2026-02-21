# denny-all-in-one

> Personal development environment - dotfiles managed with chezmoi and Bitwarden.

## Project Overview

### Background (项目背景)

Managing development environment configurations across multiple machines is challenging:
- Different operating systems (Linux, macOS) have different config paths
- API keys and secrets should never be committed to version control
- Manual synchronization is error-prone and time-consuming
- Recovering from a broken config is difficult without backups

This project solves these problems by providing a **declarative, reproducible** dotfiles management system.

### Purpose (项目目的)

- **One-command setup** - Bootstrap a complete development environment on any machine
- **Secret management** - API keys stored securely in Bitwarden, rendered at apply time
- **Version controlled** - All configs tracked in Git with proper secrets exclusion
- **Backup & restore** - Safety nets before applying changes
- **Cross-platform** - Works on Linux and macOS

### Limitations (项目限制)

- **Requires Node.js** - Bitwarden CLI needs Node.js/npm
- **Interactive setup** - First-time setup requires manual Bitwarden login
- **Single-user** - Designed for personal use, not multi-user environments
- **No GUI** - Bitwarden integration is CLI-only
- **English comments** - Most code comments are in English

### Success Criteria (成功标准)

A successful bootstrap should result in:

- [ ] chezmoi installed and configured
- [ ] Bitwarden CLI installed and vault unlocked
- [ ] All dotfiles applied to `~/` directory
- [ ] Templates rendered with real secrets from Bitwarden
- [ ] Claude Code, Codex, Neovim configs working
- [ ] Aliyun/OSS credentials properly configured
- [ ] Backup created (if requested)

### Organization (组织形式)

```
┌─────────────────────────────────────────────────────────────┐
│                    denny-all-in-one                         │
├─────────────────────────────────────────────────────────────┤
│  GitHub Repository (Version Controlled)                     │
│  ├── dot_* files (chezmoi source format)                   │
│  ├── *.tmpl files (templates with Bitwarden references)    │
│  └── scripts/ (bootstrap, backup, restore, validate)       │
└──────────────────────┬──────────────────────────────────────┘
                       │
       ┌───────────────┼───────────────┐
       ▼               ▼               ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│   chezmoi   │ │  Bitwarden  │ │    Git      │
│ (dotfiles   │ │  (secrets   │ │ (version    │
│  manager)   │ │   vault)    │ │  control)   │
└──────┬──────┘ └──────┬──────┘ └─────────────┘
       │               │
       │    ┌──────────┘
       │    │
       ▼    ▼
┌─────────────────────────────────────────────────────────────┐
│                    Home Directory (~)                       │
│  ├── .bashrc, .profile (shell configs)                      │
│  ├── .claude/, .codex/ (AI tools)                          │
│  ├── .config/ (nvim, git, etc.)                            │
│  ├── .aliyun/config.json (rendered with secrets)           │
│  └── .oss/credentials.json (rendered with secrets)         │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Concepts (核心概念)

### Chezmoi

[Chezmoi](https://chezmoi.io/) is a dotfiles manager that:
- Manages files across multiple machines with different OSes
- Uses a source directory (`~/.local/share/chezmoi/`) to track files
- Supports templates for dynamic content (like secrets from Bitwarden)
- Handles file renaming (`dot_bashrc` → `.bashrc`)

**File Naming Convention:**
```
Repository File          →  Target File
─────────────────────────────────────────
dot_bashrc               →  ~/.bashrc
dot_config/nvim/init.vim →  ~/.config/nvim/init.vim
dot_aliyun/config.json   →  ~/.aliyun/config.json
```

### Bitwarden

[Bitwarden](https://bitwarden.com/) is an open-source password manager:
- Stores passwords, API keys, tokens securely
- End-to-end encryption (zero-knowledge)
- CLI tool (`bw`) for headless/server environments
- Free for personal use

**CLI Commands:**
```bash
bw login your@email.com    # Login to account
bw unlock                  # Unlock vault (prompts for password)
bw list items              # List all stored items
bw get item "api-key-name" # Retrieve a specific secret
```

### Vault (密码保险库)

In Bitwarden, **vault** refers to your encrypted password database:
- Contains all your passwords, secure notes, API keys
- Encrypted with your master password
- Stored on Bitwarden servers (encrypted) and synced across devices

**Vault States:**
| State | Meaning |
|-------|---------|
| `unauthenticated` | Not logged in to Bitwarden account |
| `locked` | Logged in, but vault is encrypted (need password) |
| `unlocked` | Vault decrypted, secrets accessible |

---

## Quick Start

```bash
# One-line bootstrap on a new machine
curl -fsSL https://raw.githubusercontent.com/dennywu2966/denny-all-in-one/master/scripts/bootstrap.sh | bash

# Bootstrap without Bitwarden (secrets will have placeholder values)
curl -fsSL https://raw.githubusercontent.com/dennywu2966/denny-all-in-one/master/scripts/bootstrap.sh | bash -s -- --skip-bitwarden
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

---

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

---

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

### Template Syntax

Chezmoi templates use Go template syntax to reference Bitwarden items:

```go
{{ (bitwarden "item" "aliyun-access-key").login.username }}  # Access Key ID
{{ (bitwarden "item" "aliyun-access-key").login.password }}  # Access Key Secret
```

### Getting Secrets on Another Machine

```bash
# Login and unlock
bw login your-email@example.com
export BW_SESSION=$(bw unlock --raw)

# Get a specific secret (requires jq)
bw get item "aliyun-access-key" | jq -r '.login.username'  # Access Key ID
bw get item "aliyun-access-key" | jq -r '.login.password'  # Secret
```

**Note:** The commands above require `jq` for JSON parsing. Install with:
```bash
# Linux
sudo apt install jq

# macOS
brew install jq
```

---

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

---

## File Structure

```
denny-all-in-one/
├── CLAUDE.md              # Project sync workflow docs
├── README.md              # This file
├── .chezmoi.toml.tmpl     # chezmoi configuration template
├── .chezmoiignore         # Files to exclude from sync
├── dot_claude/            # Claude Code assets (~/.claude)
├── dot_codex/             # Codex CLI config (~/.codex)
├── dot_config/            # XDG configs (~/.config)
│   ├── nvim/              # Neovim
│   ├── git/               # Git
│   ├── opencode/          # OpenCode
│   └── ...
├── dot_aliyun/            # Aliyun CLI config (template with Bitwarden)
├── dot_oss/               # OSS credentials (template with Bitwarden)
├── dot_bashrc             # Shell config (secrets stripped)
├── dot_profile            # Login shell profile
├── scripts/               # Utility scripts
│   ├── bootstrap.sh       # One-time setup script
│   ├── backup.sh          # Backup existing dotfiles
│   ├── restore.sh         # Restore from backup
│   ├── sync-from-home.sh  # Sync configs from ~ to project
│   ├── bw-manage.sh       # Bitwarden CLI helper
│   ├── bw-import-keys.sh  # Import API keys to Bitwarden
│   └── validate-bootstrap.sh # Docker-based validation
└── docs/                  # Documentation
```

---

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

---

## Backup and Restore

### Before Applying (Recommended)

```bash
./scripts/backup.sh              # Create backup
./scripts/backup.sh --dry-run    # Preview what would be backed up
```

### Bootstrap with Backup

```bash
./scripts/bootstrap.sh --backup  # Backup first, then apply
```

### Restore from Backup

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

---

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

---

## Excluded Files

The following are never synced (see `.chezmoiignore`):

- **Claude Code state**: history, cache, projects, credentials
- **Codex state**: auth, history, models cache
- **Cloud credentials**: `.aliyun/config.json`, `.oss/credentials.json`
- **SSH private keys**: `id_ed25519`, `id_rsa`, `*.pem`
- **Local overrides**: `.bashrc.local`

---

## Testing

```bash
# Quick local test (without Bitwarden)
./scripts/validate-bootstrap.sh --local

# Full test with Bitwarden (requires credentials)
BW_EMAIL=your@email.com BW_PASSWORD=yourpassword ./scripts/validate-bootstrap.sh --local --with-bitwarden

# Test from GitHub (production validation)
./scripts/validate-bootstrap.sh
```

---

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

### Bitwarden session expired

```bash
bw unlock
export BW_SESSION="<new-session-key>"
chezmoi apply
```

---

## License

MIT

## Credits

- [chezmoi](https://chezmoi.io/) - Dotfiles manager
- [Bitwarden](https://bitwarden.com/) - Password manager
