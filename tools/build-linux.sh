#!/usr/bin/env bash
# Clones an upstream Node.js release tag, applies this repo's patches for it and
# builds a linux-x64 node binary inside a manylinux container, so the result runs
# on the same glibc baseline as the official binary (2.17 for 10/12/14, 2.28 for 18).
# Needs: git, python3, docker. About 10 GB free in WORKDIR.
# Usage: tools/build-linux.sh <version> [workdir]     e.g. tools/build-linux.sh v12.22.12 /mnt/nb
# Output: <workdir>/dist/node-v<version>-cm.<patch_level>-linux-x64.tar.xz (+ .sha256)
set -euo pipefail
VERSION=$1
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mkdir -p "${2:-$ROOT/work}" && cd "${2:-$ROOT/work}" && pwd)
CFG=$ROOT/$VERSION/build.json
cfg() { python3 -c "import json,sys; v=json.load(open(sys.argv[1]))[sys.argv[2]]; print(','.join(v) if isinstance(v,list) else v)" "$CFG" "$1"; }
TAG=$(cfg tag); LEVEL=$(cfg patch_level); INTL=$(cfg intl); CVES=$(cfg cves)
IMAGE=$(cfg linux_container); PY=$(cfg linux_python)
BASE=${TAG#v}; CM_BUILD="$BASE+cm.$LEVEL"
SRC=$WORK/$VERSION

[ -d "$SRC/.git" ] || git -c advice.detachedHead=false clone --depth 1 --branch "$TAG" https://github.com/nodejs/node.git "$SRC"
git -C "$SRC" checkout -q -f -B patched "$TAG"
git -C "$SRC" clean -xdfq
git -C "$SRC" -c user.name=node-patches -c user.email=node-patches@localhost am -q "$ROOT/$VERSION"/patches/*.patch
git -C "$SRC" log --oneline "$TAG..HEAD"

docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$SRC:/src" -v "$ROOT/tools:/tools:ro" \
  -e PY="$PY" -e INTL="$INTL" -e LEVEL="$LEVEL" -e CM_BUILD="$CM_BUILD" -e CVES="$CVES" \
  "$IMAGE" bash -euc '
    cd /src
    gcc --version | head -1
    "$PY" --version
    "$PY" configure --with-intl="$INTL" --dest-cpu=x64 --tag="+cm.$LEVEL" \
      --release-urlbase=https://nodejs.org/download/release/
    "$PY" /tools/stamp.py /src "$CM_BUILD" "$CVES"
    make -j"$(nproc)" PYTHON="$PY"
  '

# File names use "-cm." because GitHub rewrites "+" in release asset names.
NAME="node-v$BASE-cm.$LEVEL-linux-x64"
DIST=$WORK/dist/$NAME
rm -rf "$DIST" && mkdir -p "$DIST/bin" "$DIST/patches"
cp "$SRC/out/Release/node" "$DIST/bin/node"
cp "$ROOT/$VERSION"/patches/*.patch "$DIST/patches/"
cp "$SRC/LICENSE" "$DIST/LICENSE"
(cd "$WORK/dist" && tar -cJf "$NAME.tar.xz" "$NAME" && sha256sum "$NAME.tar.xz" > "$NAME.tar.xz.sha256")
(cd "$DIST" && sha256sum bin/node > SHA256SUMS.txt)
echo "Built $WORK/dist/$NAME.tar.xz"
"$ROOT/tools/verify.sh" "$DIST/bin/node" "$VERSION" "$SRC"
