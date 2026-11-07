#!/usr/bin/env bash
# Paired benchmark: tests/bench.mojo vs tools/bench_ref.py (CPython), ROUNDS runs pinned to one core.
# Optional BEFORE=/path/to/older/bench binary adds a before/after pair per round.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/env.sh
CPU=${CPU:-$(awk '/Cpus_allowed_list/ {split($2,a,"[-,]"); print a[1]; exit}' /proc/self/status)}
mkdir -p .work
scripts/run-capped.sh "$MOJO" build -O3 -I src -I "$HASHLIB_SRC" tests/bench.mojo -o .work/bench-after
for round in $(seq "${ROUNDS:-3}"); do
  for side in ${BEFORE:+before} after; do
    bin=.work/bench-after; [ "$side" = before ] && bin=$BEFORE
    echo "$side round=$round cpu=$CPU"
    scripts/run-capped.sh /usr/bin/time -f '%e s %M KB' taskset -c "$CPU" "$bin"
  done
done
echo 'CPython reference'
scripts/run-capped.sh /usr/bin/time -f '%e s %M KB' taskset -c "$CPU" $PYTHON -I tools/bench_ref.py
