---
name: aliyun-oauth-validation
description: "Validate Aliyun RAM SSO OAuth login flow using Playwright MCP on headless Ubuntu server. Browser automation handles navigation and form filling, pauses to prompt user for SMS verification code input when needed. Use when user wants to test OAuth authentication end-to-end, validate login flows, or verify SSO integration. Trigger phrases include: validate aliyun oauth, test oauth login, verify sso flow, check oauth authentication, oauth validation, test ram sso"
---

# 阿里云 OAuth 验证 Skill

## 概述

本 Skill 用于在无头 Ubuntu 服务器上使用 Playwright MCP 工具验证阿里云 RAM SSO OAuth 登录流程。

**工作流程:**
1. 使用 Playwright MCP 启动浏览器并导航到 OAuth 页面
2. 自动填写用户名和密码
3. 自动点击"获取验证码"
4. **暂停并提示用户输入 SMS 验证码**
5. 自动填写验证码并提交
6. 验证登录成功

**关键特性:**
- ✅ 100% 浏览器自动化（用户名、密码、按钮点击）
- 📱 SMS 验证码人工输入（最经济的方式）
- 🖥️ 专为无头 Ubuntu 服务器设计
- 🚨 验证码/异常快速失败并报告
- 📸 自动截图用于调试

## 触发条件

当用户要求以下任何操作时触发本 Skill:
- "验证阿里云 OAuth"
- "测试 OAuth 登录"
- "验证 SSO 流程"
- "检查 OAuth 认证"
- "OAuth 验证"
- "测试 RAM SSO"

## 前置条件

**必须配置的环境变量:**
```bash
KIBANA_URL=http://47.236.247.55:5601
USERNAME=dongdongplanet@1437310945246567.onaliyun.com
PASSWORD=Summer11
MOBILE=18972952966
```

**工作目录:**
```
/home/denny/projects/oauth-for-playwright/
```

## 验证工作流程

### 步骤 1: 获取 OAuth 授权 URL

使用 Playwright MCP 导航到 Kibana OAuth 端点:

```bash
playwright_browser_navigate {"url": "http://47.236.247.55:5601/api/security/aliyun/oauth/authorize?redirect_to=/"}
```

从响应中提取 `authorizationUrl`。

**成功标准:** HTTP 200，响应包含 `authorizationUrl` 字段

**失败处理:** 如果失败，提示用户检查 Kibana 是否运行，OAuth 提供商是否配置

### 步骤 2: 导航到阿里云登录页

```bash
playwright_browser_navigate {"url": "<authorizationUrl>"}
```

等待页面加载:
```bash
playwright_browser_wait_for {"time": 3}
```

获取页面快照确认到达:
```bash
playwright_browser_snapshot
```

**成功标准:** 页面标题包含"登录"或 URL 包含 aliyun.com

### 步骤 3: 填写用户名

查找用户名输入框并填写:

```bash
# 尝试多个选择器找到用户名输入框
playwright_browser_fill_form {"fields": [{"name": "username", "type": "textbox", "ref": "input[name='username']", "value": "dongdongplanet@1437310945246567.onaliyun.com"}]}
```

或:
```bash
playwright_browser_type {"element": "username input", "ref": "input[type='email']", "text": "dongdongplanet@1437310945246567.onaliyun.com"}
```

按 Enter 进入下一步:
```bash
playwright_browser_press_key {"key": "Enter"}
```

**成功标准:** 页面跳转到密码输入界面

**失败处理:** 如果找不到输入框，获取页面 snapshot 检查页面结构

### 步骤 4: 填写密码

等待密码输入框出现（最多 10 秒）:
```bash
playwright_browser_wait_for {"time": 3}
```

填写密码:
```bash
playwright_browser_type {"element": "password input", "ref": "input[type='password']", "text": "Summer11"}
```

按 Enter 提交:
```bash
playwright_browser_press_key {"key": "Enter"}
```

**成功标准:** 页面跳转到 SMS 验证界面或出现验证码输入框

### 步骤 5: 检测 SMS 验证界面

