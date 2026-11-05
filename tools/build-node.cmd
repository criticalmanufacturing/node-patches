@echo off
rem Builds Node.js (win-x64, Release, LTCG) with an older MSVC toolset hosted in a newer Visual Studio.
rem Replicates what vcbuild.bat does, since vcbuild.bat only detects the VS versions of its era.
rem Normally called by build.ps1.
rem Usage: build-node.cmd <srcdir> <vcvars_ver> <gyp_msvs_version> <platform_toolset> <intl>
rem Environment: PYTHON_DIR (folder with python.exe of the version build.json asks for),
rem              NASM_DIR (folder with nasm.exe), optional VSROOT (VS install to use).
setlocal
set SRC=%~1
set VCVER=%~2
set GYPVER=%~3
set TOOLSET=%~4
set INTL=%~5
if not defined PYTHON_DIR (echo [build] PYTHON_DIR is not set & exit /b 1)
if not defined NASM_DIR (echo [build] NASM_DIR is not set & exit /b 1)
set "PATH=%PYTHON_DIR%;%NASM_DIR%;%PATH%"

if not defined VSROOT for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -property installationPath`) do set "VSROOT=%%i"
set VSINSTALLDIR=
call "%VSROOT%\VC\Auxiliary\Build\vcvarsall.bat" amd64 -vcvars_ver=%VCVER%
if errorlevel 1 (echo [build] vcvarsall -vcvars_ver=%VCVER% failed - install the MSVC component listed in build.json & exit /b 1)
cl 2>&1 | findstr /i "Version"

set GYP_MSVS_VERSION=%GYPVER%
set "GYP_MSVS_OVERRIDE_PATH=%VSROOT%"

cd /d "%SRC%"
python --version
nasm -v

echo [build] configure
rem --with-ltcg and --release-urlbase match the official nodejs.org release binaries (vcbuild.bat "release")
rem NODE_CONFIGURE_EXTRA carries options with "=" or "+" (e.g. --tag=+cm.20261105), which cmd would split as arguments.
python configure --with-intl=%INTL% --dest-cpu=x64 --with-ltcg --release-urlbase=https://nodejs.org/download/release/ %NODE_CONFIGURE_EXTRA%
if errorlevel 1 (echo [build] configure failed & exit /b 1)

if defined CM_BUILD (
  python "%~dp0stamp.py" "%SRC%" "%CM_BUILD%" "%CM_PATCHES%"
  if errorlevel 1 (echo [build] stamp failed & exit /b 1)
)

echo [build] msbuild
msbuild node.sln /m /t:Build /p:Configuration=Release /p:Platform=x64 /p:PlatformToolset=%TOOLSET% /clp:NoItemAndPropertyList;Verbosity=minimal;Summary /nologo
if errorlevel 1 (echo [build] msbuild failed & exit /b 1)
echo [build] OK
