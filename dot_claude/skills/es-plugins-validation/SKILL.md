---
name: es-plugins-validation
description: End-to-end regression validation for Elasticsearch plugins (Lance Vector and Cloud IAM). Use when validating changes to prevent regressions, after modifying plugin code, before committing or creating PR, when user asks to validate test or regression test the plugins, or any mention of lance-vector or cloud-iam validation. Provides automated test scripts covering 75 test cases across P0/P1/P2 priorities including kNN search, OSS integration, memory leaks, authentication, role mapping, and edge cases.
---

# ES Plugins Regression Validation

## Quick Start

Run P0 critical tests:
```bash
./project_starter.sh -d && bash .claude/skills/es-plugins-validation/scripts/run_p0.sh
```

## Environment

| Component | Value |
|-----------|-------|
| ES Distribution | `build/distribution/local/elasticsearch-9.2.4-SNAPSHOT` |
| OSS Bucket | `denny-test-lance` |
| OSS Credentials | `~/.oss/credentials.json` |
| Startup Script | `./project_starter.sh` |
| Basic Auth | `elastic / Summer11` |

## Critical Regressions (P0)

| ID | Description | Method |
|----|-------------|--------|
| R1 | Zero-score bug | All `hits._score > 0` |
| R2 | Memory leaks | Heap growth < 30% |
| R3 | OSS env vars | Set before ES starts |
| R4 | Arrow types | `pa.string()` for _id |

## Test Scripts

### `run_p0.sh` - Critical Tests
Runs 21 P0 tests (blocking regressions). Use after any code change.

### `run_p1.sh` - High Priority Tests
Runs 38 P1 tests (major functionality). Run daily or per PR.

### `run_all.sh` - Full Regression
Runs all 75 tests. Run weekly or pre-release.

### `test_memory.sh` - Memory Leak Detection
Monitors heap during 1000 searches.

### `create_test_data.py` - Generate Lance Datasets
Creates test data in OSS bucket.

## Test Coverage Summary

| Category | Tests | P0 | P1 | P2 |
|----------|-------|----|----|-----|
| Lance Vector (LV) | 32 | 10 | 14 | 8 |
| Cloud IAM (CI) | 26 | 6 | 14 | 6 |
| Integration (INT) | 7 | 3 | 3 | 1 |
| Configuration (CFG) | 5 | 1 | 2 | 2 |
| Error Handling (ERR) | 5 | 1 | 3 | 1 |

**Total: 75 tests** (21 P0, 38 P1, 16 P2)

## Sync with Validation Guide

This skill is generated from `reg_validation_guide.md` (OFFICIAL guide). To update:

1. Edit `reg_validation_guide.md`
2. Run `python3 .claude/skills/es-plugins-validation/scripts/sync_from_plan.py`

## Detailed Test References

- [Lance Vector Tests](references/lance-vector-tests.md)
- [Cloud IAM Tests](references/cloud-iam-tests.md)
- [Integration Tests](references/integration-tests.md)
