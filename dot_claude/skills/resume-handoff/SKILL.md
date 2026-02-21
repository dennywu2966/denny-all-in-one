---
name: resume-handoff
description: Resume work after /clear using docs/HANDOFF.md. Reads the file, confirms goal/non-goals/constraints, then executes Next actions sequentially and keeps HANDOFF updated.
argument-hint: "[optional-focus-override]"
disable-model-invocation: true
---

# Resume from HANDOFF

## Step 1: Load state
1) Read `docs/HANDOFF.md`.
2) If `$ARGUMENTS` is non-empty, treat it as a focus override (e.g., “Only do Next action #2 first”).

## Step 2: Confirm plan in 3 bullets (in chat)
- Goal (1 line)
- Non-goals (1 line)
- Next actions (1-3)

## Step 3: Execute
Work through “Next actions” one by one.
After finishing each action:
- Update `docs/HANDOFF.md`:
  - Move completed items into ✅ Done
  - Update 🟡 In progress / ❗ Blockers
  - Refresh Next actions (keep top 3 actionable)
  - Update Verification if new checks were added
Then continue to the next action.

## Step 4: Stop condition
Stop after completing 1-2 actions, unless the remaining work is trivial.
Always leave HANDOFF in a clean, resumable state.
