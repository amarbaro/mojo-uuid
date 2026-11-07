"""RFC 9562 UUID values and generators with CPython constructor error texts."""
from std.bit import byte_swap
from std.hash import Hasher
from std.collections import Array
from std.memory import bitcast
from std.ffi import external_call
from hashlib import Md5, Sha1
from ._unicode import decimal_digit, is_printable, is_space

@fieldwise_init
struct UUIDError(Copyable, Movable, Writable):
    var kind: String
    var message: String

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.kind, ": ", self.message)

struct UUID(Comparable, Copyable, Hashable, ImplicitlyCopyable, Movable, Writable):
    var _int: UInt128

    def __init__(out self, value: UInt128):
        self._int = value

    def __init__(out self) raises UUIDError:
        raise UUIDError("TypeError", "one of the hex, bytes, bytes_le, fields, or int arguments must be given")

    def __init__(out self, hex: String, version: Optional[Int] = None) raises UUIDError:
        var bits: UInt128 = 0
        if _scan_canonical(hex.as_bytes(), bits):
            self._int = bits
        else:
            self._int = _parse_text(hex)
        if version:
            self._apply_version(version.value())

    def __init__(out self, bytes: Span[UInt8, _], version: Optional[Int] = None, *, little_endian: Bool = False) raises UUIDError:
        if len(bytes) != 16:
            if little_endian:
                raise UUIDError("ValueError", "bytes_le is not a 16-char string")
            raise UUIDError("ValueError", "bytes is not a 16-char string")
        var v: UInt128 = 0
        for i in range(16):
            var j = i
            if little_endian and i < 8:
                j = 3-i if i < 4 else (9-i if i < 6 else 13-i)
            v = (v << 8) | UInt128(bytes[j])
        self._int = v
        if version:
            self._apply_version(version.value())

    @staticmethod
    def from_fields(fields: Span[Int, _], version: Optional[Int] = None) raises UUIDError -> Self:
        if len(fields) != 6:
            raise UUIDError("ValueError", "fields is not a 6-tuple")
        var widths: Array[Int, 6] = [32, 16, 16, 8, 8, 48]
        var v: UInt128 = 0
        for i in range(6):
            if fields[i] < 0 or fields[i] >= (1 << widths[i]):
                var article = "an " if widths[i] == 8 else "a "
                raise UUIDError("ValueError", "field " + String(i+1) + " out of range (need " + article + String(widths[i]) + "-bit value)")
            v = (v << UInt128(widths[i])) | UInt128(fields[i])
        var result = Self(v)
        if version:
            result._apply_version(version.value())
        return result

    @staticmethod
    def from_int(value: String, version: Optional[Int] = None) raises UUIDError -> Self:
        var result = Self(_parse_int(value, 10))
        if version:
            result._apply_version(version.value())
        return result

    def _apply_version(mut self, version: Int) raises UUIDError:
        if version < 1 or version > 8:
            raise UUIDError("ValueError", "illegal version number")
        self._int = _stamp(self._int, version)

    def int(self) -> UInt128:
        return self._int

    def __eq__(self, other: Self) -> Bool:
        return self._int == other._int

    def __lt__(self, other: Self) -> Bool:
        return self._int < other._int

    def __gt__(self, other: Self) -> Bool:
        return self._int > other._int

    def __le__(self, other: Self) -> Bool:
        return self._int <= other._int

    def __ge__(self, other: Self) -> Bool:
        return self._int >= other._int

    def __hash__[H: Hasher](self, mut hasher: H):
        var b = self.bytes()
        hasher.update(Span(b))

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.__str__())

    def __hash__(self) -> Int:
        return Int(self._int % ((UInt128(1) << 61) - 1))

    def __str__(self) -> String:
        var chars = Array[UInt8, 36](fill=45)
        _put_canonical(self._int, chars, 0)
        return String(unsafe_from_utf8=Span(chars))

    def hex(self) -> String:
        return _hex128(self._int)

    def urn(self) -> String:
        var chars = Array[UInt8, 45](fill=45)
        var prefix: Array[UInt8, 9] = [117, 114, 110, 58, 117, 117, 105, 100, 58]
        for i in range(9):
            chars[i] = prefix[i]
        _put_canonical(self._int, chars, 9)
        return String(unsafe_from_utf8=Span(chars))

    def bytes(self) -> Array[UInt8, 16]:
        var out = Array[UInt8, 16](fill=0)
        var p = out.unsafe_ptr().unsafe_bitcast[UInt64]()
        p.unsafe_store[alignment=1](0, byte_swap(UInt64(self._int >> 64)))
        p.unsafe_store[alignment=1](1, byte_swap(UInt64(self._int & 0xffffffffffffffff)))
        return out^

    def bytes_le(self) -> Array[UInt8, 16]:
        var out = Array[UInt8, 16](fill=0)
        var hi = UInt64(self._int >> 64)
        # little-endian host: time_low, time_mid, time_hi_version stored natively, the rest big-endian
        out.unsafe_ptr().unsafe_bitcast[UInt32]().unsafe_store[alignment=1](0, UInt32(hi >> 32))
        out.unsafe_ptr().unsafe_offset(4).unsafe_bitcast[UInt16]().unsafe_store[alignment=1](0, UInt16((hi >> 16) & 0xffff))
        out.unsafe_ptr().unsafe_offset(6).unsafe_bitcast[UInt16]().unsafe_store[alignment=1](0, UInt16(hi & 0xffff))
        out.unsafe_ptr().unsafe_offset(8).unsafe_bitcast[UInt64]().unsafe_store[alignment=1](0, byte_swap(UInt64(self._int & 0xffffffffffffffff)))
        return out^

    def variant(self) -> String:
        var i = self._int
        if not (i & (UInt128(0x8000) << 48)):
            return "reserved for NCS compatibility"
        elif not (i & (UInt128(0x4000) << 48)):
            return "specified in RFC 4122"
        elif not (i & (UInt128(0x2000) << 48)):
            return "reserved for Microsoft compatibility"
        else:
            return "reserved for future definition"

    def version(self) -> Int:
        if ((self._int >> 62) & 3) != 2:
            return 0
        return Int((self._int >> 76) & 0xf)

    def time_low(self) -> UInt32:
        return UInt32(self._int >> 96)

    def time_mid(self) -> UInt16:
        return UInt16((self._int >> 80) & 0xffff)

    def time_hi_version(self) -> UInt16:
        return UInt16((self._int >> 64) & 0xffff)

    def clock_seq_hi_variant(self) -> UInt8:
        return UInt8((self._int >> 56) & 0xff)

    def clock_seq_low(self) -> UInt8:
        return UInt8((self._int >> 48) & 0xff)

    def clock_seq(self) -> Int:
        return (Int(self.clock_seq_hi_variant() & 0x3f) << 8) | Int(self.clock_seq_low())

    def node(self) -> UInt64:
        return UInt64(self._int & 0xffffffffffff)

    def time(self) -> UInt64:
        var ver = self.version()
        if ver == 6:
            var time_hi = UInt64(self._int >> 96)
            var time_lo = UInt64((self._int >> 64) & 0x0fff)
            return (time_hi << 28) | (UInt64(self.time_mid()) << 12) | time_lo
        elif ver == 7:
            return UInt64(self._int >> 80)
        else:
            var time_hi = UInt64((self._int >> 64) & 0x0fff)
            var time_lo = UInt64(self._int >> 96)
            return (time_hi << 48) | (UInt64(self.time_mid()) << 32) | time_lo


