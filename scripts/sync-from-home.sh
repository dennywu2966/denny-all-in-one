#!/usr/bin/env bash
# Sync dotfiles from home directory to this project
# Usage: ./scripts/sync-from-home.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="$HOME"

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

# Function to create a template from a secrets file
create_secret_template() {
    local src="$1"
    local dest="$2"
    local name="$3"

    if [ -f "$src" ]; then
        mkdir -p "$(dirname "$dest")"
        # Create template with placeholder values
        cat "$src" | sed -E 's/"(access_key_id|access_key_secret|token|password|secret|key)": "[^"]*"/"\1": "{{ .\1 }}"/g' > "$dest"
        echo "✓ $name (template created)"
    else
        echo "✗ $name (not found)"
    fi
}

echo "1. Syncing Claude Code configs..."
sync_item "$HOME_DIR/.claude/settings.json" "$PROJECT_DIR/home/.claude/settings.json" "settings.json"
sync_item "$HOME_DIR/.claude/CLAUDE.md" "$PROJECT_DIR/home/.claude/CLAUDE.md" "CLAUDE.md"
sync_item "$HOME_DIR/.claude/.mcp.json" "$PROJECT_DIR/home/.claude/.mcp.json" ".mcp.json"

# Sync skills (preserve structure)
echo ""
echo "2. Syncing Claude Code skills..."
rm -rf "$PROJECT_DIR/home/.claude/skills" 2>/dev/null || true
cp -r "$HOME_DIR/.claude/skills" "$PROJECT_DIR/home/.claude/skills"
# Clean up unwanted files
find "$PROJECT_DIR/home/.claude/skills" -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null || true
find "$PROJECT_DIR/home/.claude/skills" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find "$PROJECT_DIR/home/.claude/skills" -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true
echo "✓ skills/ ($(ls "$PROJECT_DIR/home/.claude/skills" 2>/dev/null | wc -l) skills)"

echo ""
echo "3. Syncing Claude Code scripts..."
rm -rf "$PROJECT_DIR/home/.claude/scripts" 2>/dev/null || true
cp -r "$HOME_DIR/.claude/scripts" "$PROJECT_DIR/home/.claude/scripts" 2>/dev/null || echo "  (no scripts)"
echo "✓ scripts/"

echo ""
echo "4. Syncing Claude Code hooks..."
rm -rf "$PROJECT_DIR/home/.claude/hooks" 2>/dev/null || true
cp -r "$HOME_DIR/.claude/hooks" "$PROJECT_DIR/home/.claude/hooks" 2>/dev/null || echo "  (no hooks)"
echo "✓ hooks/"

echo ""
echo "5. Syncing Codex config..."
sync_item "$HOME_DIR/.codex/config.toml" "$PROJECT_DIR/home/.codex/config.toml" "config.toml"

echo ""
echo "6. Syncing OpenCode config..."
sync_item "$HOME_DIR/.config/opencode/opencode.json" "$PROJECT_DIR/home/.config/opencode/opencode.json" "opencode.json"

echo ""
echo "7. Syncing Neovim config..."
rm -rf "$PROJECT_DIR/home/.config/nvim" 2>/dev/null || true
cp -r "$HOME_DIR/.config/nvim" "$PROJECT_DIR/home/.config/nvim"
echo "✓ nvim/"

echo ""
echo "8. Syncing Git config..."
sync_item "$HOME_DIR/.config/git/ignore" "$PROJECT_DIR/home/.config/git/ignore" "git ignore"

echo ""
echo "9. Syncing Shell configs..."
# Sync .bashrc with secrets stripped
if [ -f "$HOME_DIR/.bashrc" ]; then
    cp "$HOME_DIR/.bashrc" "$PROJECT_DIR/home/.bashrc"
    # Strip API keys and secrets (lines containing common secret patterns)
    sed -i -E '/export (RAM_AK|RAM_SK|JINA_API_KEY|DASHSCOPE_API_KEY|APP_ID|Z_AI_API_KEY|BIGMODEL_TOKEN|RUBE_TOKEN|KAGGLE_API_TOKEN|ANTHROPIC_API_KEY|OPENAI_API_KEY|BRAVE_API_KEY|SERPAPI_KEY|EXA_API_KEY|TAVILY_API_KEY|ZAI_API_KEY)=/d' "$PROJECT_DIR/home/.bashrc"
    echo "✓ .bashrc (secrets stripped)"
