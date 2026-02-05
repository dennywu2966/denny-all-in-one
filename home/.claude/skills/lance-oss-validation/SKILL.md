---
name: lance-oss-validation
description: "Comprehensive validation workflow for Lance Vector plugin integration with Elasticsearch using OSS storage. Validates build, local search, OSS integration, stress testing, and error handling. Use when: building or testing Lance Vector plugin, validating kNN search with local Lance datasets, testing OSS storage integration with Alibaba Cloud OSS, running stress tests or benchmarks, or verifying error handling"
---

# Lance OSS Validation Skill

Validates Lance Vector plugin integration with Elasticsearch using OSS storage. This skill automates the complete validation workflow from build verification through OSS integration testing.

## Validation Workflow Overview

The validation process follows these phases:

1. **Build Verification** - Verify plugin builds correctly with all dependencies
2. **Local Search Testing** - Validate kNN search with local Lance datasets
3. **OSS Integration Testing** - Validate kNN search with OSS-stored datasets
4. **Stress Testing** - Validate stability under load
5. **Error Handling** - Validate proper error messages

## Quick Start

### Environment Setup

Set required environment variables:

```bash
# ES project location
export ES_PROJECT_DIR=~/projects/es-lance-claude-glm

# OSS credentials (for OSS testing only)
export OSS_ACCESS_KEY_ID=your_access_key
export OSS_ACCESS_KEY_SECRET=your_secret_key
export OSS_ENDPOINT=oss-ap-southeast-1.aliyuncs.com
```

### Validate Build

```bash
python scripts/validate_build.py
```

**Success Criteria:**
- Plugin builds without errors
- Plugin zip file created (~280MB with Lance/Arrow dependencies)
- All required dependencies included

### Validate Local Search

**Prerequisites:**
- Elasticsearch running on localhost:9200 with Lance plugin
- Test dataset created at `/tmp/test-vectors.lance`

**Create test dataset:**

```bash
# Using the plugin's built-in script
cd $ES_PROJECT_DIR
python plugins/lance-vector/scripts/create_test_dataset.py /tmp/test-vectors.lance
```

**Run local search validation:**

```bash
python scripts/validate_local_search.py
```

**Success Criteria:**
- Index created with Lance vector mapping
- Metadata documents indexed
- kNN search returns 5 results with scores > 0.0
- Search latency < 5 seconds (first search)
- Stress test completes 20 searches successfully

### Validate OSS Storage

**Prerequisites:**
- Test dataset uploaded to OSS
- Elasticsearch running with OSS environment variables

**Upload dataset to OSS:**

```bash
cd $ES_PROJECT_DIR

# Create and upload in one step
python plugins/lance-vector/scripts/create_test_dataset.py /tmp/oss-vectors.lance \
  --upload oss://your-bucket/test-data/oss-vectors.lance
```

**Start Elasticsearch with OSS credentials:**

```bash
cd build/distribution/local/elasticsearch-*

# Set OSS environment variables
export OSS_ENDPOINT="oss-ap-southeast-1.aliyuncs.com"
export OSS_ACCESS_KEY_ID="your_key"
export OSS_ACCESS_KEY_SECRET="your_secret"

# Start ES
./bin/elasticsearch -d -p elasticsearch.pid
```

**Run OSS validation:**

```bash
# Full validation with ES restart check
python scripts/validate_oss_storage.py --oss-uri oss://your-bucket/test-data/oss-vectors.lance

# Skip restart if ES already running with OSS env vars
python scripts/validate_oss_storage.py \
  --oss-uri oss://your-bucket/test-data/oss-vectors.lance \
  --skip-restart
```

**Success Criteria:**
- OSS credentials configured
- Index created with OSS URI
- kNN search retrieves from OSS successfully
- First search latency < 10 seconds (dataset loading from OSS)
- Subsequent searches < 500ms (cached)

## Phase-by-Phase Validation

### Phase 1: Build Verification

**Purpose:** Verify plugin builds correctly with all dependencies.

**Script:** `scripts/validate_build.py`

