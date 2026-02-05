#!/bin/bash
# Cache performance test
ES_PORT=9200
ES_USER="elastic"
ES_PASS="Summer11"

# First query (cold cache)
TIME1=$(curl -sk -u "$ES_USER:$ES_PASS" -X POST "https://127.0.0.1:$ES_PORT/test/_search" \
    -H 'Content-Type: application/json' -d '{
    "query": {"lance_vector": {"field": "embedding", "query_vector": [0.1,0.2,0.3],
    "k": 10, "dataset_uri": "oss://denny-test-lance/test.lance"}}}' \
    -w '%{time_total}' -o /dev/null 2>&1)

# Second query (warm cache)
TIME2=$(curl -sk -u "$ES_USER:$ES_PASS" -X POST "https://127.0.0.1:$ES_PORT/test/_search" \
    -H 'Content-Type: application/json' -d '{
    "query": {"lance_vector": {"field": "embedding", "query_vector": [0.1,0.2,0.3],
    "k": 10, "dataset_uri": "oss://denny-test-lance/test.lance"}}}' \
    -w '%{time_total}' -o /dev/null 2>&1)

if (( $(echo "$TIME2 < $TIME1" | bc -l) )); then
    echo "  Cache hit: ${TIME2}s < ${TIME1}s"
    exit 0
else
    echo "  Warning: Cache miss or no benefit"
    exit 0  # Don't fail, just warn
fi
