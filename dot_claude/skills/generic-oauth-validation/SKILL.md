---
name: generic-oauth-validation
description: "Generic OAuth SSO validation skill supporting multiple providers (Aliyun, Google, Microsoft, etc.) with configurable MFA methods (SMS, Email, TOTP). Uses Playwright MCP for browser automation with human-in-the-loop for verification codes. Trigger phrases: validate oauth, test sso login, verify oauth flow, check sso authentication, oauth validation, test oauth login. Supports custom providers via JSON configuration."
---

# 通用 OAuth SSO 验证 Skill

验证任意 OAuth 2.0 / OIDC SSO 登录流程，支持多种身份提供商和 MFA 方式。

## 概述

本 Skill 使用**配置驱动架构**，通过 JSON 配置文件支持任意 OAuth 提供商，无需修改代码即可扩展。

**支持的提供商** (内置):
- ✅ 阿里云 RAM SSO
- ✅ Google Workspace / Gmail

**支持的 MFA 方式**:
- 📱 SMS 验证码 (暂停提示输入)
- 📧 Email 验证码 (暂停提示输入)
- 🔢 TOTP (Google/Microsoft Authenticator，自动计算)

**核心特性**:
- 🔧 配置驱动 - 添加新提供商只需 JSON 文件
- 🤖 浏览器自动化 - Playwright MCP 操作
- 👤 人机协作 - MFA 验证码人工输入
- 🚨 快速失败 - 明确错误提示，不自动重试
- 📸 自动截图 - 每个步骤保存截图
- 🔌 预留扩展 - Hook 系统支持未来全自动化

## 触发条件

当用户要求以下任何操作时触发本 Skill:

- "验证 OAuth"
- "测试 SSO 登录"
- "验证 OAuth 流程"
- "检查 SSO 认证"
- "OAuth 验证"
- "测试 OAuth 登录"
- "验证 [提供商名称] OAuth" (如 "验证阿里云 OAuth")

## 前置条件

### 必需环境变量

```bash
# 目标应用
export TARGET_URL="http://your-app.com"           # 登录后跳转的应用
export OAUTH_ENDPOINT="/api/oauth/authorize"      # OAuth 授权端点

# 用户凭证
export USERNAME="your-username"
export PASSWORD="your-password"

# MFA 配置 (根据 MFA 类型选择)
export MFA_TYPE="sms"                             # sms | email | totp
export MFA_SECRET=""                              # TOTP 密钥 (仅 TOTP 需要)
```

### 可选环境变量

```bash
# 提供商指定
export OAUTH_PROVIDER="aliyun"                    # aliyun | google | custom
export OAUTH_PROVIDER_CONFIG="/path/to/config.json" # 自定义配置路径

# SMS 配置 (SMS 验证时需要)
export OAUTH_PHONE="18972952966"                  # 接收验证码的手机号

# Email 配置 (Email 验证时需要)
export OAUTH_EMAIL="user@example.com"             # 接收验证码的邮箱
```

## 使用方式

### 方式 1: 指定提供商

```bash
用户: "验证阿里云 OAuth"
Claude: [自动识别提供商为 aliyun，加载配置，执行验证]
```

### 方式 2: 自动检测

```bash
用户: "验证 OAuth"
Claude: "请选择提供商：
        1) 阿里云 (aliyun)
        2) Google (google)
        3) 其他 (自定义配置)"
用户: "1"
Claude: [加载 aliyun 配置，执行验证]
```

### 方式 3: 自定义配置

```bash
用户: "验证 OAuth，配置文件 /path/to/my-company.json"
Claude: [加载自定义配置，执行验证]
```

### 方式 4: 指定 MFA 类型

```bash
用户: "验证 Google OAuth 使用 TOTP"
Claude: [使用 TOTP 处理器，自动计算验证码]
```

## 验证工作流程

所有提供商使用**相同的通用工作流程**，通过配置驱动执行：

### 步骤 1: 加载配置

Claude 根据用户输入或自动检测，加载对应的提供商配置:
- 内置配置: `references/providers/{provider}.json`
- 自定义配置: 用户指定的 JSON 文件路径

### 步骤 2: 提示输入必要信息

如果环境变量中缺少必要信息，Claude 会提示用户:
- 用户名/密码
- 手机号 (SMS MFA)
- 邮箱 (Email MFA)
- TOTP 密钥 (TOTP MFA)

### 步骤 3: 获取 OAuth 授权 URL

```bash
playwright_browser_navigate {"url": "${TARGET_URL}${OAUTH_ENDPOINT}?redirect_to=/"}
```

