"""The icon-font fetch takes the font out of the package archive and refuses
a font whose hash doesn't match; no network."""

import hashlib
import io
import sys
import tarfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import fetch_icon_font as f  # noqa: E402


def archive(font: bytes) -> bytes:
    out = io.BytesIO()
    with tarfile.open(fileobj=out, mode="w:gz") as tar:
        info = tarfile.TarInfo(f.MEMBER)
        info.size = len(font)
        tar.addfile(info, io.BytesIO(font))
    return out.getvalue()


def test_fetch(tmp_path: Path, monkeypatch) -> None:
    good = b"glyphs"
    monkeypatch.setattr(f, "SIZE", len(good))
    monkeypatch.setattr(f, "SHA256", hashlib.sha256(good).hexdigest())
    calls = []

    def download(url: str) -> bytes:
        calls.append(url)
        return archive(good)

    assert f.fetch(tmp_path, download) == []
    assert (tmp_path / f.TARGET).read_bytes() == good
    assert f.fetch(tmp_path, download) == [] and len(calls) == 1  # verified: not fetched again

    (tmp_path / f.TARGET).write_bytes(b"other")
    assert f.fetch(tmp_path, lambda url: archive(b"tampered")) == [
        "lib/fonts/MaterialSymbolsRounded.ttf: size or SHA-256 doesn't match the pinned font"]
