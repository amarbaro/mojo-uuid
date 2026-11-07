"""CPython benchmark reference, not a fixture generator. Same operations as tests/bench.mojo."""
import sys
import time
import uuid
sys.stdout.reconfigure(line_buffering=True)
N = 100000
text = "919108f7-52d1-4320-9bac-f847db4148a8"
compact = "919108f752d143209bacf847db4148a8"
urn_text = "urn:uuid:" + text
braces = "{" + text + "}"
value = uuid.UUID(text)
dns = uuid.NAMESPACE_DNS
ops = [
    ("parse", lambda: uuid.UUID(text)),
    ("parse_compact", lambda: uuid.UUID(compact)),
    ("parse_urn", lambda: uuid.UUID(urn_text)),
    ("parse_braces", lambda: uuid.UUID(braces)),
    ("str", lambda: str(value)),
    ("hex", lambda: value.hex),
    ("urn", lambda: value.urn),
    ("bytes", lambda: value.bytes),
    ("bytes_le", lambda: value.bytes_le),
    ("hash", lambda: hash(value)),
    ("uuid3", lambda: uuid.uuid3(dns, "python.org")),
    ("uuid5", lambda: uuid.uuid5(dns, "python.org")),
    ("uuid4", uuid.uuid4),
    ("uuid7_gen", uuid.uuid7),
]
for name, operation in ops:
    start = time.perf_counter_ns()
    for _ in range(N):
        operation()
    print(name, "ns/op", (time.perf_counter_ns() - start) / N)
