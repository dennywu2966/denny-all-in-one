#!/usr/bin/env bash
set -euo pipefail

# 防递归（脚本内部调用 claude -p 时，避免再触发 hooks）
if [[ "${CLAUDE_HOOK_INNER:-}" == "1" ]]; then
  exit 0
fi

proj="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$proj" || exit 0

# repo 开关
if [[ ! -f ".claude/ENABLE_AUTOCHECKPOINTS" ]]; then
  exit 0
fi

mkdir -p .claude/checkpoints .claude/logs

# 跨平台锁：mkdir 原子
lockdir=".claude/checkpoints/.lockdir"
if ! mkdir "$lockdir" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$lockdir" 2>/dev/null || true' EXIT

# 读 hook stdin（拿 session_id 找日志；解析失败也不阻塞）
input="$(cat || true)"
session_id="$(python3 - <<'PY'
import json,sys
try:
  d=json.load(sys.stdin)
  print(d.get("session_id","unknown"))
except Exception:
  print("unknown")
PY
<<<"$input")"

log_file=".claude/logs/${session_id}.ndjson"
recent_log="$(test -f "$log_file" && tail -n 200 "$log_file" || echo "NO_LOG")"

# git 信息（不是 git repo 也不炸）
git_status="$(git status --porcelain=v1 2>/dev/null || true)"
git_diff="$(git diff --stat 2>/dev/null || true)"

# 初始化文件（只创建一次）
test -f PROGRESS.md || cat > PROGRESS.md <<'MD'
# PROGRESS

<!-- AUTO:BEGIN -->
<!-- AUTO:END -->
MD

test -f DECISIONS.md || cat > DECISIONS.md <<'MD'
# DECISIONS

<!-- AUTO:BEGIN -->
<!-- AUTO:END -->
MD

schema='{"type":"object","properties":{"progress_auto":{"type":"string"},"decisions_auto":{"type":"string"}},"required":["progress_auto","decisions_auto"]}'

prompt=$(cat <<EOF
Update ONLY the AUTO sections for:
- PROGRESS.md
- DECISIONS.md

Rules:
- Output ONLY the content that should go inside each AUTO section.
- Be concrete: file paths, commands, expected outputs.
- If unknown, write "unknown" (do NOT guess).

Inputs:
[git status]
$git_status

[git diff --stat]
$git_diff

[recent tool log tail]
$recent_log

Output:
- progress_auto: current status + next 3 actions + verification
- decisions_auto: decision bullets with rationale + rejected alternatives (1-liners)
EOF
)

export CLAUDE_HOOK_INNER=1

llm_json="$(
  claude -p "$prompt" \
    --output-format json \
    --json-schema "$schema" \
  2>/dev/null || true
)"

if [[ -n "$llm_json" ]]; then
  progress_auto="$(python3 - <<'PY'
import json,sys
d=json.load(sys.stdin)
so=d.get("structured_output") or {}
print(so.get("progress_auto",""))
PY
<<<"$llm_json")"

  decisions_auto="$(python3 - <<'PY'
import json,sys
d=json.load(sys.stdin)
so=d.get("structured_output") or {}
print(so.get("decisions_auto",""))
PY
<<<"$llm_json")"
else
  # 失败 fallback：不阻塞
  progress_auto=$'## 状态\n- unknown (LLM call failed)\n\n## 下一步（3条）\n1. unknown\n2. unknown\n3. unknown\n\n## 验证\n- unknown'
  decisions_auto=$'- unknown (LLM call failed)'
fi

changed_files=()

# 只在内容变化时写回；不变就不动
p_changed="$(python3 "$HOME/.claude/hooks/update_auto_sections.py" PROGRESS.md "$progress_auto")"
d_changed="$(python3 "$HOME/.claude/hooks/update_auto_sections.py" DECISIONS.md "$decisions_auto")"

if [[ "$p_changed" == "1" ]]; then changed_files+=("PROGRESS.md"); fi
if [[ "$d_changed" == "1" ]]; then changed_files+=("DECISIONS.md"); fi

if [[ "${#changed_files[@]}" -eq 0 ]]; then
  echo "checkpoints: no changes"
else
  echo "checkpoints updated: $(IFS=', '; echo "${changed_files[*]}")"
fi
