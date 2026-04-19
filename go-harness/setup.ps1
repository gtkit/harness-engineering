Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$helperPath = Join-Path (Split-Path -Parent $scriptDir) "scripts\install-harness.ps1"
. $helperPath

$codexSkillContent = @'
---
name: go-harness
description: Go backend harness engineering skill for Gin, GORM, and gtkit projects.
---

# Go Harness Skill

The complete project rules live in the project's AGENTS.md file.
Detailed project guides live in .harness/guides/.
'@

Invoke-HarnessSetup `
    -ScriptDir $scriptDir `
    -ModuleName "go-harness" `
    -DisplayName "go-harness" `
    -CodexSkillContent $codexSkillContent
