#!/usr/bin/env node
/**
 * 通用 OAuth SSO 验证执行器
 * 
 * 配置驱动的 OAuth 验证脚本，支持多种提供商和 MFA 方式
 * 使用 Playwright MCP 进行浏览器自动化
 * 
 * 使用方法:
 *   PROVIDER=aliyun USERNAME=user PASSWORD=pass node oauth-runner.js
 * 
 * 或使用自定义配置:
 *   CONFIG=/path/to/config.json USERNAME=user PASSWORD=pass node oauth-runner.js
 */

const fs = require('fs');
const path = require('path');

// 颜色输出
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

// 配置加载器
class ConfigLoader {
  constructor() {
    this.configDir = path.join(__dirname, '..', 'references', 'providers');
  }

  load(providerId) {
    // 1. 尝试加载内置配置
    const builtinPath = path.join(this.configDir, `${providerId}.json`);
    if (fs.existsSync(builtinPath)) {
      log(`[Config] 加载内置配置: ${providerId}`, colors.dim);
      return JSON.parse(fs.readFileSync(builtinPath, 'utf8'));
    }

    // 2. 尝试加载自定义配置
    const customPath = process.env.CONFIG;
    if (customPath && fs.existsSync(customPath)) {
      log(`[Config] 加载自定义配置: ${customPath}`, colors.dim);
      return JSON.parse(fs.readFileSync(customPath, 'utf8'));
    }

    throw new Error(`Provider '${providerId}' not found. Built-in: ${builtinPath}, Custom: ${customPath || 'not set'}`);
  }

  listProviders() {
    const files = fs.readdirSync(this.configDir);
    return files
      .filter(f => f.endsWith('.json') && f !== 'template.json')
      .map(f => {
        const config = JSON.parse(fs.readFileSync(path.join(this.configDir, f), 'utf8'));
        return { id: config.id, name: config.name, triggers: config.triggers };
      });
  }
}

// 选择器匹配器
class SelectorMatcher {
  constructor(config) {
    this.config = config;
  }

  getSelector(key, type = null) {
    const selectorConfig = this.config.selectors[key];
    if (!selectorConfig) {
      throw new Error(`Selector '${key}' not found in config`);
    }

    // 如果是对象且有 type 子键
    if (type && typeof selectorConfig === 'object' && !Array.isArray(selectorConfig)) {
      return selectorConfig[type] || selectorConfig.fallback || selectorConfig.selector;
    }

    // 返回主选择器或 fallback
    if (typeof selectorConfig === 'string') {
      return selectorConfig;
    }

    return selectorConfig.selector;
  }

  getAllSelectors(key, type = null) {
    const selectorConfig = this.config.selectors[key];
    if (!selectorConfig) return [];

    const selectors = [];
    
    if (typeof selectorConfig === 'string') {
      selectors.push(selectorConfig);
    } else if (type && selectorConfig[type]) {
      selectors.push(selectorConfig[type]);
    } else if (selectorConfig.selector) {
      selectors.push(selectorConfig.selector);
    }

    if (selectorConfig.fallback && Array.isArray(selectorConfig.fallback)) {
      selectors.push(...selectorConfig.fallback);
    }

    return selectors;
  }
}

// MFA 处理器工厂
class MFAHandlerFactory {
  static getHandler(type, config) {
    switch (type) {
      case 'sms':
        return new SMSHandler(config);
      case 'email':
        return new EmailHandler(config);
      case 'totp':
        return new TOTPHandler(config);
      default:
        throw new Error(`Unknown MFA type: ${type}`);
    }
  }
}

// SMS 处理器
class SMSHandler {
  constructor(config) {
    this.config = config;
  }

