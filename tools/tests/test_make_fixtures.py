"""The sample documents: the planned set, readable as described, and nothing in
them that looks like real personal data (DK-0023)."""

import re
import sys
from pathlib import Path

import pytest

pytest.importorskip("reportlab")
pypdf = pytest.importorskip("pypdf")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import make_fixtures  # noqa: E402

PAGES = {"Mietvertrag Musterstraße 12.pdf": 3, "Invoice INV-2026-014.pdf": 1, "Lebenslauf Max Mustermann.pdf": 2,
         "Finanzamt München – Bescheid 2025.pdf": 1, "scanned-letters-bundle.pdf": 6, "form-acroform.pdf": 1,
         "form-xfa.pdf": 1, "long-300-pages.pdf": 300}


def test_fixtures(tmp_path: Path) -> None:
    sys.argv = ["make_fixtures.py", str(tmp_path)]
    assert make_fixtures.main() == 0
    assert sorted(p.name for p in tmp_path.iterdir() if p.is_file()) == sorted(make_fixtures.FIXTURES)
    assert sorted(p.name for p in (tmp_path / "corpus").iterdir()) == sorted(make_fixtures.CORPUS)

    text = ""
    for name, pages in PAGES.items():
        reader = pypdf.PdfReader(tmp_path / name)
        assert len(reader.pages) == pages, name
        text += "".join(page.extract_text() for page in reader.pages)
    assert pypdf.PdfReader(tmp_path / "scanned-letters-bundle.pdf").pages[0].extract_text().strip() == ""

    acro = pypdf.PdfReader(tmp_path / "form-acroform.pdf")
    assert {"name", "department", "membership", "consent"} <= set(acro.get_fields())
    assert "/XFA" in pypdf.PdfReader(tmp_path / "form-xfa.pdf").trailer["/Root"]["/AcroForm"]

    encrypted = pypdf.PdfReader(tmp_path / "encrypted-aes256.pdf")
    assert encrypted.is_encrypted and encrypted.decrypt(make_fixtures.PASSWORD)
    with pytest.raises(Exception):
        pypdf.PdfReader(tmp_path / "damaged-xref.pdf", strict=True).pages[0].extract_text()

    # The golden corpus's base files (DK-0658).
    corpus = {name: pypdf.PdfReader(tmp_path / "corpus" / name) for name in make_fixtures.CORPUS}
    assert "Ελληνικά" in corpus["non-latin.pdf"].pages[0].extract_text()
    assert [p.get("/Rotate", 0) for p in corpus["rotated-pages.pdf"].pages] == [0, 90, 180, 270]
    assert len({tuple(p.mediabox) for p in corpus["page-sizes.pdf"].pages}) == 6
    assert corpus["incremental-update.pdf"].metadata.title.endswith("paid")
    assert (tmp_path / "corpus" / "incremental-update.pdf").read_bytes().count(b"%%EOF") == 2
    assert len(corpus["links-annotations.pdf"].pages[0]["/Annots"]) == 3
    assert float(corpus["extreme-pages.pdf"].pages[0].mediabox.width) > 14000

    # Fictional data only: every IBAN is the zero IBAN, every email is example.com.
    assert set(re.findall(r"DE\d{2}(?: ?\d{4}){4} ?\d{2}", text)) == {make_fixtures.IBAN}
    assert all(m.endswith("example.com") for m in re.findall(r"[\w.]+@[\w.]+", text))
    assert re.findall(r"Steuer-ID: ([\d ]+)", text) == [make_fixtures.STEUER_ID]
