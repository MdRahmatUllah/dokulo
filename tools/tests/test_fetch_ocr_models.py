"""The model fetch keeps verified files, replaces bad ones and refuses a
download whose hash doesn't match; no network."""

import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import fetch_ocr_models as f  # noqa: E402


def test_fetch(tmp_path: Path, monkeypatch) -> None:
    good, bad = b"model bytes", b"tampered"
    monkeypatch.setattr(f, "FILES", {
        "a.onnx": (len(good), hashlib.sha256(good).hexdigest()),
        "b.onnx": (len(good), hashlib.sha256(good).hexdigest()),
    })
    target = tmp_path / f.TARGET
    target.mkdir(parents=True)
    (target / "a.onnx").write_bytes(good)  # already there: not fetched again
    fetched = []

    def download(url: str, to: Path) -> None:
        fetched.append(url.rsplit("/", 1)[1])
        Path(to).write_bytes(good)

    assert f.fetch(tmp_path, download) == []
    assert fetched == ["b.onnx"]
    assert (target / "b.onnx").read_bytes() == good

    (target / "b.onnx").write_bytes(bad)
    problems = f.fetch(tmp_path, lambda url, to: Path(to).write_bytes(bad))
    assert problems == ["b.onnx: size or SHA-256 doesn't match the pinned release"]
    assert not list(target.glob("*.part"))
