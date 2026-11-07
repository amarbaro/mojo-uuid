from uuid import UUID, UUID7Generator, NAMESPACE_DNS, uuid3, uuid4, uuid5
from std.time import perf_counter_ns
from std.sys import size_of

comptime N = 100000

def report(name: String, start: Int):
    var ns = Float64(perf_counter_ns() - start) / Float64(N)
    print(name, "ns/op", ns)

def main() raises:
    var text = String("919108f7-52d1-4320-9bac-f847db4148a8")
    var compact = String("919108f752d143209bacf847db4148a8")
    var urn_text = String("urn:uuid:919108f7-52d1-4320-9bac-f847db4148a8")
    var braces = String("{919108f7-52d1-4320-9bac-f847db4148a8}")
    var base = UUID(text).int()
    var dns = materialize[NAMESPACE_DNS]()
    var checksum: UInt128 = 0
    var count = 0
    for _ in range(N):  # warm-up: clocks and caches settle before the first timed row
        checksum ^= UUID(text).int()
    var start = perf_counter_ns()
    for _ in range(N):
        checksum ^= UUID(text).int()
    report("parse", start)
    start = perf_counter_ns()
    for _ in range(N):
        checksum ^= UUID(compact).int()
    report("parse_compact", start)
    start = perf_counter_ns()
    for _ in range(N):
        checksum ^= UUID(urn_text).int()
    report("parse_urn", start)
    start = perf_counter_ns()
    for _ in range(N):
        checksum ^= UUID(braces).int()
    report("parse_braces", start)
    start = perf_counter_ns()
    for i in range(N):
        count += UUID(base ^ UInt128(i)).__str__().byte_length()
    report("str", start)
    start = perf_counter_ns()
    for i in range(N):
        count += UUID(base ^ UInt128(i)).hex().byte_length()
    report("hex", start)
    start = perf_counter_ns()
    for i in range(N):
        count += UUID(base ^ UInt128(i)).urn().byte_length()
    report("urn", start)
    start = perf_counter_ns()
    for i in range(N):
        var b = UUID(base ^ UInt128(i)).bytes()
        for k in range(16):
            count += Int(b[k])
    report("bytes", start)
    start = perf_counter_ns()
    for i in range(N):
        var b = UUID(base ^ UInt128(i)).bytes_le()
        for k in range(16):
            count += Int(b[k])
    report("bytes_le", start)
    start = perf_counter_ns()
    for i in range(N):
        count += UUID(base ^ UInt128(i)).__hash__()
    report("hash", start)
    start = perf_counter_ns()
    for _ in range(N):
        checksum ^= uuid3(dns, "python.org").int()
    report("uuid3", start)
    start = perf_counter_ns()
    for _ in range(N):
        checksum ^= uuid5(dns, "python.org").int()
    report("uuid5", start)
    start = perf_counter_ns()
    for _ in range(N):
        checksum ^= uuid4().int()
    report("uuid4", start)
    var generator = UUID7Generator()
    start = perf_counter_ns()
    for _ in range(N):
        checksum ^= generator.next().int()
    report("uuid7_gen", start)
    print("UUID bytes", size_of[UUID](), "checksum", checksum, count)
