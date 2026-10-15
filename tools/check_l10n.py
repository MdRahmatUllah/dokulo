"""Localisation check (DK-0009):

1. every key of app_en.arb is in app_de.arb with the same placeholders, and
   German has no key English lacks;
2. no hard-coded user-facing string in app_pdf/lib: a string literal with
   letters passed to Text(...) or to a label-like argument. Mark a deliberate
   one (a brand name) with `// l10n-ignore` on its line.

    python tools/check_l10n.py [repo root]
"""

import json
import re
import sys
from pathlib import Path

ARB_DIR = Path("packages/app_pdf/lib/l10n")
LIB = Path("packages/app_pdf/lib")
LITERAL = r"""(?:'[^'\n]*'|"[^"\n]*")"""
HARD_CODED = re.compile(
    r"(?:\bText\(\s*|\b(?:label|labelText|hintText|helperText|errorText|tooltip|semanticsLabel|title|message)"
    r"\s*:\s*)(" + LITERAL + ")")


def placeholders(text: str) -> set[str]:
    return set(re.findall(r"\{(\w+)[,}]", text))


def load_arb(path: Path, problems: list[str]) -> dict:
    """The ARB as a dict; a key that appears twice (a merge that kept both
    sides) is a problem: JSON would silently keep the last."""
    def pairs(items):
        seen = set()
        for k, _ in items:
            if k in seen:
                problems.append(f"{path.name}: {k} appears twice")
            seen.add(k)
        return dict(items)
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=pairs)


def check_arb(root: Path) -> list[str]:
    problems: list[str] = []
    en = load_arb(root / ARB_DIR / "app_en.arb", problems)
    de = load_arb(root / ARB_DIR / "app_de.arb", problems)
    keys = lambda arb: {k for k in arb if not k.startswith("@")}  # noqa: E731
    problems += [f"app_de.arb: missing {k}" for k in sorted(keys(en) - keys(de))]
    problems += [f"app_de.arb: {k} is not in app_en.arb" for k in sorted(keys(de) - keys(en))]
    for k in sorted(keys(en) & keys(de)):
        if placeholders(en[k]) != placeholders(de[k]):
            problems.append(f"app_de.arb: {k} has placeholders {sorted(placeholders(de[k]))}, "
                            f"English has {sorted(placeholders(en[k]))}")
    return problems


def check_strings(root: Path) -> list[str]:
    problems = []
    for dart in sorted((root / LIB).rglob("*.dart")):
        if dart.name.startswith("app_localizations") or dart.name.endswith(".g.dart"):
            continue  # generated
        if "catalogue" in dart.relative_to(root / LIB).parts:
            continue  # the debug-only component catalogue: developer names, not UI
        for n, line in enumerate(dart.read_text(encoding="utf-8").splitlines(), 1):
            if "l10n-ignore" in line or line.lstrip().startswith("//"):
                continue
            for literal in HARD_CODED.findall(line):
                if re.search(r"[A-Za-zÄÖÜäöüß]", re.sub(r"\$\{[^}]*\}|\$\w+", "", literal)):
                    problems.append(f"{dart.relative_to(root).as_posix()}:{n}: hard-coded string {literal}")
    return problems


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    problems = check_arb(root) + check_strings(root)
    for problem in problems:
        print(problem)
    print("l10n check: " + (f"{len(problems)} problem(s)" if problems else "clean"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
