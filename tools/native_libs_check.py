"""Native-library check of a built app (DK-0680, DK-0018).

    python tools/native_libs_check.py <app.apk | app.aab | folder>

Fails (exit 1) when the build contains
- an FFmpeg library, an OpenCV videoio/highgui/dnn library, or a libdartcv that
  exports their functions (docs/compliance/opencv-modules.md);
- a 64-bit ELF library with a PT_LOAD segment aligned below 16 KB, or an
  uncompressed library whose data isn't 16 KB-aligned in the APK: Google Play
  requires 16 KB page support for arm64-v8a and x86_64.
"""

import re
import struct
import sys
import zipfile
from pathlib import Path

# Library file names that must not ship (lib<name>[-ver].so, <name>.framework, …).
DENIED_LIBS = re.compile(
    r"(^|/)(lib)?(avcodec|avdevice|avfilter|avformat|avutil|swresample|swscale"
    r"|opencv_(videoio|highgui|dnn))\b", re.I)
# dartcv's exports for the excluded modules (lib/src/g/{videoio,highgui,dnn}.g.dart).
DENIED_SYMBOLS = (b"cv_VideoCapture_", b"cv_VideoWriter_", b"cv_imshow", b"cv_namedWindow", b"cv_dnn_")
PAGE_16K = 16 * 1024


def native_files(target: Path) -> dict[str, bytes | None]:
    """Name → contents for the native libraries in an APK/AAB or a folder.
    ELF libraries (.so) are read for the alignment and export checks; the rest
    (iOS frameworks, dylibs) only by name."""
    def wanted(name: str) -> bool:
        return name.endswith((".so", ".dylib", ".dll")) or ".framework/" in name

    def read(name: str) -> bool:
        return name.endswith(".so") or "dartcv" in Path(name).name

    if target.is_dir():
        files = [p for p in target.rglob("*") if p.is_file()]
        return {p.relative_to(target).as_posix(): p.read_bytes() if read(p.name) else None
                for p in files if wanted(p.relative_to(target).as_posix())}
    with zipfile.ZipFile(target) as z:
        return {n: z.read(n) if read(n) else None for n in z.namelist() if wanted(n)}


def load_alignments(elf: bytes) -> list[int] | None:
    """p_align of every PT_LOAD segment of a 64-bit ELF file; None for anything else."""
    if len(elf) < 64 or elf[:4] != b"\x7fELF" or elf[4] != 2:  # EI_CLASS 2: 64-bit
        return None
    e = "<" if elf[5] == 1 else ">"
    phoff, = struct.unpack_from(e + "Q", elf, 32)
    phentsize, phnum = struct.unpack_from(e + "HH", elf, 54)
    aligns = []
    for i in range(phnum):
        at = phoff + i * phentsize
        p_type, = struct.unpack_from(e + "I", elf, at)
        if p_type == 1:  # PT_LOAD
            aligns.append(struct.unpack_from(e + "Q", elf, at + 48)[0])
    return aligns


def misaligned_in_zip(target: Path) -> list[str]:
    """Uncompressed (stored) .so entries whose data doesn't start on a 16 KB
    boundary: Android maps them straight from the APK."""
    out = []
    with zipfile.ZipFile(target) as z, target.open("rb") as f:
        for info in z.infolist():
            if not info.filename.endswith(".so") or info.compress_type != zipfile.ZIP_STORED:
                continue
            f.seek(info.header_offset + 26)
            name_len, extra_len = struct.unpack("<HH", f.read(4))
            offset = info.header_offset + 30 + name_len + extra_len
            if offset % PAGE_16K:
                out.append(f"{info.filename}: stored at offset {offset}, not 16 KB-aligned (zipalign -P 16)")
    return out


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
        aligns = load_alignments(data) if data and name.endswith(".so") else None
        if aligns and min(aligns) < PAGE_16K:
            problems.append(f"{name}: LOAD segment aligned to {min(aligns)} bytes, needs 16 KB (link with -z max-page-size=16384)")
    if target.is_file() and zipfile.is_zipfile(target):
        problems += misaligned_in_zip(target)
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
