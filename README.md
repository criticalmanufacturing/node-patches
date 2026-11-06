# node-patches

Security backports for end-of-life Node.js release lines that Critical Manufacturing products still ship.

Each version folder holds a patch series that is applied on top of the upstream `nodejs/node` release tag. A build script applies the series, builds a `node` binary (win-x64 or linux-x64), and copies the result with its patches and checksums into a distribution folder.

## Layout

```
.github/
  workflows/
    build.yml                   CI: build and verify all versions, optional release
.gitattributes                  keeps *.patch files with LF endings
.gitignore                      excludes work/, *.exe, *.pdb, *.zip
docs/
  CVE-2026-111497.md            notes, backport details and validation
tests/
  run.js                        runs the CVE regression tests against the node that runs it
  cve/
    CVE-2026-111497.js          tests for one CVE
tools/
  build.ps1                     clone, patch, build, copy and verify (Windows)
  build-linux.sh                clone, patch, build in a manylinux container and verify (Linux)
  build-node.cmd                configure and msbuild with an older MSVC toolset
  stamp.py                      adds the CM build stamp to a configured source tree
  verify.ps1                    runs the CVE tests and checks the stamp of a node.exe
  verify.sh                     Linux counterpart of verify.ps1
v10.24.1/
  build.json
  patches/
    0001-deps-brotli-backport-fix-for-CVE-2026-111497.patch
    0002-src-expose-BROTLI_DECODER_ERROR_FORMAT_BLOCK_SWITCH.patch
    0003-build-allow-build-metadata-tags-keep-release-URLs-on.patch
v12.22.12/
  build.json
  patches/
    0001-deps-brotli-backport-fix-for-CVE-2026-111497.patch
    0002-src-expose-BROTLI_DECODER_ERROR_FORMAT_BLOCK_SWITCH.patch
    0003-build-allow-build-metadata-tags-keep-release-URLs-on.patch
v14.21.3/
  build.json
  patches/
    0001-deps-brotli-backport-fix-for-CVE-2026-111497.patch
    0002-src-expose-BROTLI_DECODER_ERROR_FORMAT_BLOCK_SWITCH.patch
    0003-build-allow-build-metadata-tags-keep-release-URLs-on.patch
v16.20.2/
  build.json
  patches/
    (same three patches)
v18.20.8/
  build.json
  patches/
    0001-deps-brotli-backport-fix-for-CVE-2026-111497.patch
    0002-src-expose-BROTLI_DECODER_ERROR_FORMAT_BLOCK_SWITCH.patch
    0003-build-allow-build-metadata-tags-keep-release-URLs-on.patch
```

## Supported versions

| Version   | Upstream tag commit | Bundled Brotli | MSVC toolset  | Python | ICU        |
|-----------|---------------------|----------------|---------------|--------|------------|
| v10.24.1  | 5182a7ec            | 1.0.7          | v141 (14.16)  | 2.7    | small-icu  |
| v12.22.12 | a3d28373            | 1.0.9          | v142 (14.29)  | 2.7    | small-icu  |
| v14.21.3  | edd64fe5            | 1.0.9          | v142 (14.29)  | 3.8    | full-icu   |
| v16.20.2  | dadbde96            | 1.0.9          | v142 (14.29)  | 3.8    | full-icu   |
| v18.20.8  | 4d0b4e70            | 1.1.0          | v142 (14.29)  | 3.8    | full-icu   |

## Version stamp

`node -v` prints `v<base>+cm.<patch_level>`, for example `v12.22.12+cm.20261105`.

- The `+` marks semver build metadata. npm `engines` and semver range checks still match the base version. A `-` suffix would make the version a pre-release, which fails ranges such as `>=12`.
- `process.config.variables.cm_build` holds the full version string. `process.config.variables.cm_patches` holds the comma-separated CVE list.
- On Windows, the file properties show the same version in Product/File version and the CVEs in Comments.
- `process.release` URLs (`headersUrl`, `libUrl`, `sourceUrl`) stay on the base version, so node-gyp keeps downloading the official headers and `node.lib`. Patch 0003 does this and lets `configure --tag` accept a `+` tag.
- Release file names use `-cm.` (for example `node-v12.22.12-cm.20261105-win-x64.zip`) because GitHub rewrites `+` in asset names. The release tag keeps the `+`: `v12.22.12+cm.20261105`.

## Which CVEs does a binary fix?

The list is compiled into the binary, so these commands work on any copy, without this repo. They need the `node` you want to check: use its full path (for example `C:\app\node.exe`) if it is not the first `node` on the PATH.

