"""App size budget (DK-0017, docs/size-budget.md).

    python tools/size_check.py <app.apk>

Reports what each ABI's APK would weigh (the universal APK minus the other
ABIs' libraries: what a per-ABI split or Play's per-device APK carries) and
fails (exit 1) when
- an ABI is over BUDGET_MB, or
- the APK bundles a model file other than PP-OCRv5's det, rec and cls models:
  every other model is an on-demand download.
"""

import os
import re
import sys
import zipfile
from collections import Counter
from pathlib import Path

BUDGET_MB = 90  # per-ABI APK; docs/size-budget.md says why
# Model files by type; .bin/.spm (Bergamot packs) only inside a models/ folder,
# since Flutter and Kotlin ship unrelated .bin files.
MODEL = re.compile(r"\.(onnx|ort|gguf|tflite|pt|pth|safetensors|ckpt)$|(^|/)models?/.*\.(bin|spm)$", re.I)
ALLOWED_MODEL = re.compile(r"(?i)pp[-_]?ocr.*(det|rec|cls)")


def per_abi(apk: Path) -> dict[str, int]:
    """Bytes of the APK each ABI would get: everything but the other ABIs' libraries."""
    with zipfile.ZipFile(apk) as z:
        libs = Counter()
        for info in z.infolist():
            parts = info.filename.split("/")
            if parts[0] == "lib" and len(parts) > 2:
                libs[parts[1]] += info.compress_size
    total = os.path.getsize(apk)
    return {abi: total - sum(size for other, size in libs.items() if other != abi) for abi in libs} or {"all": total}


def bundled_models(apk: Path) -> list[str]:
    with zipfile.ZipFile(apk) as z:
        return [n for n in z.namelist() if MODEL.search(n) and not ALLOWED_MODEL.search(Path(n).name)]


def main() -> int:
    if len(sys.argv) != 2 or not Path(sys.argv[1]).is_file():
        print(__doc__)
        return 2
    apk = Path(sys.argv[1])
    problems = []
    for abi, size in sorted(per_abi(apk).items()):
        over = size > BUDGET_MB * 1_000_000
        print(f"{abi:12} {size / 1_000_000:6.1f} MB  (budget {BUDGET_MB} MB){'  OVER' if over else ''}")
        if over:
            problems.append(f"{abi} is {size / 1_000_000:.1f} MB, over the {BUDGET_MB} MB budget")
    problems += [f"{m}: a bundled model; only PP-OCRv5 det/rec/cls ship in the app, the rest are downloads"
                 for m in bundled_models(apk)]
    for p in problems:
        print(p)
    print("size check: " + (f"{len(problems)} problem(s)" if problems else "within budget"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
