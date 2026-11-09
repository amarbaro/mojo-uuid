# mojo-uuid

<!-- badges -->
[![ci](https://github.com/amarbaro/mojo-uuid/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/amarbaro/mojo-uuid/actions/workflows/ci.yml) [![license](https://img.shields.io/github/license/amarbaro/mojo-uuid)](https://github.com/amarbaro/mojo-uuid/blob/main/LICENSE)
<!-- /badges -->

UUID values, parsing, formatting, and v3/v4/v5/v6/v7/v8 generation for Mojo.
Parses and reports errors like CPython 3.14's `uuid.UUID`, and checks generators against RFC 9562 vectors.
A `UUID` is 16 inline bytes, hashable, comparable and printable. Parsing a canonical UUID takes
9 ns and formatting one 29 ns, against 929 ns and 403 ns in CPython 3.14.9 (`docs/design.md`).
Requires Linux libc `getrandom` and `clock_gettime`, Mojo 1.2, and mojo-hashlib >=0.1.2,<0.2.

Install: `pixi workspace channel add https://conda.modular.com/max https://prefix.dev/amarbaro/amarbaro`, then `pixi add mojo-uuid` (import `uuid`). From source: `git clone https://github.com/amarbaro/mojo-uuid`, then `mojo run -I mojo-uuid/src app.mojo`.
Toolchains: Mojo 1.2 stable, and the nightly 1.3.0.dev2026110805 in the weekly [mojo-libs](https://github.com/amarbaro/mojo-libs) matrix (36 libraries on stable, 35 on nightly).

From a clone, with a mojo-hashlib checkout beside it (`scripts/env.sh` clones the pinned tag otherwise):

```sh
mojo run -I src -I ../mojo-hashlib/src examples/quickstart.mojo
```

```mojo
from uuid import NAMESPACE_DNS, uuid3

def main() raises:
    var dns = materialize[NAMESPACE_DNS]()
    print(uuid3(dns, "python.org").__str__())
```

| Call | Result |
|---|---|
| `UUID(text)` | Parse a UUID string |
| `UUID(value)` | Wrap a UInt128 |
| `UUID(Span(bytes))` | Parse 16 big-endian bytes |
| `UUID(Span(bytes), little_endian=True)` | Parse UUID bytes_le |
| `UUID.from_fields(Span(fields))` | Validate six integer fields |
| `UUID.from_int(decimal_text)` | Validate a decimal 128-bit integer |
| `uuid3(ns, name)`, `uuid5(ns, name)` | MD5 / SHA-1 name UUID |
| `uuid4()`, `uuid6()`, `uuid7()`, `uuid8()` | Generate a UUID |
| `UUID6Generator`, `UUID7Generator` | Caller-owned monotonic sequences |

## Limits

Use one generator instance for monotonic v6/v7 sequences. Convenience `uuid6()`/`uuid7()`
are not monotonic across calls; use the generator for ordering. This is a
documented divergence from CPython, with no parity claim for these helpers.
Default v6 nodes use random data, without hardware lookup.
UUID1/2, SafeUUID, Python object identity and arbitrary-precision integer arguments are outside
this interface; `from_int` takes decimal text and does not reproduce CPython's 4300-digit limit.
`UUIDError` exposes CPython's `kind` and exact `message`; it is a Mojo error value,
not a Python exception class. A version omitted from a constructor preserves bits;
an explicit version must be 1 through 8. Parse differential fuzzing uses offline
CPython oracle rows (`tools/`); committed goldens stay RFC 9562 only. The Unicode tables are Unicode 16.

Run `MOJO=mojo scripts/ci.sh` for RFC replay, constructor checks, an independent
10,000-value brute oracle, generator checks, CPython differential comparison,
and compiling behaviour mutants. Bench commands and results: [design](docs/design.md).
See [API](docs/api.md), [skill](skills/mojo-uuid/SKILL.md), and [mojo-libs](../mojo-libs).

Apache-2.0. Logic adapted from CPython Lib/uuid.py: PSF-2.0, see LICENSE-PSF and NOTICE.
