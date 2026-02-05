# Architecture - denny-all-in-one

## Overview

This repository is a **declarative personal development environment** managed by [chezmoi](https://chezmoi.io/). The goal is to have a single source of truth that can reproduce your complete development setup on any Linux machine.

## Design Principles

1. **Source of Truth = GitHub Repo**: All configuration lives in this repository
2. **Declarative**: Describe what should exist, not how to create it
3. **Machine-Agnostic**: Templates handle differences between machines
4. **Secrets-Safe**: Encrypted secrets, no plaintext credentials
5. **Modular**: Each tool/service has its own directory

## How It Works

```
┌─────────────────┐      chezmoi init      ┌──────────────────────┐
│  New Machine    │ ◄───────────────────── │  GitHub Repo         │
│                 │                         │  (denny-all-in-one)  │
└─────────────────┘                         └──────────────────────┘
         │                                            │
         │ chezmoi apply                              │ git push
         ▼                                            │
┌─────────────────┐                         ┌──────────────────────┐
│  ~/.config/*    │ ──────────────────────▶ │  home/.config/*      │
│  ~/.claude/*    │    Edit locally &       │  home/.claude/*      │
│  ~/.bashrc      │    chezmoi add          │  (tracked by git)    │
└─────────────────┘                         └──────────────────────┘
```

## Directory Structure

```
denny-all-in-one/
├── .chezmoi.toml.tmpl    # chezmoi config (variables, merge, etc.)
├── .chezmoiignore         # What NOT to track (state, cache, secrets)
├── home/                  # chezmoi source (maps to ~/)
│   ├── .claude/          # Claude Code assets
│   │   ├── .claude.json.tmpl    # User preferences (theme, features)
│   │   ├── settings.json        # Hooks, plugins, MCP
│   │   ├── CLAUDE.md            # Global instructions
│   │   ├── skills/              # 20+ custom skills
│   │   ├── scripts/             # Custom scripts
│   │   └── hooks/               # Hook scripts
│   ├── .codex/           # Codex AI config
│   ├── .config/          # XDG config directory
│   │   ├── nvim/         # Neovim config
│   │   ├── git/          # Git config
│   │   ├── go/           # Go tools config
│   │   └── uv/           # Python/UV config
│   ├── .cargo/           # Rust/Cargo config
│   ├── .bashrc           # Bash configuration
│   └── .profile          # Shell profile
├── scripts/
│   ├── bootstrap.sh      # One-time setup for new machines
│   └── doctor.sh         # Health check script
└── docs/
    └── ARCHITECTURE.md   # This file
```

## Chezmoi Concepts

### Source State vs. Destination State

- **Source**: Files in `home/` directory (tracked by git)
- **Destination**: Files in `~/` (your actual home directory)
- chezmoi manages the transformation from source → destination

### Special File Types chezmoi recognizes:

| Source Name                | Destination Name | Behavior                              |
|----------------------------|------------------|---------------------------------------|
| `.bashrc`                  | `~/.bashrc`      | Direct copy                           |
| `.bashrc.tmpl`             | `~/.bashrc`      | Template (Go syntax)                  |
| `.bashrc_private.tmpl`     | `~/.bashrc`      | Encrypted template                    |
| `dot_bashrc`               | `~/.bashrc`      | Explicit rename                       |
| `executable_*.sh`          | `*.sh`           | Make executable                       |

### Template Variables

Available in `.tmpl` files:

```go
{{ .chezmoi.homeDir }}      # /home/username
{{ .chezmoi.sourceDir }}    # Path to this repo
{{ .hostname }}             # System hostname
{{ .username }}             # Current username
{{ .email }}                # From --data email=...
{{ .editor }}               # From --data editor=...
```

## Module Details

### Claude Code (.claude/)

**Included:**
- `settings.json` - Hooks, MCP servers, plugins, permissions
- `CLAUDE.md` - Global behavior instructions
- `skills/` - Custom validation and e2e test skills
- `scripts/` - Utility scripts (status line, etc.)
- `hooks/` - Session checkpoint hooks

**Excluded:**
- `.claude.json` state (project trust, session history)
- Cache, logs, temporary files
- Note: User preferences from `.claude.json` are in `.claude.json.tmpl`

### Codex (.codex/)

**Included:**
- `config.toml` - Codex configuration

**Excluded:**
- `auth.json` - Authentication tokens
- `history.jsonl` - Session history
- `models_cache.json` - Downloaded models

### Development Tools (.config/)

**nvim/**: Neovim configuration
**git/**: Git configuration and includes
**go/**: Go development tools config
**uv/**: Python package manager config

### Shell Configuration

**.bashrc**: Main bash configuration
**.profile**: Shell profile (login shell)

## Secrets Management

chezmoi supports encrypted files:

```bash
# Encrypt a file
chezmoi secret encrypt --recipient <key-id> secret.txt > secret.txt.age

# Use in config
home/.secret/config.age  → ~/.secret/config (decrypted on apply)

# Template with secret
{{ .chezmoi.homeDir }}/.secret/api_token.age
```

## Machine Differences

Use templates for per-machine customization:

```toml
# .chezmoi.toml.tmpl
[data]
  # Automatically populated
  hostname = "{{ .hostname }}"
  username = "{{ .username }}"
```

```bash
# In a script or config
HOSTNAME={{ .hostname }}
```

## Daily Workflow

### On your primary machine:

```bash
# Edit configs normally
vim ~/.claude/settings.json

# When ready to commit changes:
chezmoi add ~/.claude/settings.json
cd ~/.local/share/denny-all-in-one
git add -A
git commit -m "Update Claude settings"
git push
```

### On another machine:

```bash
# Pull and apply latest changes
chezmoi update
chezmoi apply
```

## Troubleshooting

### See what would change without applying:

```bash
chezmoi diff
```

### Interactive conflict resolution:

```bash
chezmoi merge
```

### List all managed files:

```bash
chezmoi managed
```

### Remove file from management:

```bash
chezmoi remove ~/.some/file
rm ~/.local/share/denny-all-in-one/home/some/file
```

## Future Extensibility

To add new tools:

1. Add config directory to `home/` or `home/.config/`
2. Update this architecture document
3. Run `chezmoi add` to track new files
4. Commit and push

Example - Adding tmux:

```bash
mkdir -p home/.config/tmux
cp ~/.config/tmux/tmux.conf home/.config/tmux/
chezmoi add ~/.config/tmux/tmux.conf
```

## References

- [chezmoi documentation](https://chezmoi.io/)
- [Claude Code docs](https://code.claude.com/)
- [Codex docs](https://docs.openai.com/codex)
