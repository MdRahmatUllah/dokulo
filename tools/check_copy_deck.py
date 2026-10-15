"""The copy deck (UI spec §27.1-27.3) against the ARB files (DK-0623..0625).

Every keyed row of §27.1 and §27.2 is in app_en.arb and app_de.arb with the
deck's text; every tool name of §27.3 is a `tool_<id>_name` with the deck's
EN and DE name. ICU plurals may say `=1{` where the deck says `one{`.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / 'docs' / 'dokulo-ui-design-spec.md'
L10N = ROOT / 'packages' / 'app_pdf' / 'lib' / 'l10n'


def section(text: str, heading: str) -> list[list[str]]:
    """The table rows (cells) under a `### <heading>` up to the next one."""
    body = text.split(f'### {heading}', 1)[1].split('\n### ', 1)[0]
    rows = []
    for line in body.splitlines():
        if line.startswith('|') and not line.startswith('| ---'):
            rows.append([c.strip() for c in line.strip().strip('|').split('|')])
    return rows[1:]  # without the header


def norm(s: str) -> str:
    return re.sub(r'=1\{', 'one{', s)


def problems(spec: str, en: dict, de: dict) -> list[str]:
    out = []
    for heading in ('27.1', '27.2'):
        for key, e, d in section(spec, heading):
            key = key.strip('`')
            if key not in en or key not in de:
                out.append(f'§{heading} {key}: missing')
            elif (norm(en[key]), norm(de[key])) != (norm(e), norm(d)):
                out.append(
                    f'§{heading} {key}: deck {e!r} / {d!r}, '
                    f'ARB {en[key]!r} / {de[key]!r}'
                )
    names = {
        v: k
        for k, v in en.items()
        if k.startswith('tool_') and k.endswith('_name')
    }
    for tool, e, d, *_ in section(spec, '27.3'):
        key = names.get(e)
        if key is None:
            out.append(f'§27.3 {tool}: no tool_<id>_name says {e!r}')
        elif de.get(key) != d:
            out.append(f'§27.3 {key}: deck DE {d!r}, ARB {de.get(key)!r}')
    return out


def main() -> int:
    spec = SPEC.read_text(encoding='utf-8')
    en = json.loads((L10N / 'app_en.arb').read_text(encoding='utf-8'))
    de = json.loads((L10N / 'app_de.arb').read_text(encoding='utf-8'))
    found = problems(spec, en, de)
    for p in found:
        print(p)
    print(f'copy deck: {len(found)} problem(s)')
    return 1 if found else 0


if __name__ == '__main__':
    sys.exit(main())