@always_inline
def _decode32(c: SIMD[DType.uint8, 32], mut bits: UInt128) -> Bool:
    """Decode 32 ASCII hex digits into bits; False if any byte is not a hex digit."""
    var d = c - 48
    var l = (c | 32) - 97
    var is_digit = d.le(9)
    var is_letter = l.le(5)
    var val = is_digit.select(d, l + 10)
    var pair = val.deinterleave()
    var packed = (pair[0] << 4) | pair[1]
    var raw = bitcast[DType.uint64, 2](packed)
    bits = (UInt128(byte_swap(raw[0])) << 64) | UInt128(byte_swap(raw[1]))
    return (is_digit | is_letter).reduce_and()


def _scan_canonical(b: Span[UInt8, _], mut bits: UInt128) -> Bool:
    """In-place scan of [urn:uuid:]32 hex digits with hyphens or {...}; False means use _scan_general."""
    var n = len(b)
    var off = 0
    if n == 45 and b[0] == 117 and b[1] == 114 and b[2] == 110 and b[3] == 58 and b[4] == 117 and b[5] == 117 and b[6] == 105 and b[7] == 100 and b[8] == 58:
        off = 9
        n = 36
    elif n == 38 and b[0] == 123 and b[37] == 125:
        off = 1
        n = 36
    var p = b.unsafe_ptr()
    if n == 32 and off == 0:
        return _decode32(p.unsafe_load[width=32, alignment=1](0), bits)
    if n != 36 or b[off + 8] != 45 or b[off + 13] != 45 or b[off + 18] != 45 or b[off + 23] != 45:
        return _scan_general(b, bits)
    var chars = Array[UInt8, 32](fill=0)
    var q = chars.unsafe_ptr()
    q.unsafe_store[alignment=1](0, p.unsafe_offset(off).unsafe_load[width=8, alignment=1](0))
    q.unsafe_offset(8).unsafe_store[alignment=1](0, p.unsafe_offset(off + 9).unsafe_load[width=4, alignment=1](0))
    q.unsafe_offset(12).unsafe_store[alignment=1](0, p.unsafe_offset(off + 14).unsafe_load[width=4, alignment=1](0))
    q.unsafe_offset(16).unsafe_store[alignment=1](0, p.unsafe_offset(off + 19).unsafe_load[width=4, alignment=1](0))
    q.unsafe_offset(20).unsafe_store[alignment=1](0, p.unsafe_offset(off + 24).unsafe_load[width=8, alignment=1](0))
    q.unsafe_offset(28).unsafe_store[alignment=1](0, p.unsafe_offset(off + 32).unsafe_load[width=4, alignment=1](0))
    return _decode32(q.unsafe_load[width=32, alignment=1](0), bits)


