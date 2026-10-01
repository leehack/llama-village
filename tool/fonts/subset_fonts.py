#!/usr/bin/env python3
"""Subsets the Korean fonts into assets/fonts/ (needs fontTools).

usage: python3 tool/fonts/subset_fonts.py <google-fonts checkout or download dir>

The source dir holds gowundodum/, jua/ and gowunbatang/ as in
github.com/google/fonts (ofl/). Each font keeps Latin, punctuation, jamo,
CJK symbols, fullwidth forms and the 2,350 Hangul syllables of KS X 1001,
plus any syllable the app's Korean strings use, with every layout feature.
"""
import glob
import os
import shutil
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONTS = {
    'gowundodum': ['GowunDodum-Regular.ttf'],
    'jua': ['Jua-Regular.ttf'],
    'gowunbatang': ['GowunBatang-Regular.ttf', 'GowunBatang-Bold.ttf'],
}
RANGES = [
    (0x0020, 0x007E), (0x00A0, 0x00FF), (0x2000, 0x206F), (0x20A9, 0x20A9), (0x20AC, 0x20AC),
    (0x2122, 0x2122), (0x2190, 0x21FF), (0x25A0, 0x25FF), (0x2600, 0x26FF), (0x1100, 0x11FF),
    (0x3000, 0x303F), (0x3130, 0x318F), (0xA960, 0xA97F), (0xD7B0, 0xD7FF), (0xFF00, 0xFFEF),
]


def unicodes():
    out = {c for a, b in RANGES for c in range(a, b + 1)}
    out |= {ord(bytes([hi, lo]).decode('euc-kr')) for hi in range(0xB0, 0xC9) for lo in range(0xA1, 0xFF)}
    for path in glob.glob(f'{ROOT}/lib/**/*.dart', recursive=True) + glob.glob(f'{ROOT}/lib/**/*.arb', recursive=True):
        with open(path, encoding='utf-8') as f:
            out |= {ord(c) for c in f.read() if 0xAC00 <= ord(c) <= 0xD7A3}
    return sorted(out)


def main():
    src = sys.argv[1]
    wanted = unicodes()
    for family, files in FONTS.items():
        dest = f'{ROOT}/assets/fonts/{family}'
        os.makedirs(dest, exist_ok=True)
        shutil.copy(f'{src}/{family}/OFL.txt', f'{dest}/OFL.txt')
        for name in files:
            options = subset.Options()
            options.layout_features = ['*']
            options.name_IDs = ['*']
            options.name_languages = ['*']
            options.notdef_outline = True
            font = TTFont(f'{src}/{family}/{name}')
            subsetter = subset.Subsetter(options)
            subsetter.populate(unicodes=wanted)
            subsetter.subset(font)
            font.save(f'{dest}/{name}')
            print(f'{family}/{name}: {os.path.getsize(f"{src}/{family}/{name}")} -> {os.path.getsize(f"{dest}/{name}")} bytes')


if __name__ == '__main__':
    main()
