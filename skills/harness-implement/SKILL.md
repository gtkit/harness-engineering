---
name: harness-implement
description: Execute an approved zero-decision plan in small verified stages.
argument-hint: [proposal_id]
---

# Harness Implement

Use only after a plan is approved. Work through the plan task by task; do not stop after the first task unless a boundary below says so.

## Boundaries

- Scope is the approved plan (`openspec view` / active proposal, or the plan file the user points to). Anything outside it is reported, not done.
- Before the first edit read `AGENTS.md` / `CLAUDE.md`, the relevant `.harness/guides/*.md`, and `.harness/error-journal.md` if present.
- Each task: implement, run that task's verification, update OpenSpec task state if applicable, then continue. Treat external model output as a prototype and rewrite it to project style.
- Stop and report instead of continuing when: verification fails three times on the same problem, scope becomes unclear, or context is getting too large to work safely. Say exactly where you stopped and how to resume.
- Keep output in Chinese.

## Done When

All approved tasks are complete with their verifications run, or a clear checkpoint is reached. The final report lists completed tasks, files changed, verification commands with results, remaining tasks, and the resume command.
