# Laravel Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `laravel-harness` and `laravel-fullstack-harness` template generators, plus smoke-test and CI coverage, to this repository.

**Architecture:** Mirror the existing Go harness product line: each package gets its own `setup.sh`, `SKILL.md`, `CLAUDE.md`, `AGENTS.md`, and guide set; installation behavior matches existing harness packages; verification stays repository-local via smoke tests and CI, without introducing PHP runtime dependencies.

**Tech Stack:** Bash install scripts, Markdown guides, GitHub Actions workflow YAML

---

### Task 1: Add The Laravel Template Packages

**Files:**
- Create: `laravel-harness/setup.sh`
- Create: `laravel-harness/SKILL.md`
- Create: `laravel-harness/CLAUDE.md`
- Create: `laravel-harness/AGENTS.md`
- Create: `laravel-harness/guides/*.md`
- Create: `laravel-fullstack-harness/setup.sh`
- Create: `laravel-fullstack-harness/SKILL.md`
- Create: `laravel-fullstack-harness/CLAUDE.md`
- Create: `laravel-fullstack-harness/AGENTS.md`
- Create: `laravel-fullstack-harness/guides/*.md`

- [ ] Create both package directories with the approved guide sets.
- [ ] Keep setup behavior aligned with current Go harness packages: install skills, install project files, create or update `.gitignore`, preserve existing guides by default, preserve existing `error-journal.md`.
- [ ] Encode Laravel-specific rules: optional `nwidart/laravel-modules`, queues/events/scheduler/notifications required by default, fullstack `backend/` + `frontend/` constraints.

### Task 2: Add Repository Smoke Coverage

**Files:**
- Create: `tests/laravel_package_smoke_test.sh`
- Modify: `.github/workflows/ci.yml`

- [ ] Add a smoke test that asserts both Laravel packages exist and contain the expected rule coverage and structure.
- [ ] Fail on missing queue/scheduler/event/notification/module support or missing `backend/` + `frontend/` constraints.
- [ ] Wire the new smoke test into the existing `CI` workflow.

### Task 3: Update Root Documentation

**Files:**
- Modify: `README.md`

- [ ] Extend the root README from three harness packages to five.
- [ ] Document the two new Laravel install paths and post-install outputs.
- [ ] Keep terminology aligned with the approved spec and existing README style.

### Task 4: Verify End To End

**Files:**
- Verify: `tests/setup_smoke_test.sh`
- Verify: `tests/cpp_package_smoke_test.sh`
- Verify: `tests/laravel_package_smoke_test.sh`
- Verify: `.github/workflows/ci.yml`

- [ ] Run repository smoke tests and confirm they all pass.
- [ ] Run shell syntax validation for the existing Bash setup scripts.
- [ ] Review CI YAML to confirm it still only performs checks and does not deploy anything.
