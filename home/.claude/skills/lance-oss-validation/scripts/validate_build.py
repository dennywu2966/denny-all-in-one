#!/usr/bin/env python3
"""
Validate Lance Vector plugin build.

Checks:
- Plugin builds successfully
- Plugin zip file exists (~280MB)
- Required dependencies included
"""

import subprocess
import sys
import os
from pathlib import Path

def run_command(cmd, description):
    """Run command and report result."""
    print(f"\n{'='*60}")
    print(f"Testing: {description}")
    print(f"Command: {cmd}")
    print(f"{'='*60}")

    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

    if result.returncode != 0:
        print(f"❌ FAILED")
        print(f"STDOUT:\n{result.stdout}")
        print(f"STDERR:\n{result.stderr}")
        return False

    print(f"✅ PASSED")
    if result.stdout:
        print(f"Output:\n{result.stdout}")
    return True

def main():
    es_project = os.environ.get("ES_PROJECT_DIR", "~/projects/es-lance-claude-glm")
    es_project = Path(es_project).expanduser()

    if not es_project.exists():
        print(f"❌ ES project directory not found: {es_project}")
        print("Set ES_PROJECT_DIR environment variable")
        sys.exit(1)

    os.chdir(es_project)
    print(f"Working directory: {os.getcwd()}")

    checks = []

    # Check 1: Build plugin
    checks.append(run_command(
        "./gradlew :plugins:lance-vector:assemble",
        "Build Lance Vector plugin"
    ))

    # Check 2: Verify plugin zip exists
    plugin_dir = es_project / "plugins/lance-vector/build/distributions"
    plugin_zips = list(plugin_dir.glob("lance-vector-*.zip"))

    if plugin_zips:
        print(f"\n{'='*60}")
        print(f"Testing: Plugin zip file exists")
        print(f"{'='*60}")

        for zip_file in plugin_zips:
            size_mb = zip_file.stat().st_size / (1024 * 1024)
            print(f"Found: {zip_file.name} ({size_mb:.1f} MB)")

            if size_mb >= 200:  # Should be ~280MB with dependencies
                print(f"✅ PASSED - Size looks correct")
                checks.append(True)
            else:
                print(f"❌ FAILED - Size too small (expected ~280MB)")
                checks.append(False)
    else:
        print(f"\n❌ FAILED - No plugin zip found in {plugin_dir}")
        checks.append(False)

    # Summary
    print(f"\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")
    print(f"Passed: {sum(checks)}/{len(checks)}")

    if all(checks):
        print("\n✅ All build checks passed!")
        sys.exit(0)
    else:
        print("\n❌ Some build checks failed")
        sys.exit(1)

if __name__ == "__main__":
    main()