def _scan_general(b: Span[UInt8, _], mut bits: UInt128) -> Bool:
    """Any other shape of the same grammar: prefixes, braces and hyphens anywhere, still without allocating."""
    var i = 0
    var n = len(b)
    if n >= 4 and b[0] == 117 and b[1] == 114 and b[2] == 110 and b[3] == 58:
        i = 4
    if n - i >= 5 and b[i] == 117 and b[i + 1] == 117 and b[i + 2] == 105 and b[i + 3] == 100 and b[i + 4] == 58:
        i += 5
    while i < n and (b[i] == 123 or b[i] == 125):
        i += 1
    while n > i and (b[n - 1] == 123 or b[n - 1] == 125):
        n -= 1
    var v: UInt128 = 0
    var digits = 0
    while i < n:
        var c = Int(b[i])
        i += 1
        if c == 45:
            continue
        var d = c - 48
        if d < 0 or d > 9:
            d = (c | 32) - 87
            if d < 10 or d > 15:
                return False
        if digits == 32:
            return False
        v = (v << 4) | UInt128(d)
        digits += 1
    bits = v
    return digits == 32


def _parse_text(hex: String) raises UUIDError -> UInt128:
    """CPython uuid.py L216-220 for any text: normalise, count codepoints, int(hex, 16)."""
    var h = hex.replace("urn:", "")
    h = h.replace("uuid:", "")
    var tmp = h.strip("{}")
    var tmp2 = tmp.replace("-", "")
    h = tmp2
    if h.count_codepoints() != 32:
        raise UUIDError("ValueError", "badly formed hexadecimal UUID string")
    return _parse_int(h, 16)


@always_inline
def _hex32(v: UInt128) -> SIMD[DType.uint8, 32]:
    """The 32 lowercase hex digits of v, computed in SIMD registers."""
    var raw = SIMD[DType.uint64, 2](byte_swap(UInt64(v >> 64)), byte_swap(UInt64(v & 0xffffffffffffffff)))
    var b = bitcast[DType.uint8, 16](raw)
    var nib = (b >> 4).interleave(b & 15)
    return nib + 48 + nib.gt(9).select(SIMD[DType.uint8, 32](39), SIMD[DType.uint8, 32](0))