**What it checks:**
- Gradle build succeeds: `./gradlew :plugins:lance-vector:assemble`
- Plugin zip file exists in `plugins/lance-vector/build/distributions/`
- File size ~280MB (includes Lance/Arrow native libraries)

**Common Issues:**
- **Build fails:** Check Java version (requires JDK 21)
- **Zip too small:** Dependencies not bundled, check Gradle configuration
- **Missing native libraries:** Lance/Arrow dependencies not resolved

### Phase 2: Local Search Testing

**Purpose:** Validate kNN search works with local Lance dataset (baseline).

**Script:** `scripts/validate_local_search.py`

**What it validates:**
1. **Dataset creation** - Lance dataset with IVF-PQ index
2. **Index mapping** - Lance vector field with external storage
3. **Metadata indexing** - Documents with IDs matching Lance dataset
4. **kNN search** - Returns correct results with scores > 0
5. **Stability** - 20 consecutive searches without errors

**Dataset Schema Requirements:**

CRITICAL: Use `pa.string()` NOT `pa.large_string()` for Java compatibility:

```python
schema = pa.schema([
    pa.field('_id', pa.string()),        # Regular string for Java
    pa.field('vector', pa.list_(pa.float32(), 128)),
    pa.field('category', pa.string())
])
```

**Index Mapping Example:**

```json
{
  "mappings": {
    "properties": {
      "embedding": {
        "type": "lance_vector",
        "dims": 128,
        "similarity": "cosine",
        "storage": {
          "type": "external",
          "uri": "file:///tmp/test-vectors.lance",
          "lance_id_column": "_id",
          "lance_vector_column": "vector",
          "read_only": true
        }
      }
    }
  }
}
```

**Common Issues:**

- **Path Not Found:** Use absolute paths with three slashes: `file:///tmp/...`
- **Zero scores:** Scoring conversion bug, all results show score=0.0
- **Dimension mismatch:** Query vector dimensions don't match dataset
- **ClassCastException:** Used `pa.large_string()` instead of `pa.string()`

### Phase 3: OSS Integration Testing

**Purpose:** Validate kNN search works with OSS-stored Lance dataset.

**Script:** `scripts/validate_oss_storage.py`

**What it validates:**
1. **OSS credentials** - Environment variables configured
2. **ES startup** - ES running with OSS environment variables
3. **OSS index** - Index created with `oss://` URI
4. **OSS search** - kNN search retrieves from OSS
5. **Performance** - Acceptable latency with OSS storage

**OSS Environment Variables:**

```bash
export OSS_ENDPOINT="oss-ap-southeast-1.aliyuncs.com"
export OSS_ACCESS_KEY_ID="your_access_key"
export OSS_ACCESS_KEY_SECRET="your_secret_key"
```

**CRITICAL:** Lance Rust native library reads `OSS_ENDPOINT` from process environment, NOT Java's `System.getenv()`. Set via shell before starting ES.

**OSS URI Format:**

```
oss://bucket-name/path/to/dataset.lance
```

**Common Issues:**

- **OSS endpoint required:** Lance Rust reads `OSS_ENDPOINT` from process environment
- **Authentication errors:** Verify credentials and bucket permissions
- **Slow first search:** Expected - Lance loads dataset from OSS on first access
- **Proxy conflicts:** Clear proxy environment variables before uploading

### Phase 4: Stress Testing

**Purpose:** Validate memory management and stability under load.

**Included in:** `scripts/validate_local_search.py` and `validate_oss_storage.py`

**What it tests:**
- 20 consecutive kNN searches
- Memory usage stability
- Latency patterns (first search vs. cached)
- Error handling under load

**Expected Results:**

| Metric | Local Storage | OSS Storage |
|--------|---------------|-------------|
| First search | 1-3s | 2-10s |
| Subsequent searches | 20-100ms | 50-100ms |
| Memory overhead | ~256MB | ~256MB |
| Success rate | 100% | 100% |

**Common Issues:**

- **Increasing latency:** Memory leak or dataset not releasing resources
- **OutOfMemoryError:** Arrow allocator limit reached
- **Crashes:** Native library issues or JVM heap too small

### Phase 5: Error Handling

