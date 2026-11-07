# API

`UUID` stores one UInt128 (16 bytes), copied by value.

| Constructor | Behaviour and errors |
|---|---|
| `UUID(value: UInt128)` | Wrap already bounded unsigned bits |
| `UUID(hex: String, version: Optional[Int] = None)` | Strip urn:/uuid:, braces, hyphens; 32 codepoints; then CPython `int(text, 16)` (spaces, signs, `0x`, underscores, Unicode digits) |
| `UUID(bytes: Span[UInt8, _], version: Optional[Int] = None, *, little_endian: Bool = False)` | Exactly 16 bytes; reverse first 4/2/2 fields for bytes_le |
| `UUID()` | TypeError kind: one of the hex, bytes, bytes_le, fields, or int arguments must be given |
| `UUID.from_fields(fields: Span[Int, _], version: Optional[Int] = None)` | Six fields, ranges 32/16/16/8/8/48 bits |
| `UUID.from_int(value: String, version: Optional[Int] = None)` | CPython `UUID(int=int(text))`: base-10 grammar (spaces, sign, underscores, Unicode digits), range 0..2^128-1 |

Fallible constructors raise `UUIDError(kind: String, message: String)`.
Messages are tested against CPython Lib/uuid.py v3.14.0 lines 211-257.
Wrong input length, invalid digits, field range, integer range, and version
use ValueError kind; no input uses TypeError kind. Multiple constructor input
forms are rejected by Mojo overload resolution. Invalid versions include explicit 0.
The literal-parse message retains normalized input and quotes it like CPython's `repr()`
(escapes everything `str.isprintable()` rejects). Unicode tables are Unicode 16 (CPython 3.14).
The 4300-digit limit of CPython's decimal `int()` is not reproduced by `from_int`.

Value methods: `int() -> UInt128`, `hex() -> String`, `__str__() -> String`,
`urn() -> String`, `bytes()/bytes_le() -> Array[UInt8,16]`, `variant() -> String`,
`version() -> Int` (0 for non-RFC variant), `time_low() -> UInt32`,
`time_mid()/time_hi_version() -> UInt16`, `clock_seq_hi_variant()/clock_seq_low() -> UInt8`,
`clock_seq() -> Int`, `node()/time() -> UInt64`, `__hash__() -> Int`.
`UUID` is `Comparable` (ordering compares unsigned bits), `Hashable` (usable as a `Dict`/`Set` key)
and `Writable` (`print(uuid)`, `String(uuid)`). `__hash__() -> Int` computes an `Int` hash value
modulo the Mersenne prime 2^61 - 1 from the underlying 128-bit unsigned integer,
matching `hash(uuid)` in CPython; the `Hasher` overload feeds the 16 big-endian bytes.

| Generator | Inputs |
|---|---|
| `uuid3(namespace: UUID, name: String)` | MD5 of namespace bytes and UTF-8 name |
| `uuid5(namespace: UUID, name: String)` | SHA-1, first 128 bits |
| `uuid4()` | 16 random bytes, RFC version/variant overwrite |
| `uuid6(node: Optional[Int] = None, clock_seq: Int = -1, timestamp_ns: Int = -1)` | Gregorian 100ns time, 14-bit sequence, 48-bit node; negative sequence/time select defaults |
| `uuid7(timestamp_ms: Int = -1)` | Unix milliseconds with fresh counter/tail entropy |
| `uuid8(a: Optional[Int] = None, b: Optional[Int] = None, c: Optional[Int] = None)` | Mask blocks to 48/12/62 bits, including explicitly negative inputs |
| `UUID6Generator.next(timestamp_ns: Int, node: UInt64, clock_seq: Int)` | Stateful clock rollback/same-time handling |
| `UUID7Generator.next(timestamp_ms: Int = -1)` | Stateful CPython 42-bit monotonic counter |
| `UUID7Generator.from_random(timestamp_ms: Int, random: Array[UInt8,10])` | Fixed entropy seam for state tests; `timestamp_ms` must be >= 0 |

Generators can raise an Error if the system RNG fails. Reuse a generator instance
for monotonic sequences; synchronize shared instances externally.
Internal `_uuid4_from(bytes)` and `_uuid7_from(ms,counter,tail)` assemble deterministic bits.
RFC 9562 A.6 has its counter top bit set: tests inject existing generator state, because
CPython clears that bit when seeding its own monotonic generator.

Constants: NAMESPACE_DNS, NAMESPACE_URL, NAMESPACE_OID, NAMESPACE_X500, NIL, MAX.
See tests/golden/SOURCE for RFC sections. UUID1/2 and MAC lookup are omitted.

## Limits

Convenience `uuid6()`/`uuid7()` are not monotonic across calls; use the generator for ordering.
This is a documented divergence from CPython; no CPython parity is claimed for those helpers.
The explicit generators keep their own state: v6 bumps repeated/backward timestamps;
v7 uses a 42-bit counter, bumps milliseconds on rollover, and stays ordered after clock rollback.
No stdlib underscore globals are used.
