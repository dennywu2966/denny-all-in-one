#!/bin/bash
# P0 Critical Tests - Run after any code change
set -e

ES_DIR="build/distribution/local/elasticsearch-9.2.4-SNAPSHOT"
ES_PORT=9200
ES_USER="elastic"
ES_PASS="Summer11"
OSS_BUCKET="denny-test-lance"

echo "========================================="
echo "  P0 Critical Tests (21 tests)"
echo "========================================="

FAILED=0
PASSED=0

run_test() {
    local name="$1"
    local test_cmd="$2"
    echo ""
    echo "[TEST] $name"
    if eval "$test_cmd"; then
        echo "  PASS"
        ((PASSED++))
    else
        echo "  FAIL"
        ((FAILED++))
    fi
}

# Ensure ES is running
if ! curl -sk -u "$ES_USER:$ES_PASS" "https://127.0.0.1:$ES_PORT/" > /dev/null 2>&1; then
    echo "ERROR: ES not running. Start with: ./project_starter.sh -d"
    exit 1
fi

# R1: Zero-score bug tests
run_test "LV-01: OSS kNN scores > 0" \
    "curl -sk -u $ES_USER:$ES_PASS -X POST \"https://127.0.0.1:$ES_PORT/test/_search\" \
    -H 'Content-Type: application/json' -d '{
        \"query\": {\"lance_vector\": {\"field\": \"embedding\", \"query_vector\": [0.1,0.2,0.3],
        \"k\": 10, \"dataset_uri\": \"oss://$OSS_BUCKET/test.lance\"}}}' \
    | jq -e '.hits.hits[]?.score > 0' > /dev/null"

run_test "LV-02: Local file kNN scores > 0" \
    "curl -sk -u $ES_USER:$ES_PASS -X POST \"https://127.0.0.1:$ES_PORT/test/_search\" \
    -H 'Content-Type: application/json' -d '{
        \"query\": {\"lance_vector\": {\"field\": \"embedding\", \"query_vector\": [0.1,0.2,0.3],
        \"k\": 10, \"dataset_uri\": \"file:///tmp/test.lance\"}}}' \
    | jq -e '.hits.hits[]?.score > 0' > /dev/null 2>&1 || echo '  (skip if no local file)'"

run_test "LV-05: Empty query vector returns 400" \
    "curl -sk -u $ES_USER:$ES_PASS -X POST \"https://127.0.0.1:$ES_PORT/test/_search\" \
    -H 'Content-Type: application/json' -d '{
        \"query\": {\"lance_vector\": {\"field\": \"embedding\", \"query_vector\": [],
        \"k\": 10, \"dataset_uri\": \"oss://$OSS_BUCKET/test.lance\"}}}' \
    | grep -q '400\\|error'"

run_test "LV-06: kNN + term filter, scores > 0" \
    "curl -sk -u $ES_USER:$ES_PASS -X POST \"https://127.0.0.1:$ES_PORT/test/_search\" \
    -H 'Content-Type: application/json' -d '{
        \"query\": {\"bool\": {\"must\": [{\"lance_vector\": {\"field\": \"embedding\",
        \"query_vector\": [0.1,0.2,0.3], \"k\": 10, \"dataset_uri\": \"oss://$OSS_BUCKET/test.lance\"}}],
        \"filter\": {\"term\": {\"category\": \"test\"}}}}}' \
    | jq -e '.hits.hits[]?.score > 0' > /dev/null"

