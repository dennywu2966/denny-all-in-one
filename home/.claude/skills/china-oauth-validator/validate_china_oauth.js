#!/usr/bin/env node
/**
 * China OAuth Validator
 *
 * General-purpose OAuth validation for Chinese web services
 * with automated SMS handling support.
 *
 * Usage: node validate_china_oauth.js [options]
 */

import { chromium } from 'playwright';
import { Command } from 'commander';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Import providers
import AliyunProvider from './lib/providers/aliyun.js';
import WeChatProvider from './lib/providers/wechat.js';
import QQProvider from './lib/providers/qq.js';
import DingTalkProvider from './lib/providers/dingtalk.js';
import BaiduProvider from './lib/providers/baidu.js';

// Import SMS services
import ManualSmsService from './lib/sms/manual.js';
import SMSPVA from './lib/sms/smspva.js';

const PROTOCOL_VERSION = '1.0.0';

// Provider registry
const PROVIDERS = {
  aliyun: AliyunProvider,
  wechat: WeChatProvider,
  qq: QQProvider,
  dingtalk: DingTalkProvider,
  baidu: BaiduProvider
};

// SMS service registry
const SMS_SERVICES = {
  manual: ManualSmsService,
  smspva: SMSPVA
};

// Configuration
const CONFIG = {
  screenshotDir: path.join(__dirname, 'validation_screenshots'),
  reportFile: path.join(__dirname, 'validation_report.json'),
  defaultTimeout: 30000,
  defaultHeadless: true
};

// Test results
const results = {
  protocol_version: PROTOCOL_VERSION,
  timestamp: new Date().toISOString(),
  provider: null,
  target_url: null,
  tests: [],
  summary: {},
  errors: []
};

// Utility functions
function log(message, emoji = '') {
  console.log(`${emoji} ${message}`);
}

function logSection(title) {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`${title}`);
  console.log('='.repeat(60));
}

async function screenshot(page, name) {
  const filepath = path.join(CONFIG.screenshotDir, `${name}.png`);
  await page.screenshot({ path: filepath, fullPage: true });
  log(`Screenshot: ${filepath}`, '📸');
}

function recordTest(name, status, details = null, error = null) {
  results.tests.push({ name, status, details, error, timestamp: new Date().toISOString() });
}

async function detectProvider(page, targetProviders) {
  const url = page.url();
  const content = await page.content();

  for (const [name, ProviderClass] of Object.entries(targetProviders)) {
    const provider = new ProviderClass({});
    if (await provider.detect(page, url, content)) {
      log(`Detected OAuth provider: ${name}`, '✅');
      return { name, provider };
    }
  }

  return null;
}

async function waitForSmsCode(smsService, phone, timeout = 60000) {
  log('Waiting for SMS code...', '⏳');

  const startTime = Date.now();
  let code = null;

  while (Date.now() - startTime < timeout) {
    code = await smsService.getCode();
    if (code) {
      log(`Received SMS code: ${code}`, '✅');
      return code;
    }
    await new Promise(resolve => setTimeout(resolve, 2000));
  }

  throw new Error('SMS code timeout');
}

