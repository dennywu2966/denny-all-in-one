---
name: handoff
description: When context is getting long, create/update docs/HANDOFF.md (goal/non-goals/constraints/status/next steps/verification/pitfalls) and print the exact steps to /clear and resume in a fresh session.
argument-hint: "[extra-notes-to-carry-over]"
disable-model-invocation: true
# Optional. If you want this to ignore the bloated conversation and work from repo state + files:
# context: fork
# agent: general-purpose
---

# Handoff / Checkpoint (ultrathink)

## Dynamic repo snapshot (auto-injected)
- CWD: !`pwd`
- Git status: !`git status -sb 2>/dev/null || true`
- Diffstat: !`(git diff --stat 2>/dev/null || true) | head -n 200`
- Changed files: !`(git diff --name-only 2>/dev/null || true) | head -n 200`
- Recent commits: !`(git log -n 20 --oneline 2>/dev/null || true)`

## Your task
You are creating a "carry-over package" so we can safely run /clear and continue later without losing critical context.

### Step 1: Read existing project context
1) Read and follow CLAUDE.md and any .claude/rules/* if present.
2) If docs/HANDOFF.md exists, read it first.

### Step 2: Write/update docs/HANDOFF.md
Create or update `docs/HANDOFF.md` using this exact structure:

# HANDOFF

## Goal
(one sentence; prefer measurable)

## Non-goals
(bullets; explicit “what we are NOT doing”)

## Current status
- ✅ Done:
- 🟡 In progress:
- ❗ Blockers/Risks:

## Key constraints
- Performance:
- Correctness/Consistency:
- Compatibility:
- Security:
- Cost/Resources:

## Key files / entry points
(list paths + why each matters)

## Decisions (why)
(bullets; include rejected alternatives briefly)

## Attempts & pitfalls (avoid rework)
(bullets; include “what failed and why”)

## Verification
- Commands:
- Expected outputs:
- Regression scope:

## Next actions (do these next)
1)
2)
3)

## Extra notes from invocation
$ARGUMENTS

Rules:
- Prefer concrete file paths, commands, and expected outputs.
- Keep it compact but not vague. If a detail would cause rework if forgotten, include it.
- If git snapshot shows big diffs, reference the most important changed areas.

### Step 3 (optional): also refresh PROGRESS/DECISIONS if they exist
- If `PROGRESS.md` exists: update “where we are + next verification”.
- If `DECISIONS.md` exists: add any new decisions with rationale.
If they don’t exist, do not create them unless explicitly asked.

### Step 4: Print the “fresh session resume” instructions to chat
After files are updated, print EXACTLY:
1) “Run: /clear”
2) “Then run: /resume-handoff”
3) A short 5-line summary: Goal + Next actions 1-3
