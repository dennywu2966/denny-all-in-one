#!/usr/bin/env bash
# Sync dotfiles from home directory to this project
# Converts files to chezmoi source format (dot_ prefix)
# Files are synced to the repo root (chezmoi source directory)
# Usage: ./scripts/sync-from-home.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="$HOME"

# Convert dotfile name to chezmoi source name
# .bashrc -> dot_bashrc, .config -> dot_config
to_chezmoi_name() {
    local name="$1"
    # Remove leading dot and add dot_ prefix
    echo "dot_${name#.}"
}

echo "=== Syncing Dotfiles from Home ==="
echo "Project: $PROJECT_DIR"
echo "Home: $HOME_DIR"
echo ""

# Function to sync a file/directory
sync_item() {
    local src="$1"
    local dest="$2"
    local name="$3"

    if [ -e "$src" ]; then
        mkdir -p "$(dirname "$dest")"
        cp -r "$src" "$dest"
        echo "✓ $name"
    else
        echo "✗ $name (not found)"
    fi
}

echo "1. Syncing Claude Code configs..."
CLAUDE_DIR="$PROJECT_DIR/$(to_chezmoi_name .claude)"
sync_item "$HOME_DIR/.claude/settings.json" "$CLAUDE_DIR/settings.json" "settings.json"
sync_item "$HOME_DIR/.claude/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md" "CLAUDE.md"
sync_item "$HOME_DIR/.claude/.mcp.json" "$CLAUDE_DIR/.mcp.json" ".mcp.json"

# Sync skills (preserve structure)
echo ""
echo "2. Syncing Claude Code skills..."
rm -rf "$CLAUDE_DIR/skills" 2>/dev/null || true
cp -r "$HOME_DIR/.claude/skills" "$CLAUDE_DIR/skills"
# Clean up unwanted files
find "$CLAUDE_DIR/skills" -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null || true
find "$CLAUDE_DIR/skills" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find "$CLAUDE_DIR/skills" -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true
echo "✓ skills/ ($(ls "$CLAUDE_DIR/skills" 2>/dev/null | wc -l) skills)"

echo ""
echo "3. Syncing Claude Code scripts..."
rm -rf "$CLAUDE_DIR/scripts" 2>/dev/null || true
cp -r "$HOME_DIR/.claude/scripts" "$CLAUDE_DIR/scripts" 2>/dev/null || echo "  (no scripts)"
echo "✓ scripts/"

echo ""
echo "4. Syncing Claude Code hooks..."
rm -rf "$CLAUDE_DIR/hooks" 2>/dev/null || true
cp -r "$HOME_DIR/.claude/hooks" "$CLAUDE_DIR/hooks" 2>/dev/null || echo "  (no hooks)"
echo "✓ hooks/"

echo ""
echo "5. Syncing Codex config..."
CODEX_DIR="$PROJECT_DIR/$(to_chezmoi_name .codex)"
sync_item "$HOME_DIR/.codex/config.toml" "$CODEX_DIR/config.toml" "config.toml"

echo ""
echo "6. Syncing OpenCode config..."
CONFIG_DIR="$PROJECT_DIR/$(to_chezmoi_name .config)"
sync_item "$HOME_DIR/.config/opencode/opencode.json" "$CONFIG_DIR/opencode/opencode.json" "opencode.json"

echo ""
echo "7. Syncing Neovim config..."
rm -rf "$CONFIG_DIR/nvim" 2>/dev/null || true
cp -r "$HOME_DIR/.config/nvim" "$CONFIG_DIR/nvim"
echo "✓ nvim/"

echo ""
echo "8. Syncing Git config..."
sync_item "$HOME_DIR/.config/git/ignore" "$CONFIG_DIR/git/ignore" "git ignore"

echo ""
echo "9. Syncing Shell configs..."
# Sync .bashrc with secrets stripped
BASHRC_DEST="$PROJECT_DIR/$(to_chezmoi_name .bashrc)"
if [ -f "$HOME_DIR/.bashrc" ]; then
    cp "$HOME_DIR/.bashrc" "$BASHRC_DEST"
    # Strip API keys and secrets (lines containing common secret patterns)
    # These should be stored in Bitwarden and accessed via templates
    sed -i -E '/export (RAM_AK|RAM_SK|JINA_API_KEY|DASHSCOPE_API_KEY|APP_ID|Z_AI_API_KEY|BIGMODEL_TOKEN|RUBE_TOKEN|KAGGLE_API_TOKEN|ANTHROPIC_API_KEY|OPENAI_API_KEY|BRAVE_API_KEY|SERPAPI_KEY|EXA_API_KEY|TAVILY_API_KEY|ZAI_API_KEY)=/d' "$BASHRC_DEST"
    echo "✓ dot_bashrc (secrets stripped)"
fi
sync_item "$HOME_DIR/.profile" "$PROJECT_DIR/$(to_chezmoi_name .profile)" "dot_profile"

# Check for secrets in ~/.bashrc.local and offer to sync to Bitwarden
echo ""
echo "9a. Checking for API keys in ~/.bashrc.local..."
if [ -f "$HOME_DIR/.bashrc.local" ]; then
    SECRETS_COUNT=$(grep -c "export.*_KEY\|export.*_TOKEN\|export.*_SECRET\|export.*AK\|export.*SK" "$HOME_DIR/.bashrc.local" 2>/dev/null || echo "0")
    if [ "$SECRETS_COUNT" -gt 0 ]; then
        echo "  Found $SECRETS_COUNT potential secrets in ~/.bashrc.local"
        echo "  These should be stored in Bitwarden. Run: ./scripts/bw-import-keys.sh"
    else
        echo "  No API keys found in ~/.bashrc.local"
    fi
