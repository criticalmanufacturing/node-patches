#!/usr/bin/env bash
# Checks that a node binary carries the CVE-2026-111497 fix and the CM build stamp.
# Linux counterpart of verify.ps1.
# Usage: tools/verify.sh <node> <version> [patched source tree]
set -uo pipefail
NODE=$1; VERSION=$2; SRC=${3:-}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CFG=$ROOT/$VERSION/build.json
cfg() { python3 -c "import json,sys; v=json.load(open(sys.argv[1]))[sys.argv[2]]; print(','.join(v) if isinstance(v,list) else v)" "$CFG" "$1"; }
CODE=$(cfg brotli_error_code); TAG=$(cfg tag); LEVEL=$(cfg patch_level); CVES=$(cfg cves)
BASE=${TAG#v}
ok=1

out=$("$NODE" "$ROOT/tools/cve-2026-111497-check.js" 2>&1); echo "$out" | sed 's/^/  /'
grep -q 'BLOCK_SWITCH const = -17' <<<"$out" || ok=0
grep -q "SYNC: error $CODE -17" <<<"$out" || ok=0
grep -q "STREAM: error $CODE -17" <<<"$out" || ok=0

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