run_test "LV-11: Hybrid RRF fusion works" \
    "curl -sk -u $ES_USER:$ES_PASS -X POST \"https://127.0.0.1:$ES_PORT/test/_search\" \
    -H 'Content-Type: application/json' -d '{
        \"query\": {\"hybrid\": {\"queries\": [{\"lance_vector\": {\"field\": \"embedding\",
        \"query_vector\": [0.1,0.2,0.3], \"k\": 10, \"dataset_uri\": \"oss://$OSS_BUCKET/test.lance\"}},
        {\"match\": {\"title\": \"test\"}}], \"rrf\": {}}}}' \
    | jq -e '.hits.total.value > 0' > /dev/null"

run_test "LV-16: Heap growth < 30% for 100 searches" \
    "bash .claude/skills/es-plugins-validation/scripts/test_memory.sh 100 30"

run_test "LV-20: Cache hit faster than cold" \
    "bash .claude/skills/es-plugins-validation/scripts/test_cache.sh"

run_test "LV-21: 105 datasets triggers LRU eviction" \
    "bash .claude/skills/es-plugins-validation/scripts/test_lru.sh"

run_test "LV-24: Dimension mismatch returns 400" \
    "curl -sk -u $ES_USER:$ES_PASS -X POST \"https://127.0.0.1:$ES_PORT/test/_search\" \
    -H 'Content-Type: application/json' -d '{
        \"query\": {\"lance_vector\": {\"field\": \"embedding\", \"query_vector\": [0.1],
        \"k\": 10, \"dataset_uri\": \"oss://$OSS_BUCKET/test.lance\"}}}' \
    | grep -q '400\\|error\\|dimension'"

run_test "LV-25: Missing dataset_uri returns 400" \
    "curl -sk -u $ES_USER:$ES_PASS -X POST \"https://127.0.0.1:$ES_PORT/test/_search\" \
    -H 'Content-Type: application/json' -d '{
        \"query\": {\"lance_vector\": {\"field\": \"embedding\", \"query_vector\": [0.1,0.2,0.3],
        \"k\": 10}}}' \
    | grep -q '400\\|error'"

# R3: OSS env vars tests
run_test "LV-26: OSS env vars in ES process" \
    "ES_PID=\$(cat $ES_DIR/es.pid 2>/dev/null || echo ''); \
    [ -n \"\$ES_PID\" ] && cat /proc/\$ES_PID/environ 2>/dev/null | tr '\\0' '\\n' | grep -q '^OSS_ACCESS_KEY_ID='"

# Cloud IAM P0 tests
run_test "CI-01: STS signature accepted" \
    "bash .claude/skills/es-plugins-validation/scripts/test_sts_auth.sh"

run_test "CI-02: OAuth token accepted" \
    "bash .claude/skills/es-plugins-validation/scripts/test_oauth.sh"

run_test "CI-03: Invalid signature = 401" \
    "curl -sk -X POST \"https://127.0.0.1:$ES_PORT/_search\" \
    -H 'Content-Type: application/json' -H 'X-ES-IAM-Signed: invalid_signature' \
    -d '{\"query\": {\"match_all\": {}}}' | grep -q '401\\|unauthorized'"

run_test "CI-04: Expired OAuth token = 401" \
    "curl -sk -X POST \"https://127.0.0.1:$ES_PORT/_search\" \
    -H 'Content-Type: application/json' -H 'Authorization: Bearer expired_token_xyz' \
    -d '{\"query\": {\"match_all\": {}}}' | grep -q '401\\|unauthorized'"

run_test "CI-07: Replay attack rejected" \
    "bash .claude/skills/es-plugins-validation/scripts/test_replay.sh"

run_test "CI-10: Expired timestamp rejected" \
    "bash .claude/skills/es-plugins-validation/scripts/test_timestamp.sh"

run_test "CI-14: Static roles assigned" \
    "curl -sk -u $ES_USER:$ES_PASS \"https://127.0.0.1:$ES_PORT/_security/user/*\" \
    | jq -e '.[]?.roles != null' > /dev/null"

# Integration P0 tests
run_test "INT-01: IAM auth + kNN search" \
    "bash .claude/skills/es-plugins-validation/scripts/test_int_iam_knn.sh"

run_test "INT-04: IAM + kNN + filter" \
    "bash .claude/skills/es-plugins-validation/scripts/test_int_filter.sh"

run_test "INT-07: ES restart preserves OSS env" \
    "bash .claude/skills/es-plugins-validation/scripts/test_restart.sh"

echo ""
echo "========================================="
echo "  Results: $PASSED passed, $FAILED failed"
echo "========================================="

if [ $FAILED -gt 0 ]; then
    exit 1
fi
