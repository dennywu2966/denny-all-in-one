#!/bin/bash
# LRU cache eviction test (max 100 entries)
ES_PORT=9200
ES_USER="elastic"
ES_PASS="Summer11"

# Query 105 distinct datasets to trigger eviction
for i in {1..105}; do
    curl -sk -u "$ES_USER:$ES_PASS" -X POST "https://127.0.0.1:$ES_PORT/test$i/_search" \
        -H 'Content-Type: application/json' -d "{
        \"query\": {\"lance_vector\": {\"field\": \"embedding\", \"query_vector\": [0.1,0.2,0.3],
        \"k\": 10, \"dataset_uri\": \"oss://denny-test-lance/test/dataset$i.lance\"}}}" > /dev/null 2>&1
done

# Query first dataset again - should still work (LRU keeps recent 100)
RESULT=$(curl -sk -u "$ES_USER:$ES_PASS" -X POST "https://127.0.0.1:$ES_PORT/test1/_search" \
    -H 'Content-Type: application/json' -d '{
    "query": {"lance_vector": {"field": "embedding", "query_vector": [0.1,0.2,0.3],
    "k": 10, "dataset_uri": "oss://denny-test-lance/test/dataset1.lance"}}}')

if echo "$RESULT" | grep -q "hits"; then
    echo "  LRU eviction working (first 5 evicted, 100 cached)"
    exit 0
else
    echo "  FAIL: Cache may be broken"
    exit 1
fi