async function runValidation(options) {
  logSection('China OAuth Validator');

  // Store configuration
  results.provider = options.provider;
  results.target_url = options.targetUrl;

  log('');
  log('Configuration:');
  log(`  Provider: ${options.provider}`);
  log(`  Target URL: ${options.targetUrl}`);
  log(`  Phone: ${options.phone || 'N/A'}`);
  log(`  SMS Service: ${options.smsService}`);
  log(`  Headless: ${options.headless}`);
  log(`  Timeout: ${options.timeout}s`);
  log('');

  // Create screenshot directory
  if (!fs.existsSync(CONFIG.screenshotDir)) {
    fs.mkdirSync(CONFIG.screenshotDir, { recursive: true });
    log(`Created screenshot directory: ${CONFIG.screenshotDir}`);
  }

  // Initialize provider
  const ProviderClass = PROVIDERS[options.provider];
  if (!ProviderClass) {
    throw new Error(`Unknown provider: ${options.provider}`);
  }
  const provider = new ProviderClass({});

  // Initialize SMS service
  const SmsServiceClass = SMS_SERVICES[options.smsService];
  if (!SmsServiceClass) {
    throw new Error(`Unknown SMS service: ${options.smsService}`);
  }
  const smsService = new SmsServiceClass({
    phone: options.phone,
    apiKey: options.smspvaApiKey,
    country: options.smspvaCountry,
    service: options.smspvaService
  });

  // Initialize SMS service
  try {
    await smsService.initialize();
    recordTest('SMS Service Init', 'PASS', `Service: ${options.smsService}`);
  } catch (error) {
    recordTest('SMS Service Init', 'FAIL', null, error.message);
    throw error;
  }

  // Launch browser
  logSection('Browser Launch');
  const browser = await chromium.launch({
    headless: options.headless,
    slowMo: 500
  });
  log(`Browser launched (${options.headless ? 'headless' : 'headed'})`);

  try {
    const context = await browser.newContext({
      viewport: { width: 1280, height: 720 },
      userAgent: 'ChinaOAuthValidator/1.0'
    });

    const page = await context.newPage();

    // Navigate to target URL
    logSection('Navigation');
    log(`Navigating to: ${options.targetUrl}`);
    try {
      await page.goto(options.targetUrl, {
        waitUntil: 'domcontentloaded',
        timeout: options.timeout * 1000
      });
      await screenshot(page, '01-initial-page');
      recordTest('Page Load', 'PASS', `Loaded ${options.targetUrl}`);
    } catch (error) {
      recordTest('Page Load', 'FAIL', null, error.message);
      throw error;
    }

    // Detect OAuth provider (if not explicitly specified)
    let detectedProvider = null;
    if (!options.provider) {
      logSection('Provider Detection');
      detectedProvider = await detectProvider(page, PROVIDERS);
      if (!detectedProvider) {
        recordTest('Provider Detection', 'FAIL', null, 'Could not detect OAuth provider');
        throw new Error('Could not detect OAuth provider');
      }
    } else {
      detectedProvider = { name: options.provider, provider };
    }

    // Initialize SMS service with provider-specific settings
    await smsService.configureForProvider(detectedProvider.name);

    // Enter phone number
    if (options.phone) {
      logSection('Phone Entry');
      try {
        await detectedProvider.provider.enterPhone(page, options.phone);
        await screenshot(page, '02-phone-entered');
        recordTest('Phone Entry', 'PASS', `Phone: ${options.phone}`);
      } catch (error) {
        recordTest('Phone Entry', 'FAIL', null, error.message);
        throw error;
      }

      // Request SMS code
      logSection('SMS Request');
      try {
        await detectedProvider.provider.requestSmsCode(page);
        await screenshot(page, '03-sms-requested');
        recordTest('SMS Request', 'PASS', 'SMS code requested');
      } catch (error) {
        recordTest('SMS Request', 'FAIL', null, error.message);
        throw error;
      }

      // Wait for and enter SMS code
      logSection('SMS Code Entry');
      let smsCode;
      try {
        smsCode = await waitForSmsCode(smsService, options.phone, options.smsTimeout * 1000);
        await detectedProvider.provider.enterSmsCode(page, smsCode);
        await screenshot(page, '04-sms-entered');
        recordTest('SMS Code Entry', 'PASS', `Code: ${smsCode}`);
      } catch (error) {
        recordTest('SMS Code Entry', 'FAIL', null, error.message);
        throw error;
      }
    }

    // Submit form
    logSection('Form Submission');
    try {
      await detectedProvider.provider.submit(page);
      await page.waitForTimeout(3000);
      await screenshot(page, '05-after-submit');
      recordTest('Form Submission', 'PASS', 'Form submitted');
    } catch (error) {
      recordTest('Form Submission', 'FAIL', null, error.message);
      throw error;
    }

    // Verify successful login
    logSection('Login Verification');
    try {
      const success = await detectedProvider.provider.isSuccessful(page);
      const finalUrl = page.url();
      await screenshot(page, '06-final-state');

      if (success) {
        recordTest('Login Verification', 'PASS', `Final URL: ${finalUrl}`);
        log('✅ Login successful!', '🎉');
      } else {
        recordTest('Login Verification', 'FAIL', `Final URL: ${finalUrl}`, 'Login did not succeed');
        log('❌ Login may have failed', '⚠️');
      }
    } catch (error) {
      recordTest('Login Verification', 'WARN', null, error.message);
      log('Could not verify login status', '⚠️');
    }

  } finally {
    if (!options.keepBrowser) {
      await browser.close();
      log('Browser closed');
    } else {
      log('Browser kept open for manual inspection', '🔍');
    }
  }

  // Cleanup SMS service
  await smsService.cleanup();
}

