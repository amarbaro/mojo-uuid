#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -z "${MOJO:-}" ]; then
  uv sync -q || { echo 'FAIL setup: uv sync'; exit 1; }
  MOJO=.venv/bin/mojo
fi
. scripts/env.sh
mkdir -p .work/t
"$MOJO" --version
for entry in tests/cases:cases tests/api:api tests/differential:differential tests/bench:bench examples/quickstart:quickstart tests/fuzz_probe:fuzz_probe; do
  scripts/run-capped.sh "$MOJO" build -O3 -I src -I "$HASHLIB_SRC" "${entry%%:*}.mojo" -o ".work/t/${entry##*:}" > .work/build.err 2>&1 || { cat .work/build.err; echo "FAIL build: $entry"; exit 1; }
done
python3 -c 'import re; m = re.search(r"```mojo\n(.*?)```", open("README.md").read(), re.S); open(".work/t/readme_doctest.mojo", "w").write(m.group(1))'
scripts/run-capped.sh "$MOJO" build -O3 -I src -I "$HASHLIB_SRC" .work/t/readme_doctest.mojo -o .work/t/readme_doctest > .work/build.err 2>&1 || { cat .work/build.err; echo "FAIL build: readme doctest"; exit 1; }
scripts/run-capped.sh .work/t/readme_doctest > /dev/null
CASES=.work/t/cases scripts/check.sh
scripts/run-capped.sh $PYTHON -I tools/reference.py > .work/reference.exp
scripts/run-capped.sh .work/t/differential > .work/reference.got
cmp .work/reference.exp .work/reference.got || { echo 'FAIL differential: CPython values'; exit 1; }
scripts/run-capped.sh $PYTHON -I tools/fuzz_ref.py .work/t/fuzz 7 5000
scripts/run-capped.sh .work/t/fuzz_probe .work/t/fuzz.in > .work/t/fuzz.got
diff -u .work/t/fuzz.exp .work/t/fuzz.got || { echo 'FAIL differential: fuzz probe vs CPython'; exit 1; }
scripts/run-capped.sh .work/t/api
scripts/run-capped.sh .work/t/quickstart
MOJO="$MOJO" scripts/mutants.sh
echo 'PASS 6/6'
