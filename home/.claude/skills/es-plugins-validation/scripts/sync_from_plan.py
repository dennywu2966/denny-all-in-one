#!/usr/bin/env python3
"""
Sync validation skill with reg_validation_guide.md (OFFICIAL guide)

This script parses reg_validation_guide.md and updates:
- SKILL.md (test counts)
- references/*.md (detailed test cases)

Usage:
    python3 .claude/skills/es-plugins-validation/scripts/sync_from_plan.py
"""

import re
import os
from pathlib import Path

# Paths
PROJECT_ROOT = Path("/home/denny/projects/es-9.2.4-plugins")
SKILL_DIR = Path("/home/denny/.claude/skills/es-plugins-validation")
GUIDE_FILE = PROJECT_ROOT / "reg_validation_guide.md"
SKILL_MD = SKILL_DIR / "SKILL.md"
REFS_DIR = SKILL_DIR / "references"

def parse_plan_tests(content: str) -> dict:
    """Parse test cases from validation plan into structured format."""
    sections = {}
    current_section = None
    current_table = []

    lines = content.split('\n')
    i = 0

    while i < len(lines):
        line = lines[i]

        # Detect section headers (## or ###)
        if line.startswith('## '):
            if current_section and current_table:
                sections[current_section] = current_table
            current_section = line[3:].strip()
            current_table = []
        elif line.startswith('### '):
            if current_section and current_table:
                sections[current_section] = current_table
            current_section = line[4:].strip()
            current_table = []
        # Parse table rows
        elif line.startswith('|') and current_section:
            parts = [p.strip() for p in line.split('|')[1:-1]]
            if len(parts) >= 3 and parts[0] not in ['ID', '---']:
                current_table.append({
                    'id': parts[0],
                    'test': parts[1] if len(parts) > 1 else '',
                    'priority': parts[2] if len(parts) > 2 else '',
                    'success': parts[3] if len(parts) > 3 else ''
                })
        i += 1

    # Don't forget last section
    if current_section and current_table:
        sections[current_section] = current_table

    return sections

def count_tests(sections: dict) -> dict:
    """Count tests by category and priority."""
    counts = {
        'Lance Vector': {'total': 0, 'P0': 0, 'P1': 0, 'P2': 0},
        'Cloud IAM': {'total': 0, 'P0': 0, 'P1': 0, 'P2': 0},
        'Integration': {'total': 0, 'P0': 0, 'P1': 0, 'P2': 0},
        'Configuration': {'total': 0, 'P0': 0, 'P1': 0, 'P2': 0},
        'Error Handling': {'total': 0, 'P0': 0, 'P1': 0, 'P2': 0},
    }

    category_map = {
        'Lance Vector': 'Lance Vector',
        'Cloud IAM': 'Cloud IAM',
        'Integration': 'Integration',
        'Configuration': 'Configuration',
        'Error Handling': 'Error Handling',
    }

    for section, tests in sections.items():
        for cat in category_map:
            if cat.lower() in section.lower():
                counts[cat]['total'] += len(tests)
                for test in tests:
                    priority = test.get('priority', '')
                    if priority in ['P0', 'P1', 'P2']:
                        counts[cat][priority] += 1
                break

    return counts

def generate_test_reference(tests: list, title: str) -> str:
    """Generate markdown reference file for a test category."""
    md = f"# {title}\n\n"

    # Group by subsection
    current_subsection = None
    for test in tests:
        md += f"## {test['id']}: {test['test']}\n\n"
        md += f"**Priority**: {test['priority']}\n\n"
        md += f"**Success Criteria**: {test['success']}\n\n"
        md += "---\n\n"

    return md

def main():
    # Read validation plan
    print(f"Reading {GUIDE_FILE}...")
    with open(GUIDE_FILE) as f:
        plan_content = f.read()

    # Parse tests
    print("Parsing test cases...")
    sections = parse_plan_tests(plan_content)
    counts = count_tests(sections)

    # Print summary
    total = sum(c['total'] for c in counts.values())
    p0_total = sum(c['P0'] for c in counts.values())
    p1_total = sum(c['P1'] for c in counts.values())
    p2_total = sum(c['P2'] for c in counts.values())

    print(f"\nTest Summary:")
    print(f"  Total: {total} tests ({p0_total} P0, {p1_total} P1, {p2_total} P2)")
    for cat, c in counts.items():
        if c['total'] > 0:
            print(f"  {cat}: {c['total']} ({c['P0']} P0, {c['P1']} P1, {c['P2']} P2)")

    # Generate reference files
    print(f"\nGenerating reference files in {REFS_DIR}...")
    REFS_DIR.mkdir(exist_ok=True)

    # Lance Vector reference
    lv_tests = [t for s, tests in sections.items() if 'lance' in s.lower() for t in tests]
    if lv_tests:
        with open(REFS_DIR / 'lance-vector-tests.md', 'w') as f:
            f.write("# Lance Vector Tests\n\n")
            for test in lv_tests:
                f.write(f"## {test['id']}: {test['test']}\n\n")
                f.write(f"**Priority**: {test['priority']}\n\n")
                f.write(f"**Success Criteria**: {test['success']}\n\n")
                f.write("---\n\n")

    # Cloud IAM reference
    ci_tests = [t for s, tests in sections.items() if 'cloud' in s.lower() or 'iam' in s.lower() for t in tests]
    if ci_tests:
        with open(REFS_DIR / 'cloud-iam-tests.md', 'w') as f:
            f.write("# Cloud IAM Tests\n\n")
            for test in ci_tests:
                f.write(f"## {test['id']}: {test['test']}\n\n")
                f.write(f"**Priority**: {test['priority']}\n\n")
                f.write(f"**Success Criteria**: {test['success']}\n\n")
                f.write("---\n\n")

    # Integration reference
    int_tests = [t for s, tests in sections.items() if 'integration' in s.lower() or s.startswith('INT') for t in tests]
    if int_tests:
        with open(REFS_DIR / 'integration-tests.md', 'w') as f:
            f.write("# Integration Tests\n\n")
            for test in int_tests:
                f.write(f"## {test['id']}: {test['test']}\n\n")
                f.write(f"**Priority**: {test['priority']}\n\n")
                f.write(f"**Success Criteria**: {test['success']}\n\n")
                f.write("---\n\n")

    print(f"Generated:")
    print(f"  - {REFS_DIR / 'lance-vector-tests.md'} ({len(lv_tests)} tests)")
    print(f"  - {REFS_DIR / 'cloud-iam-tests.md'} ({len(ci_tests)} tests)")
    print(f"  - {REFS_DIR / 'integration-tests.md'} ({len(int_tests)} tests)")

    print("\nSync complete!")

if __name__ == '__main__':
    main()
