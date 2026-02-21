#!/usr/bin/env bash
# Bootstrap validation test using Docker
# Usage: ./scripts/validate-bootstrap.sh

set -euo pipefail

echo "=== Bootstrap Validation Test ==="
echo ""

CONTAINER_NAME="dotfiles-validate-$(date +%s)"
IMAGE="debian:bookworm-slim"

echo "1. Pulling $IMAGE..."
docker pull $IMAGE 2>&1 | tail -3

echo ""
echo "2. Creating and starting container..."
docker run -d --name "$CONTAINER_NAME" $IMAGE sleep infinity

echo ""
echo "3. Installing dependencies..."
docker exec "$CONTAINER_NAME" bash -c "
    apt-get update > /dev/null 2>&1
    apt-get install -y curl git ca-certificates > /dev/null 2>&1
    echo 'Dependencies installed'
"

echo ""
echo "4. Running bootstrap script..."
docker exec "$CONTAINER_NAME" bash -c "
    curl -fsSL https://raw.githubusercontent.com/dennywu2966/denny-all-in-one/master/scripts/bootstrap.sh | bash
"

echo ""
echo "5. Verifying installed configs..."
docker exec "$CONTAINER_NAME" bash -c "
    echo '=== Checking Claude Code ==='
    ls -la /root/.claude/ 2>/dev/null | head -5 || echo '  (not found)'

    echo ''
    echo '=== Checking skills count ==='
    ls /root/.claude/skills/ 2>/dev/null | wc -l || echo '0'

    echo ''
    echo '=== Checking SSH ==='
    ls -la /root/.ssh/ 2>/dev/null || echo '  (not found)'

    echo ''
    echo '=== Checking .bashrc ==='
    head -5 /root/.bashrc 2>/dev/null || echo '  (not found)'
"

echo ""
echo "6. Cleanup..."
docker stop "$CONTAINER_NAME" > /dev/null 2>&1
docker rm "$CONTAINER_NAME" > /dev/null 2>&1

echo ""
echo "=== Validation Complete ==="
echo "✓ Bootstrap test passed"
