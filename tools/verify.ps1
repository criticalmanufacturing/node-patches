<#
.SYNOPSIS
  Checks that a node.exe passes the CVE regression tests in tests\cve and carries the CM build stamp.
.DESCRIPTION
  Runs tests\run.js with the given binary: every CVE must be fixed. It also checks that every CVE
  listed in the version's build.json has a test, that node -v is v<base>+cm.<patch_level>, that
  process.config lists the CVEs, and that the release URLs point at the official base-version headers.
  If -Source points to the patched source tree, it also runs test/parallel/test-zlib-invalid-input.js.
.EXAMPLE
  .\tools\verify.ps1 -Node C:\app\node.exe -Version v12.22.12
#>
param(
  [Parameter(Mandatory)][string]$Node,
  [Parameter(Mandatory)][string]$Version,
  [string]$Source,
  # Skip the +cm.<patch_level> / cm_patches checks (for binaries built before stamping existed).
  [switch]$NoStampCheck
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$cfg = Get-Content (Join-Path $root "$Version\build.json") -Raw | ConvertFrom-Json

$ok = $true
foreach ($c in $cfg.cves) {
  if (-not (Test-Path (Join-Path $root "tests\cve\$c.js"))) { "  no tests\cve\$c.js"; $ok = $false }
}
& $Node (Join-Path $root 'tests\run.js') 2>&1 | ForEach-Object { "  $_" }
$ok = $ok -and $LASTEXITCODE -eq 0

if (-not $NoStampCheck) {
  $base = $cfg.tag.TrimStart('v')
  $want = "v$base+cm.$($cfg.patch_level)"
  $info = & $Node -p "[process.version, process.config.variables.cm_patches, process.release.headersUrl].join('|')"
  $ver, $patches, $headers = $info -split '\|'
  "  version: $ver  cm_patches: $patches"
  "  headersUrl: $headers"
  $stampOk = $ver -eq $want -and
             (@($cfg.cves | Where-Object { ($patches -split ',') -notcontains $_ }).Count -eq 0) -and
             $headers -like "*/v$base/node-v$base-headers.tar.gz"
  if (-not $stampOk) { "  STAMP MISMATCH (expected $want, CVEs $($cfg.cves -join ','), base-version headers)" }
  $ok = $ok -and $stampOk
}
if ($Source) {
  & $Node (Join-Path $Source 'test\parallel\test-zlib-invalid-input.js') *> $null
  $testOk = $LASTEXITCODE -eq 0
  "  test-zlib-invalid-input.js: $(if ($testOk) { 'pass' } else { 'FAIL' })"
  $ok = $ok -and $testOk
}
if ($ok) { "PATCHED: $Node" }
else { Write-Error "NOT PATCHED (or unexpected output): $Node" }