| Question | Command | Patched output | Official binary |
|---|---|---|---|
| Version and build date | `node -v` | `v12.22.12+cm.20261105` | `v12.22.12` |
| CVEs fixed | `node -p process.config.variables.cm_patches` | `CVE-2026-111497` | `undefined` |
| Full CM build string | `node -p process.config.variables.cm_build` | `12.22.12+cm.20261105` | `undefined` |

One line for the version and the CVE list together, which also works in scripts:

```
node -p "process.version + ' ' + (process.config.variables.cm_patches || 'no CM patches')"
```

On Windows, the CVE list is also in the file properties (Details > Comments), which you can read without running the file:

```powershell
(Get-Item C:\app\node.exe).VersionInfo | Format-List ProductVersion, Comments
```

To find every node.exe on a Windows machine and show what each one fixes:

```powershell
Get-ChildItem C:\ -Recurse -Filter node.exe -ErrorAction SilentlyContinue |
  ForEach-Object { '{0}  {1}  {2}' -f $_.VersionInfo.ProductVersion, $_.VersionInfo.Comments, $_.FullName }
```

The stamp only says which fixes went into the build. To check that the fixes actually work, run the regression tests below with that binary.

To list the CVEs per version from this repo instead of from a binary: `jq -c .cves v*/build.json`, or see the release notes on the Releases page.

## Regression tests

`tests/` holds one test file per CVE. Each file runs the CVE's trigger input through the affected Node.js API and checks that the binary handles it the way the fix does. The runner uses only Node.js core modules and runs on every version from 10 to 18, so you can point it at any `node` binary:

```
<path>\node.exe tests\run.js                        # every CVE must be fixed
<path>\node.exe tests\run.js --expect vulnerable    # every CVE must reproduce
<path>\node.exe tests\run.js --list                 # CVEs that have tests
<path>\node.exe tests\run.js --cve CVE-2026-111497  # one CVE only
```

Run it once with the patched binary and once with the official one to see the vulnerability and the fix side by side. Output for the official v14.21.3:

```
CVE-2026-111497  zlib (Brotli): Brotli decoder out-of-bounds write on an invalid block switch
  FAIL brotliDecompressSync rejects the invalid block switch (-17)
       expected errno -17 (BLOCK_SWITCH), got -9 (ERR_BLOCK_LENGTH_1): the decoder read past the invalid block switch
  FAIL streaming decoder fed 1 byte at a time rejects it (-17)
       expected errno -17 (BLOCK_SWITCH), got -9 (ERR_BLOCK_LENGTH_1): the decoder read past the invalid block switch
  FAIL zlib.constants.BROTLI_DECODER_ERROR_FORMAT_BLOCK_SWITCH is -17
       constant is undefined, expected -17
  ok   valid Brotli data still round-trips (sync and stream) (control)
  => VULNERABLE
```

The same binary built with the patches prints `ok` on every line and `=> FIXED`.

- Tests marked `(control)` check behaviour that must work with or without the fix, so a broken build is reported as `BROKEN`, not as fixed.
- The tests detect each vulnerability by its behaviour, without exploiting it. For CVE-2026-111497, the unpatched decoder accepts the invalid block switch and fails later with a different error (-9). That later failure is the code path that writes out of bounds.
- `--expect vulnerable` exits with 0 only if every CVE reproduces. CI runs it against the official binary of each version as a negative control. This shows that the tests detect each bug and don't simply pass on any build.
- `verify.ps1` and `verify.sh` run the tests as part of every build. They fail if a CVE listed in `build.json` has no test file.

## Patches

| CVE              | Component             | Versions   | Doc                           |
|------------------|-----------------------|------------|-------------------------------|
| CVE-2026-111497  | Brotli decoder (node:zlib) | all five | docs/CVE-2026-111497.md    |

## Prerequisites

- Visual Studio 2022 or newer (tested with VS 2026 Professional), with the MSVC component named in the `vs_component` field of the version's `build.json`:
  - v10.24.1: `Microsoft.VisualStudio.Component.VC.v141.x86.x64`
  - v12.22.12, v14.21.3, v16.20.2, v18.20.8: `Microsoft.VisualStudio.Component.VC.14.29.16.11.x86.x64`
- The older toolsets can be installed side by side into a newer VS with the VS Installer:
  `setup.exe modify --installPath <vs> --add <component> --passive`
- Python of the version in the `python` field of `build.json` (2.7 or 3.8). Portable copies from the nuget.org `python2` and `python` packages work.
- NASM 2.15 or newer.
- git.
- 10-15 GB of free disk space per build in the work directory.

## Building

