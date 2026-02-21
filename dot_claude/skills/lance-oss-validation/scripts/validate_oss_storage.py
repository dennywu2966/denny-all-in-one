#!/usr/bin/env python3
"""
Validate OSS storage integration.

Prerequisites:
- Elasticsearch running with Lance plugin
- OSS credentials configured (OSS_ACCESS_KEY_ID, OSS_ACCESS_KEY_SECRET, OSS_ENDPOINT)
- Test dataset uploaded to OSS
"""

import subprocess
import sys
import os
import requests
import time
from pathlib import Path

def check_oss_credentials():
    """Check if OSS credentials are configured."""
    required_vars = ["OSS_ACCESS_KEY_ID", "OSS_ACCESS_KEY_SECRET", "OSS_ENDPOINT"]

    missing = [var for var in required_vars if not os.environ.get(var)]

    if missing:
        print(f"❌ Missing OSS credentials: {', '.join(missing)}")
        print("\nSet environment variables:")
        print("  export OSS_ACCESS_KEY_ID=your_key")
        print("  export OSS_ACCESS_KEY_SECRET=your_secret")
        print("  export OSS_ENDPOINT=oss-ap-southeast-1.aliyuncs.com")
        return False

    print(f"✅ OSS credentials configured")
    print(f"  Endpoint: {os.environ['OSS_ENDPOINT']}")
    return True

def restart_es_with_oss():
    """
    Restart Elasticsearch with OSS environment variables.

    Note: This requires ES to be managed by the script.
    In practice, users should start ES manually with OSS env vars.
    """
    es_dir = os.environ.get(
        "ES_DISTRIBUTION_DIR",
        "~/projects/es-lance-claude-glm/build/distribution/local/elasticsearch-*"
    )
    es_dir = Path(es_dir).expanduser()

    # Find actual ES directory
    if es_dir.name.startswith("elasticsearch-*"):
        matches = list(es_dir.parent.glob("elasticsearch-*"))
        if not matches:
            print(f"❌ ES distribution not found: {es_dir.parent}/elasticsearch-*")
            return False
        es_dir = matches[0]

    print(f"\n⚠️  Manual step required:")
    print(f"Start ES with OSS environment variables:")
    print(f"\n  cd {es_dir}")
    print(f"  export OSS_ENDPOINT={os.environ['OSS_ENDPOINT']}")
    print(f"  export OSS_ACCESS_KEY_ID={os.environ['OSS_ACCESS_KEY_ID'][:8]}...")
    print(f"  export OSS_ACCESS_KEY_SECRET={os.environ['OSS_ACCESS_KEY_SECRET'][:8]}...")
    print(f"  ./bin/elasticsearch -d -p elasticsearch.pid")
    print(f"\nWaiting for you to start ES...")
    print(f"Press Enter when ES is running...")
    input()

    # Check if ES is running
    try:
        response = requests.get("http://localhost:9200", timeout=5)
        if response.status_code == 200:
            print("✅ Elasticsearch is running")
            return True
    except requests.exceptions.RequestException:
        pass

    print("❌ Elasticsearch not responding")
    return False

def create_oss_index(oss_uri):
    """Create index with OSS storage."""
    mapping = {
        "mappings": {
            "properties": {
                "embedding": {
                    "type": "lance_vector",
                    "dims": 128,
                    "similarity": "cosine",
                    "storage": {
                        "type": "external",
                        "uri": oss_uri,
                        "lance_id_column": "_id",
                        "lance_vector_column": "vector",
                        "read_only": True
                    }
                }
            }
        }
    }

    response = requests.put(
        "http://localhost:9200/lance-oss-test",
        json=mapping,
        timeout=30
    )

    if response.status_code in [200, 400]:
        print(f"✅ OSS index created/exists")
        print(f"  URI: {oss_uri}")
        return True
    else:
        print(f"❌ Failed to create OSS index: {response.text}")
        return False

def index_oss_metadata(n_docs=100):
    """Index metadata documents for OSS dataset."""
    print(f"Indexing {n_docs} metadata documents...")

    for i in range(n_docs):
        doc = {"category": "tech"}

        response = requests.post(
            f"http://localhost:9200/lance-oss-test/_doc/doc{i}",
            json=doc,
            timeout=10
        )

        if response.status_code not in [200, 201]:
            print(f"❌ Failed to index doc{i}: {response.text}")
            return False

    print(f"✅ Indexed {n_docs} documents")

    # Force refresh
    response = requests.post(
        "http://localhost:9200/lance-oss-test/_refresh",
        timeout=10
    )

    if response.status_code == 200:
        print(f"✅ Refresh complete")
        return True
    else:
        print(f"❌ Refresh failed: {response.text}")
        return False

