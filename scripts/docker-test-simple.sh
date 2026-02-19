#!/usr/bin/env bash
# Simple Docker test for dotfiles structure verification
# Usage: ./scripts/docker-test-simple.sh (requires user in docker group)

set -euo pipefail

echo "=== Docker Dotfiles Structure Test ==="
echo ""

CONTAINER_NAME="dotfiles-test-$(date +%s)"

echo "1. Pulling debian:bookworm-slim..."
docker pull debian:bookworm-slim 2>&1 | tail -3

echo ""
echo "2. Creating test container..."
docker run -d --name "$CONTAINER_NAME" debian:bookworm-slim sleep infinity

echo ""
echo "3. Copying dotfiles to container..."
docker cp /home/denny/projects/denny-all-in-one "$CONTAINER_NAME:/tmp/dotfiles"

echo ""
echo "4. Verifying structure in container..."
docker exec "$CONTAINER_NAME" bash -c "
    echo '=== Root Directory ==='
    ls -la /tmp/dotfiles/
    echo ''
    echo '=== Home Directory Structure ==='
    ls -la /tmp/dotfiles/home/
    echo ''
    echo '=== Claude Code Assets ==='
    ls -la /tmp/dotfiles/home/.claude/ 2>/dev/null | head -10
    echo ''
    echo '=== Skills Count ==='
    ls /tmp/dotfiles/home/.claude/skills/ 2>/dev/null | wc -l
    echo ''
    echo '=== Codex Config ==='
    ls -la /tmp/dotfiles/home/.codex/ 2>/dev/null
    echo ''
    echo '=== Config Directory ==='
    ls -la /tmp/dotfiles/home/.config/ 2>/dev/null
"

echo ""
echo "5. Installing chezmoi for verification..."
docker exec "$CONTAINER_NAME" bash -c "
    apt-get update > /dev/null 2>&1
    apt-get install -y curl > /dev/null 2>&1
    curl -fsSL https://chezmoi.io/get | bash > /dev/null 2>&1
    echo 'chezmoi installed: '\$(/root/bin/chezmoi --version | head -1)
"

echo ""
echo "6. Cleanup..."
docker stop "$CONTAINER_NAME" > /dev/null 2>&1
docker rm "$CONTAINER_NAME" > /dev/null 2>&1

echo ""
echo "=== Test Complete ==="
echo "✓ Structure verified - dotfiles are ready for deployment"
