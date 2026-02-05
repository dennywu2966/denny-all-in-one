/**
 * WeChat (微信) OAuth Provider
 *
 * Handles authentication for:
 * - WeChat OAuth Login (open.weixin.qq.com)
 * - WeChat QR Code login
 * - WeChat SMS verification
 */

export default class WeChatProvider {
  constructor(config) {
    this.config = config;
    this.name = 'wechat';
  }

  async detect(page, url, content) {
    return url.includes('weixin.qq.com') ||
           url.includes('open.weixin.qq.com') ||
           url.includes('wx.qq.com') ||
           content.includes('微信') ||
           content.includes('WeChat');
  }

  async enterPhone(page, phone) {
    const selectors = [
      'input[type="tel"]',
      'input[placeholder*="手机号"]',
      'input[name*="phone"]',
      'input[name*="mobile"]',
      '#mobile',
      '#phone'
    ];

    for (const selector of selectors) {
      try {
        await page.waitForSelector(selector, { timeout: 5000 });
        await page.fill(selector, phone);
        console.log(`✓ Entered phone using: ${selector}`);
        return;
      } catch (e) {
        // Try next
      }
    }

    throw new Error('Could not find phone input for WeChat');
  }

  async requestSmsCode(page) {
    const buttonSelectors = [
      'button:has-text("获取验证码")',
      'button:has-text("发送验证码")',
      'a:has-text("获取验证码")'
    ];

    for (const selector of buttonSelectors) {
      try {
        const button = await page.$(selector);
        if (button) {
          await button.click();
          await page.waitForTimeout(2000);
          console.log(`✓ Clicked WeChat SMS button: ${selector}`);
          return;
        }
      } catch (e) {
        // Try next
      }
    }

    throw new Error('Could not click SMS button for WeChat');
  }

  async enterSmsCode(page, code) {
    const selectors = [
      'input[type="text"]',
      'input[name*="code"]',
      'input[placeholder*="验证码"]'
    ];

    for (const selector of selectors) {
      try {
        await page.waitForSelector(selector, { timeout: 5000 });
        await page.fill(selector, code);
        console.log(`✓ Entered SMS code using: ${selector}`);
        return;
      } catch (e) {
        // Try next
      }
    }

    throw new Error('Could not find SMS code input for WeChat');
  }

  async submit(page) {
    const submitSelectors = [
      'button:has-text("登录")',
      'button:has-text("确认")',
      'button[type="submit"]'
    ];

    for (const selector of submitSelectors) {
      try {
        const button = await page.$(selector);
        if (button) {
          await button.click();
          console.log(`✓ Clicked WeChat submit button`);
          return;
        }
      } catch (e) {
        // Try next
      }
    }
  }

  async isSuccessful(page) {
    const url = page.url();
    return !url.includes('login') && !url.includes('auth');
  }

  async getArn(page) {
    return null;
  }
}
