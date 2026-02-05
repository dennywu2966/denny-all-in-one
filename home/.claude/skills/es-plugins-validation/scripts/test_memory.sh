#!/bin/bash
# Memory leak detection test
ITERATIONS=${1:-100}
MAX_GROWTH=${2:-30}

ES_PORT=9200
ES_USER="elastic"
ES_PASS="Summer11"

HEAP_BEFORE=$(curl -sk -u "$ES_USER:$ES_PASS" "https://127.0.0.1:$ES_PORT/_cat/nodes?h=jvm.heap.used_percent" | tr -d ' ')

for i in $(seq 1 $ITERATIONS); do
    curl -sk -u "$ES_USER:$ES_PASS" -X POST "https://127.0.0.1:$ES_PORT/test/_search" \
        -H 'Content-Type: application/json' -d '{
        "query": {"lance_vector": {"field": "embedding", "query_vector": [0.1,0.2,0.3],
        "k": 10, "dataset_uri": "oss://denny-test-lance/test.lance"}}}' > /dev/null 2>&1
done

HEAP_AFTER=$(curl -sk -u "$ES_USER:$ES_PASS" "https://127.0.0.1:$ES_PORT/_cat/nodes?h=jvm.heap.used_percent" | tr -d ' ')
GROWTH=$((HEAP_AFTER - HEAP_BEFORE))

if [ $GROWTH -lt $MAX_GROWTH ]; then
    echo "  Heap grew ${GROWTH}% (< ${MAX_GROWTH}%)"
    exit 0
else
    echo "  Heap grew ${GROWTH}% (>= ${MAX_GROWTH}%)"
    exit 1
fi