等待页面加载:
```bash
playwright_browser_wait_for {"time": 5}
```

获取页面快照检查内容:
```bash
playwright_browser_snapshot
```

检查页面是否包含 SMS 验证相关文本:
- "验证码"
- "verification code"
- "Verify Phone"
- SMS 输入框存在

**如果检测到 SMS 验证:**
- 继续步骤 6

**如果未检测到 SMS 验证:**
- 可能直接登录成功或出现异常
- 检查是否需要验证码处理（见步骤 8）

### 步骤 6: 点击"获取验证码"按钮

查找并点击获取验证码按钮:

```bash
# 尝试多个可能的选择器
playwright_browser_click {"element": "Get code button", "ref": "button:has-text('获取')"}
```

或:
```bash
playwright_browser_click {"element": "Send code button", "ref": "button:has-text('Send')"}
```

**成功标准:** 按钮状态变为"已发送"或倒计时开始

**失败处理:** 如果按钮不可点击，提示用户可能已达到发送限制

### 步骤 7: 暂停并提示用户输入 SMS 验证码

**这是关键步骤 - 必须暂停并等待用户输入**

向用户显示提示:
```
═══════════════════════════════════════════════════════════════
📱 SMS 验证码验证
═══════════════════════════════════════════════════════════════
验证码已发送到: 18972952966

请查看您的手机短信，然后输入 6 位验证码。

注意：验证码通常会在 10-30 秒内送达。如果未收到，请检查：
1. 手机短信收件箱
2. 垃圾短信文件夹
3. 信号是否良好

验证码有效期通常为 5 分钟，请尽快输入。
═══════════════════════════════════════════════════════════════
```

**获取用户输入:**
使用 `question` 工具询问用户:

```javascript
// 使用 question 工具
{
  "questions": [{
    "question": "请输入您手机上收到的 6 位验证码",
    "options": [],
    "header": "SMS Code"
  }]
}
```

或直接在对话中等待用户回复验证码。

**验证码格式验证:**
- 必须是 6 位数字
- 格式: /^\d{6}$/
- 如果不是 6 位数字，提示用户重新输入

### 步骤 8: 填写 SMS 验证码

获取用户输入的验证码后，填写到输入框:

```bash
playwright_browser_type {"element": "SMS code input", "ref": "input[name='code']", "text": "<用户输入的验证码>"}
```

**如果找不到输入框:**
获取页面 snapshot 检查当前页面状态:
```bash
playwright_browser_snapshot
```

可能的情况:
1. 页面已过期 - 提示用户流程超时，需要重新开始
2. 页面结构变化 - 更新选择器

### 步骤 9: 提交验证码

点击提交按钮或按 Enter:

```bash
playwright_browser_click {"element": "Submit button", "ref": "button[type='submit']"}
```

或:
```bash
playwright_browser_press_key {"key": "Enter"}
```

等待提交处理:
```bash
playwright_browser_wait_for {"time": 3}
```

### 步骤 10: 检查验证码错误

获取页面快照检查是否有错误信息:
```bash
playwright_browser_snapshot
```

**检查错误指示:**
- 页面包含 "验证码错误" / "Invalid code"
- 页面包含 "验证码已过期" / "Code expired"
- 输入框变红或有错误提示
- 仍在 SMS 验证页面（未跳转）

**如果发现错误:**
```
⚠️  验证码验证失败

可能原因：
1. 验证码输入错误
2. 验证码已过期（超过5分钟）
3. 验证码已被使用

建议操作：
1. 请重新获取验证码
2. 检查输入是否正确
3. 如果多次失败，请重新开始流程
```

**快速失败:** 如果验证码错误，立即停止流程并报告失败，不自动重试。

### 步骤 11: 检测验证码/滑块挑战

获取页面快照:
```bash
playwright_browser_snapshot
```

**检查验证码/滑块指示:**
- 页面包含滑块元素 (`.nc_wrapper`, `.slider`, `captcha`)
- 页面包含图片验证码
- 页面要求"拖动滑块"或"点击验证"

