"""Fetch the bundled PP-OCRv5 models (DK-0398) into packages/doc_vision/assets/ocr/.

    python tools/fetch_ocr_models.py

The files are PaddleOCR PP-OCRv5 (Apache-2.0) in ONNX, from the pinned v1
release of github.com/gitakoos/ocr-models; docs/compliance/ai-models.md has the
intake record. Each file is checked against its SHA-256; a file already there
with the right hash is not fetched again. The folder is gitignored: the gate
(tools/check.py) runs this first, and so does every build of the app.
"""

import hashlib
import sys
import urllib.request
from pathlib import Path

RELEASE = "https://github.com/gitakoos/ocr-models/releases/download/v1"
TARGET = Path("packages/doc_vision/assets/ocr")
FILES = {
    "det.onnx": (4748769, "d7fe3ea74652890722c0f4d02458b7261d9f5ae6c92904d05707c9eb155c7924"),
    "cls.onnx": (582663, "f4bb53707100c5f3d59ba834eb05bb400369f20aed35d4b26807b1bfadd2a70e"),
    "rec_latin.onnx": (8064539, "995b0f5f28d2073896a78c03b5b863eae6af3744bafa0245b8522beea6994927"),
    "ppocrv5_latin_dict.txt": (2616, "ccbcc45730b3fbbd9050c5bc74db6a99067141ef1035e3d14889a84a6b9b1aff"),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ok(path: Path, size: int, digest: str) -> bool:
    return path.is_file() and path.stat().st_size == size and sha256(path) == digest


def fetch(root: Path, download=urllib.request.urlretrieve) -> list[str]:
    """Makes every file present and verified; returns the problems."""
    target = root / TARGET
    target.mkdir(parents=True, exist_ok=True)
    problems = []
    for name, (size, digest) in FILES.items():
        path = target / name
        if ok(path, size, digest):
            continue
        partial = path.with_suffix(path.suffix + ".part")
        try:
            download(f"{RELEASE}/{name}", partial)
        except OSError as e:
            problems.append(f"{name}: download failed: {e}")
            continue
        if ok(partial, size, digest):
            partial.replace(path)
        else:
            partial.unlink(missing_ok=True)
            problems.append(f"{name}: size or SHA-256 doesn't match the pinned release")
    return problems


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    problems = fetch(root)
    for problem in problems:
        print(problem)
    print("ocr models: " + (f"{len(problems)} problem(s)" if problems else "present and verified"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