def _put_canonical[n: Int](v: UInt128, mut buf: Array[UInt8, n], at: Int):
    """Write the 36-byte hyphenated form of v at buf[at:]; hyphen slots are left as they are."""
    var h = _hex32(v)
    var p = buf.unsafe_ptr().unsafe_offset(at)
    p.unsafe_store[alignment=1](0, h.slice[8, offset=0]())
    p.unsafe_offset(9).unsafe_store[alignment=1](0, h.slice[4, offset=8]())
    p.unsafe_offset(14).unsafe_store[alignment=1](0, h.slice[4, offset=12]())
    p.unsafe_offset(19).unsafe_store[alignment=1](0, h.slice[4, offset=16]())
    p.unsafe_offset(24).unsafe_store[alignment=1](0, h.slice[8, offset=20]())
    p.unsafe_offset(32).unsafe_store[alignment=1](0, h.slice[4, offset=28]())


def _stamp(v: UInt128, version: Int) -> UInt128:
    """Set RFC variant 10 and the version nibble."""
    return (v & ~((UInt128(0xf000) << 64) | (UInt128(0xc000) << 48))) | (UInt128(0x8000) << 48) | (UInt128(version) << 76)


def _parse_int(text: String, base: Int) raises UUIDError -> UInt128:
    """CPython int(text, base) for base 10 or 16, then the 128-bit range check of uuid.UUID(int=)."""
    var cps = List[Int](capacity=text.byte_length())
    for cp in text.codepoints():
        cps.append(Int(cp))
    var lo = 0
    var hi = len(cps)
    while lo < hi and is_space(cps[lo]):
        lo += 1
    while hi > lo and is_space(cps[hi - 1]):
        hi -= 1
    var negative = False
    if lo < hi and (cps[lo] == 43 or cps[lo] == 45):
        negative = cps[lo] == 45
        lo += 1
    var after_prefix = False
    if base == 16 and hi - lo >= 2 and cps[lo] == 48 and (cps[lo + 1] | 32) == 120:
        after_prefix = True
        lo += 2
    var v: UInt128 = 0
    var overflow = False
    var digit = False
    for i in range(lo, hi):
        var c = cps[i]
        if c == 95 and (digit or (after_prefix and i == lo)):
            digit = False
            continue
        var d = decimal_digit(c)
        if d < 0 and base == 16:
            var folded = c | 32
            if folded >= 97 and folded <= 102:
                d = folded - 87
        if d < 0:
            raise UUIDError("ValueError", "invalid literal for int() with base " + String(base) + ": " + _repr(text))
        if base == 16:
            v = (v << 4) | UInt128(d)  # _parse_text passes at most 32 codepoints: no overflow
        else:
            overflow = overflow or v > (UInt128(0xffffffffffffffffffffffffffffffff) - UInt128(d)) // 10
            v = v * 10 + UInt128(d)
        digit = True
    if not digit:
        raise UUIDError("ValueError", "invalid literal for int() with base " + String(base) + ": " + _repr(text))
    if overflow or (negative and v != 0):
        raise UUIDError("ValueError", "int is out of range (need a 128-bit value)")
    return v


def _repr(value: String) -> String:
    var quote_code = 34 if "'" in value and not "\"" in value else 39
    var quote = "\"" if quote_code == 34 else "'"
    var result = String(quote)
    var hexd = "0123456789abcdef"
    for cp in value.codepoints():
        var c = Int(cp)
        if c == quote_code:
            result += "\\"
            result += quote
        elif c == 92:
            result += "\\\\"
        elif c == 9:
            result += "\\t"
        elif c == 10:
            result += "\\n"
        elif c == 13:
            result += "\\r"
        elif not is_printable(c):
            var digits = 2 if c <= 0xff else (4 if c <= 0xffff else 8)
            result += "\\x" if digits == 2 else ("\\u" if digits == 4 else "\\U")
            for k in range(digits - 1, -1, -1):
                result += hexd[byte=(c >> (4 * k)) & 0xf]
        else:
            result += chr(c)
    result += quote
    return result


