# Design

UUID is one UInt128: 16 inline bytes, no heap per value. The hot paths are parsing and
formatting a canonical 36-byte UUID. Parse scans the input bytes in place and decodes the 32
hex digits in one SIMD step; format builds the digits in SIMD registers and writes them into a
stack buffer, so the only heap block is the returned `String`. `bytes()` and `bytes_le()` are
byte swaps stored into 16 inline bytes (little-endian hosts only, like the libc calls below).

## Parsing

`UUID(text)` takes three routes, cheapest first, all returning what CPython's `uuid.UUID(hex)` returns:
1. `_scan_canonical`: compact, hyphenated, `{...}` and `urn:uuid:...` shapes. SIMD decode, 0 allocations.
2. `_scan_general`: other shapes of the same grammar (hyphens anywhere, `urn:` or `uuid:` alone,
   stacked braces). Byte loop, 0 allocations.
3. `_parse_text`: everything else (CPython's replace/strip, then `_parse_int`, an `int(text, base)`
   for base 10 and 16 with Unicode spaces and digits, signs, `0x`, underscores and the 128-bit range
   check). Error texts quote like `repr()`. Tables: `src/uuid/_unicode.mojo` (Unicode 16, generated
   by `tools/gen_unicode.py`, static `global_constant`).

## Generators and traits

Hashing uses mojo-hashlib's MD5 and SHA-1; entropy is libc `getrandom` (failure and partial reads
checked); time is `clock_gettime`. One-shot helpers keep no state. `UUID6Generator` and
`UUID7Generator` are caller-owned: repeats, clock rollback and the 42-bit v7 counter rollover need
no hidden shared storage, and tests stay deterministic. `UUID` is `Comparable`, `Hashable` and
`Writable` (`Dict[UUID, V]`, `Set[UUID]`, `print`, `String(uuid)`); `__hash__() -> Int` stays
CPython's `hash(uuid)`, the `Hasher` overload feeds the 16 big-endian bytes.

## Verification

RFC 9562 Appendix A.2-A.6, B.1-B.2 and Sections 5.9, 5.10, 6.6 supply the goldens; error texts follow
CPython v3.14.0. A.6 uses injected generator state (CPython clears the counter MSB). Also 10,000
bit-by-bit formatter/parser rows, a CPython differential (`tools/reference.py`: accessors, name UUIDs,
uuid8, v6/v7 replay), a seeded fuzz differential (`tools/fuzz_ref.py`) and compiling mutants that must
all be killed. No fixture comes from the code under test.

## Memory and speed

Same operation, 100000 calls, pinned to one core, median of 5 rounds, ns/op (`scripts/bench.sh`):

| op | before | after | CPython 3.14.9 |
|---|---|---|---|
| parse hyphenated | 50 | 9.3 | 929 |
| parse compact | 49 | 6.3 | 636 |
| parse urn | 679 | 9.8 | 777 |
| parse braces | 656 | 9.5 | 896 |
| str | 76 | 29 | 403 |
| hex | 47 | 27 | 145 |
| urn | 105 | 33 | 428 |
| bytes / bytes_le | 32 / 40 | 5.0 / 4.9 | 93 / 358 |
| uuid3 / uuid5 | 228 / 215 | 183 / 171 | 1360 / 1462 |
| uuid4 / uuid7 generator | 48 / 45 | 35 / 46 | 962 / 1179 |

One 36-byte `String` costs about 20 ns, the floor for `str`, `hex` and `urn`; uuid3 and uuid5
are dominated by hashlib. The `bytes` rows sum all 16 result bytes into a sink, so the compiler
cannot drop the work (an earlier version read one byte and measured 0.2 ns: folded, discarded). Whole bench process: 0.2 s to 0.1 s wall; peak RSS 10148 to 10132 KB, which is runtime
start-up (CPython 14884 KB). `UUID` stays 16 bytes.

Rejected: a Python runtime, a heap block per UUID, hardware-node lookup, a buffered random pool
(hidden shared state; `getrandom` costs about 35 ns per UUID).
