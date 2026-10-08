"""Fetch the signature pad's handwriting fonts (DK-0206) into
packages/app_pdf/assets/fonts/.

    python tools/fetch_signature_fonts.py

The Type tab offers three styles (UI spec §17.3): Caveat and Dancing Script
(SIL OFL 1.1) and Homemade Apple (Apache-2.0), shipped unmodified, each
taken from google/fonts at a pinned commit and checked against its size and
SHA-256. The folder is gitignored, as for the icon font: the gate
(tools/check.py) runs this, and so does every build.
"""

import hashlib
import sys
import urllib.request
from pathlib import Path

COMMIT = "5e8a3ba899557829a76cfdac30fa512bda91d7ca"
BASE = f"https://raw.githubusercontent.com/google/fonts/{COMMIT}/"
FOLDER = Path("packages/app_pdf/assets/fonts")

# (path in google/fonts, file name here, size, SHA-256)
FONTS = [
    ("ofl/caveat/Caveat%5Bwght%5D.ttf", "Caveat.ttf", 403648,
     "0bdb6b660482d31531b3945849fba5916b3ef8695da7024a9e6b9ee3c4157988"),
    ("ofl/dancingscript/DancingScript%5Bwght%5D.ttf", "DancingScript.ttf", 133636,
     "21808625578fe8d8cd10cb684be546dca077b27cd03a53a2f1ec11dc743c924c"),
    ("apache/homemadeapple/HomemadeApple-Regular.ttf", "HomemadeApple.ttf", 110004,
     "dd1baaca3cde1b1f8415aed3b0aea6808655c9d9ca5a99c7282d9accc16c1a58"),
]


def fetch(root: Path, download=lambda url: urllib.request.urlopen(url).read()) -> list[str]:
    problems = []
    for path, name, size, sha in FONTS:
        target = root / FOLDER / name

        def ok(data: bytes) -> bool:
            return len(data) == size and hashlib.sha256(data).hexdigest() == sha

        if target.is_file() and ok(target.read_bytes()):
            continue
        try:
            font = download(BASE + path)
        except OSError as e:
            problems.append(f"{name}: download failed: {e}")
            continue
        if not ok(font):
            problems.append(f"{name}: size or SHA-256 doesn't match the pinned font")
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(font)
    return problems


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    problems = fetch(root)
    for problem in problems:
        print(problem)
    print("signature fonts: " + (f"{len(problems)} problem(s)" if problems else "present and verified"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
