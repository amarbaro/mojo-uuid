"""R differential: CPython uuid.UUID(hex) / UUID(int=int(text)) value or error text.

Rows: a fixed edge list (Unicode spaces, Unicode decimal digits, int() grammar) first,
then seeded random strings. A line starting with "#int#" is a from_int case.
"""
import random, sys, uuid
sys.stdout.reconfigure(line_buffering=True)
rnd = random.Random(int(sys.argv[2])); n = int(sys.argv[3])
SPACES = [" ", "\t", "\x0b", "\x0c", "\r", "\x1c", "\x1f", "\x85", "\xa0", " ", " ", " ", " ",
          " ", " ", " ", "　", "​", "﻿", "\x00"]
DIGITS = ["٠", "٣", "۹", "०", "０", "９", "\U0001d7ce", "\U0001d7ff", "\U0001fbf9"]
parts = list('0123456789abcdefABCDEF') * 4 + ['-', '{', '}', 'urn:', 'uuid:', '_', '+', ' ', 'x', 'X', '0x', 'é', 'g'] + SPACES + DIGITS
z = '0' * 32
edge = [z, z[:31], z + '0']
for ws in SPACES:
    edge += [ws + z[:30] + ws, ws + z[:31], z[:31] + ws, z[:15] + ws + z[:16]]
for d in DIGITS:
    edge += [d * 32, d + z[:31], z[:31] + d, d * 16 + 'a' * 16, '-' + d * 31]
edge += ['0x' + z[:30], '0X_' + z[:29], '+0x_' + z[:28], '-0x' + z[:29], '-' + z[:31], '-' + z[:30] + '1', '0_' * 15 + '00',
         '_' + z[:31], z[:31] + '_', z[:15] + '__' + z[:15], '0x_' + '0_' * 14 + '00', ' 0x' + z[:28] + ' ',
         'urn:uuid:' + z, 'URN:UUID:' + z, '{' + z + '}', '{{' + z + '}}', '{' + z, z + '}', '{urn:uuid:' + z + '}',
         'urn:urn:' + z, 'uuid:urn:' + z, '--' + z + '--', '😀' * 32, z[:30] + '😀']
ints = ['', ' ', '0', '00012', '+5', '-0', '-1', ' 5 ', '1_0', '1__0', '_1', '1_', '0x1', 'abc', '१२३', '٣', '+٣_٣', '- 5',
        '340282366920938463463374607431768211455', '340282366920938463463374607431768211456',
        '0340282366920938463463374607431768211455', '1' * 39, '9' * 40, '9' * 39 + 'x', '9' * 60 + 'a', ' 　٣ ']
for k in (1, 8, 32, 64, 100, 127, 128, 129):
    ints += [str((1 << k) - 1), str(1 << k), '-' + str(1 << k)]
for ws in SPACES:
    ints += [ws + '7', '7' + ws]
ins, exp = [], []
def add_hex(s):
    ins.append(s)
    try: exp.append('ok ' + str(uuid.UUID(s)))
    except ValueError as e: exp.append('err ValueError: ' + str(e))
def add_int(s):
    ins.append('#int#' + s)
    try: exp.append('ok ' + str(uuid.UUID(int=int(s))))
    except ValueError as e: exp.append('err ValueError: ' + str(e))
for s in edge: add_hex(s)
for s in ints: add_int(s)
for _ in range(n):
    base = uuid.UUID(int=rnd.getrandbits(128)).hex if rnd.random() < .5 else ''
    s = ''.join(rnd.choice(parts) for _ in range(rnd.randrange(0, 40))) if not base else base
    for _ in range(rnd.randrange(0, 4)):
        k = rnd.randrange(0, len(s) + 1); s = s[:k] + rnd.choice(parts) + s[k:]
    add_hex(s)
for _ in range(n // 5):
    s = str(rnd.getrandbits(rnd.randrange(1, 135)))
    for _ in range(rnd.randrange(0, 3)):
        k = rnd.randrange(0, len(s) + 1); s = s[:k] + rnd.choice(['_', '+', '-', ' ', 'x', 'a'] + SPACES + DIGITS) + s[k:]
    add_int(s)
open(sys.argv[1] + '.in', 'w', encoding='utf-8').write('\n'.join(ins) + '\n')
open(sys.argv[1] + '.exp', 'w', encoding='utf-8').write('\n'.join(exp) + '\n')
