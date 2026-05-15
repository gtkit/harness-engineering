---
name: Harness Research
description: Convert a user request into constraint sets and verifiable success criteria.
category: Harness
tags: [harness, research, constraints, openspec]
argument-hint: <user request>
---

# Harness Research

Use this before planning complex or risky changes.

## Core Output

Produce a constraint set, not an information dump.

## Guardrails

- If `openspec/` is missing, recommend `/harness:init-openspec`.
- Do not make implementation decisions during research.
- Ask the user when ambiguity blocks the constraint set.
- Divide exploration by context boundaries, not agent roles.
- Keep output in Chinese.

## Steps

1. Capture the user request verbatim.
2. Inspect project harness context:
   - `AGENTS.md` or `CLAUDE.md`
   - relevant `.harness/guides/*.md`
   - existing source layout
3. Identify context boundaries, for example:
   - backend API
   - data layer
   - frontend UI
   - auth / payment / LLM / queue
   - package API surface
4. Explore each boundary and produce the same structured report:
   ```json
   {
     "module_name": "context boundary",
     "existing_structures": [],
     "existing_conventions": [],
     "hard_constraints": [],
     "soft_constraints": [],
     "dependencies": [],
     "risks": [],
     "open_questions": [],
     "success_criteria_hints": []
   }
   ```
5. Aggregate into:
   - hard constraints
   - soft constraints
   - dependencies
   - risks
   - open questions
   - verifiable success criteria
6. If OpenSpec is available, create or update a proposal draft.
7. Stop before planning. Ask the user to approve the constraint set.

## Exit Criteria

- The request has explicit constraints and success criteria.
- Open questions are either answered by the user or listed as blockers.
