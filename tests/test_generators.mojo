from uuid import UUID, UUID6Generator, UUID7Generator, uuid4, uuid6, uuid7, uuid8
from uuid import _uuid4_from, _uuid7_from
from support import check
from std.collections import Array

def generator_tests() raises:
    var all_bits = Array[UInt8, 16](fill=255)
    check(_uuid4_from(all_bits).__str__() == "ffffffff-ffff-4fff-bfff-ffffffffffff")
    for _ in range(32):
        check(uuid4().version() == 4)
        check(uuid6().version() == 6)
        check(uuid7().version() == 7)
        check(uuid8().version() == 8)
    check(uuid6(0, 0, 0).node() == 0, "explicit zero node")
    check(uuid6(1, 0x1234, 0).clock_seq() == 0x1234)
    check(uuid8(-1, -1, -1).__str__() == "ffffffff-ffff-8fff-bfff-ffffffffffff", "negative custom blocks mask")
    check(uuid8(0x1000000000000, 0x1000, 0x4000000000000000).__str__() == "00000000-0000-8000-8000-000000000000", "oversized custom blocks mask")
    # Missing blocks are random inside their own bits only: fixed blocks survive, each random block fills its mask.
    var seen_a: UInt128 = 0
    var seen_b: UInt128 = 0
    var seen_c: UInt128 = 0
    for _ in range(128):
        var only_a = uuid8(0x123456789abc)
        check(only_a.int() >> 80 == 0x123456789abc and only_a.version() == 8, "fixed block a survives")
        seen_b |= (uuid8(0x123, None, 0x321).int() >> 64) & 0xfff
        seen_c |= uuid8(0x123, 0x456).int() & 0x3fffffffffffffff
        seen_a |= uuid8(None, 0x456, 0x321).int() >> 80
    check(seen_a == 0xffffffffffff and seen_b == 0xfff and seen_c == 0x3fffffffffffffff, "random blocks cover their mask")
    check(uuid8(0x123, 0x456, 0x321).__str__() == "00000000-0123-8456-8000-000000000321", "explicit blocks")
    var g6 = UUID6Generator()
    var first6 = g6.next(1645557742000000000, 0x9f6bdeced846, 0x33c8)
    var second6 = g6.next(1645557742000000000, 0x9f6bdeced846, 0x33c8)
    var backwards6 = g6.next(1645557741000000000, 0x9f6bdeced846, 0x33c8)
    check(second6.time() == first6.time() + 1, "v6 same timestamp")
    check(backwards6.time() == second6.time() + 1, "v6 backwards timestamp")
    var g6_transition = UUID6Generator()
    var before_epoch = g6_transition.next(-100, 0, 0)
    var at_epoch = g6_transition.next(0, 0, 0)
    check(at_epoch > before_epoch, "v6 pre-epoch then epoch ordered")
    check(before_epoch.time() == 0x01b21dd213814000 - 1, "v6 pre-epoch timestamp")
    check(at_epoch.time() == 0x01b21dd213814000, "v6 epoch timestamp")
    var random = Array[UInt8, 10](fill=0)
    random[9] = 17
    var g7 = UUID7Generator()
    var first = g7.from_random(1000, random)
    var second = g7.from_random(1000, random)
    check(first.__str__() == "00000000-03e8-7000-8000-000000000011")
    check(second.int() == first.int() + (UInt128(1) << 32), "same ms increments counter")
    var backwards = g7.from_random(999, random)
    check(backwards.time() == 1001 and backwards > second, "backwards clock")
    g7.counter = 0x3ffffffffff
    var rollover = g7.from_random(1001, random)
    check(rollover.time() == 1002, "counter rollover")
    check(g7.counter == 0, "counter reseed")
    check(rollover.__str__() == "00000000-03ea-7000-8000-000000000011")
    check(_uuid7_from(0, 0x3ffffffffff, 0xffffffff).__str__() == "00000000-0000-7fff-bfff-ffffffffffff", "all counter bits")
    print("PASS generators: fixed entropy, masking, monotonic state, rollback, rollover")

def main() raises:
    generator_tests()