**Purpose:** Verify proper error messages for common failure modes.

**Manual Validation Tests:**

```bash
# Test 1: Invalid dimensions
curl -X POST http://localhost:9200/lance-test/_search \
  -H 'Content-Type: application/json' -d '{
  "knn": {
    "field": "embedding",
    "query_vector": [0.1, 0.2],
    "k": 5
  }
}'
# Expected: Dimension mismatch error

# Test 2: Non-existent dataset
curl -X PUT http://localhost:9200/lance-bad -H 'Content-Type: application/json' -d '{
  "mappings": {
    "properties": {
      "embedding": {
        "type": "lance_vector",
        "storage": {
          "uri": "file:///nonexistent/vectors.lance"
        }
      }
    }
  }
}'
# Expected: Dataset not found error

# Test 3: Invalid OSS credentials
# Create index with invalid credentials, expect authentication error
```

**Expected Behavior:**
- Clear, actionable error messages
- No ES crashes or restarts
- Error responses include relevant details

## Performance Baselines

Expected performance on 300 vectors, 128 dimensions, IVF-PQ indexed:

| Operation | Expected Latency | Notes |
|-----------|------------------|-------|
| Dataset creation | 5-10s | IVF-PQ index build |
| First search (local) | 1-3s | Dataset loading |
| First search (OSS) | 2-10s | Dataset loading from OSS |
| Subsequent searches | 20-100ms | Dataset cached |
| Memory overhead | ~256MB | Arrow allocator limit |

## Troubleshooting

### Issue: "Failed to initialize MemoryUtil"

**Symptom:** Error about Arrow MemoryUtil on ES startup

**Solution:** Add JVM option for Arrow memory access:

```bash
echo "--add-opens=java.base/java.nio=ALL-UNNAMED" \
  > build/distribution/local/elasticsearch-*/config/jvm.options.d/lance-arrow.options
```

### Issue: "ClassCastException: LargeVarCharVector"

**Symptom:** Java class cast exception when reading Lance dataset

**Solution:** Use `pa.string()` NOT `pa.large_string()` in Python schema:

```python
# WRONG
pa.field('_id', pa.large_string())

# CORRECT
pa.field('_id', pa.string())
```

### Issue: "Path Not Found: tmp/demo-vectors.lance"

**Symptom:** Dataset path not found error

**Solution:** Use absolute paths with three slashes for file:// URIs:

```bash
# WRONG
"uri": "file://tmp/demo-vectors.lance"

# CORRECT
"uri": "file:///tmp/demo-vectors.lance"
```

### Issue: All scores = 0.0

**Symptom:** kNN search returns results but all scores are 0.0

**Solution:** Scoring conversion bug in plugin. Distance-to-score conversion missing:

```java
// Conversion formula (should be in LanceKnnQuery)
float score = 1.0f / (1.0f + distance);
```

### Issue: Slow first search (>10s)

**Symptom:** First kNN search takes very long

**Solution:** This is expected behavior - Lance loads and scans dataset on first access. Subsequent searches should be much faster (20-100ms).

### Issue: OSS authentication errors

**Symptom:** "Authentication failed" or "Access denied" errors

**Solution:** Verify OSS credentials and bucket permissions:

1. Check `OSS_ACCESS_KEY_ID` and `OSS_ACCESS_KEY_SECRET` are correct
2. Verify bucket exists and is accessible
3. Check endpoint matches bucket region
4. Verify IAM permissions if using role-based access

## Validation Checklist

Use this checklist to track validation progress:

### Build & Startup
- [ ] Plugin builds without errors
- [ ] JVM options configured for Arrow
- [ ] ES starts successfully
- [ ] Lance plugin loaded

