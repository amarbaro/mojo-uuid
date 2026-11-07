from uuid import UUID, UUIDError, NAMESPACE_DNS, NIL, MAX
from support import check
from std.collections import Array, Dict, Set
from std.sys import size_of

def api_tests() raises:
    var value = UUID("c232ab00-9414-11ec-b3c8-9f6bdeced846")
    check(size_of[UUID]() == 16, "inline UUID size")
    check(value.time_low() == 0xc232ab00)
    check(value.time_mid() == 0x9414)
    check(value.time_hi_version() == 0x11ec)
    check(value.clock_seq_hi_variant() == 0xb3)
    check(value.clock_seq_low() == 0xc8)
    check(value.clock_seq() == 0x33c8)
    check(value.node() == 0x9f6bdeced846)
    check(value.time() == 0x1ec9414c232ab00)
    check(value.urn() == "urn:uuid:c232ab00-9414-11ec-b3c8-9f6bdeced846")
    var fields: Array[Int, 6] = [0xc232ab00, 0x9414, 0x11ec, 0xb3, 0xc8, 0x9f6bdeced846]
    check(UUID.from_fields(Span(fields)).int() == value.int())
    var nil = materialize[NIL]()
    var maximum = materialize[MAX]()
    check(nil < value and value < maximum)
    check(value > nil and value >= nil and nil <= value)
    check(value == UUID(value.int()))
    check(nil.__hash__() == 0 and maximum.__hash__() == 63, "CPython unsigned integer hash")
    check(nil.variant() == "reserved for NCS compatibility" and nil.version() == 0)
    check(UUID(UInt128(0xc000) << 48).variant() == "reserved for Microsoft compatibility")
    check(maximum.variant() == "reserved for future definition" and maximum.version() == 0)
    check(value.variant() == "specified in RFC 4122" and value.version() == 1)
    check(materialize[NAMESPACE_DNS]().hex() == "6ba7b8109dad11d180b400c04fd430c8")
    # Trait surface: key in Dict/Set, printable, String(uuid), equality operators.
    var other = UUID("00000000-0000-0000-0000-000000000001")
    var table = Dict[UUID, Int]()
    table[value] = 1
    table[other] = 2
    table[UUID(value.int())] = 3
    check(len(table) == 2 and table[value] == 3 and table[other] == 2, "UUID as Dict key")
    var seen = Set[UUID]()
    seen.add(value)
    check(value in seen and other not in seen, "UUID in Set")
    check(String(value) == "c232ab00-9414-11ec-b3c8-9f6bdeced846", "String(uuid)")
    check(value != other and not (value != UUID(value.int())), "inequality")
    print("PASS public API, fields, variants, comparison, traits and 16-byte layout")

def main() raises:
    api_tests()
