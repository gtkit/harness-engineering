---
name: harness-doctor
description: Diagnose harness, OpenSpec, and optional MCP tool availability.
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
3. Check skill installation (Claude Code and Codex read the same six skills from different directories):
   - `.claude/skills/harness-{doctor,init-openspec,research,plan,implement,review}/SKILL.md`
   - `.agents/skills/harness-{doctor,init-openspec,research,plan,implement,review}/SKILL.md`
   - `.claude/rules/harness-*.md` (path-scoped pointers to `.harness/guides/`; Claude Code only)
4. Check optional OpenSpec:
   - `openspec --version`
   - `openspec/` directory
   - `openspec-auto` repo-local workflow, if installed:
     - `.openspec-auto/version`
     - `.claude/hooks/openspec_*.py` and `.claude/skills/openspec-auto/SKILL.md`
     - `OPENSPEC-AUTO:START` managed block present in both `CLAUDE.md` and `AGENTS.md`
     - run `openspec-auto doctor .` (or `bash tools/openspec/healthcheck.sh .`) and report its result
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
