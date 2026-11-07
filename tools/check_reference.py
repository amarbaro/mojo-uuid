"""Check authored error fixtures against the exact CPython source revision."""
import importlib.util
import pathlib
import sys
sys.stdout.reconfigure(line_buffering=True)
path = pathlib.Path('.work/cpython-uuid.py')
if not path.exists():
    raise SystemExit('FAIL pinned reference: fetch CPython v3.14.0 Lib/uuid.py first')
spec = importlib.util.spec_from_file_location('cpython_uuid_reference', path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

checked = 0

def error(expected_kind, expected_text, **kwargs):
    global checked
    try:
        module.UUID(**kwargs)
    except Exception as exc:
        assert type(exc).__name__ == expected_kind, (kwargs, type(exc).__name__)
        assert str(exc) == expected_text, (kwargs, str(exc))
        checked += 1
    else:
        raise AssertionError(f'accepted {kwargs!r}')

error('TypeError', 'one of the hex, bytes, bytes_le, fields, or int arguments must be given')
error('TypeError', 'one of the hex, bytes, bytes_le, fields, or int arguments must be given', hex='0'*32, int=0)
for text in ['', 'a', '0'*31, '0'*33, 'é'*31]:
    error('ValueError', 'badly formed hexadecimal UUID string', hex=text)
for text in ['g'*32, '@'*32, 'é'*32, '0'*31+'_', '_'+'0'*31]:
    error('ValueError', f'invalid literal for int() with base 16: {text!r}', hex=text)
for key in ['bytes', 'bytes_le']:
    for length in [0, 15, 17]:
        error('ValueError', f'{key} is not a 16-char string', **{key: bytes(length)})
error('ValueError', 'fields is not a 6-tuple', fields=(0,)*5)
for index, width in enumerate([32, 16, 16, 8, 8, 48]):
    for bad in [-1, 1 << width]:
        fields = [0]*6
        fields[index] = bad
        article = 'an' if width == 8 else 'a'
        error('ValueError', f'field {index+1} out of range (need {article} {width}-bit value)', fields=fields)
for bad in [-1, 1 << 128]:
    error('ValueError', 'int is out of range (need a 128-bit value)', int=bad)
for version in [-1, 0, 9]:
    error('ValueError', 'illegal version number', hex='0'*32, version=version)
print(f'PASS pinned CPython v3.14.0: {checked} error cases')
