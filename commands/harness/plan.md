---
name: Harness Plan
description: Turn an approved constraint set into a zero-decision implementation plan with test properties.
category: Harness
tags: [harness, plan, pbt, openspec]
argument-hint: [proposal_id]
---

# Harness Plan

Use this after `/harness:research`.

## Guardrails

- Do not implement code.
- Every ambiguity must become a concrete decision or a user question.
- The implementation phase should not need architectural judgment.
- Keep output in Chinese.

## Steps

1. Find the active proposal:
   - run `openspec view` if available
   - otherwise ask the user which constraint set to plan
2. Review the proposal / constraints against harness guides.
3. Identify remaining decision points:
   - technology choices
   - file ownership
   - interface contracts
   - error behavior
   - migration strategy
   - test strategy
4. Ask the user for any decision that cannot be resolved from project facts.
5. Write a zero-decision plan:
   ```markdown
   ## Goal
   ## Constraints
   ## Files To Change
   ## Sequential Tasks
   ## Verification Per Task
   ## Rollback / Migration Notes
   ## Out Of Scope
   ```
6. Extract property-style test targets where useful:
   - invariant
   - boundary condition
   - falsification strategy
   - counterexample examples
7. If OpenSpec is available, validate:
   ```bash
   openspec validate <proposal_id> --strict
   ```
8. Stop and request explicit approval before implementation.

## Exit Criteria

- No unresolved decision points remain.
- Every task has a verification command or observable check.
- The user has approved the plan.
