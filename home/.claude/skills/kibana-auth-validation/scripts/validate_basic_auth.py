#!/usr/bin/env python3
"""
Basic Auth Validation Script for Kibana

Validates basic authentication (elastic/Summer11) with positive and negative cases.
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


def run_playwright_basic_auth_test():
    """Run Playwright test for basic auth validation."""
    print("[INFO] Running basic auth Playwright tests...")

    test_code = """
async function runBasicAuthTests(page) {
    const results = { passed: [], failed: [] };

    // Test 1: Valid credentials
    console.log('[TEST] Basic Auth - Valid Credentials');
    await page.goto('http://47.236.247.55:5601');
    await page.waitForLoadState('networkidle');

    // Look for basic auth form
    const basicForm = await page.locator('form').filter({ hasText: /username|password/i }).first();
    if (await basicForm.isVisible()) {
        await page.fill('input[name="username"], input[placeholder*="username" i], input[placeholder*="用户" i]', 'elastic');
        await page.fill('input[name="password"], input[placeholder*="password" i], input[placeholder*="密码" i]', 'Summer11');
        await page.click('button[type="submit"], button:has-text("Log in"), button:has-text("登录")');

        // Wait for navigation
        await page.waitForTimeout(3000);
        const url = page.url();
        if (url.includes('/app/') || url.includes('/home')) {
            console.log('[PASS] Valid credentials - login successful');
            results.passed.push('Valid credentials');
        } else {
            console.log('[FAIL] Valid credentials - did not redirect to app');
            results.failed.push('Valid credentials - no redirect');
        }
    } else {
        console.log('[SKIP] Basic auth form not found');
    }

    // Test 2: Invalid password (logout first if logged in)
    console.log('[TEST] Basic Auth - Invalid Password');
    await page.goto('http://47.236.247.55:5601');
    await page.waitForLoadState('networkidle');

    // Try to login with wrong password
    const basicForm2 = await page.locator('form').filter({ hasText: /username|password/i }).first();
    if (await basicForm2.isVisible()) {
        await page.fill('input[name="username"], input[placeholder*="username" i]', 'elastic');
        await page.fill('input[name="password"], input[placeholder*="password" i]', 'WrongPassword123');
        await page.click('button[type="submit"], button:has-text("Log in")');

        await page.waitForTimeout(2000);
        const url2 = page.url();
        if (!url2.includes('/app/')) {
            console.log('[PASS] Invalid password - login blocked');
            results.passed.push('Invalid password blocked');
        } else {
            console.log('[FAIL] Invalid password - login should have failed');
            results.failed.push('Invalid password - login succeeded');
        }
    }

    return results;
}

module.exports = { runBasicAuthTests };
"""

    # Save test to temp file
    with open("/tmp/kibana_basic_auth_test.js", "w") as f:
        f.write(test_code)

    print("[INFO] Test script saved to /tmp/kibana_basic_auth_test.js")
    print("[INFO] Use Playwright MCP to execute the tests")
    return True


def main():
    if not check_stack_health():
        print("[ERROR] Stack not healthy. Run ./project-starter.sh first.")
        sys.exit(1)

    print("[SUCCESS] Stack is healthy")
    run_playwright_basic_auth_test()

    print("\n[INFO] Next steps:")
    print("  1. Use Playwright MCP to run the tests")
    print("  2. Check for console errors")
    print("  3. Verify login page layout")


if __name__ == "__main__":
    main()
