#!/usr/bin/env bash
# Bitwarden CLI helper script for chezmoi integration
# Usage: ./scripts/bw-manage.sh [command]
#
# Commands:
#   login     - Login to Bitwarden
#   unlock    - Unlock vault and export session
#   status    - Check login/lock status
#   sync      - Sync vault with server
#   list      - List all items
#   create    - Create a new API key item
#   session   - Print export command for BW_SESSION

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if bw is installed
check_bw() {
    if ! command -v bw &>/dev/null; then
        log_error "Bitwarden CLI not installed. Install with:"
        echo "  npm install -g @bitwarden/cli"
        exit 1
    fi
}

# Login to Bitwarden
do_login() {
    check_bw
    local status=$(bw status 2>/dev/null | jq -r '.status')

    if [[ "$status" == "unauthenticated" ]]; then
        log_info "Logging in to Bitwarden..."
        echo ""
        echo "Choose login method:"
        echo "  1) Device authorization (recommended for servers)"
        echo "  2) Email + password"
        echo ""
        read -rp "Choice [1]: " choice
        choice=${choice:-1}

        if [[ "$choice" == "1" ]]; then
            bw login --method 0
        else
            read -rp "Email: " email
            bw login "$email"
        fi
    else
        log_info "Already logged in (status: $status)"
    fi
}

# Unlock vault and get session key
do_unlock() {
    check_bw
    local status=$(bw status 2>/dev/null | jq -r '.status')

    if [[ "$status" == "unauthenticated" ]]; then
        log_error "Not logged in. Run: $0 login"
        exit 1
    fi

    if [[ "$status" == "locked" ]]; then
        log_info "Unlocking vault..."
        local session=$(bw unlock --raw 2>/dev/null)
        if [[ -n "$session" ]]; then
            echo ""
            log_info "Vault unlocked! Run this command to set session:"
            echo ""
            echo -e "${YELLOW}export BW_SESSION=\"$session\"${NC}"
            echo ""
            log_info "Or add to your shell for this session:"
            echo "  eval \"\$($0 session)\""
        fi
    else
        log_info "Vault already unlocked"
    fi
}

# Print session export command
do_session() {
    check_bw
    local status=$(bw status 2>/dev/null | jq -r '.status')

    if [[ "$status" == "locked" ]]; then
        local session=$(bw unlock --raw 2>/dev/null)
        if [[ -n "$session" ]]; then
            echo "export BW_SESSION=\"$session\""
        fi
    elif [[ "$status" == "unlocked" ]]; then
        log_warn "Vault already unlocked. BW_SESSION should be set."
    else
        log_error "Not logged in. Run: $0 login"
    fi
}

# Check status
do_status() {
    check_bw
    bw status 2>/dev/null | jq .
}

# Sync vault
do_sync() {
    check_bw
    log_info "Syncing vault..."
    bw sync
    log_info "Sync complete"
}

# List items
do_list() {
    check_bw
    bw list items 2>/dev/null | jq -r '.[] | "\(.name) (\(.type))"' 2>/dev/null || {
        log_error "Cannot list items. Make sure vault is unlocked."
        echo "Run: $0 unlock"
    }
}

# Create API key item
do_create() {
    check_bw

    echo ""
    echo "=== Create API Key Item ==="
    echo ""
    read -rp "Item name (e.g., aliyun-access-key): " name
    read -rp "Access Key ID: " key_id
    read -rsp "Access Key Secret: " key_secret
    echo ""
    read -rp "Notes (optional): " notes

    local json=$(cat << EOF
{
  "type": 1,
  "name": "$name",
  "login": {
    "username": "$key_id",
    "password": "$key_secret"
  },
  "notes": "$notes"
}
EOF
)

    echo ""
    log_info "Creating item..."
    echo "$json" | bw encode | bw create item
    log_info "Item '$name' created successfully"
}

# Test chezmoi integration
do_test() {
    check_bw

    if [[ -z "${BW_SESSION:-}" ]]; then
        log_error "BW_SESSION not set. Run: eval \"\$($0 session)\""
        exit 1
    fi

    log_info "Testing Bitwarden + chezmoi integration..."

    # Test getting an item
    if bw get item "aliyun-access-key" &>/dev/null; then
        log_info "✓ Found 'aliyun-access-key' item"
        echo ""
        echo "Access Key ID: $(bw get item "aliyun-access-key" | jq -r '.login.username')"
        echo "Secret: $(bw get item "aliyun-access-key" | jq -r '.login.password' | head -c 10)..."
    else
        log_warn "✗ 'aliyun-access-key' item not found"
        log_info "Create it with: $0 create"
    fi
}

# Usage
usage() {
    echo "Bitwarden CLI helper for chezmoi integration"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  login     Login to Bitwarden"
    echo "  unlock    Unlock vault and get session key"
    echo "  session   Print export command for BW_SESSION"
    echo "  status    Check login/lock status"
    echo "  sync      Sync vault with server"
    echo "  list      List all items"
    echo "  create    Create a new API key item"
    echo "  test      Test chezmoi integration"
    echo ""
    echo "Quick start:"
    echo "  1. $0 login"
    echo "  2. eval \"\$($0 session)\""
    echo "  3. chezmoi apply"
}

# Main
case "${1:-}" in
    login)   do_login ;;
    unlock)  do_unlock ;;
    session) do_session ;;
    status)  do_status ;;
    sync)    do_sync ;;
    list)    do_list ;;
    create)  do_create ;;
    test)    do_test ;;
    *)       usage ;;
esac
