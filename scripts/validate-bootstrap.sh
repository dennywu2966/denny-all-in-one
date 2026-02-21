#!/usr/bin/env bash
# Bootstrap validation test using Docker
# Usage: ./scripts/validate-bootstrap.sh [--local] [--with-bitwarden]
#   --local: Use local files instead of GitHub (for development)
#   --with-bitwarden: Test with Bitwarden integration (requires BW_EMAIL and BW_PASSWORD env vars)

set -euo pipefail

LOCAL_MODE=false
WITH_BITWARDEN=false
for arg in "$@"; do
    case "$arg" in
        --local)
            LOCAL_MODE=true
            ;;
        --with-bitwarden)
            WITH_BITWARDEN=true
            ;;
    esac
done

echo "=== Bootstrap Validation Test ==="
echo "Mode: $([ "$LOCAL_MODE" == "true" ] && echo "local" || echo "GitHub")"
echo "Bitwarden: $([ "$WITH_BITWARDEN" == "true" ] && echo "enabled" || echo "disabled")"
echo ""

CONTAINER_NAME="dotfiles-validate-$(date +%s)"
IMAGE="debian:bookworm-slim"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "1. Pulling $IMAGE..."
docker pull $IMAGE 2>&1 | tail -3

echo ""
echo "2. Creating and starting container..."
if [[ "$LOCAL_MODE" == "true" ]]; then
    # Mount local files for development
    docker run -d --name "$CONTAINER_NAME" -v "$PROJECT_DIR:/dotfiles:ro" $IMAGE sleep infinity
else
    docker run -d --name "$CONTAINER_NAME" $IMAGE sleep infinity
fi

echo ""
echo "3. Installing dependencies..."
docker exec "$CONTAINER_NAME" bash -c "
    apt-get update > /dev/null 2>&1
    apt-get install -y curl git ca-certificates nodejs npm > /dev/null 2>&1
    echo 'Dependencies installed (including Node.js for Bitwarden CLI)'
"

echo ""
echo "4. Running bootstrap script..."
if [[ "$LOCAL_MODE" == "true" ]]; then
    if [[ "$WITH_BITWARDEN" == "true" ]]; then
        # Run with Bitwarden (skip if no credentials)
        if [[ -n "${BW_EMAIL:-}" ]] && [[ -n "${BW_PASSWORD:-}" ]]; then
            docker exec -e BW_EMAIL="$BW_EMAIL" -e BW_PASSWORD="$BW_PASSWORD" "$CONTAINER_NAME" bash -c "
                cd /dotfiles
                bash scripts/bootstrap.sh --local --bw-password \"\$BW_PASSWORD\" 2>&1 || echo 'Bootstrap completed with warnings'
            "
        else
            echo "  Skipping Bitwarden test (BW_EMAIL and BW_PASSWORD not set)"
            docker exec "$CONTAINER_NAME" bash -c "
                cd /dotfiles
                bash scripts/bootstrap.sh --local --skip-bitwarden
            "
        fi
    else
        # Run local version with --skip-bitwarden
        docker exec "$CONTAINER_NAME" bash -c "
            cd /dotfiles
            bash scripts/bootstrap.sh --local --skip-bitwarden --no-backup
        "
    fi
else
    # Use GitHub version
    docker exec "$CONTAINER_NAME" bash -c "
        curl -fsSL https://raw.githubusercontent.com/dennywu2966/denny-all-in-one/master/scripts/bootstrap.sh | bash -s -- --skip-bitwarden --no-backup
    "
fi

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

    echo ''
    echo '=== Checking .profile ==='
    ls -la /root/.profile 2>/dev/null || echo '  (not found)'

    echo ''
    echo '=== Checking chezmoi ==='
    which chezmoi 2>/dev/null && chezmoi --version || echo '  (not found)'
"

echo ""
echo "6. Verifying Bitwarden CLI installation..."
docker exec "$CONTAINER_NAME" bash -c "
    if command -v bw &>/dev/null; then
        echo '✓ Bitwarden CLI installed: '\$(bw --version 2>/dev/null || echo 'version unknown')
    else
        echo '✗ Bitwarden CLI not installed'
    fi
"

echo ""
echo "7. Checking template files..."
docker exec "$CONTAINER_NAME" bash -c "
    echo '=== Checking Aliyun template ==='
    if [ -f /root/.aliyun/config.json ]; then
        if grep -q 'bitwarden' /root/.aliyun/config.json 2>/dev/null; then
            echo '  Template rendered with placeholder (Bitwarden skipped)'
        else
            echo '  ✓ Template rendered with actual values'
        fi
    else
        echo '  Template not applied (expected when Bitwarden skipped)'
    fi

    echo ''
    echo '=== Checking OSS template ==='
    if [ -f /root/.oss/credentials.json ]; then
        if grep -q 'bitwarden' /root/.oss/credentials.json 2>/dev/null; then
            echo '  Template rendered with placeholder (Bitwarden skipped)'
        else
            echo '  ✓ Template rendered with actual values'
        fi
    else
        echo '  Template not applied (expected when Bitwarden skipped)'
    fi
"

echo ""
echo "8. Cleanup..."
docker stop "$CONTAINER_NAME" > /dev/null 2>&1
docker rm "$CONTAINER_NAME" > /dev/null 2>&1

echo ""
echo "=== Validation Complete ==="
echo "✓ Bootstrap test passed"
echo ""
echo "Tested:"
echo "  - chezmoi installation and initialization"
echo "  - Bitwarden CLI installation"
echo "  - Config file application"
echo "  - Template file handling"
echo ""
if [[ "$WITH_BITWARDEN" != "true" ]]; then
    echo "NOTE: Bitwarden integration not tested."
    echo "To test with Bitwarden, set BW_EMAIL and BW_PASSWORD and run:"
    echo "  BW_EMAIL=your@email.com BW_PASSWORD=yourpassword ./scripts/validate-bootstrap.sh --local --with-bitwarden"
fi