**如果发现验证码挑战:**
```
⚠️  检测到验证码/滑块挑战

阿里云触发了人机验证机制，显示滑块验证码。

在当前无头服务器环境下，无法自动完成此类验证。

建议：
1. 使用有头模式运行（HEADLESS=false）手动完成验证
2. 更换 IP 地址后重试
3. 等待一段时间后再试（避免触发风控）

流程已中止。
```

**快速失败:** 立即报告失败，不尝试解决。

### 步骤 12: 等待重定向到 Kibana

等待页面跳转:
```bash
playwright_browser_wait_for {"text": "Discover", "time": 30}
```

或检查 URL 变化:
```bash
playwright_browser_evaluate {"function": "() => window.location.href"}
```

**成功标准:**
- URL 包含 `47.236.247.55:5601` 或 `localhost:5601`
- 页面包含 "Discover"、"Dashboard" 或 "Kibana" 文本

**失败处理:**
如果超时未跳转:
```bash
playwright_browser_snapshot
```

可能情况:
1. 仍在阿里云页面 - 登录失败
2. 显示错误信息 - 角色映射问题
3. 白屏或加载中 - 网络问题

### 步骤 13: 验证登录成功

获取页面快照:
```bash
playwright_browser_snapshot
```

**验证 Kibana UI 元素:**
- 包含 "Discover"
- 包含 "Dashboards"
- 包含 "Dev Tools"
- 包含 Kibana logo 或导航栏

截图保存:
```bash
playwright_browser_take_screenshot {"filename": "oauth-success.png", "fullPage": true}
```

**成功报告:**
```
✅ OAuth 验证成功！

验证结果：
- 用户名: dongdongplanet@1437310945246567.onaliyun.com
- 登录方式: 阿里云 RAM SSO
- 目标: Kibana (http://47.236.247.55:5601)
- 状态: 已登录

检测到的 UI 元素：
✓ Discover 页面
✓ Dashboards
✓ Kibana 导航栏

截图已保存: oauth-success.png
```

### 步骤 14: 关闭浏览器

```bash
playwright_browser_close
```

## 错误处理策略

### 1. 网络超时

**症状:** 页面加载超过 30 秒

**处理:**
```
⚠️  网络超时

页面加载时间过长。可能原因：
1. Kibana 服务未运行
2. 网络连接问题
3. 阿里云登录服务缓慢

建议：
1. 检查 Kibana 状态: curl http://47.236.247.55:5601/api/status
2. 检查网络连接
3. 稍后重试
```

### 2. 元素未找到

**症状:** Playwright 无法找到输入框或按钮

**处理:**
```bash
playwright_browser_snapshot
```

分析页面结构，更新选择器。

### 3. 验证码错误

**症状:** 提交后仍在 SMS 页面，显示错误信息

**处理:** 快速失败，不自动重试
```
❌ 验证码错误

输入的验证码不正确或已过期。

请：
1. 重新运行流程获取新验证码
2. 确保在 5 分钟内输入
3. 仔细核对验证码数字
```

### 4. 滑块/图片验证码

**症状:** 页面出现滑块或图片验证码

**处理:** 快速失败
```
❌ 遇到人机验证挑战

阿里云触发了额外的安全验证（滑块/图片验证码）。

在无头服务器环境下无法自动处理。

解决方案：
1. 使用有头模式（HEADLESS=false）手动完成
2. 使用其他验证方式（如 TOTP 替代 SMS）
3. 联系管理员配置免验证 IP
```

### 5. 会话过期

**症状:** 页面提示会话过期或超时

**处理:**
```
⚠️  会话已过期

登录会话超时。请重新运行验证流程。
```

## 快速失败场景

以下情况立即停止流程并报告失败：

1. ✅ **验证码错误** - 用户输入的 SMS 验证码不正确
2. ✅ **滑块/图片验证码** - 阿里云触发了人机验证
3. ✅ **会话过期** - 登录会话超时
4. ✅ **页面结构变化** - 无法找到必需的表单元素
5. ✅ **网络超时** - 页面加载超过 60 秒

