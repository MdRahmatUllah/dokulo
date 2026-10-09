"""The size check splits a universal APK per ABI, enforces the budget and
allows only the PP-OCRv5 det/rec/cls models in the app."""

import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import size_check  # noqa: E402


def apk(path: Path, files: dict[str, int]) -> Path:
    with zipfile.ZipFile(path, "w", zipfile.ZIP_STORED) as z:
        for name, size in files.items():
            z.writestr(name, b"\0" * size)
    return path


def test_per_abi_sizes_leave_out_the_other_abis(tmp_path: Path) -> None:
    target = apk(tmp_path / "app.apk", {"lib/arm64-v8a/libx.so": 3000, "lib/x86_64/libx.so": 5000,
                                       "classes.dex": 1000})
    sizes = size_check.per_abi(target)
    total = target.stat().st_size
    assert sizes["arm64-v8a"] == total - 5000 and sizes["x86_64"] == total - 3000


def test_only_the_ocr_models_may_be_bundled(tmp_path: Path) -> None:
    target = apk(tmp_path / "app.apk", {
        "assets/flutter_assets/assets/models/PP-OCRv5_mobile_det.onnx": 10,
        "assets/flutter_assets/assets/models/ppocr_latin_rec.onnx": 10,
        "assets/flutter_assets/assets/models/pp_ocr_cls.onnx": 10,
        # doc_vision's bundled PP-OCRv5 (DK-0398), under its own names
        "assets/flutter_assets/packages/doc_vision/assets/ocr/det.onnx": 10,
        "assets/flutter_assets/packages/doc_vision/assets/ocr/rec_latin.onnx": 10,
        "assets/flutter_assets/packages/doc_vision/assets/ocr/cls.onnx": 10,
        "assets/flutter_assets/assets/other/det.onnx": 10,  # not the OCR folder
        "assets/flutter_assets/assets/models/gemma-4-e2b.gguf": 10,
        "assets/flutter_assets/assets/models/e5-small.onnx": 10,
        "assets/flutter_assets/assets/models/bergamot/model.deen.intgemm.alphas.bin": 10,
        "assets/flutter_assets/AssetManifest.bin": 10,  # Flutter's own, not a model
        "DebugProbesKt.bin": 10,
    })
    assert sorted(Path(m).name for m in size_check.bundled_models(target)) == [
        "det.onnx", "e5-small.onnx", "gemma-4-e2b.gguf", "model.deen.intgemm.alphas.bin"]


def test_the_budget_fails_the_run(tmp_path: Path, monkeypatch, capsys) -> None:
    target = apk(tmp_path / "app.apk", {"lib/arm64-v8a/libx.so": 2_000_000})
    monkeypatch.setattr(size_check, "BUDGET_MB", 1)
    monkeypatch.setattr(sys, "argv", ["size_check.py", str(target)])
    assert size_check.main() == 1
    assert "OVER" in capsys.readouterr().out
