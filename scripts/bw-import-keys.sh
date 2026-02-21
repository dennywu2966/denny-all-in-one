#!/usr/bin/env bash
# Import API keys to Bitwarden (prompts for values)
# Usage: ./scripts/bw-import-keys.sh
#
# Prerequisites:
#   1. Create account at https://vault.bitwarden.com/#/register
#   2. Run: bw login your-email@example.com
#   3. Run: bw unlock
#   4. Run this script

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check bw is installed and logged in
check_bw() {
    if ! command -v bw &>/dev/null; then
        log_error "Bitwarden CLI not installed. Run: npm install -g @bitwarden/cli"
        exit 1
    fi

    local status=$(bw status 2>/dev/null | jq -r '.status')
    if [[ "$status" == "unauthenticated" ]]; then
        log_error "Not logged in. Run: bw login"
        exit 1
    fi
    if [[ "$status" == "locked" ]]; then
        log_error "Vault is locked. Run: bw unlock"
        exit 1
    fi
}

# Create a login item in Bitwarden
create_item() {
    local name="$1"
    local username="$2"
    local password="$3"
    local notes="$4"

    local json=$(cat << JSON
{
  "type": 1,
  "name": "$name",
  "login": {
    "username": "$username",
    "password": "$password"
  },
  "notes": "$notes"
}
JSON
)

    echo "$json" | bw encode | bw create item 2>/dev/null && \
        log_info "Created: $name" || \
        log_warn "Failed or exists: $name"
}

# Auto-detect keys from environment/shell configs
detect_keys() {
    echo "=== Auto-detecting API keys from ~/.bashrc.local ==="
    
    # Read from bashrc.local if exists
    if [[ -f ~/.bashrc.local ]]; then
        source ~/.bashrc.local 2>/dev/null || true
    fi
    
    # Check for common keys
    local items_created=0
    
    # Aliyun RAM Key
    if [[ -n "${RAM_AK:-}" && -n "${RAM_SK:-}" ]]; then
        create_item "aliyun-ram-key" "$RAM_AK" "$RAM_SK" "Aliyun RAM Access Key"
        ((items_created++)) || true
    fi
    
    # Jina API Key
    if [[ -n "${JINA_API_KEY:-}" ]]; then
        create_item "jina-api-key" "jina" "$JINA_API_KEY" "Jina AI API Key"
        ((items_created++)) || true
    fi
    
    # DashScope API Key
    if [[ -n "${DASHSCOPE_API_KEY:-}" ]]; then
        create_item "dashscope-api-key" "dashscope" "$DASHSCOPE_API_KEY" "Alibaba DashScope API Key"
        ((items_created++)) || true
    fi
    
    # BigModel Token
    if [[ -n "${BIGMODEL_TOKEN:-}" ]]; then
        create_item "zhipu-bigmodel-token" "zhipu" "$BIGMODEL_TOKEN" "Zhipu AI / BigModel Token"
        ((items_created++)) || true
    fi
    
    # Rube Token
    if [[ -n "${RUBE_TOKEN:-}" ]]; then
        create_item "rube-token" "rube" "$RUBE_TOKEN" "Rube Platform Token"
        ((items_created++)) || true
    fi
    
    # Kaggle API Token
    if [[ -n "${KAGGLE_API_TOKEN:-}" ]]; then
        create_item "kaggle-api-token" "kaggle" "$KAGGLE_API_TOKEN" "Kaggle API Token"
        ((items_created++)) || true
    fi
    
    # Brave API Key
    if [[ -n "${BRAVE_API_KEY:-}" ]]; then
        create_item "brave-api-key" "brave" "$BRAVE_API_KEY" "Brave Search API Key"
        ((items_created++)) || true
    fi
    
    # SerpAPI Key
    if [[ -n "${SERPAPI_KEY:-}" ]]; then
        create_item "serpapi-key" "serpapi" "$SERPAPI_KEY" "SerpAPI Key"
        ((items_created++)) || true
    fi
    
    # Exa API Key
    if [[ -n "${EXA_API_KEY:-}" ]]; then
        create_item "exa-api-key" "exa" "$EXA_API_KEY" "Exa Search API Key"
        ((items_created++)) || true
    fi
    
    # Tavily API Key
    if [[ -n "${TAVILY_API_KEY:-}" ]]; then
        create_item "tavily-api-key" "tavily" "$TAVILY_API_KEY" "Tavily Search API Key"
        ((items_created++)) || true
    fi
    
    # ZAI API Key
    if [[ -n "${ZAI_API_KEY:-}" ]]; then
        create_item "zai-api-key" "zai" "$ZAI_API_KEY" "Z AI API Key"
        ((items_created++)) || true
    fi
    
    echo ""
    log_info "Auto-detected and created $items_created items"
}

# Manual entry mode
manual_entry() {
    echo ""
    echo "=== Manual API Key Entry ==="
    echo ""
    read -rp "Item name (e.g., aliyun-access-key): " name
    read -rp "Access Key ID / Username: " key_id
    read -rsp "Access Key Secret / Password: " key_secret
    echo ""
    read -rp "Notes (optional): " notes
    
    create_item "$name" "$key_id" "$key_secret" "$notes"
}

# Main
echo "=== Bitwarden API Key Import ==="
echo ""
echo "Options:"
echo "  1) Auto-detect from ~/.bashrc.local"
echo "  2) Manual entry"
echo "  3) Exit"
echo ""
read -rp "Choice [1]: " choice
choice=${choice:-1}

case "$choice" in
    1)
        check_bw
        detect_keys
        ;;
    2)
        check_bw
        while true; do
            manual_entry
            echo ""
            read -rp "Add another? [y/N]: " another
            [[ "$another" != "y" && "$another" != "Y" ]] && break
        done
        ;;
    3)
        exit 0
        ;;
    *)
        log_error "Invalid choice"
        exit 1
        ;;
esac

echo ""
log_info "Import complete!"
echo ""
echo "Verify items with: bw list items"
echo "Sync to other devices with: bw sync"
