#!/usr/bin/env python3
import sys
import json
import argparse
import subprocess
from pathlib import Path
from datetime import datetime

SENTINEL_REL = Path(".claude/checkpoint-enabled")


def parse_hook_stdin() -> dict:
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            return {}
        return json.loads(raw)
    except Exception:
        return {}


def detect_project_root() -> Path:
    """Find project root by looking for .git or package.json."""
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists() or (parent / "package.json").exists():
            return parent
    return cwd


def append_log(project_root: Path, message: str) -> None:
    """Append to checkpoint log file."""
    log_file = project_root / ".claude" / "checkpoint.log"
    log_file.parent.mkdir(exist_ok=True)
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(log_file, "a") as f:
        f.write(f"[{timestamp}] {message}\n")


def run_checkpoint(project_root: Path, notes: str, hook_mode: bool) -> tuple[bool, list[str]]:
    """Create/update PROGRESS.md and DECISIONS.md."""
    updated_files = []

    # Update PROGRESS.md
    progress_file = project_root / "PROGRESS.md"
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    progress_entry = f"\n## {timestamp}\n"

    if notes:
        progress_entry += f"**Notes:** {notes}\n"

    # Get current git branch and recent commits
    try:
        branch = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=project_root,
            capture_output=True,
            text=True
        ).stdout.strip() or "unknown"

        recent = subprocess.run(
            ["git", "log", "--oneline", "-5"],
            cwd=project_root,
            capture_output=True,
            text=True
        ).stdout.strip()

        if recent:
            progress_entry += f"\n**Recent commits ({branch}):**\n```\n{recent}\n```\n"
    except Exception:
        pass

    if progress_file.exists():
        existing = progress_file.read_text()
        if progress_entry.strip() not in existing:
            progress_file.write_text(existing + progress_entry)
            updated_files.append("PROGRESS.md")
    else:
        progress_file.write_text(f"# Progress Log\n\n{progress_entry}")
        updated_files.append("PROGRESS.md")

    # Create DECISIONS.md if it doesn't exist
    decisions_file = project_root / "DECISIONS.md"
    if not decisions_file.exists():
        decisions_file.write_text("# Decisions Log\n\n*Use this file to record architectural decisions and their rationale.*\n")
        updated_files.append("DECISIONS.md")

    return (len(updated_files) > 0, updated_files)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--hook", action="store_true", help="Run as Claude Code hook (reads JSON from stdin)")
    ap.add_argument("--notes", default="", help="Optional notes for manual checkpoint")
    args = ap.parse_args()

    project_root = detect_project_root()

    # Hook 模式：严格按事件过滤 + 哨兵控制
    if args.hook:
        payload = parse_hook_stdin()
        event = payload.get("hook_event_name", "")

        # 仅在启用哨兵时运行（避免所有 repo 被自动污染）
        sentinel = project_root / SENTINEL_REL
        if not sentinel.exists():
            append_log(project_root, f"SKIP: sentinel missing ({event})")
            return 0

        if event == "PreCompact":
            trigger = payload.get("trigger", "")
            # manual/auto 都运行
            if trigger not in ("manual", "auto"):
                append_log(project_root, f"SKIP: PreCompact trigger={trigger}")
                return 0
            notes = ""  # hook 不写 notes，避免频繁变更
            changed, files = run_checkpoint(project_root, notes=notes, hook_mode=True)
            append_log(project_root, f"RUN: PreCompact({trigger}) changed={changed} files={files}")
            return 0

        if event == "SessionEnd":
            reason = payload.get("reason", "")
            if reason != "clear":
                append_log(project_root, f"SKIP: SessionEnd reason={reason}")
                return 0
            changed, files = run_checkpoint(project_root, notes="", hook_mode=True)
            append_log(project_root, f"RUN: SessionEnd(clear) changed={changed} files={files}")
            return 0

        append_log(project_root, f"SKIP: event={event}")
        return 0

    # 手动模式：不依赖哨兵（你都手动敲了，就认为你想写）
    changed, files = run_checkpoint(project_root, notes=args.notes, hook_mode=False)

    if changed:
        print(f"checkpoint: updated {', '.join(files)}")
    else:
        print("checkpoint: no changes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