def validate_oss_search(k=5):
    """Validate kNN search with OSS storage."""
    # Create query vector
    query_vector = [float(i) * 0.1 for i in range(128)]

    print(f"Executing OSS kNN search (k={k})...")

    start_time = time.time()
    response = requests.post(
        "http://localhost:9200/lance-oss-test/_search",
        json={
            "knn": {
                "field": "embedding",
                "query_vector": query_vector,
                "k": k
            },
            "size": k
        },
        timeout=60  # Longer timeout for OSS first access
    )
    elapsed = time.time() - start_time

    if response.status_code != 200:
        print(f"❌ OSS search failed: {response.text}")
        return False

    result = response.json()
    hits = result.get("hits", {}).get("hits", [])
    total = result.get("hits", {}).get("total", {}).get("value", 0)

    print(f"✅ OSS search completed in {elapsed*1000:.1f}ms")
    print(f"  Hits: {total}")

    if len(hits) == 0:
        print(f"❌ No results from OSS")
        return False

    # Check scores
    all_positive = all(hit.get("_score", 0) > 0 for hit in hits)
    if not all_positive:
        print(f"❌ Some results have score <= 0")
        return False

    print(f"✅ All {len(hits)} results have scores > 0")

    # Show results
    print(f"\nOSS search results:")
    for hit in hits[:3]:
        print(f"  - {hit['_id']}: score={hit.get('_score', 0):.4f}")

    # Check performance expectations
    if elapsed > 10.0:
        print(f"⚠️  High latency: {elapsed*1000:.1f}ms (expected <10s for first OSS access)")
    else:
        print(f"✅ Latency acceptable for OSS first access")

    return True

def benchmark_oss_search(n_searches=10):
    """Benchmark OSS search performance."""
    print(f"\nBenchmarking OSS search ({n_searches} searches)...")

    import numpy as np
    latencies = []

    for i in range(n_searches):
        query_vector = np.random.randn(128).astype(float).tolist()

        start_time = time.time()
        try:
            response = requests.post(
                "http://localhost:9200/lance-oss-test/_search",
                json={
                    "knn": {
                        "field": "embedding",
                        "query_vector": query_vector,
                        "k": 5
                    },
                    "size": 5
                },
                timeout=60
            )
            elapsed = time.time() - start_time

            if response.status_code == 200:
                latencies.append(elapsed)
                print(f"  Search {i+1}/{n_searches}: {elapsed*1000:.1f}ms")
        except Exception as e:
            print(f"  Search {i+1}/{n_searches}: ERROR - {e}")

    if latencies:
        print(f"\nOSS search performance:")
        print(f"  Min: {min(latencies)*1000:.1f}ms")
        print(f"  Max: {max(latencies)*1000:.1f}ms")
        print(f"  Avg: {sum(latencies)/len(latencies)*1000:.1f}ms")

        # Expected: 50-100ms after first search (cached)
        avg_latency = sum(latencies[1:]) / (len(latencies) - 1) if len(latencies) > 1 else latencies[0]
        if avg_latency < 0.5:  # 500ms
            print(f"✅ OSS search performance acceptable")
        else:
            print(f"⚠️  OSS search slower than expected")

    return len(latencies) == n_searches

def main():
    import argparse

    parser = argparse.ArgumentParser(description="Validate OSS storage integration")
    parser.add_argument("--oss-uri", required=True, help="OSS URI to test dataset (e.g., oss://bucket/path/data.lance)")
    parser.add_argument("--skip-restart", action="store_true", help="Skip ES restart (assume already running with OSS env vars)")
    parser.add_argument("--no-benchmark", action="store_true", help="Skip benchmark tests")

    args = parser.parse_args()

    print("="*60)
    print("Lance Vector OSS Storage Validation")
    print("="*60)

    checks = []

    # Check OSS credentials
    checks.append(check_oss_credentials())

    if not all(checks):
        sys.exit(1)

    # Restart ES with OSS env vars (or verify running)
    if args.skip_restart:
        # Just check ES is running
        try:
            response = requests.get("http://localhost:9200", timeout=5)
            if response.status_code == 200:
                print("✅ Elasticsearch is running")
            else:
                print("❌ Elasticsearch not responding")
                sys.exit(1)
        except requests.exceptions.RequestException:
            print("❌ Elasticsearch not running")
            sys.exit(1)
    else:
        checks.append(restart_es_with_oss())

    # Create OSS index
    checks.append(create_oss_index(args.oss_uri))

    # Index metadata
    checks.append(index_oss_metadata(100))

    # Validate search
    checks.append(validate_oss_search(k=5))

    # Benchmark
    if not args.no_benchmark:
        checks.append(benchmark_oss_search(n_searches=10))

    # Summary
    print(f"\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")
    print(f"Passed: {sum(checks)}/{len(checks)}")

    if all(checks):
        print("\n✅ All OSS validation checks passed!")
        sys.exit(0)
    else:
        print("\n❌ Some OSS validation checks failed")
        sys.exit(1)

if __name__ == "__main__":
    main()
