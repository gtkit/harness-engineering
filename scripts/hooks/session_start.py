#!/usr/bin/env python3
"""harness 的 SessionStart hook：会话开始时把两件事注入上下文。

1. .harness/error-journal.md 里 Status 为 open 的条目摘要——"任务开始前先读错误记忆"不再依赖模型自觉。
2. .harness/VERSION 记录的模板 commit 与模板仓库当前 HEAD 不一致时，提示刷新命令。

两条都没有可说的就不输出任何内容。Claude Code 与 Codex 共用同一份，输出格式是两端共同契约：
hookSpecificOutput.additionalContext。
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HARNESS_DIR = ROOT / ".harness"
MAX_OPEN_ENTRIES = 10


def read_version() -> dict[str, str]:
    path = HARNESS_DIR / "VERSION"
    if not path.is_file():
        return {}
    fields: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        key, sep, value = line.partition(":")
        if sep:
            fields[key.strip()] = value.strip()
    return fields


def open_entries() -> list[str]:
    path = HARNESS_DIR / "error-journal.md"
    if not path.is_file():
        return []
    entries: list[str] = []
    current_id = ""
    current_open = False
    summary_next = False
    for line in path.read_text(encoding="utf-8").splitlines():
        heading = re.match(r"^## \[(ERR-[^\]]+)\]", line)
        if heading:
            current_id = heading.group(1)
            current_open = False
            summary_next = False
            continue
        if not current_id:
            continue
        if re.match(r"^\*\*Status\*\*:\s*open\b", line):
            current_open = True
            continue
        if line.startswith("### Summary"):
            summary_next = current_open
            continue
        if summary_next and line.strip():
            entries.append(f"{current_id}: {line.strip()}")
            summary_next = False
            current_id = ""
    return entries


def template_head(source_path: str) -> str:
    if not source_path or not Path(source_path).is_dir():
        return ""
    try:
        result = subprocess.run(
            ["git", "-C", source_path, "rev-parse", "--short=12", "HEAD"],
            text=True,
            capture_output=True,
            check=False,
            timeout=5,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return result.stdout.strip() if result.returncode == 0 else ""


def main() -> int:
    sys.stdin.read()  # 两端都会喂 payload，内容用不上
    version = read_version()
    lines: list[str] = []

    entries = open_entries()
    if entries:
        lines.append(f"harness 错误记忆里有 {len(entries)} 条未关闭（.harness/error-journal.md，Status: open），动手前先看：")
        lines.extend(f"- {item}" for item in entries[:MAX_OPEN_ENTRIES])
        if len(entries) > MAX_OPEN_ENTRIES:
            lines.append(f"- … 另有 {len(entries) - MAX_OPEN_ENTRIES} 条，见文件")

    installed = version.get("source-commit", "")
    current = template_head(version.get("source-path", ""))
    if installed and current and installed != current.rstrip("-dirty"):
        harness = version.get("harness", "harness")
        lines.append(
            f"harness 模板已更新：项目里是 {installed}，模板仓库当前是 {current}。"
            f"提醒用户在项目目录运行 `{harness} --force-guides`（只刷 guides）或 `{harness} --force`（连入口文件、skills、rules 一起刷）后再继续。"
        )

    if lines:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "\n".join(lines)}}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
