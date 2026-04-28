param(
    [string]$RepoRoot = "."
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$filePath = Join-Path $RepoRoot ".harness\error-journal.md"

if (-not (Test-Path -LiteralPath $filePath)) {
    throw "missing: $filePath"
}

Get-Content -LiteralPath $filePath -TotalCount 240
