"""Fetch the icon font (DK-0048) into packages/app_pdf/assets/fonts/.

    python tools/fetch_icon_font.py

The app draws its icons with Material Symbols Rounded (Apache-2.0), taken
from the material_symbols_icons 4.2960.0 archive on pub.dev and checked
against its SHA-256. We ship this one font, declared in app_pdf's pubspec,
instead of depending on the package, which bundles three fonts (34 MB) the
icon tree-shaker can't reduce while nothing references them. The folder is
gitignored: the gate (tools/check.py) runs this first, and so does every
build.
"""

import hashlib
import io
import sys
import tarfile
import urllib.request
from pathlib import Path

ARCHIVE = "https://pub.dev/api/archives/material_symbols_icons-4.2960.0.tar.gz"
MEMBER = "lib/fonts/MaterialSymbolsRounded.ttf"
TARGET = Path("packages/app_pdf/assets/fonts/MaterialSymbolsRounded.ttf")
SIZE = 15073408
SHA256 = "0ff80fedb8afa8eba26c58426a569f03da4da3597b9cb8806408a568a98dd031"


def ok(data: bytes) -> bool:
    return len(data) == SIZE and hashlib.sha256(data).hexdigest() == SHA256


def fetch(root: Path, download=lambda url: urllib.request.urlopen(url).read()) -> list[str]:
    target = root / TARGET
    if target.is_file() and ok(target.read_bytes()):
        return []
    try:
        with tarfile.open(fileobj=io.BytesIO(download(ARCHIVE)), mode="r:gz") as archive:
            font = archive.extractfile(MEMBER).read()
    except (OSError, KeyError, tarfile.TarError) as e:
        return [f"{MEMBER}: download failed: {e}"]
    if not ok(font):
        return [f"{MEMBER}: size or SHA-256 doesn't match the pinned font"]
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(font)
    return []


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    problems = fetch(root)
    for problem in problems:
        print(problem)
    print("icon font: " + (f"{len(problems)} problem(s)" if problems else "present and verified"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
