#!/usr/bin/env python3
"""
Validate kNN search with local Lance dataset.

Prerequisites:
- Elasticsearch running with Lance plugin on localhost:9200
- Test dataset created at /tmp/test-vectors.lance
"""

import requests
import subprocess
import sys
import time
import numpy as np
from pathlib import Path

def check_es_running():
    """Check if Elasticsearch is running."""
    try:
        response = requests.get("http://localhost:9200", timeout=5)
        return response.status_code == 200
    except requests.exceptions.RequestException:
        return False

def create_index(dataset_uri="file:///tmp/test-vectors.lance"):
    """Create index with Lance vector mapping."""
    mapping = {
        "mappings": {
            "properties": {
                "id": {"type": "keyword"},
                "embedding": {
                    "type": "lance_vector",
                    "dims": 128,
                    "similarity": "cosine",
                    "storage": {
                        "type": "external",
                        "uri": dataset_uri,
                        "lance_id_column": "_id",
                        "lance_vector_column": "vector",
                        "read_only": True
                    }
                },
                "category": {"type": "keyword"}
            }
        }
    }

    response = requests.put(
        "http://localhost:9200/lance-validation-test",
        json=mapping,
        timeout=30
    )

    if response.status_code in [200, 400]:  # 400 = already exists
        print(f"✅ Index created/exists")
        return True
    else:
        print(f"❌ Failed to create index: {response.text}")
        return False

def index_metadata_documents(n_docs=100):
    """Index metadata documents matching Lance dataset IDs."""
    print(f"Indexing {n_docs} metadata documents...")

    for i in range(n_docs):
        doc = {
            "id": f"doc{i}",
            "category": "tech"
        }

        response = requests.post(
            f"http://localhost:9200/lance-validation-test/_doc/doc{i}",
            json=doc,
            timeout=10
        )

        if response.status_code not in [200, 201]:
            print(f"❌ Failed to index doc{i}: {response.text}")
            return False

    print(f"✅ Indexed {n_docs} documents")

    # Force refresh
    response = requests.post(
        "http://localhost:9200/lance-validation-test/_refresh",
        timeout=10
    )

    if response.status_code == 200:
        print(f"✅ Refresh complete")
        return True
    else:
        print(f"❌ Refresh failed: {response.text}")
        return False

def validate_search(k=5, num_candidates=10):
    """Validate kNN search returns correct results."""
    # Create query vector
    query_vector = [float(i) * 0.1 for i in range(128)]

    print(f"Executing kNN search (k={k}, num_candidates={num_candidates})...")

    start_time = time.time()
    response = requests.post(
        "http://localhost:9200/lance-validation-test/_search",
        json={
            "knn": {
                "field": "embedding",
                "query_vector": query_vector,
                "k": k,
                "num_candidates": num_candidates
            },
            "size": k
        },
        timeout=30
    )
    elapsed = time.time() - start_time

    if response.status_code != 200:
        print(f"❌ Search failed: {response.text}")
        return False

    result = response.json()
    hits = result.get("hits", {}).get("hits", [])
    total = result.get("hits", {}).get("total", {}).get("value", 0)

    print(f"✅ Search completed in {elapsed*1000:.1f}ms")
    print(f"  Hits: {total}")

    # Validate results
    if len(hits) == 0:
        print(f"❌ No results returned")
        return False

    if len(hits) != k:
        print(f"⚠️  Expected {k} results, got {len(hits)}")
        # Don't fail, just warn

    # Check scores > 0 (validates scoring fix)
    all_positive = all(hit.get("_score", 0) > 0 for hit in hits)
    if not all_positive:
        print(f"❌ Some results have score <= 0 (scoring broken)")
        print("Results:")
        for hit in hits[:5]:
            print(f"  - {hit['_id']}: score={hit.get('_score', 0)}")
        return False

    print(f"✅ All {len(hits)} results have scores > 0")

    # Show sample results
    print(f"\nSample results:")
    for hit in hits[:3]:
        print(f"  - {hit['_id']}: score={hit.get('_score', 0):.4f}")

    # Check latency expectations
    if elapsed > 5.0:
        print(f"⚠️  High latency: {elapsed*1000:.1f}ms (expected <5000ms for first search)")
    else:
        print(f"✅ Latency within expected range")

    return True

def stress_test(n_searches=20):
    """Run multiple searches to validate stability."""
    print(f"\nRunning stress test ({n_searches} searches)...")

    latencies = []
    errors = 0

    for i in range(n_searches):
        query_vector = np.random.randn(128).astype(float).tolist()

        start_time = time.time()
        try:
            response = requests.post(
                "http://localhost:9200/lance-validation-test/_search",
                json={
                    "knn": {
                        "field": "embedding",
                        "query_vector": query_vector,
                        "k": 5,
                        "num_candidates": 10
                    },
                    "size": 5
                },
                timeout=30
            )
            elapsed = time.time() - start_time

            if response.status_code == 200:
                latencies.append(elapsed)
                print(f"  Search {i+1}/{n_searches}: {elapsed*1000:.1f}ms")
            else:
                errors += 1
                print(f"  Search {i+1}/{n_searches}: FAILED")
        except Exception as e:
            errors += 1
            print(f"  Search {i+1}/{n_searches}: ERROR - {e}")

    print(f"\nStress test results:")
    print(f"  Successful: {len(latencies)}/{n_searches}")
    print(f"  Errors: {errors}")

    if latencies:
        print(f"  Latency (ms):")
        print(f"    Min: {min(latencies)*1000:.1f}ms")
        print(f"    Max: {max(latencies)*1000:.1f}ms")
        print(f"    Avg: {sum(latencies)/len(latencies)*1000:.1f}ms")

        # Check if latency stabilizes after first search
        if len(latencies) > 1:
            first_search = latencies[0]
            avg_subsequent = sum(latencies[1:]) / (len(latencies) - 1)

            print(f"\n  Dataset loading effect:")
            print(f"    First search: {first_search*1000:.1f}ms")
            print(f"    Avg subsequent: {avg_subsequent*1000:.1f}ms")

            if avg_subsequent < first_search * 0.5:
                print(f"    ✅ Latency stabilizes after first search (dataset cached)")
            else:
                print(f"    ⚠️  Latency not stabilizing as expected")

    return errors == 0

def main():
    print("="*60)
    print("Lance Vector Local Search Validation")
    print("="*60)

    checks = []

    # Check ES running
    if not check_es_running():
        print("❌ Elasticsearch not running on localhost:9200")
        print("Start Elasticsearch first:")
        print("  cd build/distribution/local/elasticsearch-*")
        print("  ./bin/elasticsearch -d -p elasticsearch.pid")
        sys.exit(1)

    print("✅ Elasticsearch is running")

    # Check dataset exists
    dataset_path = Path("/tmp/test-vectors.lance")
    if not dataset_path.exists():
        print(f"❌ Dataset not found: {dataset_path}")
        print("Create dataset first:")
        print("  python scripts/create_test_dataset.py /tmp/test-vectors.lance")
        sys.exit(1)

    print(f"✅ Dataset exists: {dataset_path}")

    # Create index
    checks.append(create_index())

    # Index metadata
    checks.append(index_metadata_documents(100))

    # Validate search
    checks.append(validate_search(k=5, num_candidates=10))

    # Stress test
    checks.append(stress_test(n_searches=20))

    # Summary
    print(f"\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")
    print(f"Passed: {sum(checks)}/{len(checks)}")

    if all(checks):
        print("\n✅ All validation checks passed!")
        sys.exit(0)
    else:
        print("\n❌ Some validation checks failed")
        sys.exit(1)

if __name__ == "__main__":
    main()
