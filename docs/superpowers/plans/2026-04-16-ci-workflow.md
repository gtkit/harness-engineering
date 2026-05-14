# CI Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a minimal GitHub Actions CI workflow that runs shell syntax validation and the repository smoke test on `push` and `pull_request` targeting `main`.

**Architecture:** Keep the workflow intentionally small: one workflow file, one job, sequential steps, no deploy behavior, no secrets, and no matrix. Extend the existing smoke test so the repository verifies the workflow contract locally instead of trusting the YAML by inspection.

**Tech Stack:** GitHub Actions workflow YAML, Bash smoke tests

---

### Task 1: Lock The CI Contract In Tests

**Files:**
- Modify: `tests/setup_smoke_test.sh`

- [ ] Add assertions that fail until `.github/workflows/ci.yml` exists and contains the expected trigger and command patterns.
- [ ] Run `bash tests/setup_smoke_test.sh` and confirm it fails because the workflow file does not exist yet.

### Task 2: Add The Minimal Workflow

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] Create one GitHub Actions workflow named `CI`.
- [ ] Trigger on `push` to `main` and `pull_request` targeting `main`.
- [ ] Run one job on `ubuntu-latest` with checkout, shell syntax validation, and the smoke test.

### Task 3: Verify End To End

**Files:**
- Verify: `.github/workflows/ci.yml`
- Verify: `tests/setup_smoke_test.sh`

- [ ] Run `bash tests/setup_smoke_test.sh` and confirm it passes.
- [ ] Run `gitHub`-independent local validation: `bash -n go-harness/setup.sh fullstack-harness/setup.sh go-pkg-harness/setup.sh`.
- [ ] Review the workflow file to ensure it does not include deploy steps, secrets, or non-`main` triggers.
