---
name: harness-doctor
description: Diagnose harness files, required technical skills, OpenSpec, and optional MCP tool availability without installing anything.
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
   - Identify the harness from `.harness/VERSION` (`harness:`) or project facts; if ambiguous, report it as unverified.
   - Read `references/skill-dependencies.md` for the harness and current task/phase. Check external technical skills as well as the six workflow skills.
   - Use the skill list exposed by the current runtime first. If needed, check project `.claude/skills` / `.agents/skills` and the active runtime's user skill roots (`~/.claude/skills`, `~/.agents/skills`, `$CODEX_HOME/skills` or `~/.codex/skills`). Do not scan credentials or entire user directories.
   - Record exact resolved paths and overrides. A readable file proves presence, not automatic discovery or execution; report those states separately. Multiple differing copies require identifying which one is active.
   - Missing optional skills are warnings. Missing task/phase requirements allow independent work within the user's existing authorization, including implementation supported by available project rules, but block the corresponding unverified gate/readiness conclusion. Do not invent the missing skill, silently skip a required gate, or stop all authorized work just because a reference skill is absent.
   - Give a source-specific sync/install suggestion using the known skills repository; do not run it without authorization, fetch arbitrary packages, or refresh unrelated projects.
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
   - Ready for which phase (research / implementation / validation / release); never a blanket Ready from file presence
   - Per dependency: task/phase, required or conditional, resolved path, presence/discovery/execution status
   - Warnings
   - Required actions
   - Suggested next command

## Exit Criteria

- User can tell which workflow is available now.
- Missing prerequisites include exact remediation commands or next steps.
