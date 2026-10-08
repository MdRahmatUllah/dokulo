"""Token check (DK-0024): screens, components and patterns read design tokens
(`context.tokens`), never raw colour values.

    python tools/check_tokens.py [repo root]

Fails on `Color(0x…)`, `Color.fromARGB`/`fromRGBO` or a `Colors.<name>` other
than `Colors.transparent` in packages/app_pdf/lib/screens, lib/components and
lib/patterns.
The values themselves live in lib/theme/dk_tokens.dart.
"""

import re
import sys
from pathlib import Path

DIRS = (
    "packages/app_pdf/lib/screens",
    "packages/app_pdf/lib/components",
    "packages/app_pdf/lib/patterns",
)
RAW = re.compile(r"\bColor\(0x|\bColor\.from(ARGB|RGBO)\(|\bColors\.(?!transparent\b)\w+")


def check(root: Path) -> list[str]:
    problems = []
    for d in DIRS:
        for dart in sorted((root / d).rglob("*.dart")):
            for n, line in enumerate(dart.read_text(encoding="utf-8").splitlines(), 1):
                code = line.split("//")[0]
                if m := RAW.search(code):
                    problems.append(f"{dart.relative_to(root).as_posix()}:{n}: raw colour {m.group(0)}…: use a DkTokens colour")
    return problems


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    problems = check(root)
    for p in problems:
        print(p)
    print("token check: " + (f"{len(problems)} problem(s)" if problems else "clean"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
