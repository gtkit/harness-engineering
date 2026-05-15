---
name: Harness Implement
description: Execute an approved zero-decision plan in small verified stages.
category: Harness
tags: [harness, implementation, openspec]
argument-hint: [proposal_id]
---

# Harness Implement

Use this only after a plan is approved.

## Guardrails

- Keep changes scoped to the approved plan.
- Do not apply external model output directly. Treat it as a prototype and rewrite to match project style.
- After each stage, run the stage verification before continuing.
- If context is getting too large, stop at a checkpoint and tell the user how to resume.
- Keep output in Chinese.

## Steps

1. Identify the approved plan:
   - `openspec view` / active proposal if available
   - otherwise ask for the plan file or approved task list
2. Read:
   - `AGENTS.md` / `CLAUDE.md`
   - relevant `.harness/guides/*.md`
   - `.harness/error-journal.md` if present
3. Pick the smallest next verifiable task.
4. Implement only that task.
5. Run the task verification.
6. Update OpenSpec task state if applicable.
7. Repeat only while:
   - verification passes
   - scope remains clear
   - context remains manageable
8. Before stopping, report:
   - completed tasks
   - files changed
   - verification commands and results
   - remaining tasks
   - next resume command

## Exit Criteria

- All approved tasks are complete, or a clear checkpoint is reached.
- Verification evidence is recorded in the response.
