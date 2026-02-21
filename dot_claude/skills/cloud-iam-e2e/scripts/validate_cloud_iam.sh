#!/usr/bin/env bash
# Cloud IAM E2E Validation Script
# 
# Validates Cloud IAM authentication for Elasticsearch and Kibana
# Outputs JSON report with test results

set -euo pipefail

# Default parameters
ES_URL="${ES_URL:-http://47.236.247.55:9201}"
KB_URL="${KB_URL:-http://47.236.247.55:5602}"
RAM_AK="${RAM_AK:-}"
RAM_SK="${RAM_SK:-}"
CHECK_TYPE="${CHECK_TYPE:-both}"
WORK_DIR="$(mktemp -d)"
REPORT_FILE="${REPORT_FILE:-$WORK_DIR/validation_report.json}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Cleanup on exit
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# Initialize JSON report
init_report() {
  cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "es_url": "$ES_URL",
  "kb_url": "$KB_URL",
  "check_type": "$CHECK_TYPE",
  "tests": []
}
EOF
}

# Add test result to report
add_test_result() {
  local name="$1"
  local status="$2"
  local message="$3"
  local details="${4:-{}}"
  
  tmp_file="$WORK_DIR/report.tmp"
  jq --arg name "$name" --arg status "$status" --arg message "$message" --argjson details "$details" \
    '.tests += [{"name": $name, "status": $status, "message": $message, "details": $details}]' \
    "$REPORT_FILE" > "$tmp_file"
  mv "$tmp_file" "$REPORT_FILE"
}

# Test 1: Check if Elasticsearch is running
test_es_running() {
  log_info "Testing Elasticsearch connectivity..."
  if curl -s -f "$ES_URL/" >/dev/null 2>&1; then
    add_test_result "es_running" "pass" "Elasticsearch is accessible" "{}"
    return 0
  else
    add_test_result "es_running" "fail" "Elasticsearch is not accessible" "{\"url\": \"$ES_URL\"}"
    return 1
  fi
}

# Test 2: Check if Kibana is running
test_kb_running() {
  log_info "Testing Kibana connectivity..."
  if curl -s -f "$KB_URL/" >/dev/null 2>&1; then
    add_test_result "kb_running" "pass" "Kibana is accessible" "{}"
    return 0
  else
    add_test_result "kb_running" "fail" "Kibana is not accessible" "{\"url\": \"$KB_URL\"}"
    return 1
  fi
}

# Test 3: Generate signed header
generate_signed_header() {
  log_info "Generating signed header..."
  
  local sign_script="/home/denny/projects/elasticsearch/plugins/security-realm-cloud-iam/tools/aliyun_sts_sign.py"
  
  if [ ! -f "$sign_script" ]; then
    add_test_result "generate_signed_header" "fail" "Signature script not found" "{\"script\": \"$sign_script\"}"
    return 1
  fi
  
  if [ -z "$RAM_AK" ] || [ -z "$RAM_SK" ]; then
    add_test_result "generate_signed_header" "fail" "RAM credentials not provided" "{}"
    return 1
  fi
  
  local signed_header
  signed_header=$(python3 "$sign_script" --access-key-id "$RAM_AK" --access-key-secret "$RAM_SK" 2>&1)
  
  if [ $? -eq 0 ] && [ -n "$signed_header" ]; then
    echo "$signed_header" > "$WORK_DIR/signed_header.txt"
    add_test_result "generate_signed_header" "pass" "Signed header generated successfully" "{\"length\": ${#signed_header}}"
    return 0
  else
    add_test_result "generate_signed_header" "fail" "Failed to generate signed header" "{\"error\": \"$signed_header\"}"
    return 1
  fi
}

# Test 4: Test Elasticsearch Cloud IAM authentication
test_es_cloud_iam_auth() {
  log_info "Testing Elasticsearch Cloud IAM authentication..."
  
  if [ ! -f "$WORK_DIR/signed_header.txt" ]; then
    add_test_result "es_cloud_iam_auth" "skip" "Signed header not available" "{}"
    return 1
  fi
  
  local signed_header
  signed_header=$(cat "$WORK_DIR/signed_header.txt")
  
  local response
  response=$(curl -s -w "\n%{http_code}" -H "X-ES-IAM-Signed: $signed_header" \
    "$ES_URL/_security/_authenticate" 2>&1)
  
  local status_code
  status_code=$(echo "$response" | tail -n1)
  local body
  body=$(echo "$response" | head -n -1)
  
  if [ "$status_code" = "200" ]; then
    local username
    username=$(echo "$body" | jq -r '.username // empty')
    local realm
    realm=$(echo "$body" | jq -r '.authentication_realm[0] // empty')
    
    add_test_result "es_cloud_iam_auth" "pass" "Cloud IAM authentication successful" \
      "{\"username\": \"$username\", \"realm\": \"$realm\", \"status_code\": $status_code}"
    return 0
  else
    add_test_result "es_cloud_iam_auth" "fail" "Cloud IAM authentication failed" \
      "{\"status_code\": $status_code, \"response\": \"$body\"}"
    return 1
  fi
}

