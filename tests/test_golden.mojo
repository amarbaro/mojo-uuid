"""Replay every RFC final UUID through its generator and its textual parser."""
from uuid import UUID, UUIDError, uuid3, uuid5, uuid6, uuid8, NAMESPACE_DNS, NAMESPACE_URL, NAMESPACE_OID, NAMESPACE_X500, NIL, MAX
from uuid import _uuid4_from, _uuid7_from
from uuid import UUID6Generator, UUID7Generator
from std.collections import Array
from support import check

def golden_tests() raises:
    var text = open("tests/golden/rfc9562.txt", "r").read()
    var count = 0
    for line in text.split("\n"):
        if line.byte_length() == 0:
            continue
        var row = line.split("|")
        var section = String(row[0])
        var expected = String(row[1]).lower()
        var value: UUID
        var dns = materialize[NAMESPACE_DNS]()
        if section == "A.2":  # RFC 9562 Appendix A.2, DNS + www.example.com
            value = uuid3(dns, "www.example.com")
        elif section == "A.3":  # RFC 9562 Appendix A.3, original random bytes
            value = _uuid4_from(UUID("919108F752D133205BACF847DB4148A8").bytes())
        elif section == "A.4":  # RFC 9562 Appendix A.4, DNS + www.example.com
            value = uuid5(dns, "www.example.com")
        elif section == "A.5":  # RFC 9562 Appendix A.5, timestamp + clock_seq + node
            var generator = UUID6Generator()
            value = generator.next(1645557742000000000, 0x9f6bdeced846, 0x33c8)
            check(uuid6(0x9f6bdeced846, 0x33c8, 1645557742000000000).int() == value.int(), "v6 state golden: " + value.__str__())
        elif section == "A.6":  # RFC 9562 Appendix A.6, exact rand_a/rand_b
            # Inject an existing counter: this RFC example has the seed MSB set.
            var counter = (UInt64(0xcc3) << 30) | 0x18c4dc0c
            var generator = UUID7Generator()
            generator.last_timestamp = 1645557742000
            generator.counter = counter - 1
            var entropy: Array[UInt8, 10] = [0, 0, 0, 0, 0, 0, 0x0c, 0x07, 0x39, 0x8f]
            value = generator.from_random(1645557742000, entropy)
            check(_uuid7_from(1645557742000, counter, 0x0c07398f).int() == value.int(), "v7 state golden: " + value.__str__())
        elif section == "B.1":  # RFC 9562 Appendix B.1, custom_a/b/c
            value = uuid8(0x2489e9ad2ee2, 0xe00, 0xec932d5f69181c0)
        elif section == "B.2":  # RFC 9562 Appendix B.2, SHA-256 custom blocks
            value = uuid8(0x5c146b143c52, 0xafd, 0x138a375d0df1fbf6)
        elif section == "6.6.DNS":  # RFC 9562 Section 6.6, Table 3
            value = dns
        elif section == "6.6.URL":  # RFC 9562 Section 6.6, Table 3
            value = materialize[NAMESPACE_URL]()
        elif section == "6.6.OID":  # RFC 9562 Section 6.6, Table 3
            value = materialize[NAMESPACE_OID]()
        elif section == "6.6.X500":  # RFC 9562 Section 6.6, Table 3
            value = materialize[NAMESPACE_X500]()
        elif section == "5.9":  # RFC 9562 Section 5.9, Nil
            value = materialize[NIL]()
        elif section == "5.10":  # RFC 9562 Section 5.10, Max
            value = materialize[MAX]()
        else:
            raise Error("unknown RFC fixture " + section)
        check(value.__str__() == expected, "RFC 9562 " + section + ": " + value.__str__())
        check(UUID(String(row[1])).int() == value.int(), "RFC parse " + section)
        count += 1
    check(count == 13, "missing RFC fixture")
    var dns_ns = materialize[NAMESPACE_DNS]()
    var url_ns = materialize[NAMESPACE_URL]()
    # Pinned CPython Lib/uuid.py v3.14.0 uuid3 / uuid5 rows for empty and multibyte UTF-8 names.
    check(uuid3(dns_ns, "").__str__() == "c87ee674-4ddc-3efe-a74e-dfe25da5d7b3", "uuid3 DNS empty")
    check(uuid5(dns_ns, "").__str__() == "4ebd0208-8328-5d69-8c44-ec50939c0967", "uuid5 DNS empty")
    check(uuid3(dns_ns, "café").__str__() == "f658bdc1-094e-346d-8373-1cd586a2bccd", "uuid3 DNS cafe")
    check(uuid5(dns_ns, "café").__str__() == "5e2e2331-a683-5e18-b56d-666e31574b41", "uuid5 DNS cafe")
    check(uuid3(dns_ns, "こんにちは").__str__() == "d87bee46-169c-319b-9a06-c1248dfbc362", "uuid3 DNS ja")
    check(uuid5(dns_ns, "こんにちは").__str__() == "9b351131-5ce4-5f98-9285-2cb6252a8c36", "uuid5 DNS ja")
    check(uuid3(dns_ns, "🌍").__str__() == "9c71c1e3-fcf2-3600-9958-1b53ae0ee497", "uuid3 DNS emoji")
    check(uuid5(dns_ns, "🌍").__str__() == "c8f67c2c-b677-5d88-8ac4-ce4065247739", "uuid5 DNS emoji")
    check(uuid3(url_ns, "").__str__() == "14cdb9b4-de01-3faa-aff5-65bc2f771745", "uuid3 URL empty")
    check(uuid5(url_ns, "").__str__() == "1b4db7eb-4057-5ddf-91e0-36dec72071f5", "uuid5 URL empty")
    check(uuid3(url_ns, "café").__str__() == "e3c5138d-fa47-372c-a143-e9a287f8075f", "uuid3 URL cafe")
    check(uuid5(url_ns, "café").__str__() == "79d4db4c-73a9-5cec-bd37-4fc862e2120d", "uuid5 URL cafe")
    check(uuid3(url_ns, "こんにちは").__str__() == "9d4338bc-6bc0-367f-b091-3b6fb0595442", "uuid3 URL ja")
    check(uuid5(url_ns, "こんにちは").__str__() == "6c99f3de-d04d-5568-b140-f84c60c2f8c0", "uuid5 URL ja")
    check(uuid3(url_ns, "🌍").__str__() == "8f0179c0-f4ba-3d05-976a-0d3628873319", "uuid3 URL emoji")
    check(uuid5(url_ns, "🌍").__str__() == "7a7787db-1861-58d8-95ca-438577b4bc30", "uuid5 URL emoji")
    print("PASS RFC 9562: 13 complete vectors")

def main() raises:
    golden_tests()
