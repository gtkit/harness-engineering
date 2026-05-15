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
3. Check whether `openspec/` exists in the project.
4. If missing, ask for confirmation, then run:
   ```bash
   openspec init --tools claude
   ```
5. Validate initialization:
   ```bash
   openspec view
   ```
6. Report:
   - OpenSpec CLI status
   - project initialization status
   - next recommended command: `/harness:research`

## Exit Criteria

- `openspec view` works, or the user receives a concrete blocker and remediation path.
