/**
 * QQ OAuth Provider
 */

export default class QQProvider {
  constructor(config) {
    this.config = config;
    this.name = 'qq';
  }

  async detect(page, url, content) {
    return url.includes('qq.com') ||
           url.includes('graph.qq.com') ||
           url.includes('xui.ptlogin2.qq.com') ||
           content.includes('QQ') ||
           content.includes('腾讯') ||
           content.includes('QQ登录');
  }

  async enterPhone(page, phone) {
    const selectors = ['input[type="tel"]', 'input[name*="phone"]', '#phone', '#mobile'];
    for (const selector of selectors) {
      try {
        await page.waitForSelector(selector, { timeout: 5000 });
        await page.fill(selector, phone);
        return;
      } catch (e) {}
    }
    throw new Error('Could not find phone input for QQ');
  }

  async requestSmsCode(page) {
    const buttons = ['button:has-text("获取验证码")', 'button:has-text("发送验证码")'];
    for (const selector of buttons) {
      try {
        const button = await page.$(selector);
        if (button) {
          await button.click();
          return;
        }
      } catch (e) {}
    }
    throw new Error('Could not click SMS button for QQ');
  }

  async enterSmsCode(page, code) {
    const selectors = ['input[name*="code"]', 'input[placeholder*="验证码"]', '#code'];
    for (const selector of selectors) {
      try {
        await page.waitForSelector(selector, { timeout: 5000 });
        await page.fill(selector, code);
        return;
      } catch (e) {}
    }
    throw new Error('Could not find SMS code input for QQ');
  }

  async submit(page) {
    const buttons = ['button:has-text("登录")', 'button[type="submit"]'];
    for (const selector of buttons) {
      try {
        const button = await page.$(selector);
        if (button) {
          await button.click();
          return;
        }
      } catch (e) {}
    }
  }

  async isSuccessful(page) {
    return !page.url().includes('login');
  }

  async getArn(page) {
    return null;
  }
}
