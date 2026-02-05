const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newContext().then(ctx => ctx.newPage());
  
  // Get OAuth URL first
  const kibanaResponse = await page.goto('http://localhost:5601/api/security/aliyun/oauth/authorize?redirect_to=/');
  const data = await kibanaResponse.json();
  
  console.log('Authorization URL:', data.authorizationUrl);
  
  // Navigate to Aliyun login
  await page.goto(data.authorizationUrl);
  await page.waitForLoadState('domcontentloaded');
  await page.waitForTimeout(3000);
  
  // Get page HTML
  const html = await page.content();
  console.log('\n=== PAGE HTML ===\n');
  console.log(html);
  
  //screenshot
  await page.screenshot({ path: '/tmp/aliyun-login-debug.png', fullPage: true });
  console.log('\nScreenshot saved to: /tmp/aliyun-login-debug.png');
  
  await browser.close();
})();
