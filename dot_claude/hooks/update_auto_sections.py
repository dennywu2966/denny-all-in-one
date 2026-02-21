#!/usr/bin/env python3
import sys

path = sys.argv[1]
auto = sys.argv[2]

BEGIN = "<!-- AUTO:BEGIN -->"
END = "<!-- AUTO:END -->"

with open(path, "r", encoding="utf-8") as f:
    s = f.read()

b = s.find(BEGIN)
e = s.find(END)
if b == -1 or e == -1 or e < b:
    raise SystemExit(f"{path}: missing AUTO markers")

new_s = s[: b + len(BEGIN)] + "\n\n" + auto.strip() + "\n\n" + s[e:]

if new_s == s:
    # 不变：打印 0（供 shell 汇总用），不改文件
    print("0")
    sys.exit(0)

with open(path, "w", encoding="utf-8") as f:
    f.write(new_s)

# 有变化：打印 1
print("1")