function generateReport() {
  logSection('Report Generation');

  const passed = results.tests.filter(t => t.status === 'PASS').length;
  const failed = results.tests.filter(t => t.status === 'FAIL').length;
  const warnings = results.tests.filter(t => t.status === 'WARN').length;

  results.summary = {
    total: results.tests.length,
    passed,
    failed,
    warnings,
    status: failed === 0 ? 'PASS' : 'FAIL'
  };

  fs.writeFileSync(CONFIG.reportFile, JSON.stringify(results, null, 2));

  log('Validation Results:');
  log(`  Total: ${results.summary.total}`);
  log(`  Passed: ${passed} ✅`);
  log(`  Failed: ${failed} ❌`);
  log(`  Warnings: ${warnings} ⚠️`);
  log('');

  results.tests.forEach(test => {
    const icon = test.status === 'PASS' ? '✅' : test.status === 'FAIL' ? '❌' : '⚠️';
    log(`  ${icon} ${test.name}: ${test.details || test.error || 'No details'}`);
  });

  log('');
  log(`Report: ${CONFIG.reportFile}`);
  log(`Screenshots: ${CONFIG.screenshotDir}/`);
}

// CLI setup
const program = new Command();

program
  .name('validate_china_oauth')
  .description('Validate OAuth flows for Chinese web services')
  .version(PROTOCOL_VERSION);

program
  .option('--provider <name>', 'OAuth provider (aliyun, wechat, qq, dingtalk, baidu)')
  .option('--target-url <url>', 'Target URL to start OAuth flow')
  .option('--phone <number>', 'Phone number for SMS verification (e.g., 8618972952966)')
  .option('--sms-service <service>', 'SMS service (manual, smspva)', 'manual')
  .option('--smspva-api-key <key>', 'SMSPVA API key')
  .option('--smspva-country <code>', 'SMSPVA country code', 'CN')
  .option('--smspva-service <service>', 'SMSPVA service code', 'ot')
  .option('--sms-timeout <seconds>', 'SMS code wait timeout', '60')
  .option('--timeout <seconds>', 'Page load timeout', '30')
  .option('--headless', 'Run in headless mode', true)
  .option('--keep-browser', 'Keep browser open after validation', false)
  .parse(process.argv);

const options = program.opts();

// Run validation
(async () => {
  try {
    await runValidation(options);
    generateReport();

    if (results.summary.status === 'PASS') {
      log('✅ ALL VALIDATIONS PASSED!', '🎉');
      process.exit(0);
    } else {
      log('⚠️  VALIDATION COMPLETED WITH FAILURES', '⚠️');
      process.exit(1);
    }
  } catch (error) {
    log(`Fatal error: ${error.message}`, '💥');
    console.error(error);
    process.exit(1);
  }
})();
