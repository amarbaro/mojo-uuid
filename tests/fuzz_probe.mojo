from uuid import UUID
from std.sys import argv

def main() raises:
    var text = open(argv()[1], "r").read()
    var lines = text.split("\n")
    if text.endswith("\n") and len(lines) > 0:
        _ = lines.pop()
    for line in lines:
        try:
            if line.startswith("#int#"):
                print("ok", UUID.from_int(String(line[byte=5:])).__str__())
            else:
                print("ok", UUID(String(line)).__str__())
        except e:
            print("err", e)
