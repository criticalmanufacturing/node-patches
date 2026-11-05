<#
.SYNOPSIS
  Clones an upstream Node.js release tag, applies this repo's patches for it and builds a win-x64 node.exe.
.EXAMPLE
  .\tools\build.ps1 -Version v12.22.12 -PythonDir C:\tools\python27 -NasmDir C:\tools\nasm -WorkDir D:\NodeBuild
.NOTES
  A build needs 10-15 GB free in WorkDir. Output: <WorkDir>\dist\node-<Version>-patched-win-x64\
#>
param(
  [Parameter(Mandatory)][string]$Version,
  [Parameter(Mandatory)][string]$PythonDir,
  [Parameter(Mandatory)][string]$NasmDir,
  [string]$WorkDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'work'),
  [switch]$PatchOnly
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$verDir = Join-Path $root $Version
if (-not (Test-Path "$verDir\build.json")) { throw "No $Version\build.json in this repo." }
$cfg = Get-Content "$verDir\build.json" -Raw | ConvertFrom-Json

$pyVer = (& "$PythonDir\python.exe" --version 2>&1) -join ''
if ($pyVer -notmatch "Python $([regex]::Escape($cfg.python))\.") { throw "$Version needs Python $($cfg.python); $PythonDir has '$pyVer'." }

$src = Join-Path $WorkDir $Version
if (-not (Test-Path "$src\.git")) {
  git -c core.longpaths=true clone --depth 1 --branch $cfg.tag https://github.com/nodejs/node.git $src
  if ($LASTEXITCODE) { throw 'clone failed' }
}
# Start from the pristine tag every time, then apply the patch series in order.
git -C $src checkout -q -f -B patched $cfg.tag
git -C $src clean -xdfq
$patches = Get-ChildItem "$verDir\patches\*.patch" | Sort-Object Name
git -C $src am -q $patches.FullName
if ($LASTEXITCODE) { git -C $src am --abort; throw "Patches failed to apply to $($cfg.tag)." }
Write-Host "Applied $($patches.Count) patch(es) to $($cfg.tag):"
git -C $src log --oneline "$($cfg.tag)..HEAD"
if ($PatchOnly) { return }

$env:PYTHON_DIR = $PythonDir
$env:NASM_DIR = $NasmDir
$log = Join-Path $WorkDir "build-$Version.log"
cmd /c "`"$PSScriptRoot\build-node.cmd`" `"$src`" $($cfg.vcvars_ver) $($cfg.gyp_msvs_version) $($cfg.platform_toolset) $($cfg.intl) > `"$log`" 2>&1"
if ($LASTEXITCODE) { Get-Content $log -Tail 30; throw "Build failed, see $log" }

$out = Join-Path $src $cfg.output
$dist = Join-Path $WorkDir "dist\node-$Version-patched-win-x64"
New-Item -ItemType Directory -Force $dist | Out-Null
Copy-Item "$out\node.exe", "$out\node.pdb" $dist
Copy-Item $patches.FullName $dist
Get-ChildItem $dist -File -Exclude SHA256SUMS.txt |
  ForEach-Object { '{0}  {1}' -f (Get-FileHash $_.FullName).Hash.ToLower(), $_.Name } |
  Set-Content -Encoding ascii "$dist\SHA256SUMS.txt"
Write-Host "Built $dist"
& "$PSScriptRoot\verify.ps1" -Node "$dist\node.exe" -Version $Version -Source $src
