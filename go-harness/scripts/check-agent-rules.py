#!/usr/bin/env python3
"""Compare project rule bodies without rewriting either client entry point."""
from __future__ import annotations

import argparse
import difflib
import sys
from pathlib import Path

BODY_START = "## 行为纪律（铁律）\n"


def rule_body(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    if text.count(BODY_START) != 1:
        raise ValueError(f"{path.name}: expected one shared rule body")
    return BODY_START + text.split(BODY_START, 1)[1]


def check_rules(root: Path) -> bool:
    agents = rule_body(root / "AGENTS.md")
    claude = rule_body(root / "CLAUDE.md")
    if agents == claude:
        return True
    sys.stderr.writelines(difflib.unified_diff(
        agents.splitlines(keepends=True), claude.splitlines(keepends=True),
        fromfile="AGENTS.md shared rules", tofile="CLAUDE.md shared rules",
    ))
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repo", nargs="?", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    try:
        if not check_rules(args.repo):
            print("[harness] project rule bodies differ", file=sys.stderr)
            return 1
    except (OSError, ValueError) as exc:
        print(f"[harness] {exc}", file=sys.stderr)
        return 1
    print("[harness] project rule bodies match (read-only check)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
