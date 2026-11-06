#!/usr/bin/env bash
# Checks that a node binary passes the CVE regression tests in tests/cve and
# carries the CM build stamp. Linux counterpart of verify.ps1.
# Usage: tools/verify.sh <node> <version> [patched source tree]
set -uo pipefail
NODE=$1; VERSION=$2; SRC=${3:-}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CFG=$ROOT/$VERSION/build.json
cfg() { python3 -c "import json,sys; v=json.load(open(sys.argv[1]))[sys.argv[2]]; print(','.join(v) if isinstance(v,list) else v)" "$CFG" "$1"; }
TAG=$(cfg tag); LEVEL=$(cfg patch_level); CVES=$(cfg cves)
BASE=${TAG#v}
ok=1

# Every CVE this version claims to fix needs a regression test.
for c in ${CVES//,/ }; do [ -f "$ROOT/tests/cve/$c.js" ] || { echo "  no tests/cve/$c.js"; ok=0; }; done
"$NODE" "$ROOT/tests/run.js" | sed 's/^/  /'; [ "${PIPESTATUS[0]}" = 0 ] || ok=0

ver=$("$NODE" -v)
patches=$("$NODE" -p 'process.config.variables.cm_patches')
headers=$("$NODE" -p 'process.release.headersUrl')
echo "  version: $ver  cm_patches: $patches"
echo "  headersUrl: $headers"
[ "$ver" = "v$BASE+cm.$LEVEL" ] || { echo "  STAMP MISMATCH: expected v$BASE+cm.$LEVEL"; ok=0; }
for c in ${CVES//,/ }; do [[ ",$patches," == *",$c,"* ]] || { echo "  missing $c in cm_patches"; ok=0; }; done
[[ "$headers" == */v$BASE/node-v$BASE-headers.tar.gz ]] || { echo "  headersUrl not on base version"; ok=0; }

if [ -n "$SRC" ]; then
  if "$NODE" "$SRC/test/parallel/test-zlib-invalid-input.js" >/dev/null 2>&1; then
    echo "  test-zlib-invalid-input.js: pass"
  else
    echo "  test-zlib-invalid-input.js: FAIL"; ok=0
  fi
fi

if [ $ok = 1 ]; then echo "PATCHED: $NODE"; else echo "NOT PATCHED (or unexpected output): $NODE" >&2; exit 1; fi
