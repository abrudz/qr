"""Verify qr.QR against an independent encoder (segno) and decoder (zxing-cpp).

For every generated case the symbol must
  * decode with zxing-cpp to the original text, at the requested level, and
  * for ASCII text, equal segno's symbol module for module when segno is
    given the same mask (mask choice differs between penalty conventions),
and for every length the chosen version, or the capacity error, must match segno.

Run from any directory:  python tests/verify.py
"""
import json
import os
import random
import string
import subprocess
import sys
import tempfile

import numpy as np
import segno
import segno.consts
import segno.encoder
import zxingcpp
from PIL import Image


def _padding_bits(buff, version, length):
    # ISO/IEC 18004 7.4.10 pads to the next codeword boundary only when the
    # stream does not already end on one; segno 1.6 always adds at least one
    # bit, which yields a different (though still valid) symbol.
    if version not in (segno.consts.VERSION_M1, segno.consts.VERSION_M3):
        buff.extend([0] * ((8 - length % 8) % 8))


segno.encoder.write_padding_bits = _padding_bits

HERE = os.path.dirname(os.path.abspath(__file__))
AN = segno.consts.ALPHANUMERIC_CHARS.decode()
FORMAT_LEVEL = {1: 'L', 0: 'M', 3: 'Q', 2: 'H'}
CAPACITY = {'L': (7089, 4296, 2953), 'M': (5596, 3391, 2331),
            'Q': (3993, 2420, 1663), 'H': (3057, 1852, 1273)}


def generate_cases():
    rnd = random.Random(1)
    gens = (lambda n: ''.join(rnd.choice(string.digits) for _ in range(n)),
            lambda n: ''.join(rnd.choice(AN) for _ in range(n)),
            lambda n: ''.join(rnd.choice(string.ascii_letters + string.digits + ' .,!?') for _ in range(n)))
    cases = []
    for lv, caps in CAPACITY.items():
        cases += [[lv, t] for t in ('', '7', 'HELLO WORLD', 'https://www.dyalog.com',
                                    'Ünïcødé ⍳⍴⍬ 日本語 text')]
        for gen, cap in zip(gens, caps):
            cases += [[lv, gen(n)] for n in range(1, cap, max(1, cap // 40))]
            cases += [[lv, gen(cap)], [lv, gen(cap + 1)]]
    return cases


def modules(rows):
    m = []
    for row in rows:
        idx = [' ▀▄█'.index(c) for c in row]
        m.append([i & 1 for i in idx])
        m.append([i >> 1 for i in idx])
    assert not any(m[-1]), 'padding row must be light'
    return np.array(m[:-1], dtype=np.uint8)


def format_info(m):
    seq = [m[i, 8] for i in (0, 1, 2, 3, 4, 5, 7, 8)] + [m[8, c] for c in (7, 5, 4, 3, 2, 1, 0)]
    f = sum(int(b) << i for i, b in enumerate(seq)) ^ 0x5412
    return FORMAT_LEVEL[f >> 13], (f >> 10) & 7


def decode(m):
    s = m.shape[0]
    img = (np.pad(1 - m, 4, constant_values=1) * 255).astype(np.uint8)
    img = Image.fromarray(img).resize(((s + 8) * 4,) * 2, Image.NEAREST)
    res = zxingcpp.read_barcodes(img)
    return res[0].text if res else None


def check(lv, txt, rows):
    try:
        ref = segno.make(txt, error=lv, boost_error=False, micro=False)
    except segno.DataOverflowError:
        ref = None
    if isinstance(rows, str):
        return ref is None, f'error: {rows}'
    if ref is None:
        return False, 'segno reports the text as too long'
    m = modules(rows)
    ver = (m.shape[0] - 17) // 4
    if ver != ref.version:
        return False, f'version {ver}, segno chose {ref.version}'
    level, mask = format_info(m)
    if level != lv:
        return False, f'format information says level {level}'
    # zxing-cpp cannot locate a symbol that encodes no data
    if txt and decode(m) != txt:
        return False, 'zxing-cpp did not decode the original text'
    if txt.isascii():
        same = segno.make(txt, error=lv, boost_error=False, micro=False, mask=mask)
        if not (np.array([list(r) for r in same.matrix], dtype=np.uint8) == m).all():
            return False, f'differs from segno with mask {mask}'
    return True, f'v{ver} mask {mask}'


def main():
    cases = generate_cases()
    with tempfile.TemporaryDirectory() as tmp:
        with open(os.path.join(tmp, 'cases.json'), 'w', encoding='utf-8') as f:
            json.dump(cases, f, ensure_ascii=False)
        env = dict(os.environ, QR_SOURCE=os.path.join(HERE, '..', 'qr.dyalog'))
        subprocess.run(['dyalogscript', os.path.join(HERE, 'encode.apls')], cwd=tmp, env=env, check=True)
        with open(os.path.join(tmp, 'out.json'), encoding='utf-8') as f:
            out = json.load(f)
    failures = 0
    for (lv, txt), rows in zip(cases, out):
        ok, note = check(lv, txt, rows)
        if not ok:
            failures += 1
            print(f'FAIL {lv} length {len(txt)}: {note}')
    print(f'{len(cases) - failures} of {len(cases)} cases passed')
    sys.exit(failures > 0)


if __name__ == '__main__':
    main()
