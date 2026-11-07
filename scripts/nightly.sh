#!/usr/bin/env bash
# Package precompile, every test and the quickstart on a nightly toolchain: NIGHTLY_MOJO=/path/to/mojo.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${NIGHTLY_MOJO:?FAIL setup: set NIGHTLY_MOJO to a nightly mojo binary}"
M=$NIGHTLY_MOJO
MOJO=$M . scripts/env.sh
mkdir -p .work/nightly
"$M" --version
scripts/run-capped.sh "$M" precompile -I src -I "$HASHLIB_SRC" src/uuid -o .work/nightly/uuid.mojoc
for test in tests/test_*.mojo tests/api.mojo examples/quickstart.mojo; do
  name=$(basename "$test" .mojo)
  scripts/run-capped.sh "$M" run -I src -I "$HASHLIB_SRC" "$test" > ".work/nightly/$name.txt" 2>&1 || { cat ".work/nightly/$name.txt"; echo "FAIL nightly: $name"; exit 1; }
  echo "ok $name"
done
echo 'PASS nightly package, all tests and quickstart'