fi
sync_item "$HOME_DIR/.profile" "$PROJECT_DIR/home/.profile" ".profile"

echo ""
echo "10. Syncing ~/.agents..."
rm -rf "$PROJECT_DIR/home/.agents" 2>/dev/null || true
if [ -d "$HOME_DIR/.agents" ]; then
    cp -r "$HOME_DIR/.agents" "$PROJECT_DIR/home/.agents"
    # Remove lock files and caches
    rm -f "$PROJECT_DIR/home/.agents/.skill-lock.json" 2>/dev/null || true
    find "$PROJECT_DIR/home/.agents" -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$PROJECT_DIR/home/.agents" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    echo "✓ .agents/ ($(ls "$PROJECT_DIR/home/.agents/skills" 2>/dev/null | wc -l) skills)"
else
    echo "✗ .agents/ (not found)"
fi

echo ""
echo "11. Syncing ~/.scripts..."
rm -rf "$PROJECT_DIR/home/.scripts" 2>/dev/null || true
if [ -d "$HOME_DIR/.scripts" ]; then
    cp -r "$HOME_DIR/.scripts" "$PROJECT_DIR/home/.scripts"
    echo "✓ .scripts/"
else
    echo "✗ .scripts/ (not found)"
fi

echo ""
echo "12. Syncing ~/.aliyun (template only - secrets excluded)..."
if [ -d "$HOME_DIR/.aliyun" ]; then
    mkdir -p "$PROJECT_DIR/home/.aliyun"
    # Create template with placeholders for secrets
    if [ -f "$HOME_DIR/.aliyun/config.json" ]; then
        cat > "$PROJECT_DIR/home/.aliyun/config.json.tmpl" << 'EOF'
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
        echo "✓ .aliyun/config.json.tmpl (template created)"
    fi
else
    echo "✗ .aliyun/ (not found)"
fi

echo ""
echo "13. Syncing ~/.oss (template only - secrets excluded)..."
if [ -d "$HOME_DIR/.oss" ]; then
    mkdir -p "$PROJECT_DIR/home/.oss"
    # Create template with placeholders for secrets
    if [ -f "$HOME_DIR/.oss/credentials.json" ]; then
        cat > "$PROJECT_DIR/home/.oss/credentials.json.tmpl" << 'EOF'
{
  "access_key_id": "{{ (bitwarden "item" "aliyun-access-key").login.username }}",
  "access_key_secret": "{{ (bitwarden "item" "aliyun-access-key").login.password }}",
  "endpoint": "oss-ap-southeast-1-internal.aliyuncs.com",
  "region": "ap-southeast-1",
  "bucket_name": "denny-test-lance"
}
EOF
        echo "✓ .oss/credentials.json.tmpl (template created)"
    fi
else
    echo "✗ .oss/ (not found)"
fi

echo ""
echo "=== Sync Complete ==="
echo ""
echo "Changes summary:"
echo "  Claude Code: settings, CLAUDE.md, skills, scripts, hooks"
echo "  Codex: config.toml"
echo "  OpenCode: opencode.json"
echo "  Neovim: init.vim, lazy-lock.json"
echo "  Shell: .bashrc (secrets stripped), .profile"
echo "  Agents: .agents/skills/"
echo "  Scripts: .scripts/"
echo "  Aliyun: .aliyun/config.json.tmpl (template)"
echo "  OSS: .oss/credentials.json.tmpl (template)"
echo ""
echo "NOTE: Secret files (.aliyun/config.json, .oss/credentials.json) are NOT synced."
echo "      Templates created for chezmoi to generate with your secret manager."
echo ""
echo "Next: git add -A && git commit -m 'Sync latest configs' && git push"
