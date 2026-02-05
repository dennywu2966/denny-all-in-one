#!/usr/bin/env bash
# Playwright Test Runner for Cloud IAM Validation
#
# Runs Playwright tests for Cloud IAM authentication flow
# Requires: Node.js, npm, and Playwright installed

set -euo pipefail

ES_URL="${ES_URL:-http://47.236.247.55:9201}"
KB_URL="${KB_URL:-http://47.236.247.55:5602}"
RAM_AK="${RAM_AK:-}"
RAM_SK="${RAM_SK:-}"
WORK_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

log_info() { echo "[INFO] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

# Check if Playwright is installed
check_playwright() {
  if ! command -v npx >/dev/null 2>&1; then
    log_error "npx not found. Please install Node.js and npm."
    return 1
  fi
  
  if ! npx playwright --version >/dev/null 2>&1; then
    log_info "Installing Playwright..."
    npm install -D @playwright/test || {
      log_error "Failed to install Playwright"
      return 1
    }
  fi
}

# Create Playwright config
create_playwright_config() {
  cat > "$WORK_DIR/playwright.config.ts" << 'EOF'
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1,
  reporter: 'json',
  use: {
    baseURL: process.env.KB_URL || 'http://47.236.247.55:5602',
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
EOF
}

# Create test directory structure
setup_test_environment() {
  mkdir -p "$WORK_DIR/tests"
  
  # Copy the Playwright test file
  local test_file="/home/denny/projects/elasticsearch/.cloud-iam-e2e/playwright-cloud-iam-validation.spec.ts"
  if [ -f "$test_file" ]; then
    cp "$test_file" "$WORK_DIR/tests/"
  else
    log_error "Test file not found: $test_file"
    return 1
  fi
}

# Run tests
run_tests() {
  log_info "Running Playwright tests..."
  log_info "ES_URL: $ES_URL"
  log_info "KB_URL: $KB_URL"
  
  export ES_URL KB_URL RAM_AK RAM_SK
  
  cd "$WORK_DIR"
  
  npx playwright test --reporter=json > "$WORK_DIR/test-results.json" || true
  
  # Parse results
  if [ -f "$WORK_DIR/test-results.json" ]; then
    local passed
    passed=$(jq '[.suites[].specs[].tests[] | select(.status == "passed")] | length' "$WORK_DIR/test-results.json" 2>/dev/null || echo "0")
    local failed
    failed=$(jq '[.suites[].specs[].tests[] | select(.status == "failed")] | length' "$WORK_DIR/test-results.json" 2>/dev/null || echo "0")
    
    log_info "Playwright tests: $passed passed, $failed failed"
    
    # Show failures
    if [ "$failed" -gt 0 ]; then
      jq -r '.suites[].specs[].tests[] | select(.status == "failed") | "  - \(.title): \(.error)"' "$WORK_DIR/test-results.json" 2>/dev/null || true
    fi
    
    # Copy results if requested
    if [ "${SAVE_RESULTS:-}" = "1" ]; then
      cp "$WORK_DIR/test-results.json" "./playwright_results_$(date +%s).json"
      log_info "Results saved to: ./playwright_results_$(date +%s).json"
    fi
    
    [ "$failed" -eq 0 ]
  else
    log_error "No test results found"
    return 1
  fi
}

main() {
  check_playwright || return 1
  create_playwright_config
  setup_test_environment || return 1
  run_tests
}

main "$@"
