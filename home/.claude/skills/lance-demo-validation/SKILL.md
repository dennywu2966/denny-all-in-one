---
name: lance-demo-validation
description: Automated end-to-end validation for the Lance Vector Plugin Demo (es-lance-demo). Use this when you need to validate API endpoints, UI features, or run regression tests after making changes to the demo application. Runs prerequisite checks, service startup, API tests, and UI smoke tests with Playwright MCP.
---

# Lance Demo Validation

## Overview

Comprehensive automated validation for the Lance Vector Plugin Demo - a Next.js application showcasing Elasticsearch's Lance Vector Plugin integration with Alibaba Cloud OSS storage. This skill provides end-to-end testing of all core features including dataset management, kNN search, hybrid search, and interactive UI features.

**When to use this skill:**
- After making changes to the es-lance-demo codebase
- Before deploying or committing changes
- When troubleshooting issues with vector search or OSS integration
- For regression testing of the demo application
- To verify service health (Elasticsearch, Next.js, OSS connectivity)

## Quick Start

```bash
# Run full validation (API + UI tests)
python ~/.claude/skills/lance-demo-validation/scripts/validate_es_lance_demo.py --full

# Quick smoke tests (homepage + basic API)
python ~/.claude/skills/lance-demo-validation/scripts/validate_es_lance_demo.py --quick

# API tests only
python ~/.claude/skills/lance-demo-validation/scripts/validate_es_lance_demo.py --api-only

# UI tests only (requires Playwright MCP)
python ~/.claude/skills/lance-demo-validation/scripts/validate_es_lance_demo.py --ui-only
```

## Validation Modes

### Full Validation (`--full`)
Runs comprehensive tests including:
1. Prerequisite checks (Node.js, Python deps, OSS credentials, ES distribution)
2. Service startup (Elasticsearch + Next.js)
3. API endpoint tests (list datasets, fetch documents, kNN search, hybrid search)
4. UI smoke tests (homepage load, dataset refresh, interactive features)

**Time:** ~3-5 minutes

### Quick Smoke Tests (`--quick`)
Fast validation of critical functionality:
1. Prerequisite checks
2. Service health check
3. List datasets API
4. kNN Search API

**Time:** ~1 minute

### API-Only Tests (`--api-only`)
Tests all API endpoints without UI validation:
1. `/api/vectors/list` - Dataset listing
2. `/api/vectors/documents` - Document fetch
3. `/api/search` - kNN vector search
4. `/api/search/hybrid` - Hybrid text+vector search

**Time:** ~2 minutes

### UI-Only Tests (`--ui-only`)
Validates UI features using Playwright MCP:
1. Homepage load
2. Dataset refresh
3. Interactive features (if available)

**Time:** ~2 minutes

## Prerequisites

The validation script checks for:

1. **Node.js v18+** - Required for Next.js
2. **Python dependencies** - numpy, lance, pyarrow
3. **OSS credentials** - `~/.oss/credentials.json` with access_key_id and access_key_secret
4. **Elasticsearch distribution** - `../es-9.2.4-plugins/build/distribution/local/elasticsearch-9.2.4-SNAPSHOT`

### Manual Prerequisites Check

```bash
# Check Node.js
node --version  # Should be v18+

# Check Python deps
python3 -c "import numpy, lance, pyarrow; print('OK')"

# Check OSS credentials
cat ~/.oss/credentials.json

# Check ES distribution
ls ../es-9.2.4-plugins/build/distribution/local/
```

## Exit Codes

- `0` - All tests passed
- `1` - Some tests failed
- `2` - Prerequisites not met

