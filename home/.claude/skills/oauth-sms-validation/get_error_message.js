const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newContext().then(ctx => ctx.newPage());
  
  const resp = await page.goto('http://localhost:5601/kibana/api/security/aliyun/oauth/authorize?redirect_to=/');
  const data = await resp.json();
  
  await page.goto(data.authorizationUrl);
  await page.waitForLoadState('domcontentloaded');
  await page.waitForTimeout(3000);
  
  const emailInput = page.locator('input[name="username"]').first();
  await emailInput.fill('dongdongplanet@1437310945246567.onaliyun.com');
  await emailInput.press('Enter');
  await page.waitForTimeout(3000);
  
  const passwordInput = page.locator('input[type="password"]').first();
  await passwordInput.fill('Summer11');
  
  const submitBtn = page.locator('button[type="submit"]').first();
  await submitBtn.click();
  await page.waitForTimeout(5000);
  
  // Get error messages
  const errorSelectors = ['.error', '.alert', '.message-error', '[class*="error"]', '[class*="Error"]', '.login-error'];
  
  console.log('=== Checking for error messages ===\n');
  for (const selector of errorSelectors) {
    const elements = page.locator(selector);
    const count = await elements.count();
    if (count > 0) {
      for (let i = 0; i < count; i++) {
        const text = await elements.nth(i).textContent();
        if (text && text.trim()) {
          console.log(`${selector}: "${text.trim()}"`);
        }
      }
    }
  }
  
  // Also get all visible text from elements that might contain errors
  const allText = await page.locator('body').evaluate(body => {
    const walker = document.createTreeWalker(body, NodeFilter.SHOW_TEXT);
    const texts = [];
    let node;
    while (node = walker.nextNode()) {
      const text = node.textContent.trim();
      if (text && (text.includes('错误') || text.includes('error') || text.includes('失败') || text.includes('Error'))) {
        texts.push(text);
      }
    }
    return texts;
  });
  
  if (allText.length > 0) {
    console.log('\n=== Text containing "error" or "错误" ===');
    allText.forEach(t => console.log(`  ${t}`));
  }
  
  await browser.close();
})();
