#!/usr/bin/env python3
"""harness 的 PreToolUse hook：在破坏性操作真正执行前拒绝它。

入口文件与 .harness/guides/ai-safety.md 是"软约束"，模型可以不遵守；这个 hook 是唯一
能真正拦住命令的一层。拦截清单只收**不可恢复**的操作——删除、改写历史、清库、提权、
远端脚本直接执行、凭据读取、写用户级配置。可恢复的操作不拦，否则误伤会逼用户关掉整个 hook。

输出契约（Claude Code 与 Codex 一致）：拒绝时输出
hookSpecificOutput.permissionDecision = "deny"；放行时输出空对象，把决定权留给用户
自己的权限规则，不用 allow 绕过它们。

fail-open：本脚本自身出错时放行并把原因打到 stderr。它是纵深防御的一层而不是唯一防线，
崩溃时挡住全部工作的代价，大于漏掉一次拦截。
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# 临时目录下的删除是日常操作，不拦
TEMP_PREFIXES = ("/tmp/", "/private/tmp/", "/var/folders/", "/private/var/folders/")

# rm 的危险目标：空展开后会变成删根的写法，以及家目录与项目外绝对路径
RM_FATAL_TARGETS = {"/", "/*", "~", "~/", "~/*", "$HOME", "$HOME/", "$HOME/*", ".", "..", "*", "./*", "../*"}

CREDENTIAL_PATHS = (
    "/.ssh/", "/.aws/credentials", "/.aws/config", "/.gnupg/", "/.kube/config",
    "/.docker/config.json", "/.netrc", "/.npmrc", "/.pypirc",
)

# 写到这些位置会改变用户全局环境，项目内的改动不该外溢到这里
USER_CONFIG_PATHS = (
    "/.ssh/", "/.aws/", "/.gnupg/", "/.kube/", "/.claude/", "/.codex/", "/.agents/",
    "/.gitconfig", "/.zshrc", "/.bashrc", "/.bash_profile", "/.profile", "/.zprofile",
)

SPLIT_RE = re.compile(r"&&|\|\||;|\n")

# 这些命令只是在搜索或输出文本，命令串里出现危险关键词不代表会执行它
INERT_HEADS = ("grep", "rg", "ag", "echo", "printf", "awk", "sed", "diff", "comm", "jq", "head", "tail")
# heredoc 的内容是写进文件的，除非喂给解释器
INTERPRETERS = ("bash", "sh", "zsh", "python", "python3", "node", "ruby", "perl", "php")


def strip_heredoc(command: str) -> str:
    """去掉 heredoc 正文：写文档时正文里常含危险命令示例，那是文本不是执行。

    正文喂给解释器时（bash <<EOF）原样保留——那才是真的要执行。
    """
    if "<<" not in command:
        return command
    head = command.split("<<", 1)[0]
    if any(re.search(rf"\b{re.escape(i)}\b", head) for i in INTERPRETERS):
        return command
    return head


def is_inert(segment: str) -> bool:
    parts = tokens(segment)
    if not parts:
        return True
    head = parts[0].split("/")[-1]
    return head in INERT_HEADS


def deny(reason: str) -> None:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": (
                f"{reason}\n\n"
                "这是 harness 的安全拦截（.harness/hooks/pre_tool_use.py）。不要换个写法绕过去："
                "停下来告诉用户你想做什么、为什么需要它、影响范围，由用户决定。"
                "细则见 .harness/guides/ai-safety.md。"
            ),
        }
    }, ensure_ascii=False))
    sys.exit(0)


def tokens(cmd: str) -> list[str]:
    """粗分词：够用来看 rm / chmod 的参数，不追求 shell 语义完整。"""
    return [t for t in re.split(r"\s+", cmd.strip()) if t]


def check_rm(cmd: str) -> str | None:
    if not re.search(r"\brm\b", cmd):
        return None
    parts = tokens(cmd)
    try:
        idx = next(i for i, t in enumerate(parts) if t == "rm" or t.endswith("/rm"))
    except StopIteration:
        return None
    flags = "".join(t for t in parts[idx + 1:] if t.startswith("-"))
    if not ("r" in flags and "f" in flags):
        return None
    for target in parts[idx + 1:]:
        if target.startswith("-"):
            continue
        clean = target.strip("\"'")
        if clean in RM_FATAL_TARGETS:
            return f"`rm -rf {clean}` 的目标是根目录 / 家目录 / 当前目录，删除不可恢复。"
        # 变量为空时 "$DIR/" 会展开成 "/"：先校验非空再删
        if re.match(r"^[\"']?\$[A-Za-z_{]", clean):
            return (f"`rm -rf {clean}` 的路径来自变量：变量为空时会展开成删根。"
                    "先 `[ -n \"$VAR\" ] || exit 1` 校验，或改成写死的具体路径。")
        if clean.startswith("/") and not clean.startswith(TEMP_PREFIXES):
            if not clean.startswith(str(ROOT) + "/"):
                return f"`rm -rf {clean}` 指向项目外的绝对路径。"
    return None


def check_git(cmd: str) -> str | None:
    if not re.search(r"\bgit\b", cmd):
        return None
    rules = [
        (r"\bgit\s+reset\s+.*--hard", "`git reset --hard` 会丢弃工作区里未提交的改动，那些只有用户知道价值。"),
        (r"\bgit\s+checkout\s+--\s+\.", "`git checkout -- .` 会丢弃全部未提交改动。"),
        (r"\bgit\s+clean\s+-[a-z]*f", "`git clean -f` 会删除未跟踪文件，其中可能有用户还没提交的新文件。"),
        (r"\bgit\s+push\b.*--force", "强推会改写远端历史，影响所有拿到过这个分支的人。"),
        (r"\bgit\s+push\b.*\s-f(\s|$)", "强推会改写远端历史，影响所有拿到过这个分支的人。"),
        (r"\bgit\s+push\s+.*--delete", "删除远端分支影响所有协作者。"),
        (r"\bgit\s+push\s+\S+\s+:", "`git push remote :branch` 是删除远端分支。"),
        (r"\bgit\s+tag\s+-d\b", "删除 tag 会影响已发布的版本引用。"),
        (r"\bgit\s+filter-(repo|branch)\b", "改写全部历史，影响所有仓库副本。"),
        (r"\bgit\s+reflog\s+expire", "清空 reflog 会让误操作失去最后的恢复手段。"),
        (r"\bgit\s+gc\s+.*--prune=now", "立即 prune 会让悬空对象无法恢复。"),
        (r"\bgit\s+update-ref\s+-d", "直接删引用绕过了所有保护。"),
    ]
    for pattern, reason in rules:
        if re.search(pattern, cmd):
            return reason
    return None


def check_database(cmd: str) -> str | None:
    # 只检查真的在调数据库客户端的命令，避免误伤 grep "DROP TABLE" 这类搜索
    if not re.search(r"\b(mysql|mysqldump|psql|sqlite3|redis-cli|mongo|mongosh|clickhouse-client)\b", cmd):
        return None
    upper = cmd.upper()
    rules = [
        (r"\bDROP\s+(DATABASE|SCHEMA|TABLE)\b", "DROP 会删掉整个库 / 表，不可恢复。"),
        (r"\bTRUNCATE\b", "TRUNCATE 清空整表且通常不写 binlog，不可回滚。"),
        (r"\bFLUSHALL\b", "FLUSHALL 清空 Redis 全部 db。"),
        (r"\bFLUSHDB\b", "FLUSHDB 清空当前 Redis db。"),
        (r"\bKEYS\s+[*\"']", "`KEYS *` 会阻塞 Redis 直到扫完全部 key，用 SCAN 代替。"),
    ]
    for pattern, reason in rules:
        if re.search(pattern, upper):
            return reason
    if re.search(r"\bDELETE\s+FROM\b", upper) and "WHERE" not in upper:
        return "没有 WHERE 的 DELETE 会清空整表。"
    if re.search(r"\bUPDATE\s+\S+\s+SET\b", upper) and "WHERE" not in upper:
        return "没有 WHERE 的 UPDATE 会改写整表。"
    return None


def check_system(cmd: str) -> str | None:
    rules = [
        (r"\bsudo\b", "提权操作交给用户自己执行。"),
        (r"\bchmod\s+(-[a-zA-Z]+\s+)*777\b", "`chmod 777` 让任何本机用户可写，用最小必要权限。"),
        (r"\bdd\b.*\bof=/dev/", "直接写块设备会损坏磁盘。"),
        (r"\bmkfs(\.|\s)", "格式化会抹掉整个文件系统。"),
        (r":\(\)\s*\{.*\|.*&.*\}", "fork bomb。"),
        (r"\bdocker\s+system\s+prune", "会删掉本机所有未使用的容器、镜像、卷，含用户其它项目的。"),
        (r"\bdocker\s+volume\s+rm\b", "删卷会丢掉容器里的持久化数据。"),
        (r"\bdocker\s+(rm|stop|kill)\s+.*-", "停止 / 删除容器前先 `docker ps` 确认它不是用户在用的。"),
        (r"\b(curl|wget)\b[^|]*\|\s*(sudo\s+)?(ba)?sh\b", "把远端脚本直接喂给 shell：先下载、读完内容、告诉用户它做什么，再由用户决定。"),
        (r">\s*/dev/(sd|nvme|disk)", "直接覆写块设备。"),
    ]
    for pattern, reason in rules:
        if re.search(pattern, cmd):
            return reason
    return None


SEARCH_HEADS = ("grep", "rg", "ag", "awk", "sed", "diff", "comm", "jq")


def check_credentials(cmd: str) -> str | None:
    # 搜索命令里出现凭据路径是在找它，不是在读它
    parts = tokens(cmd)
    if parts and parts[0].split("/")[-1] in SEARCH_HEADS:
        return None
    if re.search(r"\b(cat|less|more|head|tail|bat|xxd|od|strings|cp|scp|rsync|base64)\b", cmd):
        for path in CREDENTIAL_PATHS:
            if path in cmd or path.replace("/.", "~/.", 1) in cmd:
                return f"读取凭据文件（{path}）。需要凭据时说明需要哪一个，让用户注入环境变量。"
    if re.search(r"\becho\s+\"?\$[A-Z_]*(TOKEN|SECRET|PASSWORD|KEY|CREDENTIAL)", cmd):
        return "回显凭据环境变量会把它写进日志与会话记录。确认是否已设置用 `[ -n \"$VAR\" ] && echo set`。"
    if re.search(r"\benv\b[^|]*\|[^|]*\b(curl|wget|nc)\b", cmd) or re.search(r"\b(curl|wget)\b.*\$[A-Z_]*(TOKEN|SECRET|PASSWORD|KEY)", cmd):
        return "把环境变量发往外部服务。凭据不得离开本机。"
    return None


def check_bash(command: str) -> str | None:
    command = strip_heredoc(command)
    segments = [seg for seg in SPLIT_RE.split(command) if not is_inert(seg)]
    # 管道类规则要看完整命令串（curl | bash 跨越管道），其余按子命令逐段判断
    reason = check_credentials(command)
    if reason:
        return reason
    if not is_inert(command):
        reason = check_system(command)
        if reason:
            return reason
    for segment in segments:
        for check in (check_rm, check_git, check_database):
            reason = check(segment)
            if reason:
                return reason
    return None


def check_file_write(path_str: str) -> str | None:
    if not path_str:
        return None
    home = str(Path.home())
    resolved = os.path.expanduser(path_str)
    for marker in USER_CONFIG_PATHS:
        if resolved.startswith(home) and marker in resolved[len(home):] + "/":
            return f"写用户级配置（{path_str}）会影响用户在所有项目里的环境。"
    if resolved.startswith("/etc/"):
        return f"写系统配置（{path_str}）。"
    if "/.git/" in resolved.replace(str(ROOT), "", 1):
        return f"直接改 .git 内部文件（{path_str}）会绕过 git 自身的保护，用 git 命令代替。"
    return None


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except Exception as exc:  # noqa: BLE001 - 读不到输入时放行，见模块 docstring
        print(f"harness pre_tool_use: cannot read payload: {exc}", file=sys.stderr)
        print("{}")
        return

    tool = payload.get("tool_name", "")
    tool_input = payload.get("tool_input") or {}

    reason = None
    if tool == "Bash":
        reason = check_bash(tool_input.get("command", "") or "")
    elif tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
        reason = check_file_write(tool_input.get("file_path", "") or tool_input.get("notebook_path", "") or "")

    if reason:
        deny(reason)
    print("{}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001
        print(f"harness pre_tool_use: {exc}", file=sys.stderr)
        print("{}")
