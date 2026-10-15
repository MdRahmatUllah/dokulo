"""Licence scan: every package in every pubspec.lock must be allowed by the
licence register (docs/compliance/licence-register.md). DK-0672.

    python tools/licence_scan.py [repo root]

Fails (exit 1) on a denied engine or SDK, a direct dependency without a
register line, any GPL, AGPL or LGPL package, or an MPL or unrecognised
licence without a register line.
Reads each package's LICENSE from the pub cache, so run `flutter pub get` first.
"""

import os
import re
import sys
from pathlib import Path

REGISTER = Path("docs/compliance/licence-register.md")
DENIED = ("mupdf", "ghostscript", "bentopdf", "syncfusion", "apryse", "pdftron",
          "pspdfkit", "nutrient", "foxit", "google_mlkit", "verapdf")
# The earliest match in the text wins: a licence names itself before it quotes
# others (MPL-2.0 mentions the GNU licences in its definitions).
LICENCES = (
    ("AGPL", r"GNU AFFERO GENERAL PUBLIC"),
    ("LGPL", r"GNU (LESSER|LIBRARY) GENERAL PUBLIC"),
    ("GPL", r"GNU GENERAL PUBLIC LICENSE"),
    ("MPL", r"Mozilla Public License"),
    ("Apache-2.0", r"Apache License"),
    ("MIT", r"Permission is hereby granted, free of charge"),
    ("BSD", r"Redistribution and use in source and binary forms"),
    ("Zlib", r"provided 'as-is', without any express or implied"),
    ("ISC", r"Permission to use, copy, modify, and/or distribute this software"),
)
PERMISSIVE = {"Apache-2.0", "MIT", "BSD", "Zlib", "ISC"}
# Never in the app, register line or not (DK-0681): GPL and AGPL at all, and
# LGPL because a pub package ships to iOS too, where it would be linked
# statically. MPL may ship with a register line (file-level copyleft).
NEVER = {"AGPL", "GPL", "LGPL"}


def registered(root: Path) -> set[str]:
    """Package names in the register's tables: a row's first cell in backticks."""
    text = (root / REGISTER).read_text(encoding="utf-8")
    return set(re.findall(r"^\| `([a-z0-9_]+)` \|", text, re.M))


def lock_packages(lock: Path) -> list[dict]:
    """The packages of a pubspec.lock: name, dependency, source, version."""
    packages, current = [], None
    for line in lock.read_text(encoding="utf-8").splitlines():
        if m := re.match(r"^  ([a-z0-9_]+):$", line):
            current = {"name": m[1]}
            packages.append(current)
        elif current and (m := re.match(r'^    (dependency|source|version): "?([^"]*)"?$', line)):
            current[m[1]] = m[2]
        elif not line.startswith("  "):
            current = None
    return packages


def pub_cache() -> Path:
    if os.environ.get("PUB_CACHE"):
        return Path(os.environ["PUB_CACHE"])
    if os.name == "nt":
        return Path(os.environ["LOCALAPPDATA"]) / "Pub" / "Cache"
    return Path.home() / ".pub-cache"


def classify(package_dir: Path) -> str | None:
    """The licence family of a package's LICENSE file, or None if unrecognised."""
    files = [f for f in package_dir.glob("*") if re.match(r"(?i)licen[cs]e", f.name)]
    if not files:
        return None
    main_file = min(files, key=lambda f: (len(f.name), f.name))  # LICENSE before LICENSE-THIRD-PARTY
    text = main_file.read_text(encoding="utf-8", errors="replace")
    found = [(m.start(), name) for name, pattern in LICENCES if (m := re.search(pattern, text, re.I))]
    return min(found)[1] if found else None


def declared(root: Path) -> set[str]:
    """Packages any pubspec.yaml lists under (dev_)dependencies. A pub workspace's
    lock marks every package "transitive", so this is what makes one direct."""
    names = set()
    for pubspec in root.rglob("pubspec.yaml"):
        if any(part.startswith(".") for part in pubspec.relative_to(root).parts):
            continue
        section = None
        for line in pubspec.read_text(encoding="utf-8").splitlines():
            if m := re.match(r"^(\w+):", line):
                section = m[1]
            elif section in ("dependencies", "dev_dependencies") and (m := re.match(r"^  (\w+):", line)):
                names.add(m[1])
    return names


def scan(root: Path, cache: Path) -> list[str]:
    allowed = registered(root)
    direct = declared(root)
    problems = []
    for lock in sorted(root.rglob("pubspec.lock")):
        if any(part.startswith(".") for part in lock.relative_to(root).parts):
            continue  # .dart_tool, .worktrees, .team
        where = lock.relative_to(root).as_posix()
        for p in lock_packages(lock):
            name = p["name"]
            if any(d in name for d in DENIED):
                problems.append(f"{where}: {name} is excluded by the licence register")
                continue
            if p.get("source") in ("sdk", "path"):
                continue
            if (p.get("dependency", "").startswith("direct") or name in direct) and name not in allowed:
                problems.append(f"{where}: {name} is a direct dependency with no register line")
            if p.get("source") != "hosted":
                continue  # git packages need their register line, checked above for direct ones
            package_dir = cache / "hosted" / "pub.dev" / f"{name}-{p.get('version')}"
            if not package_dir.is_dir():
                problems.append(f"{where}: {name} {p.get('version')} not in the pub cache (run `flutter pub get`)")
                continue
            licence = classify(package_dir)
            if licence in NEVER:
                problems.append(f"{where}: {name} has licence {licence}: never in the app (DK-0681)")
            elif licence not in PERMISSIVE and name not in allowed:
                problems.append(f"{where}: {name} has licence {licence or 'unrecognised'}: needs a register line or removal")
    return problems


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    problems = scan(root, pub_cache())
    for problem in problems:
        print(problem)
    print("licence scan: " + (f"{len(problems)} problem(s)" if problems else "clean"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