## Service Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     es-lance-demo                          │
│                  (Next.js on :3000)                        │
├─────────────────────────────────────────────────────────────┤
│  API Endpoints Tested:                                     │
│  - /api/vectors/list        - List OSS datasets            │
│  - /api/vectors/documents   - Fetch document data          │
│  - /api/search              - kNN vector search            │
│  - /api/search/hybrid       - Hybrid search                │
└─────────────────────────────────────────────────────────────┘
                          │
         ┌─────────────────────────────────────────┐
         │  Alibaba Cloud OSS                          │
         │  └── datasets/*.lance                      │
         └─────────────────────────────────────────┘
                          │
         ┌─────────────────────────────────────────┐
         │  Elasticsearch (with Lance Vector Plugin)  │
         │  └── lance-validation-test index           │
         └─────────────────────────────────────────┘
```

## Troubleshooting

### Prerequisites Not Met

**Node.js v18+ not found**
```bash
# Install Node.js v18+
# Ubuntu/Debian:
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

**Python deps missing**
```bash
python3 -m pip install numpy lance pyarrow --user
```

**OSS credentials not found**
```bash
# Create credentials file
cat > ~/.oss/credentials.json << 'EOF'
{
  "access_key_id": "YOUR_KEY",
  "access_key_secret": "YOUR_SECRET",
  "endpoint": "oss-ap-southeast-1.aliyuncs.com",
  "region": "ap-southeast-1",
  "bucket_name": "denny-test-lance"
}
EOF
```

**ES distribution not found**
```bash
# Ensure ES is built at the expected path
ls ../es-9.2.4-plugins/build/distribution/local/
```

### Service Startup Issues

**Elasticsearch not responding**
```bash
# Check ES health
curl -s -k -u elastic:Summer11 https://127.0.0.1:9200/_cluster/health

# Restart ES if needed
cd ../es-9.2.4-plugins/build/distribution/local/elasticsearch-9.2.4-SNAPSHOT
kill $(cat elasticsearch.pid 2>/dev/null)
./bin/elasticsearch -d -p elasticsearch.pid
```

**Next.js port 3000 in use**
```bash
fuser -k 3000/tcp
cd /home/denny/projects/es-lance-demo
npm run dev
```

### API Test Failures

**OSS credentials error**
```bash
# Verify credentials file is valid
cat ~/.oss/credentials.json

# Restart Next.js to reload credentials
fuser -k 3000/tcp && cd /home/denny/projects/es-lance-demo && npm run dev
```

**"require accessKeyId, accessKeySecret"**
- This should be fixed with lazy initialization in `lib/oss-client.ts`
- If persists, check that `getOSSConfig()` is exported and used in API routes

**Wrong OSS region error**
- The bucket `denny-test-lance` is in Singapore region (`oss-ap-southeast-1`)
- Verify `lib/oss-client.ts` uses correct region

## Known Issues

### kNN Search / SAMPLE API Python Credentials
**Status:** FIXED

The Python scripts spawned by Node.js `exec()` don't inherit environment variables. Fixed by:
1. Importing `getOSSConfig()` in API routes
2. Passing OSS credentials via explicit environment variables
3. Using `os.environ.get()` with defaults in Python scripts

### Generate & Upload Dataset Limit
**Status:** DESIGN LIMITATION

UI enforces single dataset limit to avoid OSS clutter. Delete existing dataset before generating new one.

## Resources

### scripts/validate_es_lance_demo.py
Main validation script with:
- `PrerequisiteChecker` - Validates system requirements
- `ServiceManager` - Manages ES and Next.js startup
- `APIValidator` - Tests all API endpoints
- `MCPPlaywrightValidator` - UI tests using Playwright MCP (placeholder)

### /home/denny/projects/es-lance-demo/reg_validation_guide.md
Comprehensive validation guide with detailed test procedures, API examples, and troubleshooting steps.

## Integration with Claude Code

This skill is designed to be invoked via natural language:

- "Run lance demo validation"
- "Validate the es-lance-demo application"
- "Run regression tests for the Lance demo"
- "Check if the Lance Vector Plugin demo is working"

Claude Code will automatically invoke the appropriate validation mode based on context.
