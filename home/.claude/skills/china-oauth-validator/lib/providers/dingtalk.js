/**
 * DingTalk (钉钉) OAuth Provider
 */

export default class DingTalkProvider {
  constructor(config) {
    this.config = config;
    this.name = 'dingtalk';
  }

  async detect(page, url, content) {
    return url.includes('dingtalk.com') ||
           url.includes('dingtalk') ||
           content.includes('钉钉') ||
           content.includes('DingTalk');
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
    throw new Error('Could not find phone input for DingTalk');
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
    throw new Error('Could not click SMS button for DingTalk');
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
    throw new Error('Could not find SMS code input for DingTalk');
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
