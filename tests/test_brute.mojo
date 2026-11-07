"""Independent bit-by-bit oracle, 10,000 deterministic UInt128 inputs."""
from uuid import UUID, UUID6Generator, UUID7Generator
from std.collections import Array
from support import check

def slow_hex(v: UInt128) -> String:
    var result = String()
    for nibble in range(31, -1, -1):
        var digit = 0
        for bit in range(4):
            if (v >> UInt128(nibble*4 + bit)) & 1:
                digit += 1 << bit
        result += chr(48 + digit if digit < 10 else 87 + digit)
    return result

def slow_parse(text: String) -> UInt128:
    var v: UInt128 = 0
    for cp in text.codepoints():
        var c = Int(cp)
        if c == 45:
            continue
        v = v * 16 + UInt128(c-48 if c <= 57 else c-87)
    return v

def brute_tests() raises:
    var state: UInt128 = 0x123456789abcdef0fedcba9876543210
    var generator6 = UUID6Generator()
    var generator7 = UUID7Generator()
    var previous6: UInt64 = 0
    var previous7: UInt128 = 0
    for _ in range(10000):
        state = state * UInt128(6364136223846793005) + 1442695040888963407
        var u = UUID(state)
        var expected = slow_hex(state)
        check(u.hex() == expected, "brute hex")
        var rendered = u.__str__()
        check(rendered.byte_length() == 36, "render length")
        check(rendered[byte=8] == "-" and rendered[byte=13] == "-" and rendered[byte=18] == "-" and rendered[byte=23] == "-", "hyphen positions")
        check(slow_parse(rendered) == state, "independent parse")
        check(UUID(rendered).int() == state, "parse roundtrip")
        var bytes = u.bytes()
        check(UUID(Span(bytes)).int() == state, "bytes roundtrip")
        var little = u.bytes_le()
        check(UUID(Span(little), little_endian=True).int() == state, "bytes_le roundtrip")
        check(little[6] == bytes[7] and little[7] == bytes[6], "bytes_le third field")
        check(u.clock_seq() == Int((state >> 48) & 0x3fff), "clock_seq")
        check(u.node() == UInt64(state & 0xffffffffffff), "node")
        # Random clocks repeatedly move backwards and reuse timestamps.
        var clock = 1000000 + Int(state & 0xff)
        var next6 = generator6.next(clock * 100, UInt64(state & 0xffffffffffff), Int(state & 0x3fff))
        var expected6 = UInt64(clock) + 0x01b21dd213814000
        if expected6 <= previous6:
            expected6 = previous6 + 1
        check(next6.time() == expected6, "brute v6 timestamp bump")
        check(next6.node() == UInt64(state & 0xffffffffffff), "brute v6 node")
        previous6 = expected6
        var entropy = Array[UInt8, 10](fill=0)
        for i in range(10):
            entropy[i] = bytes[i]
        if Int(state & 0x3ff) == 0:
            generator7.counter = 0x3ffffffffff
        var next7 = generator7.from_random(clock, entropy)
        check(next7.int() > previous7, "brute v7 ordering")
        check(generator7.counter <= 0x3ffffffffff, "brute v7 counter width")
        check(next7.time() >= UInt64(clock), "brute v7 clock")
        previous7 = next7.int()
    print("PASS brute: 10000 independent formatter/parser and byte round trips")
    print("PASS brute generators: 10000 v6/v7 clock, counter and ordering rows each")

def main() raises:
    brute_tests()
