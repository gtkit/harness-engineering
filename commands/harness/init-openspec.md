---
name: Harness Init OpenSpec
description: Initialize or verify OpenSpec for the current harness project.
category: Harness
tags: [harness, openspec, init]
---

# Harness Init OpenSpec

Initialize OpenSpec only when the project needs proposal-driven changes.

## Guardrails

- Ask before installing global tools.
- Do not overwrite existing OpenSpec files without confirmation.
- Adapt commands for Windows, macOS, or Linux.
- Keep output in Chinese.

## Steps

1. Detect OS and package manager availability.
2. Check whether `openspec` exists:
   - `openspec --version`
   - if missing, find the current official/project-documented install command and ask before running it
   - do not guess or hard-code an install package name
3. Check whether the project already has OpenSpec:
   - `openspec/` directory
   - `.openspec-auto/version` (installed by `openspec-auto`, the repo-local auto workflow: hooks + skills + managed blocks in `CLAUDE.md` / `AGENTS.md`)
4. If `.openspec-auto/version` exists, run the healthcheck instead of re-initializing:
   ```bash
   openspec-auto doctor .
   ```
   or, when the binary is not on PATH:
   ```bash
   bash tools/openspec/healthcheck.sh .
   ```
5. If nothing is installed, prefer `openspec-auto` (it runs `openspec init --tools none` itself and takes over the Claude / Codex integration). Ask for confirmation, then run:
   ```bash
   openspec-auto install .
   ```
   Only when `openspec-auto` is unavailable and the user does not want to install it, fall back to the bare CLI:
   ```bash
   openspec init --tools claude
   ```
6. Validate initialization:
   ```bash
   openspec list --json
   ```
7. Report:
   - OpenSpec CLI status
   - project initialization status (`openspec/` present; `openspec-auto` installed or not)
   - next recommended command: `/harness:research`

## Exit Criteria

- `openspec list --json` works, or the user receives a concrete blocker and remediation path.
