/**
 * Aliyun (阿里云) OAuth Provider
 *
 * Handles authentication for:
 * - Aliyun Console (console.aliyun.com)
 * - Aliyun OAuth (oauth.aliyun.com)
 * - Aliyun SSO (signin.aliyun.com)
 */

export default class AliyunProvider {
  constructor(config) {
    this.config = config;
    this.name = 'aliyun';
  }

  /**
   * Detect if current page is Aliyun OAuth
   */
  async detect(page, url, content) {
    return url.includes('oauth.aliyun.com') ||
           url.includes('signin.aliyun.com') ||
           url.includes('account.aliyun.com') ||
           content.includes('aliyun') ||
           content.includes('阿里云');
  }

  /**
   * Enter phone number
   * Aliyun uses various input selectors for phone
   */
  async enterPhone(page, phone) {
    const selectors = [
      'input[type="tel"]',
      'input[placeholder*="手机"]',
      'input[placeholder*="号码"]',
      'input[name*="phone"]',
      'input[name*="mobile"]',
      'input[id*="phone"]',
      'input[id*="mobile"]',
      '#mobile',
      '#phone',
      'input[placeholder*="请输入手机号"]'
    ];

    for (const selector of selectors) {
      try {
        await page.waitForSelector(selector, { timeout: 5000, state: 'visible' });
        await page.fill(selector, phone);
        console.log(`✓ Entered phone using selector: ${selector}`);
        return;
      } catch (e) {
        // Try next selector
      }
    }

    throw new Error('Could not find phone input field');
  }

  /**
   * Request SMS code
   * Click "Get Verification Code" button
   */
  async requestSmsCode(page) {
    const buttonSelectors = [
      'button:has-text("获取验证码")',
      'button:has-text("发送验证码")',
      'button:has-text("获取")',
      'a:has-text("获取验证码")',
      'button:has-text("发送验证码")',
      'button[type="submit"]',
      'button:has-text("同意并登录")',
      'button:has-text("登录")'
    ];

    for (const selector of buttonSelectors) {
      try {
        const button = await page.$(selector);
        if (button) {
          await button.click();
          await page.waitForTimeout(2000);
          console.log(`✓ Clicked SMS request button: ${selector}`);
          return;
        }
      } catch (e) {
        // Try next selector
      }
    }

    throw new Error('Could not find or click SMS request button');
  }

  /**
   * Enter SMS verification code
   */
  async enterSmsCode(page, code) {
    const selectors = [
      'input[type="text"]',
      'input[name*="code"]',
      'input[id*="code"]',
      'input[placeholder*="验证码"]',
      'input[placeholder*="请输入验证码"]',
      '#code',
      '#verifyCode',
      '#smsCode'
    ];

    for (const selector of selectors) {
      try {
        await page.waitForSelector(selector, { timeout: 5000, state: 'visible' });
        await page.fill(selector, code);
        console.log(`✓ Entered SMS code using selector: ${selector}`);
        return;
      } catch (e) {
        // Try next selector
      }
    }

    throw new Error('Could not find SMS code input field');
  }

  /**
   * Submit the form
   */
  async submit(page) {
    // Look for submit/login button
    const submitSelectors = [
      'button:has-text("登录")',
      'button:has-text("提交")',
      'button:has-text("确认")',
      'button:has-text("同意并登录")',
      'button[type="submit"]',
      'button:has-text("下一步")'
    ];

    for (const selector of submitSelectors) {
      try {
        const button = await page.$(selector);
        if (button) {
          await button.click();
          console.log(`✓ Clicked submit button: ${selector}`);
          return;
        }
      } catch (e) {
        // Try next selector
      }
    }

    // Sometimes submitting is automatic after entering code
    console.log('Note: No submit button found, may auto-submit');
  }

  /**
   * Check if login was successful
   */
  async isSuccessful(page) {
    const url = page.url();

    // Check if redirected away from OAuth pages
    if (!url.includes('oauth') && !url.includes('signin') && !url.includes('login')) {
      return true;
    }

    // Check for success indicators on page
    try {
      const content = await page.content();
      return content.includes('控制台') ||
             content.includes('Console') ||
             content.includes('用户中心') ||
             content.includes('Dashboard');
    } catch (e) {
      return false;
    }
  }

  /**
   * Get ARN from authenticated session
   * For Aliyun, this would be: acs:ram::{accountId}:user/{userId}
   */
  async getArn(page) {
    // This would need to extract user info from Aliyun console
    // Implementation depends on specific use case
    return null;
  }
}