def _hex128(v: UInt128) -> String:
    var chars = Array[UInt8, 32](fill=0)
    chars.unsafe_ptr().unsafe_store[alignment=1](0, _hex32(v))
    return String(unsafe_from_utf8=Span(chars))


comptime NAMESPACE_DNS = UUID(UInt128(0x6ba7b8109dad11d180b400c04fd430c8))
comptime NAMESPACE_URL = UUID(UInt128(0x6ba7b8119dad11d180b400c04fd430c8))
comptime NAMESPACE_OID = UUID(UInt128(0x6ba7b8129dad11d180b400c04fd430c8))
comptime NAMESPACE_X500 = UUID(UInt128(0x6ba7b8149dad11d180b400c04fd430c8))
comptime NIL = UUID(UInt128(0))
comptime MAX = UUID(UInt128(0xffffffffffffffffffffffffffffffff))


def _be_u128[n: Int](ref buf: Array[UInt8, n]) -> UInt128:
    """First 16 bytes of buf as a big-endian integer."""
    var p = buf.unsafe_ptr().unsafe_bitcast[UInt64]()
    return (UInt128(byte_swap(p.unsafe_load[alignment=1](0))) << 64) | UInt128(byte_swap(p.unsafe_load[alignment=1](1)))


def uuid3(namespace: UUID, name: String) raises -> UUID:
    var h = Md5()
    var nb = namespace.bytes()
    h.update(Span(nb))
    h.update(name.as_bytes())
    return UUID(_stamp(_be_u128(h.digest()), 3))


def uuid4() raises -> UUID:
    var buf = Array[UInt8, 16](fill=0)
    _random_fill(buf)
    return _uuid4_from(buf)


def _uuid4_from(buf: Array[UInt8, 16]) -> UUID:
    return UUID(_stamp(_be_u128(buf), 4))


def uuid5(namespace: UUID, name: String) raises -> UUID:
    var h = Sha1()
    var nb = namespace.bytes()
    h.update(Span(nb))
    h.update(name.as_bytes())
    return UUID(_stamp(_be_u128(h.digest()), 5))


def _now_ns() -> Int:
    var ts = Array[Int64, 2](fill=0)
    _ = external_call["clock_gettime", Int32](Int32(0), ts.unsafe_ptr())
    return Int(ts[0]) * 1000000000 + Int(ts[1])


def _random_fill[n: Int](mut buf: Array[UInt8, n]) raises:
    var offset = 0
    while offset < n:
        var got = external_call["getrandom", Int](buf.unsafe_ptr().unsafe_offset(offset), n-offset, 0)
        if got <= 0:
            raise Error("getrandom failed")
        offset += got


def _uuid6_from(timestamp: Int, clock_seq: Int, node: UInt64) -> UUID:
    var time_hi_and_mid = (timestamp >> 12) & 0xffff_ffff_ffff
    var time_lo = timestamp & 0x0fff
    var clock_s = clock_seq & 0x3fff
    var int_uuid_6: UInt128 = UInt128(time_hi_and_mid) << 80
    int_uuid_6 |= UInt128(time_lo) << 64
    int_uuid_6 |= UInt128(clock_s) << 48
    int_uuid_6 |= UInt128(node) & 0xffff_ffff_ffff
    int_uuid_6 |= UInt128(6) << 76
    int_uuid_6 |= UInt128(0x8000) << 48
    return UUID(int_uuid_6)


def uuid6(node: Optional[Int] = None, clock_seq: Int = -1, timestamp_ns: Int = -1) raises -> UUID:
    var ns = timestamp_ns
    if ns < 0:
        ns = _now_ns()
    var nanoseconds = ns
    var timestamp = nanoseconds // 100 + 0x01b21dd213814000
    var cs = clock_seq
    if cs < 0:
        var b = Array[UInt8, 2](fill=0)
        _random_fill(b)
        cs = Int(b[0]) | (Int(b[1]) << 8)
        cs &= 0x3fff
    var nd: UInt64
    if node:
        nd = UInt64(node.value())
    else:
        var b = Array[UInt8, 6](fill=0)
        _random_fill(b)
        var v: UInt64 = 0
        for i in range(6):
            v = (v << 8) | UInt64(b[i])
        nd = v
    return _uuid6_from(timestamp, cs, nd)


