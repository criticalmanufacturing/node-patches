# node-patches

Security backports for end-of-life Node.js release lines that Critical Manufacturing products still ship.

Each version folder holds a patch series that is applied on top of the upstream `nodejs/node` release tag. A build script applies the series, builds a win-x64 `node.exe`, and copies the result with its patches and checksums into a distribution folder.

## Layout

```
.gitattributes                  keeps *.patch files with LF endings
.gitignore                      excludes work/, *.exe, *.pdb, *.zip
docs/
  CVE-2026-111497.md            notes, backport details and validation
tools/
  build.ps1                     clone, patch, build, copy and verify
  build-node.cmd                configure and msbuild with an older MSVC toolset
  verify.ps1                    checks a node.exe for the CVE-2026-111497 fix
  cve-2026-111497-check.js      regression input used by verify.ps1
v10.24.1/
  build.json
  patches/
    0001-deps-brotli-backport-fix-for-CVE-2026-111497.patch
    0002-src-expose-BROTLI_DECODER_ERROR_FORMAT_BLOCK_SWITCH.patch
v12.22.12/
  build.json
  patches/
    0001-deps-brotli-backport-fix-for-CVE-2026-111497.patch
    0002-src-expose-BROTLI_DECODER_ERROR_FORMAT_BLOCK_SWITCH.patch
v14.21.3/
  build.json
  patches/
    0001-deps-brotli-backport-fix-for-CVE-2026-111497.patch
    0002-src-expose-BROTLI_DECODER_ERROR_FORMAT_BLOCK_SWITCH.patch
v18.20.8/
  build.json
  patches/
    0001-deps-brotli-backport-fix-for-CVE-2026-111497.patch
    0002-src-expose-BROTLI_DECODER_ERROR_FORMAT_BLOCK_SWITCH.patch
```

## Supported versions

| Version   | Upstream tag commit | Bundled Brotli | MSVC toolset  | Python | ICU        |
|-----------|---------------------|----------------|---------------|--------|------------|
| v10.24.1  | 5182a7ec            | 1.0.7          | v141 (14.16)  | 2.7    | small-icu  |
| v12.22.12 | a3d28373            | 1.0.9          | v142 (14.29)  | 2.7    | small-icu  |
| v14.21.3  | edd64fe5            | 1.0.9          | v142 (14.29)  | 3.8    | full-icu   |
| v18.20.8  | 4d0b4e70            | 1.1.0          | v142 (14.29)  | 3.8    | full-icu   |

## Patches

| CVE              | Component             | Versions   | Doc                           |
|------------------|-----------------------|------------|-------------------------------|
| CVE-2026-111497  | Brotli decoder (node:zlib) | all four | docs/CVE-2026-111497.md    |

## Prerequisites

- Visual Studio 2022 or newer (tested with VS 2026 Professional), with the MSVC component named in the `vs_component` field of the version's `build.json`:
  - v10.24.1: `Microsoft.VisualStudio.Component.VC.v141.x86.x64`
  - v12.22.12, v14.21.3, v18.20.8: `Microsoft.VisualStudio.Component.VC.14.29.16.11.x86.x64`
- The older toolsets can be installed side by side into a newer VS with the VS Installer:
  `setup.exe modify --installPath <vs> --add <component> --passive`
- Python of the version in the `python` field of `build.json` (2.7 or 3.8). Portable copies from the nuget.org `python2` and `python` packages work.
- NASM 2.15 or newer.
- git.
- 10-15 GB of free disk space per build in the work directory.

## Building

```powershell
.\tools\build.ps1 -Version v12.22.12 -PythonDir C:\tools\python27 -NasmDir C:\tools\nasm -WorkDir D:\NodeBuild
```

Parameters:

- `-Version`, `-PythonDir`, `-NasmDir`: required.
- `-WorkDir`: optional. Defaults to `work\` in the repo root.
- `-PatchOnly`: optional. Stops after the patches are applied.

What the script does:

1. Checks that the Python in `-PythonDir` matches the version in `build.json`.
2. Shallow-clones the tag from `github.com/nodejs/node` into `<WorkDir>\<version>`, if the clone does not exist yet.
3. Resets the clone to the tag, cleans it, and applies the patch series with `git am`, in file name order.
4. Configures and builds with `tools\build-node.cmd`, using:
   `--with-intl=<intl> --dest-cpu=x64 --with-ltcg --release-urlbase=https://nodejs.org/download/release/`
   These options match the official release binaries. The build log is written to `<WorkDir>\build-<version>.log`.
5. Copies `node.exe`, `node.pdb` and the patch files to `<WorkDir>\dist\node-<version>-patched-win-x64\` and writes `SHA256SUMS.txt`.
6. Runs `verify.ps1` on the result, using the patched source tree.

## Verifying a binary

```powershell
.\tools\verify.ps1 -Node <path>\node.exe -Version <version> [-Source <patched source tree>]
```

The script runs `cve-2026-111497-check.js` with the given binary. A patched binary rejects the regression input with errno -17 (`BLOCK_SWITCH`). An unpatched binary fails later with -9. If `-Source` is given, the script also runs `test/parallel/test-zlib-invalid-input.js` from that tree.

## Adding a patch

1. Write the fix, or cherry-pick it, as commits on top of the upstream tag in a Node.js checkout. Give each commit message `Refs:` and `CVE-ID:` trailers.
2. Export the commits:

   ```
   git format-patch --no-signature --zero-commit -N <tag>..HEAD -o <version>\patches
   ```

   Use the next number prefix (for example `0003-`).
3. Run `build.ps1` and `verify.ps1` for the version.
4. Add a `docs/<CVE>.md` file that describes the fix and the validation.

## Binaries

- Never commit `node.exe` or `node.pdb`. They are excluded by `.gitignore`.
- Publish binaries as GitHub Release assets, together with `SHA256SUMS.txt`.
- The binaries are not Authenticode-signed. Sign them with the company certificate before shipping.

## Caveat

These release lines are end-of-life. Only the CVEs listed in this repo are fixed. All other upstream security fixes released after each line's end-of-life date are missing.
