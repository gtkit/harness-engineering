Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$helperPath = Join-Path (Split-Path -Parent $scriptDir) "scripts\install-harness.ps1"
. $helperPath

$codexSkillContent = @'
---
name: go-pkg-harness
description: Go package harness engineering skill for reusable libraries and packages.
---

# Go Package Harness Skill

The complete project rules live in the project's AGENTS.md file.
Detailed project guides live in .harness/guides/.
'@

Invoke-HarnessSetup `
    -ScriptDir $scriptDir `
    -ModuleName "go-pkg-harness" `
    -DisplayName "go-pkg-harness" `
    -CodexSkillContent $codexSkillContent
