---
name: checkpoint
description: Create/update PROGRESS.md and DECISIONS.md in the repo root. Use before context compaction or when you want a clean project checkpoint.
disable-model-invocation: true
argument-hint: "[notes]"
# 只放开 python3，避免 Bash 全放开
allowed-tools: Bash(python3:*)
---


# /checkpoint


Run the checkpoint script from the current project and print a one-line result.


```bash
python3 ~/.claude/skills/checkpoint/scripts/checkpoint.py --notes "$ARGUMENTS"
