param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,
    [Parameter(Mandatory = $true)]
    [string]$EventType,
    [Parameter(Mandatory = $true)]
    [string]$Area,
    [Parameter(Mandatory = $true)]
    [string]$Summary
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$filePath = Join-Path $RepoRoot ".harness\error-journal.md"
if (-not (Test-Path -LiteralPath $filePath)) {
    throw "missing: $filePath"
}

$day = Get-Date -Format "yyyyMMdd"
$stamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
$existing = @(Select-String -LiteralPath $filePath -Pattern '^## \[ERR-' -AllMatches)
$seq = "{0:D3}" -f ($existing.Count + 1)
$entryId = "ERR-$day-$seq"

$entry = @"

## [$entryId] $EventType

**Logged**: $stamp
**Status**: open
**Area**: $Area

### Summary
$Summary

### What Happened
待补充

### Root Cause
待补充

### Corrective Action
待补充

### Prevention Rule
待补充

### Related Files
- 待补充

### Validation Added
- 待补充

---
"@

Add-Content -LiteralPath $filePath -Value $entry
Write-Output $entryId
