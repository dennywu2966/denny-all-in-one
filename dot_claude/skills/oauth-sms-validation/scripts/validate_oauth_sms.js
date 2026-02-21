#!/usr/bin/env node

/**
 * OAuth SMS Validation Script
 *
 * Validates OAuth login flow with SMS verification code.
 * Usage: node validate_oauth_sms.js [--mobile PHONE] [--url KIBANA_URL]
 */

const { chromium } = require('playwright');
const readline = require('readline');

// Configuration
const CONFIG = {
  KIBANA_URL: process.env.KIBANA_URL || 'http://localhost:5601',
  USERNAME: process.env.USERNAME || 'dongdongplanet@1437310945246567.onaliyun.com',
  PASSWORD: process.env.PASSWORD || 'Summer11',
  MOBILE: process.env.MOBILE || '18972952966',
  HEADLESS: process.env.HEADLESS !== 'false',
};

// Colors for terminal output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  bold: '\x1b[1m',
};

function log(message, color = colors.reset) {
  console.log(`${color}${message}${colors.reset}`);
}

function askQuestion(query) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  return new Promise(resolve => {
    rl.question(query, (answer) => {
      rl.close();
      resolve(answer);
    });
  });
}

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function validateOAuthLogin() {
  log('=== OAuth SMS Validation ===', colors.bold);
  log(`Target: ${CONFIG.KIBANA_URL}`, colors.cyan);
  log(`Username: ${CONFIG.USERNAME}`, colors.cyan);
  log('');

  const browser = await chromium.launch({
    headless: CONFIG.HEADLESS,
  });

  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
  });

  const page = await context.newPage();

  try {
    // Step 1: Get OAuth authorization URL
    log('[Step 1] Getting OAuth authorization URL...', colors.blue);

    const response = await page.goto(`${CONFIG.KIBANA_URL}/kibana/api/security/aliyun/oauth/authorize?redirect_to=/`);

    if (!response.ok()) {
      throw new Error(`Failed to get OAuth URL: ${response.status()}`);
    }

    const body = await response.text();
    const data = JSON.parse(body);

    if (!data.authorizationUrl) {
      throw new Error('No authorizationUrl in response');
    }

    log('✓ Got authorization URL', colors.green);
    log(`  URL: ${data.authorizationUrl.substring(0, 80)}...`, colors.dim);

    // Step 2: Navigate to Aliyun login page
    log('[Step 2] Navigating to Aliyun login page...', colors.blue);

    await page.goto(data.authorizationUrl);
    await page.waitForLoadState('domcontentloaded');
    await sleep(2000);

    log(`✓ Reached Aliyun login page`, colors.green);
    log(`  Current URL: ${page.url()}`, colors.dim);

    // Step 3: Enter username/email
    log('[Step 3] Entering username...', colors.blue);

    const emailSelectors = [
      'input[name="username" i]',
      'input[type="email" i]',
      'input[id*="email" i]',
      'input[id*="phone" i]',
      'input[id*="user" i]',
      'input[placeholder*="账号" i]',
      'input[placeholder*="邮箱" i]',
      'input[placeholder*="手机" i]',
    ];

    let emailInput = null;
    for (const selector of emailSelectors) {
      try {
        const element = page.locator(selector).first();
        if (await element.count() > 0) {
          emailInput = element;
          break;
        }
      } catch {}
    }

    if (!emailInput) {
      throw new Error('Could not find username/email input field');
    }

    // Clear the field first, then type slowly to ensure complete input
    await emailInput.clear();
    await emailInput.type(CONFIG.USERNAME, { delay: 50 });

    // Verify the value was entered correctly
    const enteredValue = await emailInput.inputValue();
    log(`  Entered: ${enteredValue}`, colors.dim);

    if (enteredValue !== CONFIG.USERNAME) {
      log(`  Warning: Expected ${CONFIG.USERNAME}, got ${enteredValue}`, colors.yellow);
      // Retry with click and fill
      await emailInput.click();
      await emailInput.fill(CONFIG.USERNAME);
    }

    await emailInput.press('Enter');

    log('✓ Entered username', colors.green);
    await sleep(3000);

    // Step 4: Handle authentication - password then possibly SMS
    log('[Step 4] Checking authentication requirements...', colors.blue);

    // Wait a bit for form to transition
    await sleep(2000);

    // Take screenshot to see current state
    await page.screenshot({ path: '/tmp/oauth-after-username.png' });

    // Helper function to find visible input
    const findVisibleInput = async (selectors) => {
      for (const selector of selectors) {
        try {
          const element = page.locator(selector).first();
          if (await element.count() > 0) {
            const isVisible = await element.isVisible().catch(() => false);
            if (isVisible) {
              return element;
            }
          }
        } catch {}
      }
      return null;
    };

    // First, check for password field
    const passwordSelectors = [
      'input[type="password"]',
      'input[name="password" i]',
      'input[id="loginPassword" i]',
    ];

    let passwordInput = await findVisibleInput(passwordSelectors);

    if (passwordInput) {
      log('Found password field - entering password...', colors.yellow);
      await passwordInput.fill(CONFIG.PASSWORD);
      await sleep(500);
      await passwordInput.press('Enter');
      log('✓ Entered password', colors.green);

      // Wait for next step
      await sleep(4000);
      await page.screenshot({ path: '/tmp/oauth-after-password.png' });
    }

    // Now check for SMS verification (after password or directly)
    const smsSelectors = [
      'input[name="code" i]',
      'input[name="sms" i]',
      'input[placeholder*="验证码" i]',
      'input[placeholder*="verification" i]',
      'input[placeholder*="code" i]',
    ];

    let smsInput = await findVisibleInput(smsSelectors);

    // Check if page is asking for SMS verification
    const pageText = await page.locator('body').textContent();
    const needsSMS = pageText?.includes('Verify Phone Number') ||
                     pageText?.includes('verification code') ||
                     pageText?.includes('验证码') ||
                     smsInput !== null;

    if (needsSMS && smsInput) {
      log('SMS verification required - waiting for SMS code...', colors.yellow);

      // Check if we need to click "Obtain Verification Code" button
      const obtainButton = page.locator('button:has-text("Obtain"), button:has-text("Get"), button:has-text("获取"), button:has-text("Send")').first();
      if (await obtainButton.count() > 0) {
        log('Clicking "Obtain Verification Code" button...', colors.dim);
        await obtainButton.click();
        await sleep(2000);
      }

      // Prompt user for SMS code
      log('', colors.reset);
      log('========================================', colors.cyan);
      log('  SMS VERIFICATION CODE REQUIRED', colors.bold);
      log('========================================', colors.cyan);
      log('', colors.reset);
      log(`An SMS verification code should be sent to: ${colors.bold}${CONFIG.MOBILE}${colors.reset}`);
      log('', colors.reset);

      const smsCode = await askQuestion(colors.yellow + 'Please enter the 6-digit SMS verification code: ' + colors.reset);
      log('', colors.reset);

      if (!smsCode || smsCode.trim().length === 0) {
        throw new Error('No SMS code provided');
      }

      await smsInput.fill(smsCode.trim());

      // Find and click submit button
      const submitButton = page.locator('button:has-text("Submit"), button:has-text("Confirm"), button:has-text("提交"), button:has-text("确定")').first();
      if (await submitButton.count() > 0) {
        await submitButton.click();
      } else {
        await smsInput.press('Enter');
      }

      log('✓ Entered SMS verification code', colors.green);
    } else if (!passwordInput && !smsInput) {
      // Take screenshot for debugging
      await page.screenshot({ path: '/tmp/oauth-no-input.png', fullPage: true });
      const bodyText = await page.locator('body').textContent();
      log('Page text preview:', colors.dim);
      log(bodyText?.substring(0, 200) + '...', colors.dim);
      throw new Error('Could not find password or SMS input field. Screenshot saved to /tmp/oauth-no-input.png');
    }

    // Step 5: Wait for redirect back to Kibana
    log('[Step 5] Waiting for redirect back to Kibana...', colors.blue);

    try {
      await page.waitForURL(/(localhost:5601|47\.236\.247\.55:5601)/, { timeout: 30000 });
      log('✓ Redirected back to Kibana', colors.green);

      const url = page.url();
      log(`  Current URL: ${url}`, colors.dim);

      // Wait for page to fully load
      await page.waitForLoadState('domcontentloaded');
      await sleep(3000);

      // Step 6: Verify successful login
      log('[Step 6] Verifying successful login...', colors.blue);

      const bodyText = await page.locator('body').textContent();

      const hasKibanaUI = await page.locator('.kbnChrome, [class*="kbn"], [data-test-subj]').count() > 0;
      const hasDiscover = bodyText?.includes('Discover');
      const hasDashboards = bodyText?.includes('Dashboards');
      const hasDevTools = bodyText?.includes('Dev Tools');

      const isLoggedIn = hasKibanaUI || hasDiscover || hasDashboards || hasDevTools;

      if (isLoggedIn) {
        log('✓ Successfully logged in to Kibana!', colors.green);
        log('  - Kibana UI elements found', colors.dim);
        log('  - Can access Discover/Dashboards', colors.dim);

        // Get final screenshot
        await page.screenshot({ path: '/tmp/oauth-success.png', fullPage: true });
        log('  Screenshot saved: /tmp/oauth-success.png', colors.dim);

        log('', colors.reset);
        log('========================================', colors.green);
        log('  ✓ VALIDATION SUCCESSFUL', colors.bold);
        log('========================================', colors.green);
        log('', colors.reset);

        return true;
      } else {
        log('✗ Login verification failed - UI not fully loaded', colors.red);
        log('  Page title:', await page.title(), colors.dim);

        await page.screenshot({ path: '/tmp/oauth-failure.png', fullPage: true });
        log('  Screenshot saved: /tmp/oauth-failure.png', colors.dim);

        return false;
      }

    } catch (error) {
      log(`✗ Failed to redirect: ${error.message}`, colors.red);

      await page.screenshot({ path: '/tmp/oauth-error.png', fullPage: true });
      log(`  Current URL: ${page.url()}`, colors.dim);
      log('  Screenshot saved: /tmp/oauth-error.png', colors.dim);

      return false;
    }

  } catch (error) {
    log(`✗ Validation failed: ${error.message}`, colors.red);
    return false;

  } finally {
    await context.close();
    await browser.close();
  }
}

// Run the validation
validateOAuthLogin()
  .then(success => {
    process.exit(success ? 0 : 1);
  })
  .catch(error => {
    log(`✗ Fatal error: ${error.message}`, colors.red);
    console.error(error);
    process.exit(1);
  });
