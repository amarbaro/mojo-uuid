"""Offline differential oracle against stdlib uuid, never writes RFC fixtures."""
import sys
import uuid
sys.stdout.reconfigure(line_buffering=True)
M = (1 << 128) - 1
state = 0x123456789ABCDEF0FEDCBA9876543210
for _ in range(256):
    state = (state * 6364136223846793005 + 1442695040888963407) & M
    value = uuid.UUID(int=state)
    print(str(value), value.hex, value.bytes_le.hex(), value.clock_seq, value.node, hash(value), sep="|")
# every accessor, over values that hit all four variants and versions 0-15
for k in range(512):
    state = (state * 6364136223846793005 + 1442695040888963407) & M
    value = uuid.UUID(int=state)
    print("acc", value.urn, value.bytes.hex(), value.variant, value.version or 0, value.time, value.time_low, value.time_mid,
          value.time_hi_version, value.clock_seq_hi_variant, value.clock_seq_low, value.int, sep="|")
# name-based UUIDs over ASCII, empty, multibyte and long names
names = ["", "python.org", "www.example.com", "é", "日本語", "😀" * 3, "a" * 1000, "\x00", "x\x00y"]
for ns_name in ("NAMESPACE_DNS", "NAMESPACE_URL", "NAMESPACE_OID", "NAMESPACE_X500"):
    ns = getattr(uuid, ns_name)
    for name in names:
        print("v3", ns_name, uuid.uuid3(ns, name), uuid.uuid5(ns, name), sep="|")
# uuid8 with explicit blocks, including negative and oversized ones
for a, b, c in [(0, 0, 0), (-1, -1, -1), (1 << 48, 1 << 12, 1 << 62), ((1 << 48) - 1, 0xFFF, (1 << 62) - 1), (-5, 7, -(1 << 63) + 1), (123456789, 4095, 99)]:
    print("v8", uuid.uuid8(a, b, c), sep="|")
# stateful v6/v7: CPython replayed with patched clock and entropy against the same seeded sequence
import os, time
from unittest import mock
LCG = lambda s: (s * 6364136223846793005 + 1442695040888963407) & M
DELTAS = [-3, -1, 0, 0, 0, 1, 1, 5]
ms = 1_700_000_000_000
uuid._last_timestamp_v7 = None
uuid._last_counter_v7 = 0
for step in range(3000):
    state = LCG(state)
    ms += DELTAS[(state >> 100) % 8]
    rand = ((state >> 20) & ((1 << 80) - 1)).to_bytes(10, "big")
    if step % 17 == 16:
        uuid._last_counter_v7 = 0x3FF_FFFF_FFFF - (state >> 90) % 3
    before = uuid._last_counter_v7
    with mock.patch("time.time_ns", lambda: ms * 1_000_000), mock.patch("os.urandom", lambda n: rand if n == 10 else rand[6:]):
        value = uuid.uuid7()
    print("v7", step % 17 == 16, before, ms, rand.hex(), value, sep="|")
ns = 1_700_000_000_000_000_000
uuid._last_timestamp_v6 = None
for step in range(3000):
    state = LCG(state)
    ns += [-250, -100, 0, 0, 0, 100, 100, 100, 5000][(state >> 100) % 9]
    node, seq = (state >> 8) & ((1 << 48) - 1), (state >> 60) & 0x7FFF
    with mock.patch("time.time_ns", lambda: ns):
        value = uuid.uuid6(node, seq)
    print("v6", ns, node, seq, value, sep="|")
