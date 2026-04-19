# Windows Setup Scripts Design

## Goal

Add native Windows setup entrypoints for the five harness modules:

- `go-harness`
- `fullstack-harness`
- `go-pkg-harness`
- `laravel-harness`
- `laravel-fullstack-harness`

Each module should support both PowerShell and `cmd.exe` users through:

- `setup.ps1`
- `setup.bat`

The Windows flow must preserve the behavior of the existing `setup.sh` scripts:

- install the global Claude skill
- install the global Codex skill
- install project-level files into the current working directory
- preserve existing project files unless forced
- update `.gitignore` idempotently

## Approaches Considered

### Recommended: PowerShell primary implementation plus batch launcher

Implement all installation logic in `setup.ps1`, then keep `setup.bat` as a thin launcher that forwards execution to PowerShell.

Pros:

- one source of truth per module on Windows
- better path, file, and text handling than pure batch
- easier to test and maintain

Cons:

- `setup.bat` depends on PowerShell being available, which is acceptable on supported Windows systems

### Rejected: full logic duplicated in both `setup.ps1` and `setup.bat`

This improves direct `cmd.exe` ergonomics but doubles maintenance and raises drift risk across five modules.

### Rejected: wrappers that require Git Bash

This keeps one implementation but is not a native Windows experience and adds an avoidable dependency.

## Design

### Script layout

Each of the five modules will contain:

- `setup.sh` for macOS and Linux
- `setup.ps1` for Windows PowerShell
- `setup.bat` for `cmd.exe`

### PowerShell behavior

`setup.ps1` will:

1. Resolve `SCRIPT_DIR` from the script location.
2. Resolve `PROJECT_DIR` from the current working directory.
3. Read `HARNESS_FORCE_GUIDES` from the environment and default it to `0`.
4. Validate the presence of required source files and `guides/`.
5. Copy global skill files into:
   - `$HOME/.claude/skills/<module>/SKILL.md`
   - `$CODEX_HOME/skills/<module>/SKILL.md`, defaulting `CODEX_HOME` to `$HOME/.codex`
6. Create or preserve `CLAUDE.md`, `AGENTS.md`, `.harness/guides/`, and `.harness/error-journal.md`.
7. Copy guide files while skipping `error-journal-template.md`.
8. Preserve existing guide files unless `HARNESS_FORCE_GUIDES=1`.
9. Create or update `.gitignore` without duplicating lines.

### Batch behavior

`setup.bat` will:

1. Resolve its own directory.
2. Call the sibling `setup.ps1`.
3. Forward the current environment so `HARNESS_FORCE_GUIDES` and `CODEX_HOME` still work.
4. Exit non-zero if PowerShell execution fails.

## Verification

Add a Windows smoke test script that verifies:

- each module contains both `setup.ps1` and `setup.bat`
- `setup.ps1` installs expected project files
- rerunning the script preserves local guide edits when not forced
- `setup.bat` can invoke the PowerShell implementation
- `.gitignore` rules remain idempotent

README documentation will be updated to show Windows usage for all five modules.
