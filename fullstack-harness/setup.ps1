Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$helperPath = Join-Path (Split-Path -Parent $scriptDir) "scripts\install-harness.ps1"
. $helperPath

$codexSkillContent = @'
---
name: fullstack-harness
description: Fullstack harness engineering skill for Go backend and Vue frontend projects.
---

# Fullstack Harness Skill

The complete project rules live in the project's AGENTS.md file.
Detailed project guides live in .harness/guides/.
'@

Invoke-HarnessSetup `
    -ScriptDir $scriptDir `
    -ModuleName "fullstack-harness" `
    -DisplayName "fullstack-harness" `
    -CodexSkillContent $codexSkillContent
