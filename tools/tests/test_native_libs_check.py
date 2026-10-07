"""The native-library check passes a clean build and fails FFmpeg, excluded
OpenCV libraries and a libdartcv that exports excluded modules."""

import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import native_libs_check  # noqa: E402

CLEAN_DARTCV = b"\x7fELF...cv_cvtColor\x00cv_imencode\x00cv_Mat_close\x00"


def apk(path: Path, files: dict[str, bytes]) -> Path:
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:  # stored entries get the 16 KB zip check
        for name, data in files.items():
            z.writestr(name, data)
    return path


def test_clean_build_passes(tmp_path: Path) -> None:
    target = apk(tmp_path / "app.apk", {
        "lib/arm64-v8a/libdartcv.so": CLEAN_DARTCV,
        "lib/arm64-v8a/libflutter.so": b"\x7fELF",
        "classes.dex": b"cv_dnn_ in dex is not a native library",
    })
    assert native_libs_check.check(target) == []


def test_excluded_libraries_and_exports_fail(tmp_path: Path) -> None:
    target = apk(tmp_path / "app.apk", {
        "lib/arm64-v8a/libdartcv.so": CLEAN_DARTCV + b"cv_VideoCapture_create\x00cv_dnn_Net_close\x00",
        "lib/arm64-v8a/libavcodec.so": b"\x7fELF",
        "lib/arm64-v8a/libswscale-7.so": b"\x7fELF",
    })
    problems = native_libs_check.check(target)
    assert len(problems) == 4
    assert sum("excluded library" in p for p in problems) == 2
    assert any("cv_VideoCapture_" in p for p in problems) and any("cv_dnn_" in p for p in problems)


def test_folder_with_ios_frameworks(tmp_path: Path) -> None:
    framework = tmp_path / "Frameworks" / "avformat.framework"
    framework.mkdir(parents=True)
    (framework / "avformat").write_bytes(b"\xcf\xfa\xed\xfe")
    (framework / "Info.plist").write_bytes(b"<plist/>")  # still one problem per framework
    (tmp_path / "Frameworks" / "dartcv.framework").mkdir()
    (tmp_path / "Frameworks" / "dartcv.framework" / "dartcv").write_bytes(CLEAN_DARTCV)
    assert native_libs_check.check(tmp_path) == ["Frameworks/avformat.framework: excluded library "
                                                 "(FFmpeg or OpenCV videoio/highgui/dnn)"]


def elf64(*aligns: int) -> bytes:
    """A minimal little-endian ELF64 header with one PT_LOAD per alignment."""
    import struct
    phoff, phentsize = 64, 56
    header = bytearray(64)
    header[:6] = b"\x7fELF\x02\x01"
    struct.pack_into("<Q", header, 32, phoff)
    struct.pack_into("<HH", header, 54, phentsize, len(aligns))
    phdrs = b"".join(struct.pack("<IIQQQQQQ", 1, 5, 0, 0, 0, 0, 0, a) for a in aligns)
    return bytes(header) + phdrs


def test_16k_alignment(tmp_path: Path) -> None:
    assert native_libs_check.load_alignments(elf64(16384, 65536)) == [16384, 65536]
    assert native_libs_check.load_alignments(b"\x7fELF\x01\x01") is None  # 32-bit: not checked
    target = apk(tmp_path / "app.apk", {
        "lib/arm64-v8a/libgood.so": elf64(16384, 16384),
        "lib/arm64-v8a/libold.so": elf64(4096, 4096),
        "lib/armeabi-v7a/libv7.so": b"\x7fELF\x01\x01" + bytes(60),
    })
    problems = native_libs_check.check(target)
    assert [p for p in problems if "LOAD segment" in p] == [
        "lib/arm64-v8a/libold.so: LOAD segment aligned to 4096 bytes, needs 16 KB (link with -z max-page-size=16384)"]


def test_stored_libraries_must_start_on_a_16k_boundary(tmp_path: Path) -> None:
    import zipfile
    target = tmp_path / "app.apk"
    with zipfile.ZipFile(target, "w", zipfile.ZIP_STORED) as z:
        z.writestr("lib/arm64-v8a/libx.so", elf64(16384))  # at offset ~40: misaligned
    problems = native_libs_check.misaligned_in_zip(target)
    assert len(problems) == 1 and "not 16 KB-aligned" in problems[0]
