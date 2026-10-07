"""The OCR test set (DK-0400): scanned pages with their exact text, for the
character error rate of each OCR engine.

    python tools/make_ocr_fixtures.py

Writes packages/doc_vision/test/fixtures/ocr/<name>.jpg and <name>.txt (one
line of truth per text line). Everything is fictional, as in test/fixtures.
The German page is page 1 of test/fixtures/scanned-letters-bundle.pdf (made by
tools/make_fixtures.py), copied as it is; its truth is that generator's text.
The English page is drawn here the same way: 110 dpi, a slight rotation, noise,
JPEG at quality 55. Output is byte-identical on every run. Change this, not the
files, and run it again.
"""

import io
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from pypdf import PdfReader

OUT = Path("packages/doc_vision/test/fixtures/ocr")

GERMAN = [
    "Stadtwerke Musterstadt",
    "Herrn Max Mustermann",
    "Musterstraße 12",
    "80331 München",
    "Jahresabrechnung Strom 2025",
    "Sehr geehrter Herr Mustermann,",
    "anbei erhalten Sie die Unterlagen zu Ihrem Vertrag. Bitte prüfen Sie",
    "die Angaben und melden Sie sich bei Fragen unter 089 0000000 oder",
    "service@example.com.",
    "Zahlungen bitte auf IBAN DE00 0000 0000 0000 0000 00.",
    "Mit freundlichen Grüßen",
    "Stadtwerke Musterstadt",
    "Seite 1 von 2",
]

ENGLISH = [
    "Corner Bakery Example Ltd",
    "12 Sample Road, London",
    "Receipt 2026-0314",
    "2 x Sourdough loaf 7.80",
    "1 x Oat flat white 3.40",
    "3 x Cinnamon bun 8.25",
    "Total 19.45",
    "Paid by card. Thank you for your visit!",
]


def english_page() -> bytes:
    rng = random.Random(41)
    dpi = 110
    img = Image.new("L", (int(148 / 25.4 * dpi), int(210 / 25.4 * dpi)), 247)  # A5
    d = ImageDraw.Draw(img)
    big, normal = ImageFont.load_default(size=26), ImageFont.load_default(size=17)
    d.text((60, 60), ENGLISH[0], font=big, fill=25)
    y = 120
    for line in ENGLISH[1:]:
        d.text((60, y), line, font=normal, fill=30)
        y += 44 if line.startswith(("Receipt", "Total")) else 30
    noise = Image.effect_noise(img.size, 18).point(lambda v: v - 128)
    img = Image.blend(img, noise.convert("L"), 0.06)
    img = img.rotate(rng.uniform(-1.2, 1.2), fillcolor=235, resample=Image.BICUBIC)
    out = io.BytesIO()
    img.save(out, "JPEG", quality=55)
    return out.getvalue()


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    out = root / OUT
    out.mkdir(parents=True, exist_ok=True)
    scan = PdfReader(root / "test/fixtures/scanned-letters-bundle.pdf").pages[0].images[0].data
    (out / "letter-de.jpg").write_bytes(scan)
    (out / "letter-de.txt").write_text("\n".join(GERMAN) + "\n", encoding="utf-8", newline="\n")
    (out / "receipt-en.jpg").write_bytes(english_page())
    (out / "receipt-en.txt").write_text("\n".join(ENGLISH) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote 4 files to {OUT.as_posix()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
