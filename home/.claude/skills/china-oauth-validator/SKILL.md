# China OAuth Validator

General-purpose OAuth validation for Chinese services with automated SMS handling.

## Overview

Automates OAuth login flows for:
- **Aliyun (阿里云)** - Cloud services and RAM authentication
- **WeChat (微信)** - Social login with SMS verification

## Features

- 🤖 **Automated browser automation** via Playwright
- 📱 **SMS code handling** - Manual entry or automated via SMSPVA
- 📸 **Screenshot debugging** - Automatic screenshots at each step
- 📊 **Validation reports** - JSON output of test results

## Installation

```bash
cd ~/.claude/skills/china-oauth-validator
npm install
```

## Usage

### Aliyun OAuth (Manual SMS)

```bash
node validate_china_oauth.js \
  --provider aliyun \
  --target-url "http://localhost:5601" \
  --phone "8618972952966" \
  --headless false
```

### WeChat OAuth (Manual SMS)

```bash
node validate_china_oauth.js \
  --provider wechat \
  --target-url "https://example.com/login" \
  --phone "8618972952966" \
  --headless false
```

### With Automated SMS (SMSPVA)

```bash
node validate_china_oauth.js \
  --provider aliyun \
  --target-url "http://localhost:5601" \
  --sms-service smspva \
  --smspva-api-key "YOUR_API_KEY"
```

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `--provider` | Yes | `aliyun` or `wechat` |
| `--target-url` | Yes | URL to start OAuth flow |
| `--phone` | Yes* | Phone number (e.g., 8618972952966) |
| `--sms-service` | No | `manual` (default) or `smspva` |
| `--smspva-api-key` | No | SMSPVA API key |
| `--headless` | No | Headless mode (default: true) |
| `--timeout` | No | Timeout in seconds (default: 30) |

*Phone required for SMS verification

## Output

- **Console**: Real-time progress
- **Report**: `validation_report.json`
- **Screenshots**: `validation_screenshots/`

## SMSPVA Setup

1. Get API key from https://smspva.com/
2. Set country code: `--smspva-country CN` (China)
3. Service code is auto-set based on provider

## Troubleshooting

| Issue | Solution |
|-------|----------|
| SMS not received | Use `--headless false` to see what's happening |
| Phone input not found | OAuth page structure may have changed |
| SMS timeout | Increase `--sms-timeout 120` for slower services |

## Example: Validate Aliyun OAuth

```bash
# Start validation
node validate_china_oauth.js \
  --provider aliyun \
  --target-url "http://localhost:5601" \
  --phone "8618972952966" \
  --headless false

# Script will:
# 1. Navigate to target URL
# 2. Detect Aliyun OAuth page
# 3. Enter phone number
# 4. Request SMS code
# 5. Prompt you to enter SMS code
# 6. Submit and verify login
# 7. Save screenshots and report
```

## Sources

- [Alibaba Cloud SMS API](https://help.aliyun.com/zh/sms/getting-started/use-sms-api)
- [SMSPVA API](https://smspva.com/)
