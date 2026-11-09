"""Cuts the app's fonts down to the glyphs site/index.html uses, as woff2.

The full fonts are ~5MB together; the page needs a few hundred glyphs.
Rerun after changing the page's text, or new characters fall back to the
system font:

    python tool/subset_site_fonts.py
"""

from pathlib import Path

from fontTools import subset

ROOT = Path(__file__).resolve().parents[1]
FONTS = {
    'GriunFromsol-Regular.ttf': 'griun-fromsol.woff2',
    'GriunGyuwon-Regular.ttf': 'griun-gyuwon.woff2',
    'OwnglyphParkDaHyun-Regular.ttf': 'ownglyph-parkdahyun.woff2',
}

text = (ROOT / 'site/index.html').read_text(encoding='utf-8')
# Every printable ASCII character too, so versions and links never miss.
chars = set(text) | {chr(c) for c in range(0x20, 0x7F)}
unicodes = sorted(ord(c) for c in chars if ord(c) >= 0x20)

for src, out in FONTS.items():
    options = subset.Options()
    options.flavor = 'woff2'
    font = subset.load_font(str(ROOT / 'assets/fonts' / src), options)
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=unicodes)
    subsetter.subset(font)
    dest = ROOT / 'site/fonts' / out
    subset.save_font(font, str(dest), options)
    print(f'{out}: {dest.stat().st_size // 1024} KB')
