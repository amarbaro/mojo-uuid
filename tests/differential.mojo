from uuid import UUID, UUID6Generator, UUID7Generator, NAMESPACE_DNS, NAMESPACE_URL, NAMESPACE_OID, NAMESPACE_X500, uuid3, uuid5, uuid8

def hex_of(data: Array[UInt8, 16]) -> String:
    var hex = "0123456789abcdef"
    var text = String()
    for b in data:
        text += hex[byte=Int(b >> 4)]
        text += hex[byte=Int(b & 15)]
    return text

def main() raises:
    var state: UInt128 = 0x123456789abcdef0fedcba9876543210
    for _ in range(256):
        state = state * UInt128(6364136223846793005) + 1442695040888963407
        var value = UUID(state)
        print(value.__str__(), "|", value.hex(), "|", hex_of(value.bytes_le()), "|", value.clock_seq(), "|", value.node(), "|", value.__hash__(), sep="")
    for _ in range(512):
        state = state * UInt128(6364136223846793005) + 1442695040888963407
        var value = UUID(state)
        print("acc|", value.urn(), "|", hex_of(value.bytes()), "|", value.variant(), "|", value.version(), "|", value.time(), "|", value.time_low(), "|",
              value.time_mid(), "|", value.time_hi_version(), "|", value.clock_seq_hi_variant(), "|", value.clock_seq_low(), "|", value.int(), sep="")
    var names = List[String]()
    names.append("")
    names.append("python.org")
    names.append("www.example.com")
    names.append("é")
    names.append("日本語")
    names.append("😀😀😀")
    names.append("a" * 1000)
    names.append(chr(0))
    names.append("x" + chr(0) + "y")
    for pair in range(4):
        var ns = materialize[NAMESPACE_DNS]()
        var label = "NAMESPACE_DNS"
        if pair == 1:
            ns = materialize[NAMESPACE_URL]()
            label = "NAMESPACE_URL"
        elif pair == 2:
            ns = materialize[NAMESPACE_OID]()
            label = "NAMESPACE_OID"
        elif pair == 3:
            ns = materialize[NAMESPACE_X500]()
            label = "NAMESPACE_X500"
        for name in names:
            print("v3|", label, "|", uuid3(ns, name).__str__(), "|", uuid5(ns, name).__str__(), sep="")
    print("v8|", uuid8(0, 0, 0).__str__(), sep="")
    print("v8|", uuid8(-1, -1, -1).__str__(), sep="")
    print("v8|", uuid8(1 << 48, 1 << 12, 1 << 62).__str__(), sep="")
    print("v8|", uuid8((1 << 48) - 1, 0xfff, (1 << 62) - 1).__str__(), sep="")
    print("v8|", uuid8(-5, 7, -(1 << 63) + 1).__str__(), sep="")
    print("v8|", uuid8(123456789, 4095, 99).__str__(), sep="")
    # stateful v6/v7 against CPython replayed on the same seeded sequence (tools/reference.py)
    var deltas: Array[Int, 8] = [-3, -1, 0, 0, 0, 1, 1, 5]
    var ms = 1_700_000_000_000
    var gen7 = UUID7Generator()
    for step in range(3000):
        state = state * UInt128(6364136223846793005) + 1442695040888963407
        ms += deltas[Int((state >> 100) % 8)]
        var rand = Array[UInt8, 10](fill=0)
        var bits = (state >> 20) & ((UInt128(1) << 80) - 1)
        for i in range(10):
            rand[9 - i] = UInt8(bits & 0xff)
            bits >>= 8
        var rollover = step % 17 == 16
        if rollover:
            gen7.counter = UInt64(0x3FFFFFFFFFF - Int((state >> 90) % 3))
        var before = gen7.counter
        var value = gen7.from_random(ms, rand)
        var hex = String()
        for i in range(10):
            hex += "0123456789abcdef"[byte=Int(rand[i] >> 4)]
            hex += "0123456789abcdef"[byte=Int(rand[i] & 15)]
        print("v7|", "True" if rollover else "False", "|", before, "|", ms, "|", hex, "|", value.__str__(), sep="")
    var ns = 1_700_000_000_000_000_000
    var steps: Array[Int, 9] = [-250, -100, 0, 0, 0, 100, 100, 100, 5000]
    var gen6 = UUID6Generator()
    for _ in range(3000):
        state = state * UInt128(6364136223846793005) + 1442695040888963407
        ns += steps[Int((state >> 100) % 9)]
        var node = UInt64((state >> 8) & ((UInt128(1) << 48) - 1))
        var seq = Int((state >> 60) & 0x7FFF)
        print("v6|", ns, "|", node, "|", seq, "|", gen6.next(ns, node, seq).__str__(), sep="")