  async execute(selectorMatcher) {
    log('\n[步骤] 处理 SMS 验证码', colors.blue);
    
    const phone = process.env.OAUTH_PHONE;
    if (!phone) {
      log('⚠️  未设置 OAUTH_PHONE 环境变量', colors.yellow);
    }

    // 1. 点击获取验证码按钮
    const getCodeSelectors = selectorMatcher.getAllSelectors('getCodeButton');
    log('  点击获取验证码按钮...', colors.dim);
    
    // 这里应该调用 Playwright MCP，但在这个脚本中我们只是模拟流程
    // 实际执行由 Claude 使用 Playwright MCP 工具完成
    
    // 2. 提示用户输入
    const mfaConfig = this.config.mfa?.sms || {};
    const promptTemplate = mfaConfig.promptTemplate || '请输入 6 位验证码：';
    const prompt = promptTemplate.replace('{phone}', phone || '您的手机');
    
    log('\n' + '='.repeat(60), colors.cyan);
    log('📱 SMS 验证码验证', colors.bold + colors.cyan);
    log('='.repeat(60), colors.cyan);
    log(prompt, colors.yellow);
    log('验证码有效期：' + (mfaConfig.maxWaitSeconds || 300) + ' 秒', colors.dim);
    log('='.repeat(60), colors.cyan);
    log('\n👉 请在 Claude Code 中回复验证码\n', colors.bold);

    // 3. 等待用户输入 (在实际 Skill 执行中，Claude 会暂停并询问用户)
    // 这里我们只是演示流程
    
    return {
      type: 'sms',
      prompt: prompt,
      needsUserInput: true
    };
  }
}

// Email 处理器
class EmailHandler {
  constructor(config) {
    this.config = config;
  }

  async execute(selectorMatcher) {
    log('\n[步骤] 处理 Email 验证码', colors.blue);
    
    const email = process.env.OAUTH_EMAIL;
    if (!email) {
      log('⚠️  未设置 OAUTH_EMAIL 环境变量', colors.yellow);
    }

    const mfaConfig = this.config.mfa?.email || {};
    const promptTemplate = mfaConfig.promptTemplate || '请输入邮箱验证码：';
    const prompt = promptTemplate.replace('{email}', email || '您的邮箱');
    
    log('\n' + '='.repeat(60), colors.cyan);
    log('📧 Email 验证码验证', colors.bold + colors.cyan);
    log('='.repeat(60), colors.cyan);
    log(prompt, colors.yellow);
    log('='.repeat(60), colors.cyan);
    log('\n👉 请在 Claude Code 中回复验证码\n', colors.bold);

    return {
      type: 'email',
      prompt: prompt,
      needsUserInput: true
    };
  }
}

// TOTP 处理器
class TOTPHandler {
  constructor(config) {
    this.config = config;
  }

  async execute(selectorMatcher) {
    log('\n[步骤] 处理 TOTP 验证码', colors.blue);
    
    const secret = process.env.MFA_SECRET;
    if (!secret) {
      throw new Error('MFA_SECRET environment variable is required for TOTP');
    }

    // 自动计算 TOTP 码
    // 注意：这里需要实现 TOTP 计算逻辑，或者提示用户提供
    log('  自动计算 TOTP 验证码...', colors.dim);
    
    // 实际实现中需要 otplib 或类似库
    // const code = generateTOTP(secret);
    
    log('⚠️  请手动输入 TOTP 验证器中的 6 位验证码', colors.yellow);

    return {
      type: 'totp',
      needsUserInput: true
    };
  }
}

// 主执行器
class OAuthRunner {
  constructor() {
    this.configLoader = new ConfigLoader();
  }

  async run(providerId) {
    log('\n' + '='.repeat(60), colors.bold);
    log('通用 OAuth SSO 验证', colors.bold);
    log('='.repeat(60), colors.bold);
    
    // 1. 加载配置
    log('\n[步骤 1] 加载提供商配置...', colors.blue);
    const config = this.configLoader.load(providerId);
    log(`✓ 配置加载成功: ${config.name}`, colors.green);
    
    // 2. 检查环境变量
    log('\n[步骤 2] 检查环境变量...', colors.blue);
    const required = ['USERNAME', 'PASSWORD'];
    const missing = required.filter(key => !process.env[key]);
    
    if (missing.length > 0) {
      throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
    }
    
    log(`✓ 用户凭证: ${process.env.USERNAME.substring(0, 5)}...`, colors.green);
    
    // 3. 初始化选择器匹配器
    const selectorMatcher = new SelectorMatcher(config);
    
    // 4. 获取 MFA 配置
    const mfaType = process.env.MFA_TYPE || config.mfa?.defaultType || 'sms';
    log(`  MFA 类型: ${mfaType}`, colors.dim);
    
    // 5. 执行 MFA 处理
    const mfaHandler = MFAHandlerFactory.getHandler(mfaType, config);
    const mfaResult = await mfaHandler.execute(selectorMatcher);
    
    // 返回执行计划 (供 Claude Skill 使用)
    return {
      config: config,
      selectorMatcher: selectorMatcher,
      mfa: mfaResult,
      steps: this.generateSteps(config, mfaResult)
    };
  }