# Test 5: Test Kibana Cloud IAM login
test_kb_cloud_iam_login() {
  log_info "Testing Kibana Cloud IAM login..."
  
  if [ ! -f "$WORK_DIR/signed_header.txt" ]; then
    add_test_result "kb_cloud_iam_login" "skip" "Signed header not available" "{}"
    return 1
  fi
  
  local signed_header
  signed_header=$(cat "$WORK_DIR/signed_header.txt")
  
  # Get login state
  local login_state
  login_state=$(curl -s "$KB_URL/internal/security/login_state")
  
  if echo "$login_state" | jq -e '.selector.providers[] | select(.type == "cloud_iam")' >/dev/null; then
    add_test_result "kb_cloud_iam_login" "pass" "Cloud IAM provider available in Kibana" "{}"
    
    # Try to login
    local login_response
    login_response=$(curl -s -w "\n%{http_code}" -X POST "$KB_URL/internal/security/login" \
      -H "Content-Type: application/json" \
      -H "X-ES-IAM-Signed: $signed_header" \
      -d "{
        \"providerType\": \"cloud_iam\",
        \"providerName\": \"iam1\",
        \"currentURL\": \"$KB_URL/\",
        \"params\": {\"signedRequest\": \"$signed_header\"}
      }" 2>&1)
    
    local status_code
    status_code=$(echo "$login_response" | tail -n1)
    
    if [ "$status_code" = "200" ]; then
      add_test_result "kb_cloud_iam_login_success" "pass" "Kibana login successful" "{}"
      return 0
    else
      add_test_result "kb_cloud_iam_login_success" "fail" "Kibana login failed" \
        "{\"status_code\": $status_code}"
      return 1
    fi
  else
    add_test_result "kb_cloud_iam_login" "fail" "Cloud IAM provider not found in Kibana" \
      "{\"login_state\": \"$login_state\"}"
    return 1
  fi
}

# Test 6: Verify role mappings
test_role_mappings() {
  log_info "Verifying role mappings..."
  
  if [ ! -f "$WORK_DIR/signed_header.txt" ]; then
    add_test_result "role_mappings" "skip" "Cannot verify without authentication" "{}"
    return 1
  fi
  
  local signed_header
  signed_header=$(cat "$WORK_DIR/signed_header.txt")
  
  # Get user info with roles
  local auth_response
  auth_response=$(curl -s -H "X-ES-IAM-Signed: $signed_header" \
    "$ES_URL/_security/_authenticate")
  
  local roles
  roles=$(echo "$auth_response" | jq -r '.roles[]? // empty' | tr '\n' ',' | sed 's/,$//')
  
  if [ -n "$roles" ]; then
    add_test_result "role_mappings" "pass" "User has roles assigned" \
      "{\"roles\": [$roles]}"
    return 0
  else
    add_test_result "role_mappings" "fail" "No roles assigned to user" "{}"
    return 1
  fi
}

# Main validation flow
main() {
  log_info "Starting Cloud IAM E2E Validation..."
  log_info "ES_URL: $ES_URL"
  log_info "KB_URL: $KB_URL"
  log_info "CHECK_TYPE: $CHECK_TYPE"
  
  init_report
  
  local failed=0
  
  # Check ES if needed
  if [[ "$CHECK_TYPE" == "es" ]] || [[ "$CHECK_TYPE" == "both" ]]; then
    test_es_running || failed=1
    generate_signed_header || failed=1
    test_es_cloud_iam_auth || failed=1
    test_role_mappings || failed=1
  fi
  
  # Check Kibana if needed
  if [[ "$CHECK_TYPE" == "kibana" ]] || [[ "$CHECK_TYPE" == "both" ]]; then
    test_kb_running || failed=1
    if [[ "$CHECK_TYPE" == "both" ]]; then
      test_kb_cloud_iam_login || failed=1
    else
      # Need to generate signed header for Kibana-only check
      generate_signed_header || failed=1
      test_kb_cloud_iam_login || failed=1
    fi
  fi
  
  # Generate summary
  local total
  total=$(jq '.tests | length' "$REPORT_FILE")
  local passed
  passed=$(jq '[.tests[] | select(.status == "pass")] | length' "$REPORT_FILE")
  local failed_count
  failed_count=$(jq '[.tests[] | select(.status == "fail")] | length' "$REPORT_FILE")
  local skipped
  skipped=$(jq '[.tests[] | select(.status == "skip")] | length' "$REPORT_FILE")
  
  jq --arg total "$total" --arg passed "$passed" --arg failed "$failed_count" --arg skipped "$skipped" \
    '. + {summary: {total: ($total|tonumber), passed: ($passed|tonumber), failed: ($failed|tonumber), skipped: ($skipped|tonumber)}}' \
    "$REPORT_FILE" > "$WORK_DIR/report_final.json"
  
  mv "$WORK_DIR/report_final.json" "$REPORT_FILE"
  
  # Output results
  log_info "=== Validation Complete ==="
  jq '.summary' "$REPORT_FILE"
  
  # Show failures if any
  if [ "$failed_count" -gt 0 ]; then
    log_error "Failed tests:"
    jq -r '.tests[] | select(.status == "fail") | "  - \(.name): \(.message)"' "$REPORT_FILE"
    return 1
  fi
  
  # Save report to current directory if requested
  if [ "${SAVE_REPORT:-}" = "1" ]; then
    cp "$REPORT_FILE" "./cloud_iam_validation_report_$(date +%s).json"
    log_info "Report saved to: ./cloud_iam_validation_report_$(date +%s).json"
  fi
  
  return 0
}

# Run main
main "$@"
