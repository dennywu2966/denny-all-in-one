#!/bin/bash
# ES restart preserves OSS env vars test
ES_DIR="build/distribution/local/elasticsearch-9.2.4-SNAPSHOT"
ES_PID=$(cat $ES_DIR/es.pid 2>/dev/null || echo "")

if [ -n "$ES_PID" ]; then
    if cat /proc/$ES_PID/environ 2>/dev/null | tr '\0' '\n' | grep -q '^OSS_ACCESS_KEY_ID='; then
        echo "  OSS env vars present in ES process"
        exit 0
    else
        echo "  FAIL: OSS env vars missing"
        exit 1
    fi
else
    echo "  SKIP: ES not running"
    exit 0
fi
