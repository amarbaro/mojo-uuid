# Validation

- `MOJO=mojo scripts/ci.sh`: full stable suite, differential rows, API, example, mutants.
- `NIGHTLY_MOJO=/path/to/nightly/mojo scripts/nightly.sh`: package precompile, every tests/test_*.mojo, tests/api.mojo and the example.
- `scripts/bench.sh`: benchmark and CPython twin; `BEFORE=<older bench binary>` pairs it with an earlier build.
- `$PYTHON -I tools/fuzz_ref.py PREFIX SEED N` (`PYTHON` from scripts/env.sh: CPython >= 3.14, else `uv run --python 3.14`): writes PREFIX.in/.exp (edge list, then N random hex rows and N/5 `from_int` rows) from the installed CPython; `scripts/ci.sh` runs seed 7, 5000.
- `python3 -I tools/gen_unicode.py > src/uuid/_unicode.mojo`: regenerates the Unicode tables (review the diff after a CPython upgrade).
- `python3 -I tools/check_reference.py`: verify error expectations against pinned source.

Fetch the pinned reference before that last check:

```sh
gh api 'repos/python/cpython/contents/Lib/uuid.py?ref=v3.14.0' --jq .content | base64 -d > .work/cpython-uuid.py
```

RFC goldens are copied from https://www.rfc-editor.org/rfc/rfc9562.txt.
`tests/golden/APPENDIX.txt` preserves the Appendix A.2 through B.2 text verbatim;
`rfc9562.txt` indexes each final value and constants with its section.
`SOURCE` records provenance. No Python script writes a golden file.

The fixed scaffold mutant runner compiles each changed source before checking its
behaviour. Fields in tests/mutants.txt use `|` separators, so patterns must not
contain that character. Its restore trap protects the source on interruption.

Every compile and executable test uses scripts/run-capped.sh (120 s wall-clock cap, CAP_SECONDS to change).
mojo-hashlib resolves through scripts/env.sh: a sibling checkout, else the pinned v0.1.2 clone in .work/deps.
