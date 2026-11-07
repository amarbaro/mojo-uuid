from uuid import UUIDError

def check(ok: Bool, message: String = "assertion failed") raises UUIDError:
    if not ok:
        raise UUIDError("AssertionError", message)
