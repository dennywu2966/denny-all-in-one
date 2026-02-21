#!/usr/bin/env python3
import json
import os
import shutil
import sys

def main():
    # hooks 从 stdin 收 JSON（官方说明）5
    try:
        _ = json.load(sys.stdin)
    except Exception:
        print("{}")
        return

    proj = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    if not os.path.isfile(os.path.join(proj, ".claude", "ENABLE_AUTOCHECKPOINTS")):
        print("{}")
        return

    if shutil.which("jq"):
        print("{}")
        return

    # SessionStart：stdout 会被注入上下文（exit code 0 时）6
    msg = (
        "[deps] 未检测到 jq（不影响自动 checkpoint：已用 Python fallback，不会阻塞）。\n"
        "建议安装 jq（Claude Code hooks quickstart 也把它作为推荐依赖）。\n"
        "常见安装命令：\n"
        "- Debian/Ubuntu: sudo apt-get update && sudo apt-get install -y jq\n"
        "- RHEL/CentOS:   sudo yum install -y jq  （或 dnf install -y jq）\n"
        "- Alpine:       sudo apk add jq\n"
        "- Termux:       pkg install -y jq\n"
        "- macOS:        brew install jq\n"
        "提示：sudo 密码只在终端提示时输入，不要在对话里粘贴密码。"
    )

    out = {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": msg
        },
        "suppressOutput": True
    }
    print(json.dumps(out, ensure_ascii=False))

if __name__ == "__main__":
    main()
