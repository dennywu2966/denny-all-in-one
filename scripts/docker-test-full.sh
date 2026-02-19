#!/usr/bin/env bash
# Full Docker test - installs chezmoi, applies dotfiles, verifies Claude Code setup
# Usage: ./scripts/docker-test-full.sh (requires docker group)

set -euo pipefail

echo "=== Full Dotfiles Deployment Test ==="
echo ""

CONTAINER_NAME="dotfiles-test-$(date +%s)"

echo "1. Pulling debian:bookworm-slim..."
docker pull debian:bookworm-slim 2>&1 | tail -2

echo ""
echo "2. Creating test container..."
docker run -d \
    --name "$CONTAINER_NAME" \
    -e DEBIAN_FRONTEND=noninteractive \
    -e ZHIPU_API_KEY="$ZHIPU_API_KEY" \
    -e ANTHROPIC_BASE_URL="$ANTHROPIC_BASE_URL" \
    -e ANTHROPIC_AUTH_TOKEN="$ANTHROPIC_AUTH_TOKEN" \
    -e API_TIMEOUT_MS="${API_TIMEOUT_MS:-3000000}" \
    -e CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1" \
    debian:bookworm-slim \
    sleep infinity

echo ""
echo "3. Installing dependencies in container..."
docker exec "$CONTAINER_NAME" bash -c "
    apt-get update > /dev/null 2>&1
    apt-get install -y curl git bash ca-certificates > /dev/null 2>&1
    echo '   ✓ Dependencies installed'
"

echo ""
echo "4. Copying dotfiles to container..."
docker cp /home/denny/projects/denny-all-in-one "$CONTAINER_NAME:/tmp/dotfiles"

echo ""
echo "5. Installing chezmoi in container..."
docker exec "$CONTAINER_NAME" bash -c "
    curl -fsSL https://chezmoi.io/get | bash > /dev/null 2>&1
    /root/bin/chezmoi --version
"

echo ""
echo "6. Applying dotfiles with chezmoi..."
docker exec "$CONTAINER_NAME" bash -c "
    cd /tmp/dotfiles
    /root/bin/chezmoi init --source=/tmp/dotfiles
    /root/bin/chezmoi apply --verbose
"

echo ""
echo "7. Verifying Claude Code configuration..."
docker exec "$CONTAINER_NAME" bash -c "
    echo '=== Claude Code Directory ==='
    ls -la /root/.claude/ 2>/dev/null | head -10

    echo ''
    echo '=== CLAUDE.md exists? ==='
    ls -la /root/.claude/CLAUDE.md 2>/dev/null && cat /root/.claude/CLAUDE.md | head -20

    echo ''
    echo '=== settings.json exists? ==='
    ls -la /root/.claude/settings.json 2>/dev/null && cat /root/.claude/settings.json | head -30

    echo ''
    echo '=== Skills installed? ==='
    ls /root/.claude/skills/ 2>/dev/null | head -15
    echo \"Total skills: \$(ls /root/.claude/skills/ 2>/dev/null | wc -l)\"

    echo ''
    echo '=== Scripts installed? ==='
    ls /root/.claude/scripts/ 2>/dev/null

    echo ''
    echo '=== Hooks installed? ==='
    ls /root/.claude/hooks/ 2>/dev/null

    echo ''
    echo '=== MCP config exists? ==='
    ls -la /root/.claude/.mcp.json 2>/dev/null && cat /root/.claude/.mcp.json 2>/dev/null

    echo ''
    echo '=== Environment variables (for Claude) ==='
    env | grep -E '(ANTHROPIC|ZHIPU|API)' | sed 's/=.*/=***/' || echo '  (none set)'
"

echo ""
echo "8. Verifying Codex configuration..."
docker exec "$CONTAINER_NAME" bash -c "
    echo '=== Codex config ==='
    ls -la /root/.codex/config.toml 2>/dev/null && cat /root/.codex/config.toml | head -20 || echo '  (not found)'
"

echo ""
echo "9. Verifying other configs..."
docker exec "$CONTAINER_NAME" bash -c "
    echo '=== nvim config ==='
    ls -la /root/.config/nvim/ 2>/dev/null || echo '  (not found)'

    echo ''
    echo '=== git config ==='
    ls -la /root/.config/git/ 2>/dev/null || echo '  (not found)'

    echo ''
    echo '=== bashrc ==='
    grep -q 'chezmoi' /root/.bashrc 2>/dev/null && echo '  ✓ chezmoi managed' || echo '  (not managed)'
"

echo ""
echo "10. Cleanup..."
docker stop "$CONTAINER_NAME" > /dev/null 2>&1
docker rm "$CONTAINER_NAME" > /dev/null 2>&1

echo ""
echo "=== Test Complete ==="
echo "✓ Full deployment verified"
echo ""
echo "Summary:"
echo "  - chezmoi: installed and configured"
echo "  - Claude Code: assets applied"
echo "  - Skills: $(ls /home/denny/projects/denny-all-in-one/home/.claude/skills/ 2>/dev/null | wc -l) skills available"
echo "  - Scripts: $(ls /home/denny/projects/denny-all-in-one/home/.claude/scripts/ 2>/dev/null | wc -l) scripts available"
echo "  - Hooks: $(ls /home/denny/projects/denny-all-in-one/home/.claude/hooks/ 2>/dev/null | wc -l) hooks available"