**不自动重试**，直接报告失败原因给用户。

## 调试指南

### 启用可见浏览器（调试用）

设置环境变量:
```bash
HEADLESS=false
```

然后在 Claude Code 中:
```bash
export HEADLESS=false
```

再运行验证流程。

### 查看页面 Snapshot

在任何步骤都可以获取当前页面状态:
```bash
playwright_browser_snapshot
```

这会显示:
- 当前 URL
- 页面标题
- 所有可见元素和选择器

### 查看截图

流程会自动保存截图到 `/tmp/`:
- `oauth-step1-login.png` - 登录页面
- `oauth-step2-username.png` - 填写用户名后
- `oauth-step3-password.png` - 填写密码后
- `oauth-step4-sms.png` - SMS 验证页面
- `oauth-success.png` - 登录成功
- `oauth-failure.png` - 登录失败

### 手动接管

如果自动流程失败，可以手动接管:
```bash
# 获取当前状态
playwright_browser_snapshot

# 手动点击元素
playwright_browser_click {"element": "<描述>", "ref": "<选择器>"}

# 手动输入
playwright_browser_type {"element": "<描述>", "ref": "<选择器>", "text": "<值>"}
```

## 最佳实践

### 1. 验证码输入时机

- 在点击"获取验证码"后立即提示用户
- 给用户充足的时间（验证码 5 分钟有效）
- 提醒用户检查垃圾短信文件夹

### 2. 错误提示

- 明确说明失败原因
- 提供具体解决建议
- 不要自动重试 SMS 验证码（避免锁定账户）

### 3. 安全检查

- 验证验证码格式（6位数字）
- 检查页面是否出现异常提示
- 确认最终跳转 URL 正确

## 示例对话

**用户:** "验证阿里云 OAuth"

**Claude:**
```
我来帮您验证阿里云 OAuth 登录流程。这将在无头服务器上使用 Playwright MCP 自动完成大部分操作。

═══════════════════════════════════════════════════════════════
开始 OAuth 验证
═══════════════════════════════════════════════════════════════
目标: http://47.236.247.55:5601
用户名: dongdongplanet@1437310945246567.onaliyun.com
手机号: 18972952966

[步骤 1/14] 正在获取 OAuth 授权 URL...
✓ 已获取授权 URL

[步骤 2/14] 正在导航到阿里云登录页面...
✓ 已到达登录页面

[步骤 3/14] 正在填写用户名...
✓ 用户名已填写

[步骤 4/14] 正在填写密码...
✓ 密码已填写

[步骤 5/14] 检测 SMS 验证界面...
检测到 SMS 验证要求

[步骤 6/14] 正在点击"获取验证码"...
✓ 已触发验证码发送

═══════════════════════════════════════════════════════════════
📱 SMS 验证码验证
═══════════════════════════════════════════════════════════════
验证码已发送到: 18972952966

请查看您的手机短信，然后输入 6 位验证码：
```

**用户:** "847291"

**Claude:**
```
收到验证码: 847291

[步骤 8/14] 正在填写验证码...
✓ 验证码已填写

[步骤 9/14] 正在提交...
✓ 已提交

[步骤 10/14] 等待跳转到 Kibana...
✓ 已跳转到 Kibana

[步骤 11/14] 验证登录状态...

✅ OAuth 验证成功！

验证结果：
- 登录状态: 已成功
- 检测到的页面: Discover, Dashboards, Dev Tools
- 截图已保存: oauth-success.png

浏览器已关闭。
```

## 相关文件

- `/home/denny/projects/oauth-for-playwright/oauth_validation_playwright.js` - 独立脚本版本
- `/home/denny/projects/oauth-for-playwright/plan.md` - 完整方案文档

## 参考

- Playwright MCP 文档: 使用 `playwright_*` 工具
- 阿里云 RAM 文档: https://www.alibabacloud.com/help/en/ram
- Kibana 安全配置: 检查 kibana.yml 中的 xpack.security.authc.providers
