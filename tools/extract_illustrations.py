"""Extract the design export's illustrations as SVG assets (DK-0050..DK-0069).

    python tools/extract_illustrations.py ill-01 ill-02 …     # or no argument: all

Takes the inline SVG of dokulo-design/light/00-design-system/illustrations/
<name>.html into packages/app_pdf/assets/illustrations/<name>.svg. The light
file is the one asset: DkIllustration recolours it from the active theme's
tokens (the dark export differs only in these colours; the check below
makes sure the two exports still agree, so a redesign can't slip through).
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPORT = ROOT / "dokulo-design"
OUT = ROOT / "packages" / "app_pdf" / "assets" / "illustrations"
# light hex → dark hex: what DkIllustration's colour map must reproduce.
THEMED = {"#2251E6": "#8AA8FF", "#2E3440": "#DDE2EA", "#E6ECFF": "#1C2A5C", "#FFFFFF": "#181B21"}
FIXED = {"#8A5A0B", "#FFF4DD"}  # the paywall's amber: the same in both exports


def svg(theme: str, name: str) -> str:
    html = (EXPORT / theme / "00-design-system" / "illustrations" / f"{name}.html").read_text(encoding="utf-8")
    found = re.findall(r"<svg[\s\S]*?</svg>", html)
    if len(found) != 1:
        raise SystemExit(f"{name}: expected one <svg> in the {theme} export, found {len(found)}")
    return found[0]


def check_dark(name: str, light: str) -> None:
    dark = svg("dark", name)
    hexes = r"#[0-9A-Fa-f]{6}"
    if re.sub(hexes, "#", light) != re.sub(hexes, "#", dark):
        raise SystemExit(f"{name}: the dark export's shapes differ from the light one")
    for lo, da in zip(re.findall(hexes, light), re.findall(hexes, dark)):
        lo, da = lo.upper(), da.upper()
        if THEMED.get(lo, lo if lo in FIXED else None) != da:
            raise SystemExit(f"{name}: light {lo} is dark {da}, which the colour map doesn't produce")


def main() -> int:
    names = sorted(p.stem for p in (EXPORT / "light" / "00-design-system" / "illustrations").glob("ill-*.html"))
    wanted = [n for n in names if not sys.argv[1:] or any(n.startswith(a) for a in sys.argv[1:])]
    OUT.mkdir(parents=True, exist_ok=True)
    for name in wanted:
        light = svg("light", name)
        check_dark(name, light)
        # The asset keeps the viewBox; the widget sets the size.
        clean = re.sub(r'\s(width|height|style)="[^"]*"', "", light, count=3)
        (OUT / f"{name}.svg").write_text(clean + "\n", encoding="utf-8", newline="\n")
        print(f"{name}.svg")
    return 0


if __name__ == "__main__":
    sys.exit(main())
