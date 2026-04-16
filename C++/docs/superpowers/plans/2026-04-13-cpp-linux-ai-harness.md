# C++ Linux AI Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land a reusable enterprise harness for C++ Linux AI projects, including governance docs, validation gates, error memory, skill packaging, and a detailed README.

**Architecture:** Keep the implementation documentation-first and non-invasive. Add a root `AGENTS.md`, a `.harness/` governance tree, a repo-local reusable skill under `.harness/skills/`, and a dedicated harness README without replacing the existing project overview README.

**Tech Stack:** Markdown, YAML, POSIX shell, repository-local documentation assets

---

### Task 1: Create Governance Entry Points

**Files:**
- Create: `AGENTS.md`
- Create: `.harness/error-journal.md`

- [x] **Step 1: Write the governance rules**

Add project entry rules that enforce:
- reading `.harness/error-journal.md` first
- strict structured output
- no fabrication / no guessing
- validation and review before completion

- [x] **Step 2: Create the error journal bootstrap entry**

Add:
- template entry format
- one initial bootstrap entry
- rules for read-before-work and append-on-failure

- [x] **Step 3: Verify files exist**

Run:
```bash
test -f AGENTS.md && test -f .harness/error-journal.md
```

Expected: exit 0

### Task 2: Create Harness Guides

**Files:**
- Create: `.harness/guides/architecture.md`
- Create: `.harness/guides/cpp-coding.md`
- Create: `.harness/guides/linux-systems.md`
- Create: `.harness/guides/ai-engineering.md`
- Create: `.harness/guides/build-and-toolchain.md`
- Create: `.harness/guides/testing-and-validation.md`
- Create: `.harness/guides/review-checklist.md`

- [x] **Step 1: Add architecture and coding guides**
- [x] **Step 2: Add Linux and AI runtime guides**
- [x] **Step 3: Add build, validation, and review guides**
- [x] **Step 4: Verify files exist**

Run:
```bash
test -f .harness/guides/architecture.md && test -f .harness/guides/review-checklist.md
```

Expected: exit 0

### Task 3: Create Checklists, Validation, Reviews, and Templates

**Files:**
- Create: `.harness/checklists/pre-commit.md`
- Create: `.harness/checklists/pre-merge.md`
- Create: `.harness/checklists/pre-release.md`
- Create: `.harness/validation/test-matrix.md`
- Create: `.harness/validation/cross-validation.md`
- Create: `.harness/validation/regression-policy.md`
- Create: `.harness/reviews/risk-register.md`
- Create: `.harness/reviews/hidden-risk-checklist.md`
- Create: `.harness/templates/task-output-template.md`
- Create: `.harness/templates/review-report-template.md`
- Create: `.harness/templates/test-report-template.md`

- [x] **Step 1: Add checklists**
- [x] **Step 2: Add validation policy and matrix**
- [x] **Step 3: Add risk review docs**
- [x] **Step 4: Add output templates**
- [x] **Step 5: Verify directories and files**

Run:
```bash
test -f .harness/checklists/pre-commit.md && test -f .harness/templates/test-report-template.md
```

Expected: exit 0

### Task 4: Package the Repo-Local Skill

**Files:**
- Create: `.harness/skills/cpp-linux-ai-harness/SKILL.md`
- Create: `.harness/skills/cpp-linux-ai-harness/agents/openai.yaml`
- Create: `.harness/skills/cpp-linux-ai-harness/references/project-scope.md`
- Create: `.harness/skills/cpp-linux-ai-harness/references/workflow.md`
- Create: `.harness/skills/cpp-linux-ai-harness/references/error-memory.md`
- Create: `.harness/skills/cpp-linux-ai-harness/references/review-standard.md`
- Create: `.harness/skills/cpp-linux-ai-harness/references/validation-standard.md`
- Create: `.harness/skills/cpp-linux-ai-harness/references/output-contract.md`
- Create: `.harness/skills/cpp-linux-ai-harness/scripts/read_error_journal.sh`
- Create: `.harness/skills/cpp-linux-ai-harness/scripts/append_error_journal.sh`

- [x] **Step 1: Create SKILL.md and metadata**
- [x] **Step 2: Create references**
- [x] **Step 3: Create helper scripts**
- [x] **Step 4: Mark scripts executable**

Run:
```bash
chmod +x .harness/skills/cpp-linux-ai-harness/scripts/*.sh
```

Expected: exit 0

- [x] **Step 5: Validate metadata and script presence**

Run:
```bash
test -f .harness/skills/cpp-linux-ai-harness/agents/openai.yaml && test -x .harness/skills/cpp-linux-ai-harness/scripts/read_error_journal.sh
```

Expected: exit 0

### Task 5: Write Detailed README and Link It

**Files:**
- Create: `doc/harness/README.md`
- Modify: `README.md`

- [x] **Step 1: Write a dedicated harness README**
- [x] **Step 2: Add a short entry link into the root README**
- [x] **Step 3: Verify the new README path exists**

Run:
```bash
test -f doc/harness/README.md
```

Expected: exit 0

### Task 6: Create Spec Artifacts for Auditability

**Files:**
- Create: `openspec/changes/cpp-linux-ai-harness/proposal.md`
- Create: `openspec/changes/cpp-linux-ai-harness/spec.md`
- Create: `openspec/changes/cpp-linux-ai-harness/tasks.md`
- Create: `docs/superpowers/plans/2026-04-13-cpp-linux-ai-harness.md`

- [x] **Step 1: Write proposal**
- [x] **Step 2: Write spec**
- [x] **Step 3: Write tasks**
- [x] **Step 4: Save implementation plan**

### Task 7: Final Verification

**Files:**
- Verify only

- [x] **Step 1: List all created files**

Run:
```bash
rg --files AGENTS.md .harness doc/harness openspec/changes/cpp-linux-ai-harness docs/superpowers/plans
```

Expected: required files listed

- [x] **Step 2: Validate skill metadata format**

Run:
```bash
ruby -e 'require "yaml"; p YAML.load_file(".harness/skills/cpp-linux-ai-harness/agents/openai.yaml")'
```

Expected: parsed hash output

- [x] **Step 3: Verify helper scripts**

Run:
```bash
.harness/skills/cpp-linux-ai-harness/scripts/read_error_journal.sh .
```

Expected: prints the beginning of `.harness/error-journal.md`

- [x] **Step 4: Review git diff**

Run:
```bash
git diff -- AGENTS.md .harness doc/harness README.md openspec/changes/cpp-linux-ai-harness docs/superpowers/plans/2026-04-13-cpp-linux-ai-harness.md
```

Expected: only harness-related documentation and script changes
