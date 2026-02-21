---
name: oauth-sms-validation
description: OAuth login validation with two methods - Direct (manual browser, recommended) and Automated (Playwright). Direct method bypasses captcha/automation detection by having user complete login manually then testing callback. Automated method uses Playwright but may fail on captcha. Handles Aliyun RAM OAuth with SMS/captcha verification. Use for testing OAuth 2.0/2.1 flows with Kibana or web apps.
---

# OAuth SMS Validation

Validates OAuth login flows with support for SMS verification and captcha challenges.

## Two Validation Methods

### Method 1: Direct Validation (Recommended)

**Best for:** Production testing, when captcha/slider verification is present

The user completes login manually in browser (handling captcha/SMS naturally), then the script validates the callback.

```bash
# Run direct validation (recommended)
node ~/.claude/skills/oauth-sms-validation/scripts/validate_oauth_direct.js

# Custom Kibana URL
KIBANA_HOST=47.236.247.55 \
KIBANA_PORT=5601 \
KIBANA_BASE=/kibana \
node ~/.claude/skills/oauth-sms-validation/scripts/validate_oauth_direct.js
```

**How it works:**
1. Script gets OAuth URL from Kibana
2. User opens URL in browser and completes login (handles captcha/SMS)
3. User copies callback URL back to script
4. Script validates the OAuth callback and session creation

**Advantages:**
- ✅ Bypasses captcha/slider verification
- ✅ Handles all security challenges naturally
- ✅ More reliable for production testing
- ✅ No browser automation dependencies

### Method 2: Automated Validation (Browser Automation)

**Best for:** CI/CD when captcha is disabled, development environments

Uses Playwright to fully automate the login flow.

```bash
# Run automated validation (may fail on captcha)
node ~/.claude/skills/oauth-sms-validation/scripts/validate_oauth_sms.js

# Custom URL and phone number
KIBANA_URL=http://myapp.example.com:8080 \
MOBILE=1234567890 \
node ~/.claude/skills/oauth-sms-validation/scripts/validate_oauth_sms.js

# Run with visible browser (for debugging)
HEADLESS=false \
node ~/.claude/skills/oauth-sms-validation/scripts/validate_oauth_sms.js
```

**Limitations:**
- ❌ Cannot bypass captcha/slider verification
- ❌ May be detected by anti-bot measures
- ⚠️ Requires manual intervention for captcha

## Configuration

Environment variables:

| Variable | Default | Description |
|-----------|---------|-------------|
| `KIBANA_URL` | `http://localhost:5601` | Target web application URL |
| `MOBILE` | `18972952966` | Mobile phone number for SMS |
| `HEADLESS` | `true` | Run in headless mode (set `false` for visible browser) |

## How It Works

The script automates the complete OAuth flow:

1. **Get OAuth URL** - Fetches authorization URL from Kibana's OAuth endpoint
2. **Navigate to login** - Opens Aliyun OAuth page in Playwright browser
3. **Enter mobile number** - Fills in phone/email input and submits
4. **Handle authentication** - Supports both:
   - Password-based login
   - SMS verification code (prompts user for code)
5. **Verify success** - Confirms successful redirect back to application

## SMS Verification Flow

When SMS verification is required:

1. Script waits for Aliyun to send SMS to configured phone number
2. User is prompted: `Please enter the SMS verification code:`
3. User enters code from their phone
4. Script submits code and continues with login

## Success Criteria

Validation is successful when:
- User is redirected back to target application (localhost:5601)
- Kibana UI elements are detected (Discover, Dashboards, etc.)
- Screenshot saved to `/tmp/oauth-success.png`

## Failure Diagnostics

Screenshots are saved for debugging:
- `/tmp/oauth-no-input.png` - No password/SMS input found
- `/tmp/oauth-error.png` - Redirect or login error
- `/tmp/oauth-failure.png` - Login verification failed

## Troubleshooting

**"Could not find mobile/email input"**
- Aliyun login page may have changed
- Page may not have fully loaded
- Try running with `HEADLESS=false` to see what's happening

**"No SMS code provided"**
- Script timed out waiting for user input
- Enter code when prompted and press Enter

**"Failed to redirect"**
- OAuth credentials may be incorrect
- Check ES logs for authentication errors
- Verify role mappings exist in Elasticsearch

**"Login verification failed"**
- Kibana UI may be loading slowly (increase wait time)
- Check browser screenshot for diagnostic information

**Slider/Captcha Verification Required**
- Aliyun may present a slider verification (captcha) after password entry
- This is a security measure that is difficult to automate
- **Option 1**: Run with `HEADLESS=false` and complete the slider manually
- **Option 2**: Use a different account/location that doesn't trigger captcha
- **Option 3**: Manual testing - open browser and complete the flow manually

**Note on Aliyun Security**
Aliyun's login system includes several security layers:
1. Username/email entry
2. Password entry
3. **Slider verification** (anti-bot measure) - may appear randomly
4. SMS verification (for "unusual logon" detection)

The automated script can handle steps 1, 2, and 4, but step 3 (slider) typically requires manual interaction or specialized captcha-solving services.
