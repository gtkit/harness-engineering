---
name: harness-implement
description: Execute an approved zero-decision plan in small verified stages.
argument-hint: [proposal_id]
---

# Harness Implement

Use only after a plan is approved. Work through the plan task by task; do not stop after the first task unless a boundary below says so.

## Boundaries

- Scope is the approved plan (`openspec view` / active proposal, or the plan file the user points to). Anything outside it is reported, not done.
- Before the first edit read `AGENTS.md` / `CLAUDE.md`, the relevant `.harness/guides/*.md`, and `.harness/error-journal.md` if present. In a Go project that includes `.harness/guides/skills-index.md`: pick the Go skills it maps to this task and invoke them before the first edit, not while writing.
- Each task: implement, run that task's verification, update OpenSpec task state if applicable, then continue. Treat external model output as a prototype and rewrite it to project style.
- Stop and report instead of continuing when: verification fails three times on the same problem, scope becomes unclear, or context is getting too large to work safely. Say exactly where you stopped and how to resume.
- Keep output in Chinese.

## Project Session Contract

This section applies when `.harness/guides/workflow-contract.md` and `.harness/scripts/workflow.py` are installed. A harness installed with `--no-openspec` still requires the saved approved plan, but must not invoke missing OpenSpec/session tools.

For code tasks, follow `.harness/guides/workflow-contract.md`: use the actual runtime session ID, read the saved plan and required context through `workflow.py read`, then activate it. Use file tools for exact planned targets and `workflow.py run --check ID` for declared checks. Call `ready` only after functional evidence exists; controlled checks still need later explicit user authorization. Finish through recorded evidence, or use `checkpoint` to report incomplete work without claiming success. Do not import another session's state, handwrite passing receipts, or apply this code workflow to pure documentation requests.

## Done When

All approved tasks are complete with their verifications run, or a clear checkpoint is reached. The final report lists completed tasks, files changed, verification commands with results, remaining tasks, and the resume command.
