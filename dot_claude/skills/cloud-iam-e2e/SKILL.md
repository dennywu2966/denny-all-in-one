---
name: cloud-iam-e2e
description: Comprehensive end-to-end validation for Cloud IAM authentication with Elasticsearch and Kibana. Validates Aliyun RAM/IAM credential authentication, role mappings, and browser-based login flows. Use for testing Cloud IAM realm plugin integration, verifying Kibana authentication providers, validating role mapping configurations, running automated UI tests for login flows, and troubleshooting Cloud IAM authentication issues.
---

# Cloud IAM E2E Validation

Validates Cloud IAM authentication for Elasticsearch and Kibana with Aliyun RAM credentials.

## Quick Start

```bash
# Validate both ES and Kibana
export RAM_AK="your-access-key"
export RAM_SK="your-secret-key"
cloud-iam-e2e validate --check-type=both

# Validate only Elasticsearch
cloud-iam-e2e validate --check-type=es

# Validate only Kibana
cloud-iam-e2e validate --check-type=kibana

# Run Playwright browser tests
cloud-iam-e2e test-ui

# Full validation with UI tests
cloud-iam-e2e validate-all
```

## Parameters

All commands accept these parameters (via environment variables or command-line):

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ES_URL` | `http://47.236.247.55:9201` | Elasticsearch URL |
| `KB_URL` | `http://47.236.247.55:5602` | Kibana URL |
| `RAM_AK` | *(required)* | Aliyun Access Key ID |
| `RAM_SK` | *(required)* | Aliyun Access Key Secret |
| `CHECK_TYPE` | `both` | `es`, `kibana`, or `both` |

## Commands

### `validate`

Runs core validation tests (connectivity, authentication, role mappings).

**Usage:**
```bash
cloud-iam-e2e validate [options]
```

**Tests performed:**
1. Elasticsearch connectivity
2. Kibana connectivity (if CHECK_TYPE includes kibana)
3. Signed header generation
4. Elasticsearch Cloud IAM authentication
5. Kibana Cloud IAM provider availability
6. Kibana Cloud IAM login (if CHECK_TYPE includes kibana)
7. Role mapping verification

**Output:**
JSON report with pass/fail status for each test.

### `test-ui`

Runs Playwright browser-based UI tests.

**Usage:**
```bash
cloud-iam-e2e test-ui
```

**Tests performed:**
1. Login page displays Cloud IAM provider
2. Cloud IAM authentication flow
3. Session management
4. User profile display
5. Feature access (Discover, Dashboards)
6. Error handling

**Requirements:**
- Node.js and npm installed
- Playwright browsers installed (`npx playwright install`)

### `validate-all`

Runs both core validation and UI tests.

**Usage:**
```bash
cloud-iam-e2e validate-all
```

## Validation Reports

### Core Validation Report

JSON structure:
```json
{
  "timestamp": "2026-01-24T20:00:00Z",
  "es_url": "http://47.236.247.55:9201",
  "kb_url": "http://47.236.247.55:5602",
  "check_type": "both",
  "tests": [
    {
      "name": "es_running",
      "status": "pass|fail|skip",
      "message": "Description",
      "details": {}
    }
  ],
  "summary": {
    "total": 7,
    "passed": 6,
    "failed": 1,
    "skipped": 0
  }
}
```

### Playwright Report

JSON structure with test suites, specs, and results.

## Troubleshooting

### Common Failures

**`es_running` fails:**
- Verify Elasticsearch is running: `curl $ES_URL/`
- Check firewall rules
- Verify network binding (0.0.0.0 vs 127.0.0.1)

**`kb_running` fails:**
- Verify Kibana is running: `curl $KB_URL/`
- Check Kibana logs for startup errors
- Ensure Elasticsearch is accessible from Kibana

**`generate_signed_header` fails:**
- Verify RAM credentials are valid
- Check Python 3 is installed
- Verify signature script exists

**`es_cloud_iam_auth` fails:**
- Verify Cloud IAM realm is configured in Elasticsearch
- Check realm name matches (default: `iam1`)
- Verify Aliyun STS endpoint is accessible

**`kb_cloud_iam_login` fails:**
- Verify Cloud IAM provider is configured in `kibana.yml`
- Check provider realm name matches ES realm
- Verify Elasticsearch credentials in Kibana config

### Debug Mode

Enable verbose output:
```bash
export DEBUG=1
cloud-iam-e2e validate
```

Save detailed reports:
```bash
export SAVE_REPORT=1
cloud-iam-e2e validate
```

## Integration with CI/CD

Example GitHub Actions workflow:
```yaml
- name: Validate Cloud IAM
  env:
    RAM_AK: ${{ secrets.RAM_AK }}
    RAM_SK: ${{ secrets.RAM_SK }}
    ES_URL: http://elasticsearch:9201
    KB_URL: http://kibana:5602
  run: cloud-iam-e2e validate-all
```

## References

See [references/config.md](references/config.md) for:
- Elasticsearch realm configuration
- Kibana provider configuration
- Role mapping examples
- Common troubleshooting scenarios
