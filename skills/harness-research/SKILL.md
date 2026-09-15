---
name: harness-research
description: Convert a user request into constraint sets and verifiable success criteria.
argument-hint: <user request>
---

# Harness Research

Use before planning complex or risky changes. Output is a constraint set, not an information dump, and no code is written.

## Boundaries

- Read `AGENTS.md` / `CLAUDE.md`, the relevant `.harness/guides/*.md`, and the existing source layout; explore each affected context boundary (backend API, data layer, frontend, auth / payment / LLM / queue, package API surface) rather than the whole repository.
- Do not make implementation decisions; record them as open questions.
- Ask the user only when an ambiguity blocks the constraint set. Everything else becomes an explicit assumption in the output.
- If `openspec/` is missing, recommend `/harness-init-openspec`. If OpenSpec is available, create or update the proposal draft from the result.
- Keep output in Chinese.

## Output

Per context boundary, then aggregated:

- hard constraints / soft constraints
- dependencies
- risks
- open questions (each with the decision it blocks)
- verifiable success criteria (each one an observable check, not a feeling)

## Done When

The request has explicit constraints and success criteria, open questions are either answered or listed as blockers, and the user has been asked to approve the constraint set before any planning starts.
