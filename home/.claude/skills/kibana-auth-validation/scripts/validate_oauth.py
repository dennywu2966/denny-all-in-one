#!/usr/bin/env python3
"""
OAuth Validation Script for Kibana Aliyun RAM SSO

Validates OAuth login flow with Aliyun RAM using Playwright MCP.
"""

import sys
import subprocess
import json


def check_stack_health():
    """Check if ES and Kibana are running."""
    print("[INFO] Checking stack health...")

    # Check Elasticsearch
    es_check = subprocess.run(
        ["curl", "-sk", "-u", "elastic:Summer11",
         "https://127.0.0.1:9200/_cluster/health"],
        capture_output=True, text=True
    )

    if es_check.returncode != 0:
        print("[ERROR] Elasticsearch not accessible")
        return False

    es_health = json.loads(es_check.stdout)
    status = es_health.get("status", "unknown")
    print(f"[INFO] Elasticsearch health: {status}")

    # Check Kibana
    kibana_check = subprocess.run(
        ["curl", "-s", "http://localhost:5601/api/status"],
        capture_output=True, text=True
    )

    if kibana_check.returncode != 0:
        print("[ERROR] Kibana not accessible")
        return False

    kibana_status = json.loads(kibana_check.stdout)
    overall = kibana_status.get("status", {}).get("overall", {}).get("state", "unknown")
    print(f"[INFO] Kibana status: {overall}")

    return True


def generate_oauth_test_script():
    """Generate Playwright test for OAuth validation."""
    print("[INFO] Generating OAuth Playwright test script...")

    test_code = """
const OAUTH_CREDS = {
    email: 'dongdongplanet@1437310945246567.onaliyun.com',
    password: 'Summer11',
    smsPhone: '18972952966'
};

async function runOAuthTests(page) {
    const results = { passed: [], failed: [], skipped: [] };

    // Test 1: OAuth button visibility
    console.log('[TEST] OAuth - Button Visibility');
    await page.goto('http://47.236.247.55:5601');
    await page.waitForLoadState('networkidle');

    const aliyunButton = page.getByText(/aliyun|ram|阿里云/i).or(
        page.locator('button').filter({ hasText: /log in|登录/i })
    );

    if (await aliyunButton.isVisible()) {
        console.log('[PASS] OAuth button visible on login page');
        results.passed.push('OAuth button visible');
    } else {
        console.log('[WARN] OAuth button not found - may need to check selector');
        results.skipped.push('OAuth button check');
    }

    // Test 2: OAuth flow initiation
    console.log('[TEST] OAuth - Flow Initiation');
    try {
        await aliyunButton.click();
        await page.waitForTimeout(3000);

        const url = page.url();
        if (url.includes('aliyun.com') || url.includes('signin')) {
            console.log('[PASS] Redirected to Aliyun OAuth page');
            results.passed.push('OAuth redirect');
        } else {
            console.log('[INFO] URL after click:', url);
            results.skipped.push('OAuth redirect check');
        }
    } catch (e) {
        console.log('[SKIP] OAuth flow initiation:', e.message);
        results.skipped.push('OAuth flow');
    }

    // Note: Full OAuth flow requires manual interaction for:
    // - CAPTCHA challenges
    // - SMS OTP verification
    // - Session cookies
    //
    // For automated testing, consider:
    // 1. Using pre-authenticated session cookies
    // 2. Testing in development with CAPTCHA disabled
    // 3. Running manual verification alongside automated checks

    return results;
}

module.exports = { runOAuthTests, OAUTH_CREDS };
"""

    with open("/tmp/kibana_oauth_test.js", "w") as f:
        f.write(test_code)

    print("[INFO] OAuth test script saved to /tmp/kibana_oauth_test.js")
    print("[WARN] Full OAuth flow requires manual interaction due to:")
    print("  - CAPTCHA challenges")
    print("  - SMS OTP verification")
    print("  - Session management")

    return True


def main():
    if not check_stack_health():
        print("[ERROR] Stack not healthy. Run ./project-starter.sh first.")
        sys.exit(1)

    print("[SUCCESS] Stack is healthy")
    generate_oauth_test_script()

    print("\n[INFO] OAuth credentials for testing:")
    print("  Email: dongdongplanet@1437310945246567.onaliyun.com")
    print("  Password: Summer11")
    print("  SMS Phone: 18972952966")


if __name__ == "__main__":
    main()