从响应中提取 `authorizationUrl`。

### 步骤 4: 导航到 IdP 登录页

```bash
playwright_browser_navigate {"url": "<authorizationUrl>"}
playwright_browser_wait_for {"time": 3}
```

### 步骤 5: 填写用户名

使用配置中的选择器:
```bash
playwright_browser_type {"element": "username", "ref": "<config.selectors.username>", "text": "${USERNAME}"}
playwright_browser_click {"element": "next button", "ref": "<config.selectors.nextButton>"}
```

尝试多个 fallback 选择器直到成功。

### 步骤 6: 填写密码

```bash
playwright_browser_type {"element": "password", "ref": "<config.selectors.password>", "text": "${PASSWORD}"}
playwright_browser_click {"element": "login button", "ref": "<config.selectors.loginButton>"}
```

### 步骤 7: 检测 MFA 界面

获取页面快照，检查是否进入 MFA 验证:
```bash
playwright_browser_snapshot
```

匹配配置中的 `detection.mfaPageText`。

### 步骤 8: 选择 MFA 类型 (如有多个)

如果提供商支持多种 MFA，切换到用户指定的类型:
```bash
# 例如切换到 SMS
playwright_browser_click {"element": "SMS tab", "ref": "<config.selectors.mfaTab.sms>"}
```

### 步骤 9: 处理 MFA (策略模式)

根据 MFA 类型选择处理器:

#### SMS 处理器
1. 点击"获取验证码"按钮
2. **暂停并提示用户输入**
3. 填写验证码
4. 提交

#### Email 处理器
1. 点击"发送验证码"按钮
2. **暂停并提示用户输入**
3. 填写验证码
4. 提交

#### TOTP 处理器
1. 自动计算当前 TOTP 码
2. 自动填写
3. 提交

### 步骤 10: 授权应用访问

如果显示授权页面，点击授权:
```bash
playwright_browser_click {"element": "authorize button", "ref": "<config.selectors.authorizeButton>"}
```

### 步骤 11: 验证登录成功

等待跳转到目标应用:
```bash
playwright_browser_wait_for {"text": "<config.detection.successText>", "time": 30}
```

检测成功标识:
- 页面包含成功文本
- URL 匹配目标应用
- 检测到目标应用 UI 元素

### 步骤 12: 截图保存

```bash
playwright_browser_take_screenshot {"filename": "oauth-success.png", "fullPage": true}
```

### 步骤 13: 关闭浏览器

```bash
playwright_browser_close
```

## 配置驱动架构

### 配置结构

每个提供商一个 JSON 配置文件:

```json
{
  "id": "aliyun",
  "name": "阿里云 RAM SSO",
  "description": "阿里云 RAM 用户 SSO 登录",
  
  "triggers": ["aliyun", "阿里云", "ram"],
  
  "selectors": {
    "username": {
      "selector": "input[name='username']",
      "fallback": ["input[type='email']", "input[placeholder*='账号']"]
    },
    "password": {
      "selector": "input[type='password']",
      "fallback": ["input[id='loginPassword']"]
    },
    "nextButton": {
      "selector": "button:has-text('Next')",
      "fallback": ["button[type='submit']"]
    },
    "loginButton": {
      "selector": "button:has-text('Log On')",
      "fallback": ["button:has-text('登录')"]
    },
    "mfaTab": {
      "sms": "tab:has-text('Phone Number')",
      "totp": "tab:has-text('Virtual MFA')"
    },
    "mfaInput": {
      "sms": "input[placeholder*='verification code']",
      "fallback": "input[name='code']"
    },
    "getCodeButton": "button:has-text('Obtain')",
    "submitButton": "button[type='submit']",
    "authorizeButton": "button:has-text('Authorize')"
  },
  
  "mfa": {
    "defaultType": "sms",
    "types": ["sms", "totp"],
    "sms": {
      "needPhoneInput": false,
      "promptTemplate": "验证码已发送到 {phone}，请输入 6 位验证码：",
      "codeRegex": "\\d{6}",
      "maxWaitSeconds": 300
    }
  },
  
  "detection": {
    "loginPageText": "RAM User Logon",
    "mfaPageText": "An unusual logon is detected",
    "successText": "Welcome to Elastic",
    "errorTexts": ["verification code is invalid", "password is incorrect"]
  },
  
  "hooks": {
    "preFill": null,
    "postMFA": null,
    "automation": {
      "enabled": false
    }
  }
}
```

