---
name: Harness Review
description: Review current changes against harness quality gates and project guides.
category: Harness
tags: [harness, review, quality]
argument-hint: [optional scope]
---

# Harness Review

Use this before final delivery or before asking for human review.

## Guardrails

- Lead with findings by severity.
- Do not summarize first if there are defects.
- Use file paths and line references where possible.
- Keep output in Chinese.

## Steps

1. Inspect changed files:
   ```bash
   git status --short
   git diff --stat
   git diff --check
   ```
2. Load relevant guides:
   - `.harness/guides/review-checklist.md` or package review guide
   - architecture / frontend / database guide as relevant
3. Review for:
   - correctness
   - security
   - performance
   - architecture and layering
   - code quality gate（代码质量门禁）
   - observability
   - compatibility and migration
   - tests and verification
4. Run available verification commands from the plan or guides.
5. Output:
   - Critical findings
   - Important findings
   - Minor findings
   - Test gaps
   - Verification run
   - Ready / not ready recommendation

## Exit Criteria

- The user can see whether the change is ready to deliver.
- Any remaining risk is explicit.
