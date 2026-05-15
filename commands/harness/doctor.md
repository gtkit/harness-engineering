---
name: Harness Doctor
description: Diagnose harness, OpenSpec, and optional MCP tool availability.
category: Harness
tags: [harness, doctor, diagnostics, openspec, mcp]
argument-hint: [optional focus]
---

# Harness Doctor

Run this before a complex task or after installing a harness.

## Guardrails

- Do not modify project files.
- Report missing tools as actionable warnings, not fatal errors, unless the requested workflow requires them.
- Prefer project facts over assumptions.
- Keep output in Chinese.

## Steps

1. Detect OS and shell.
2. Check project-level harness files:
   - `CLAUDE.md`
   - `AGENTS.md`
   - `.harness/guides/`
   - `.harness/scripts/`
   - `.harness/VERSION`
3. Check command installation:
   - `.claude/commands/harness/doctor.md`
   - `.claude/commands/harness/init-openspec.md`
   - `.claude/commands/harness/research.md`
   - `.claude/commands/harness/plan.md`
   - `.claude/commands/harness/implement.md`
   - `.claude/commands/harness/review.md`
4. Check optional OpenSpec:
   - `openspec --version`
   - `openspec/` directory
5. Check optional MCP tools if visible in the current runtime:
   - Codex MCP
   - Gemini MCP
   - codebase retrieval MCP
6. Check repository hygiene:
   - working tree status
   - current branch
   - test/CI entry points if obvious
7. Output:
   - Ready
   - Warnings
   - Required actions
   - Suggested next command

## Exit Criteria

- User can tell which workflow is available now.
- Missing prerequisites include exact remediation commands or next steps.