  generateSteps(config, mfaResult) {
    return [
      { step: 1, name: '获取 OAuth 授权 URL', action: 'navigate', url: '${TARGET_URL}${OAUTH_ENDPOINT}' },
      { step: 2, name: '导航到登录页', action: 'navigate', url: 'authorizationUrl' },
      { step: 3, name: '填写用户名', action: 'fill', field: 'username' },
      { step: 4, name: '填写密码', action: 'fill', field: 'password' },
      { step: 5, name: '检测 MFA 界面', action: 'detect', text: config.detection?.mfaPageText },
      { step: 6, name: '处理 MFA', action: 'mfa', type: mfaResult.type },
      { step: 7, name: '授权应用', action: 'click', button: 'authorize' },
      { step: 8, name: '验证登录成功', action: 'detect', text: config.detection?.successText }
    ];
  }

  listProviders() {
    return this.configLoader.listProviders();
  }
}

// CLI 入口
async function main() {
  const args = process.argv.slice(2);
  const command = args[0];
  
  const runner = new OAuthRunner();
  
  if (command === 'list') {
    // 列出所有提供商
    const providers = runner.listProviders();
    log('\n可用提供商列表:', colors.bold);
    providers.forEach(p => {
      log(`  • ${p.id}: ${p.name}`, colors.cyan);
      log(`    触发词: ${p.triggers.join(', ')}`, colors.dim);
    });
    return;
  }
  
  if (command === 'validate') {
    // 验证配置
    const providerId = args[1] || process.env.PROVIDER;
    if (!providerId) {
      log('错误: 请指定提供商 ID', colors.red);
      log('用法: node oauth-runner.js validate <provider-id>', colors.dim);
      process.exit(1);
    }
    
    try {
      const config = new ConfigLoader().load(providerId);
      log(`✓ 配置验证通过: ${config.name}`, colors.green);
      log(`  选择器: ${Object.keys(config.selectors).length} 个`, colors.dim);
      log(`  MFA 类型: ${config.mfa?.types?.join(', ') || 'none'}`, colors.dim);
    } catch (err) {
      log(`✗ 配置验证失败: ${err.message}`, colors.red);
      process.exit(1);
    }
    return;
  }
  
  // 默认：执行验证
  const providerId = process.env.PROVIDER || args[0];
  
  if (!providerId) {
    log('错误: 请指定提供商', colors.red);
    log('\n用法:', colors.dim);
    log('  PROVIDER=aliyun USERNAME=user PASSWORD=pass node oauth-runner.js', colors.dim);
    log('  node oauth-runner.js list', colors.dim);
    log('  node oauth-runner.js validate <provider-id>', colors.dim);
    process.exit(1);
  }
  
  try {
    const result = await runner.run(providerId);
    log('\n✓ 执行计划生成成功', colors.green);
    log(`  提供商: ${result.config.name}`, colors.dim);
    log(`  MFA: ${result.mfa.type}`, colors.dim);
    log(`  步骤: ${result.steps.length} 个`, colors.dim);
    
    // 输出执行计划 (JSON 格式，供 Skill 解析)
    console.log('\n---EXECUTION_PLAN---');
    console.log(JSON.stringify(result, null, 2));
    
  } catch (err) {
    log(`\n✗ 错误: ${err.message}`, colors.red);
    process.exit(1);
  }
}

// 如果直接运行此脚本
if (require.main === module) {
  main().catch(err => {
    console.error(err);
    process.exit(1);
  });
}

// 导出模块 (供其他脚本使用)
module.exports = {
  ConfigLoader,
  SelectorMatcher,
  MFAHandlerFactory,
  OAuthRunner
};
