<#
.SYNOPSIS
  Checks that a node.exe carries the CVE-2026-111497 fix.
.DESCRIPTION
  Feeds the upstream regression input to zlib.brotliDecompressSync and to a byte-by-byte stream.
  A patched binary rejects it with errno -17 (BLOCK_SWITCH). An unpatched one fails later with -9.
  If -Source points to the patched source tree, it also runs test/parallel/test-zlib-invalid-input.js.
.EXAMPLE
  .\tools\verify.ps1 -Node C:\app\node.exe -Version v12.22.12
#>
param(
  [Parameter(Mandatory)][string]$Node,
  [Parameter(Mandatory)][string]$Version,
  [string]$Source
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$cfg = Get-Content (Join-Path $root "$Version\build.json") -Raw | ConvertFrom-Json
$out = & $Node "$PSScriptRoot\cve-2026-111497-check.js" 2>&1
$out | ForEach-Object { "  $_" }
$expected = "error $($cfg.brotli_error_code) -17"
$ok = ($out -match 'BLOCK_SWITCH const = -17').Count -eq 1 -and
      ($out -match "SYNC: $expected").Count -eq 1 -and
      ($out -match "STREAM: $expected").Count -eq 1
if ($Source) {
  & $Node (Join-Path $Source 'test\parallel\test-zlib-invalid-input.js') *> $null
  $testOk = $LASTEXITCODE -eq 0
  "  test-zlib-invalid-input.js: $(if ($testOk) { 'pass' } else { 'FAIL' })"
  $ok = $ok -and $testOk
}
if ($ok) { "PATCHED: $Node rejects the CVE-2026-111497 input at the block switch." }
else { Write-Error "NOT PATCHED (or unexpected output): $Node" }
