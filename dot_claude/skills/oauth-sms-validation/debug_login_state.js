const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newContext().then(ctx => ctx.newPage());
  
  console.log('Step 1: Get OAuth URL');
  const resp = await page.goto('http://localhost:5601/kibana/api/security/aliyun/oauth/authorize?redirect_to=/');
  const data = await resp.json();
  
  console.log('Step 2: Navigate to Aliyun');
  await page.goto(data.authorizationUrl);
  await page.waitForLoadState('domcontentloaded');
  await page.waitForTimeout(3000);
  
  console.log('Step 3: Enter username');
  const emailInput = page.locator('input[name="username"]').first();
  await emailInput.fill('dongdongplanet@1437310945246567.onaliyun.com');
  await emailInput.press('Enter');
  await page.waitForTimeout(3000);
  
  console.log('Step 4: Enter password');
  const passwordInput = page.locator('input[type="password"]').first();
  if (await passwordInput.count() > 0) {
    await passwordInput.fill('Summer11');
    await page.waitForTimeout(500);
    
    // Take screenshot before submitting
    await page.screenshot({ path: '/tmp/before-submit.png' });
    
    // Try to find and click submit button
    const submitSelectors = [
      'button[type="submit"]',
      'button:has-text("登录")',
      'button:has-text("Login")',
      'button:has-text("Sign in")',
      'button.login-button'
    ];
    
    let submitted = false;
    for (const selector of submitSelectors) {
      const btn = page.locator(selector).first();
      if (await btn.count() > 0 && await btn.isVisible().catch(() => false)) {
        console.log(`Found submit button: ${selector}`);
        await btn.click();
        submitted = true;
        break;
      }
    }
    
    if (!submitted) {
      console.log('No submit button found, pressing Enter on password field');
      await passwordInput.press('Enter');
    }
    
    // Wait and capture state
    await page.waitForTimeout(5000);
    await page.screenshot({ path: '/tmp/after-submit.png' });
    
    console.log('Current URL:', page.url());
    console.log('\n=== Page Text ===');
    const bodyText = await page.locator('body').textContent();
    console.log(bodyText.substring(0, 500));
    
    // Check for specific elements
    console.log('\n=== Checking for elements ===');
    console.log('Has verification code input:', await page.locator('input[placeholder*="验证码"], input[name="code"]').count());
    console.log('Has slider:', await page.locator('.nc-container, .nc_wrapper').count());
    console.log('Has error message:', await page.locator('.error, .alert, [class*="error"]').count());
  }
  
  await browser.close();
})();
