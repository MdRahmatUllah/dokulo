"""The signature-font fetch writes each pinned font once and refuses one
whose hash doesn't match; no network."""

import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import fetch_signature_fonts as f  # noqa: E402


def test_fetch(tmp_path: Path, monkeypatch) -> None:
    fonts = {"a.ttf": b"caveat", "b.ttf": b"dancing"}
    monkeypatch.setattr(f, "FONTS", [
        (f"x/{name}", name, len(data), hashlib.sha256(data).hexdigest())
        for name, data in fonts.items()
    ])
    calls = []

    def download(url: str) -> bytes:
        calls.append(url)
        return fonts[url.rsplit("/", 1)[1]]

    assert f.fetch(tmp_path, download) == []
    for name, data in fonts.items():
        assert (tmp_path / f.FOLDER / name).read_bytes() == data
    assert f.fetch(tmp_path, download) == [] and len(calls) == 2  # verified: not fetched again

    (tmp_path / f.FOLDER / "a.ttf").write_bytes(b"other")
    assert f.fetch(tmp_path, lambda url: b"tampered") == [
        "a.ttf: size or SHA-256 doesn't match the pinned file"]


def test_pinned_to_a_commit() -> None:
    assert len(f.COMMIT) == 40 and f.COMMIT in f.BASE
    assert {name for _, name, _, _ in f.FONTS} == {
        "Caveat.ttf", "DancingScript.ttf", "HomemadeApple.ttf",
        "Caveat-OFL.txt", "DancingScript-OFL.txt", "HomemadeApple-LICENSE.txt"}
