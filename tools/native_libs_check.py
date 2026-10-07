"""Native-library check of a built app: no FFmpeg, no OpenCV videoio/highgui/dnn.
DK-0680 (docs/compliance/opencv-modules.md).

    python tools/native_libs_check.py <app.apk | app.aab | folder>

Fails (exit 1) when the build contains an FFmpeg library, an OpenCV
videoio/highgui/dnn library, or a libdartcv that exports their functions.
"""

import re
import sys
import zipfile
from pathlib import Path

# Library file names that must not ship (lib<name>[-ver].so, <name>.framework, …).
DENIED_LIBS = re.compile(
    r"(^|/)(lib)?(avcodec|avdevice|avfilter|avformat|avutil|swresample|swscale"
    r"|opencv_(videoio|highgui|dnn))\b", re.I)
# dartcv's exports for the excluded modules (lib/src/g/{videoio,highgui,dnn}.g.dart).
DENIED_SYMBOLS = (b"cv_VideoCapture_", b"cv_VideoWriter_", b"cv_imshow", b"cv_namedWindow", b"cv_dnn_")


def native_files(target: Path) -> dict[str, bytes | None]:
    """Name → contents for the native libraries in an APK/AAB or a folder.
    Contents are read only for dartcv, the one library whose exports we check."""
    def wanted(name: str) -> bool:
        return name.endswith((".so", ".dylib", ".dll")) or ".framework/" in name

    def read(name: str) -> bool:
        return "dartcv" in Path(name).name

    if target.is_dir():
        files = [p for p in target.rglob("*") if p.is_file()]
        return {p.relative_to(target).as_posix(): p.read_bytes() if read(p.name) else None
                for p in files if wanted(p.relative_to(target).as_posix())}
    with zipfile.ZipFile(target) as z:
        return {n: z.read(n) if read(n) else None for n in z.namelist() if wanted(n)}


def check(target: Path) -> list[str]:
    problems = []
    files = native_files(target)
    reported = set()
    for name, data in sorted(files.items()):
        lib = re.sub(r"(\.framework)/.*", r"\1", name)  # one report per framework folder
        if DENIED_LIBS.search(lib) and lib not in reported:
            reported.add(lib)
            problems.append(f"{lib}: excluded library (FFmpeg or OpenCV videoio/highgui/dnn)")
        for symbol in DENIED_SYMBOLS if data else ():
            if symbol in data:
                problems.append(f"{name}: exports {symbol.decode()}* (an excluded OpenCV module is built)")
    return problems


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    target = Path(sys.argv[1])
    if not target.exists():
        print(f"native libs check: {target} not found (build the app first)")
        return 2
    problems = check(target)
    for problem in problems:
        print(problem)
    print("native libs check: " + (f"{len(problems)} problem(s)" if problems else "clean"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