### 配置字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 提供商唯一标识 |
| `name` | string | 显示名称 |
| `triggers` | array | 触发关键词 |
| `selectors` | object | DOM 选择器配置 |
| `selectors.*.selector` | string | 主选择器 |
| `selectors.*.fallback` | array | 备选选择器 |
| `mfa` | object | MFA 配置 |
| `mfa.defaultType` | string | 默认 MFA 类型 |
| `mfa.types` | array | 支持的 MFA 类型 |
| `detection` | object | 页面检测文本 |
| `hooks` | object | 扩展钩子 |

### 添加新提供商

**步骤**:

1. 复制模板:
```bash
cp references/providers/template.json references/providers/new-provider.json
```

2. 编辑配置，填写:
   - 选择器 (通过浏览器开发者工具获取)
   - 检测文本
   - MFA 配置

3. 立即使用:
```bash
"验证 {new-provider} OAuth"
```

**无需修改任何代码!**

## 错误处理策略

### 快速失败 (Fail Fast)

遇到以下情况立即停止，不自动重试:

1. **验证码错误**
   - 提示: "验证码不正确，请重新运行流程"
   - 原因: 避免账户锁定

2. **元素未找到**
   - 提示: "页面结构可能已变化，请更新配置"
   - 建议: 检查选择器是否正确

3. **网络超时**
   - 提示: "网络连接超时，请检查服务状态"
   - 建议: `curl ${TARGET_URL}/api/status`

4. **滑块/图片验证码**
   - 提示: "检测到验证码挑战，当前环境无法自动处理"
   - 建议: 使用有头模式或联系管理员

5. **页面结构变化**
   - 提示: "页面结构不匹配配置，可能需要更新"
   - 调试: 查看截图和页面快照

### 错误提示格式

```
❌ OAuth 验证失败

提供商: {provider-name}
步骤: {current-step}
原因: {error-message}

当前页面: {current-url}
检测到的文本: {page-text-preview}

建议操作:
1. {suggestion-1}
2. {suggestion-2}

调试信息:
- 截图: {screenshot-path}
- 配置: {config-file}
- 日志: {log-path}
```

## 调试指南

### 查看页面快照

任何步骤都可以获取当前页面状态:
```bash
playwright_browser_snapshot
```

### 查看截图

自动保存的截图:
- `oauth-step{N}-{description}.png` - 各步骤截图
- `oauth-success.png` - 成功截图
- `oauth-failure.png` - 失败截图
- `oauth-error.png` - 错误截图

### 手动接管

如果自动流程失败，可手动接管:
```bash
# 查看当前状态
playwright_browser_snapshot

# 手动操作
playwright_browser_click {"element": "...", "ref": "..."}
playwright_browser_type {"element": "...", "ref": "...", "text": "..."}
```

### 启用可见浏览器

调试用:
```bash
export HEADLESS=false
```

## 扩展性设计

### 预留全自动化 (Hooks)

配置中预留 `hooks.automation` 用于未来全自动化:

```json
{
  "hooks": {
    "automation": {
      "enabled": true,
      "smsProvider": "twilio",
      "emailProvider": "gmail-api",
      "captchaSolver": "2captcha"
    }
  }
}
```

**未来支持**:
- Twilio SMS 自动接收
- Gmail API 自动读取邮件
- 2Captcha 验证码自动解决

### 自定义 Hook

```json
{
  "hooks": {
    "preFill": "scripts/custom-pre-fill.js",
    "postMFA": "scripts/custom-post-mfa.js"
  }
}
```

## 安全注意事项

1. **不要提交凭证到 Git**
   ```bash
   echo ".env" >> .gitignore
   ```

2. **使用环境变量**
   - 不要在命令行历史记录中明文输入密码
   - 使用 `export` 或 `.env` 文件

3. **定期更换密码**
   - 测试完成后更换密码
   - 不要在生产环境使用测试账号

4. **限制应用权限**
   - OAuth 授权时只授予必要权限
   - 定期检查已授权应用

## 已知限制

1. **验证码挑战**
   - 无法自动处理滑块/图片验证码
   - 需要人工介入或验证码解决服务

2. **风控机制**
   - 频繁登录可能触发风控
   - 可能需要等待或更换 IP

3. **页面变化**
   - IdP 页面结构变化时需要更新配置
   - 建议定期验证配置有效性

## 参考

- [架构设计文档](../docs/ARCHITECTURE.md)
- [阿里云 OAuth 验证](../aliyun-oauth-validation/SKILL.md)
- [OAuth 2.0 规范](https://tools.ietf.org/html/rfc6749)
- [OIDC 规范](https://openid.net/specs/openid-connect-core-1_0.html)

---

**版本**: 1.0  
**最后更新**: 2026-02-14
