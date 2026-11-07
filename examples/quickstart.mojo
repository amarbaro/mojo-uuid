from uuid import *
def main() raises:
    var u = uuid4()
    print(u.__str__())
    var ns = materialize[NAMESPACE_DNS]()
    var u3 = uuid3(ns, "python.org")
    print(u3.__str__())
    print(uuid3(ns, "python.org").hex())
    print(NIL.__str__())
    print(MAX.__str__())
