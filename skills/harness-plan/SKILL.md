---
name: harness-plan
description: Turn an approved constraint set into a zero-decision implementation plan with test properties.
argument-hint: [proposal_id]
---

# Harness Plan

Use after `/harness-research` has been approved. The plan must be executable without architectural judgment; no code is written here.

## Boundaries

- Start from the approved constraint set: the active OpenSpec proposal (`openspec view`) when available, otherwise ask which constraint set to plan.
- Every remaining decision point (technology choice, file ownership, interface contract, error behavior, migration strategy, test strategy) becomes either a concrete decision grounded in project facts and harness guides, or a question to the user. None may be left for the implementer.
- If OpenSpec is available, run `openspec validate <proposal_id> --strict` on the result.
- Keep output in Chinese.

## Output

```markdown
## Goal
## Constraints
## Files To Change
## Sequential Tasks          # each task with its own verification command or observable check
## Verification Per Task
## Rollback / Migration Notes
## Out Of Scope
```

Where useful, add property-style test targets: invariant, boundary condition, falsification strategy, counterexamples.

## Done When

No unresolved decision points remain, every task has a verification, and the user has explicitly approved the plan. Implementation does not start until then.
