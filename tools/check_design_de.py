"""German strings as the design export has them (DK-0626..DK-0633).

dokulo-design/light/<f>.html and deutsch/<f>.html show one screen state in
English and in German with the same markup, so their text nodes pair up in
document order. An ARB key whose English is one of those texts must have
that text's German. The design's German is the reviewed copy (brand voice:
"du", "Handy", sentence case).

A frame whose German still shows the English text (left untranslated in
the export) says nothing about the German, so it is skipped. The same
English can mean two things: [CONTEXT] lists keys whose screen is
not the one the design pairs them with.
"""

import html
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / 'packages' / 'app_pdf' / 'lib' / 'l10n'

CONTEXT = {
    # A text field's clear button; the design's "Löschen" is the signature pad.
    'common_clear',
    # Image to PDF's margins; the design's "Klein" is a model size.
    'img2pdf_margins_small',
    # Compress's level "Light" is "Leicht"; the frame's "Hell" is the colour.
    'compress_light',
}


def texts(page: Path) -> list[str]:
    s = page.read_text(encoding='utf-8')
    frame = s.find('class="dk-frame"')
    s = s[s.find('>', frame) + 1:]  # from inside the frame's tag
    s = re.sub(r'<(style|script|svg)\b.*?</\1>', '', s, flags=re.S)
    s = re.sub(r'<span class="i[ "][^>]*>[^<]*</span>', '', s)  # icon names
    out = []
    for t in re.split(r'<[^>]+>', s):
        t = html.unescape(re.sub(r'\s+', ' ', t)).strip()
        if t:
            out.append(t)
    return out


def design_pairs(design: Path) -> dict[str, dict[str, str]]:
    """English text -> {its German: the light page it is on}."""
    pairs: dict[str, dict[str, str]] = defaultdict(dict)
    for light in sorted((design / 'light').rglob('*.html')):
        rel = light.relative_to(design / 'light')
        german = design / 'deutsch' / rel
        if not german.exists():
            continue
        a, b = texts(light), texts(german)
        if len(a) != len(b):
            continue  # the markup differs: no safe pairing
        for e, d in zip(a, b):
            pairs[e].setdefault(d, rel.as_posix())
    return pairs


def problems(pairs: dict, en: dict, de: dict) -> list[str]:
    out = []
    for key, value in en.items():
        if key.startswith('@') or key in CONTEXT or value not in pairs:
            continue
        if set(pairs[value]) == {value}:
            continue  # the frame's German is still English: nothing to check
        if de.get(key) not in pairs[value]:
            want = ' | '.join(f'{d!r} ({p})' for d, p in pairs[value].items())
            out.append(f'{key}: {de.get(key)!r}, the design says {want}')
    return out


def main() -> int:
    en = json.loads((L10N / 'app_en.arb').read_text(encoding='utf-8'))
    de = json.loads((L10N / 'app_de.arb').read_text(encoding='utf-8'))
    found = problems(design_pairs(ROOT / 'dokulo-design'), en, de)
    for p in found:
        print(p)
    print(f'design German: {len(found)} problem(s)')
    return 1 if found else 0


if __name__ == '__main__':
    sys.exit(main())
