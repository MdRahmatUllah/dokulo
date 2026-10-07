"""The native-library check passes a clean build and fails FFmpeg, excluded
OpenCV libraries and a libdartcv that exports excluded modules."""

import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import native_libs_check  # noqa: E402

CLEAN_DARTCV = b"\x7fELF...cv_cvtColor\x00cv_imencode\x00cv_Mat_close\x00"


def apk(path: Path, files: dict[str, bytes]) -> Path:
    with zipfile.ZipFile(path, "w") as z:
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