else
    echo "  ~/.bashrc.local not found"
fi

echo ""
echo "9b. Syncing SSH config (public keys only)..."
SSH_DIR="$PROJECT_DIR/$(to_chezmoi_name .ssh)"
mkdir -p "$SSH_DIR"
sync_item "$HOME_DIR/.ssh/authorized_keys" "$SSH_DIR/authorized_keys" "authorized_keys"
sync_item "$HOME_DIR/.ssh/id_ed25519.pub" "$SSH_DIR/id_ed25519.pub" "id_ed25519.pub"
sync_item "$HOME_DIR/.ssh/known_hosts" "$SSH_DIR/known_hosts" "known_hosts"

echo ""
echo "10. Syncing ~/.agents..."
AGENTS_DIR="$PROJECT_DIR/$(to_chezmoi_name .agents)"
rm -rf "$AGENTS_DIR" 2>/dev/null || true
if [ -d "$HOME_DIR/.agents" ]; then
    cp -r "$HOME_DIR/.agents" "$AGENTS_DIR"
    # Remove lock files and caches
    rm -f "$AGENTS_DIR/.skill-lock.json" 2>/dev/null || true
    find "$AGENTS_DIR" -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$AGENTS_DIR" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    echo "✓ dot_agents/ ($(ls "$AGENTS_DIR/skills" 2>/dev/null | wc -l) skills)"
else
    echo "✗ dot_agents/ (not found)"
fi

echo ""
echo "11. Syncing ~/.scripts..."
SCRIPTS_DIR="$PROJECT_DIR/$(to_chezmoi_name .scripts)"
rm -rf "$SCRIPTS_DIR" 2>/dev/null || true
if [ -d "$HOME_DIR/.scripts" ]; then
    cp -r "$HOME_DIR/.scripts" "$SCRIPTS_DIR"
    echo "✓ dot_scripts/"
else
    echo "✗ dot_scripts/ (not found)"
fi

echo ""
echo "12. Syncing ~/.aliyun (template only - secrets excluded)..."
ALIYUN_DIR="$PROJECT_DIR/$(to_chezmoi_name .aliyun)"
if [ -d "$HOME_DIR/.aliyun" ]; then
    mkdir -p "$ALIYUN_DIR"
    # Create template with placeholders for secrets
    if [ -f "$HOME_DIR/.aliyun/config.json" ]; then
        cat > "$ALIYUN_DIR/config.json.tmpl" << 'EOF'
{
	"current": "default",
	"profiles": [
		{
			"name": "default",
			"mode": "AK",
			"access_key_id": "{{ (bitwarden "item" "aliyun-access-key").login.username }}",
			"access_key_secret": "{{ (bitwarden "item" "aliyun-access-key").login.password }}",
			"region_id": "ap-southeast-1",
			"output_format": "json",
			"language": "en",
			"site": "china"
		}
	],
	"meta_path": ""
}
EOF
        echo "✓ dot_aliyun/config.json.tmpl (template created)"
    fi
else
    echo "✗ dot_aliyun/ (not found)"
fi

echo ""
echo "13. Syncing ~/.oss (template only - secrets excluded)..."
OSS_DIR="$PROJECT_DIR/$(to_chezmoi_name .oss)"
if [ -d "$HOME_DIR/.oss" ]; then
    mkdir -p "$OSS_DIR"
    # Create template with placeholders for secrets
    if [ -f "$HOME_DIR/.oss/credentials.json" ]; then
        cat > "$OSS_DIR/credentials.json.tmpl" << 'EOF'
{
  "access_key_id": "{{ (bitwarden "item" "aliyun-access-key").login.username }}",
  "access_key_secret": "{{ (bitwarden "item" "aliyun-access-key").login.password }}",
  "endpoint": "oss-ap-southeast-1-internal.aliyuncs.com",
  "region": "ap-southeast-1",
  "bucket_name": "denny-test-lance"
}
EOF
        echo "✓ dot_oss/credentials.json.tmpl (template created)"
    fi
else
    echo "✗ dot_oss/ (not found)"
fi

echo ""
echo "=== Sync Complete ==="
echo ""
echo "Changes summary:"
echo "  Claude Code: settings, CLAUDE.md, skills, scripts, hooks"
echo "  Codex: config.toml"
echo "  OpenCode: opencode.json"
echo "  Neovim: init.vim, lazy-lock.json"
echo "  Shell: dot_bashrc (secrets stripped), dot_profile"
echo "  Agents: dot_agents/skills/"
echo "  Scripts: dot_scripts/"
echo "  Aliyun: dot_aliyun/config.json.tmpl (template)"
echo "  OSS: dot_oss/credentials.json.tmpl (template)"
echo ""
echo "NOTE: Secret files (.aliyun/config.json, .oss/credentials.json) are NOT synced."
echo "      Templates created for chezmoi to generate with Bitwarden."
echo ""
echo "SECRETS MANAGEMENT:"
echo "  - API keys should be stored in Bitwarden"
echo "  - Run ./scripts/bw-import-keys.sh to import keys from ~/.bashrc.local"
echo "  - Templates use Bitwarden to render secrets at apply time"
echo ""
echo "Next: git add -A && git commit -m 'Sync latest configs' && git push"