### Local Storage
- [ ] Lance dataset created (300 vectors, 128 dims)
- [ ] IVF-PQ index created
- [ ] Index mapping created
- [ ] Metadata documents indexed
- [ ] kNN search returns results
- [ ] All results have scores > 0.0
- [ ] Path handling correct (file:///tmp/...)

### OSS Storage
- [ ] Dataset uploaded to OSS
- [ ] OSS credentials configured via environment variables
- [ ] Index mapping with OSS storage
- [ ] kNN search retrieves from OSS
- [ ] No authentication errors
- [ ] Performance acceptable (first search <10s, cached <500ms)

### Stress Testing
- [ ] 20 consecutive searches successful
- [ ] Memory usage stable (~256MB)
- [ ] Latency stabilizes after first search
- [ ] No crashes or OOM errors

### Error Handling
- [ ] Dimension mismatch: clear error
- [ ] Missing dataset: clear error
- [ ] Invalid credentials: clear error
- [ ] No ES crashes from bad inputs

## Advanced Usage

### Custom Dataset Parameters

Create dataset with custom parameters:

```bash
python plugins/lance-vector/scripts/create_test_dataset.py \
  /tmp/custom-vectors.lance \
  --n-vectors 1000 \
  --dims 256
```

### Java Integration Tests

Run the Java integration test suite:

```bash
cd $ES_PROJECT_DIR

# Local filesystem test
./gradlew :plugins:lance-vector:integTest \
  -Dtests.class="org.elasticsearch.plugin.lance.LanceVectorOssIntegrationTests#testLocalLanceDatasetWithIvfPqIndex" \
  -Dtest.dataset.path=/tmp/test-vectors.lance

# OSS test (requires OSS credentials)
export OSS_TEST_URI=oss://your-bucket/test-data/oss-vectors.lance
./gradlew :plugins:lance-vector:integTest \
  -Dtests.class="org.elasticsearch.plugin.lance.LanceVectorOssIntegrationTests#testElasticsearchKnnSearchWithOssUri"
```

### Memory Profiling

Profile Arrow memory usage during stress test:

```bash
# Start ES with JVM profiling
./bin/elasticsearch -d -p elasticsearch.pid

# Run stress test
python scripts/validate_local_search.py

# Check heap usage
jmap -heap $(cat elasticsearch.pid) | grep -E "Heap Memory|Max Heap"
```

## Scripts Reference

### `scripts/validate_build.py`

Validates plugin build process.

**Environment Variables:**
- `ES_PROJECT_DIR` - Path to ES project (default: `~/projects/es-lance-claude-glm`)

**Exit Codes:**
- 0: All checks passed
- 1: One or more checks failed

### `scripts/validate_local_search.py`

Validates kNN search with local Lance dataset.

**Prerequisites:**
- ES running on localhost:9200
- Dataset at `/tmp/test-vectors.lance`

**What it does:**
1. Creates index with Lance vector mapping
2. Indexes 100 metadata documents
3. Executes kNN search
4. Runs 20-search stress test
5. Reports latency statistics

**Exit Codes:**
- 0: All checks passed
- 1: One or more checks failed

### `scripts/validate_oss_storage.py`

Validates OSS storage integration.

**Arguments:**
- `--oss-uri` - OSS URI to test dataset (required)
- `--skip-restart` - Skip ES restart check (optional)
- `--no-benchmark` - Skip benchmark tests (optional)

**Environment Variables:**
- `OSS_ACCESS_KEY_ID` - OSS access key
- `OSS_ACCESS_KEY_SECRET` - OSS secret key
- `OSS_ENDPOINT` - OSS endpoint
- `ES_DISTRIBUTION_DIR` - Path to ES distribution (optional)

**What it does:**
1. Checks OSS credentials
2. Verifies ES running with OSS env vars
3. Creates index with OSS URI
4. Indexes metadata documents
5. Executes kNN search
6. Runs 10-search benchmark
7. Reports performance statistics

**Exit Codes:**
- 0: All checks passed
- 1: One or more checks failed

## Related Documentation

- **Validation Guide:** `$ES_PROJECT_DIR/VALIDATION_GUIDE.md` - Detailed validation procedures
- **Plugin Tests:** `$ES_PROJECT_DIR/plugins/lance-vector/src/test/java/.../LanceVectorOssIntegrationTests.java` - Java integration tests
- **Dataset Creation:** `$ES_PROJECT_DIR/plugins/lance-vector/scripts/create_test_dataset.py` - Test dataset generator
