# Validate E2E

Validates end-to-end authentication flows for web applications, with special support for Aliyun OAuth + Kibana integration.

**When to use this skill:**
- Need to test OAuth login flows end-to-end
- Validate authentication between Kibana and Elasticsearch
- Test role mappings and user permissions
- Verify Cloud IAM realm integration
- Any web application E2E testing that requires phone/SMS authentication

**What this skill does:**
1. Checks ES health and role mappings
2. Starts Kibana if needed
3. Automates browser-based OAuth login flow
4. Validates authentication with ES Cloud IAM realm
5. Tests basic application features
6. Generates validation report with screenshots

**Parameters:**
- `url` (optional): Kibana URL (default: http://localhost:5601)
- `phone` (optional): Phone number for SMS (default: from config or prompt)
- `headless` (optional): Run in headless mode (default: true)
- `keep_browser` (optional): Keep browser open for inspection (default: false)
- `es_url` (optional): Elasticsearch URL (default: http://localhost:9200)
- `es_user` (optional): ES username (default: elastic)
- `es_pass` (optional): ES password (will prompt if needed)

**Usage Examples:**
```
"Validate the Aliyun OAuth E2E flow for Kibana"
"Test the login flow with phone number 18972952966"
"Do E2E validation and keep browser open for debugging"
```

**Implementation:**
This skill runs a Playwright-based validation script located at:
`~/validate_oauth_e2e_complete.js`

The script:
- Uses Playwright to automate browser interactions
- Handles SMS code input (requires manual entry)
- Takes screenshots at key steps
- Generates JSON validation report
- Creates screenshot directory for debugging

**Requirements:**
- Node.js 22.21.1
- Playwright npm package
- ES running on localhost:9200
- Kibana accessible
- Internet connection for Aliyun OAuth

**Output:**
- Validation report (JSON) with test results
- Screenshots (PNG) for each step
- Console log with progress updates
- Exit code 0 for success, 1 for failure

**Troubleshooting:**
- If browser fails to start, check if Node version is 22.21.1
- If ES connection fails, verify ES is running and credentials are correct
- If Kibana won't start, check port 5601 is available
- If OAuth page doesn't load, check internet connection and Aliyun service status
