"""The OCR test set (DK-0400): scanned pages with their exact text, for the
character error rate of each OCR engine.

    python tools/make_ocr_fixtures.py

Writes packages/doc_vision/test/fixtures/ocr/<name>.jpg and <name>.txt (one
line of truth per text line). Everything is fictional, as in test/fixtures.
The German page is page 1 of test/fixtures/scanned-letters-bundle.pdf (made by
tools/make_fixtures.py), copied as it is; its truth is that generator's text.
The English page is drawn here the same way: 110 dpi, a slight rotation, noise,
JPEG at quality 55. PAGES (DK-0661) adds one page per hard case: a clean 300 dpi
invoice, low contrast, 7.5 pt small print, a mixed DE/EN statement with
numbers, a faded narrow receipt. Output is byte-identical on every run. Change this, not the
files, and run it again.
"""

import io
import random
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont
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


# DK-0661: the wider set, one page per hard case.


def roboto(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    """Roboto from the Flutter SDK (Apache-2.0), with ß and umlauts."""
    flutter = shutil.which("flutter")
    if not flutter:
        raise SystemExit("make_ocr_fixtures: the extra pages need Flutter's Roboto; put flutter on PATH")
    sdk = Path(flutter).resolve().parent.parent
    name = "roboto-bold.ttf" if bold else "roboto-regular.ttf"
    return ImageFont.truetype(str(sdk / "bin" / "cache" / "artifacts" / "material_fonts" / name), size)


def mm(v: float, dpi: int) -> int:
    return int(v / 25.4 * dpi)


def page(lines, *, dpi, size_mm=(210, 297), pt=11, title_pt=None, ink=30, paper=247, noise=0.05, skew=1.0,
         seed=1, leading=1.55, margin_mm=20, quality=60, blur=0.0):
    """Lines drawn top to bottom; the first in title_pt (bold) when given."""
    rng = random.Random(seed)
    img = Image.new("L", (mm(size_mm[0], dpi), mm(size_mm[1], dpi)), paper)
    d = ImageDraw.Draw(img)
    px = lambda points: max(8, int(points / 72 * dpi))  # noqa: E731
    x, y = mm(margin_mm, dpi), mm(margin_mm, dpi)
    for i, line in enumerate(lines):
        font = roboto(px(title_pt), bold=True) if (i == 0 and title_pt) else roboto(px(pt))
        d.text((x, y), line, font=font, fill=ink)
        y += int(px(title_pt if (i == 0 and title_pt) else pt) * leading)
    if blur:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    if noise:
        n = Image.effect_noise(img.size, 18).point(lambda v: v - 128)
        img = Image.blend(img, n.convert("L"), noise)
    img = img.rotate(rng.uniform(-skew, skew), fillcolor=paper - 12, resample=Image.BICUBIC)
    out = io.BytesIO()
    img.save(out, "JPEG", quality=quality)
    return out.getvalue()


INVOICE_DE = [
    "Rechnung Nr. 2026-0815",
    "Beispiel Handwerk GmbH, Werkstraße 7, 80333 München",
    "Rechnungsdatum: 14.10.2026  Leistungsdatum: 09.10.2026",
    "Pos. 1  Wartung Heizungsanlage  1 Std.  89,00 EUR",
    "Pos. 2  Dichtungssatz  2 Stk.  24,50 EUR",
    "Pos. 3  Anfahrtspauschale  1  35,00 EUR",
    "Nettobetrag 173,00 EUR",
    "zzgl. 19 % USt. 32,87 EUR",
    "Gesamtbetrag 205,87 EUR",
    "Zahlbar bis 28.10.2026 ohne Abzug auf IBAN DE00 0000 0000 0000 0000 00.",
]

LETTER_EN_LOW = [
    "Sample Housing Association",
    "Dear Ms Example,",
    "thank you for your letter of 2 October. We have checked the meter",
    "readings for flat 4B and corrected your annual statement.",
    "The new balance is GBP 42.10 in your favour and will be refunded",
    "to your account within ten working days.",
    "Kind regards,",
    "Customer Services",
]

SMALLPRINT_DE = [
    "Allgemeine Geschäftsbedingungen (Auszug)",
    "§ 1 Geltungsbereich. Diese Bedingungen gelten für alle Verträge",
    "zwischen der Beispiel Versand GmbH und ihren Kundinnen und Kunden.",
    "§ 2 Vertragsschluss. Der Vertrag kommt mit unserer Bestätigung zustande.",
    "§ 3 Widerruf. Sie können Ihre Erklärung innerhalb von 14 Tagen widerrufen.",
    "§ 4 Lieferung. Wir liefern innerhalb Deutschlands in 2 bis 4 Werktagen.",
    "§ 5 Gewährleistung. Es gelten die gesetzlichen Vorschriften.",
]

TABLE_MIXED = [
    "Kontoauszug / Account statement 09/2026",
    "01.09.2026  Miete September  -1.240,00",
    "03.09.2026  Gehalt Beispiel AG  +3.512,46",
    "11.09.2026  Card payment Corner Bakery  -19,45",
    "18.09.2026  Stromabschlag Stadtwerke  -86,00",
    "30.09.2026  Kontostand / Balance  4.127,01",
    "IBAN DE00 0000 0000 0000 0000 00  BIC BEISDEMMXXX",
]

RECEIPT_DE = [
    "Bäckerei Muster",
    "Hauptstraße 3, 80331 München",
    "2 x Brezel  1,60",
    "1 x Laugenstange  1,10",
    "1 x Kaffee groß  2,90",
    "Summe EUR  5,60",
    "Bar  10,00  Rückgeld  4,40",
    "Vielen Dank für Ihren Einkauf!",
]

PAGES = {
    # name: (truth lines, drawing options)
    "invoice-de-300dpi": (INVOICE_DE, dict(dpi=300, pt=11, title_pt=16, noise=0.03, skew=0.5, seed=2, quality=75)),
    "letter-en-lowcontrast": (LETTER_EN_LOW, dict(dpi=150, pt=12, title_pt=15, ink=120, paper=205, seed=3)),
    "smallprint-de": (SMALLPRINT_DE, dict(dpi=200, pt=7.5, title_pt=10, seed=4, leading=1.5)),
    "statement-mixed": (TABLE_MIXED, dict(dpi=150, pt=10.5, title_pt=13, seed=5)),
    "receipt-de-faded": (RECEIPT_DE, dict(dpi=200, size_mm=(80, 140), pt=9, title_pt=12, ink=125, paper=240,
                                          seed=6, margin_mm=6, blur=0.6)),
}


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    out = root / OUT
    out.mkdir(parents=True, exist_ok=True)
    scan = PdfReader(root / "test/fixtures/scanned-letters-bundle.pdf").pages[0].images[0].data
    (out / "letter-de.jpg").write_bytes(scan)
    (out / "letter-de.txt").write_text("\n".join(GERMAN) + "\n", encoding="utf-8", newline="\n")
    (out / "receipt-en.jpg").write_bytes(english_page())
    (out / "receipt-en.txt").write_text("\n".join(ENGLISH) + "\n", encoding="utf-8", newline="\n")
    for name, (lines, opts) in PAGES.items():
        (out / f"{name}.jpg").write_bytes(page(lines, **opts))
        # The truth has one space between words: the gaps drawn for columns
        # aren't text, and the CER joins words with single spaces.
        truth = "\n".join(" ".join(line.split()) for line in lines)
        (out / f"{name}.txt").write_text(truth + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {4 + 2 * len(PAGES)} files to {OUT.as_posix()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