### Windows

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
   `--with-intl=<intl> --dest-cpu=x64 --with-ltcg --release-urlbase=https://nodejs.org/download/release/ --tag=+cm.<patch_level>`
   These options match the official release binaries. The build log is written to `<WorkDir>\build-<version>.log`.
5. Copies `node.exe`, `node.pdb` and the patch files to `<WorkDir>\dist\node-v<base>-cm.<patch_level>-win-x64\` and writes `SHA256SUMS.txt`.
6. Runs `verify.ps1` on the result, using the patched source tree.

### Linux

```sh
tools/build-linux.sh v12.22.12 /mnt/nb
```

Needs git, python3 and docker. The script builds inside manylinux containers, so the binary has the same glibc baseline as the official binary:

- v10.24.1, v12.22.12, v14.21.3, v16.20.2: glibc 2.17, image `quay.io/pypa/manylinux2014_x86_64`.
- v18.20.8: glibc 2.28, image `quay.io/pypa/manylinux_2_28_x86_64`.

The image and the Python inside it are set by the `linux_container` and `linux_python` fields of `build.json`. The work directory needs about 10 GB free. Output: `<workdir>/dist/node-v<base>-cm.<patch_level>-linux-x64.tar.xz`, with a `.sha256` file next to it. The script runs `verify.sh` on the result at the end.

## Verifying a binary

```powershell
.\tools\verify.ps1 -Node <path>\node.exe -Version <version> [-Source <patched source tree>] [-NoStampCheck]
```

```sh
tools/verify.sh <path>/node <version> [<patched source tree>]
```

Both scripts run `tests/run.js` with the given binary, and every CVE must show `FIXED`. If a source tree is given, the scripts also run `test/parallel/test-zlib-invalid-input.js` from that tree.

Both scripts also check the version stamp. `node -v` must be `v<base>+cm.<patch_level>`, `cm_patches` must list every CVE in `build.json`, and `headersUrl` must point at the base-version headers. For binaries built before the stamp existed, pass `-NoStampCheck` to `verify.ps1`.

## Adding a patch

1. Write the fix, or cherry-pick it, as commits on top of the upstream tag in a Node.js checkout. Give each commit message `Refs:` and `CVE-ID:` trailers.
2. Export the commits:

   ```
   git format-patch --no-signature --zero-commit -N <tag>..HEAD -o <version>\patches
   ```

   Use the next number prefix (for example `0004-`).
3. Bump `patch_level` in the version's `build.json` (and add the CVE to `cves`).
4. Add `tests/cve/<CVE>.js`, using `tests/cve/CVE-2026-111497.js` as the model. Export `id`, `title`, `component` and `tests`. Each test throws when the binary misbehaves. Run it with an official binary and `--expect vulnerable` to confirm that the test catches the bug. For a CVE that affects only some versions, export `applies()` that returns false on the other versions, which the runner then reports as `NOT APPLICABLE`.
5. Run `build.ps1` (or `build-linux.sh`) and `verify.ps1` (or `verify.sh`) for the version.
6. Add a `docs/<CVE>.md` file that describes the fix and the validation.

## CI pipeline

The workflow `.github/workflows/build.yml` builds and verifies all versions on:

- win-x64: `windows-2022`. It installs the MSVC component named in `build.json` (`vs_component`).
- linux-x64: `ubuntu-22.04` with docker.

Pull requests that touch `v*/**`, `tools/**` or the workflow run the build and verification. Build artifacts are kept for 30 days.

Manual run: Actions > build > Run workflow. Inputs:

- `versions`: comma-separated folder names. Default: all versions.
- `platforms`: comma-separated `win-x64`, `linux-x64`. Default: both.
- `publish`: when true, creates one GitHub release per version with the win zip, the pdb zip, the linux tar.xz, `SHA256SUMS.txt` and build-provenance attestations. The release tag is `v<base>+cm.<patch_level>`.

To check a downloaded file against its attestation:

```
gh attestation verify <file> --repo criticalmanufacturing/node-patches
```

## Binaries

- Never commit `node.exe` or `node.pdb`. They are excluded by `.gitignore`.
- Publish binaries as GitHub Release assets, together with `SHA256SUMS.txt`. The CI `publish` run does this.
- Windows binaries are not Authenticode-signed. Sign them with the company certificate before shipping. If signing is added to CI, it must run before the attestations and checksums are created, or they will not match the shipped files.
- Linux binaries: no signing applies. Use the attestations and checksums.

## Caveat

These release lines are end-of-life. Only the CVEs listed in this repo are fixed. All other upstream security fixes released after each line's end-of-life date are missing.