def _uuid7_from(timestamp_ms: Int, counter: UInt64, tail: UInt32) -> UUID:
    var v = (UInt128(timestamp_ms) & 0xffffffffffff) << 80
    v |= UInt128((counter >> 30) & 0xfff) << 64
    v |= UInt128(counter & 0x3fffffff) << 32
    v |= UInt128(tail)
    v |= UInt128(7) << 76
    v |= UInt128(0x8000) << 48
    return UUID(v)


def uuid7(timestamp_ms: Int = -1) raises -> UUID:
    var ts_ms = timestamp_ms
    if ts_ms < 0:
        ts_ms = _now_ns() // 1000000
    var rand = Array[UInt8, 10](fill=0)
    _random_fill(rand)
    var counter: UInt64 = 0
    for i in range(6):
        counter = (counter << 8) | UInt64(rand[i])
    var tail: UInt32 = 0
    for i in range(6, 10):
        tail = (tail << 8) | UInt32(rand[i])
    return _uuid7_from(ts_ms, counter & 0x1ffffffffff, tail)


def uuid8(a: Optional[Int] = None, b: Optional[Int] = None, c: Optional[Int] = None) raises -> UUID:
    var rand: UInt128 = 0
    if not a or not b or not c:
        var r = Array[UInt8, 16](fill=0)
        _random_fill(r)
        rand = _be_u128(r)
    var aa = UInt128(a.value()) if a else rand >> 80
    var bb = UInt128(b.value()) if b else rand >> 68
    var cc = UInt128(c.value()) if c else rand
    return UUID(_stamp(((aa & 0xffff_ffff_ffff) << 80) | ((bb & 0xfff) << 64) | (cc & 0x3fff_ffff_ffff_ffff), 8))


struct UUID6Generator:
    """Caller-owned monotonic timestamp, CPython uuid.py L807-813."""
    var last_timestamp: Int

    def __init__(out self):
        self.last_timestamp = -1

    def next(mut self, timestamp_ns: Int, node: UInt64, clock_seq: Int) raises -> UUID:
        var timestamp = timestamp_ns // 100 + 0x01b21dd213814000
        if timestamp <= self.last_timestamp:
            timestamp = self.last_timestamp + 1
        self.last_timestamp = timestamp
        return _uuid6_from(timestamp, clock_seq, node)


struct UUID7Generator:
    """Caller-owned CPython uuid7 state, uuid.py L844-905; no hidden globals."""
    var last_timestamp: Int
    var counter: UInt64

    def __init__(out self):
        self.last_timestamp = -1
        self.counter = 0

    def from_random(mut self, timestamp_ms: Int, random: Array[UInt8, 10]) -> UUID:
        var timestamp = timestamp_ms
        var next_counter = self.counter
        var tail: UInt32 = 0
        for i in range(6, 10):
            tail = (tail << 8) | UInt32(random[i])
        var fresh = timestamp > self.last_timestamp
        if not fresh:
            if timestamp < self.last_timestamp:
                timestamp = self.last_timestamp + 1
            next_counter += 1
            if next_counter > 0x3ffffffffff:
                timestamp += 1
                fresh = True
        if fresh:
            next_counter = 0
            for i in range(6):
                next_counter = (next_counter << 8) | UInt64(random[i])
            next_counter &= 0x1ffffffffff
        var result = _uuid7_from(timestamp, next_counter, tail)
        self.last_timestamp = timestamp
        self.counter = next_counter
        return result

    def next(mut self, timestamp_ms: Int = -1) raises -> UUID:
        var random = Array[UInt8, 10](fill=0)
        _random_fill(random)
        return self.from_random(_now_ns() // 1000000 if timestamp_ms < 0 else timestamp_ms, random)
