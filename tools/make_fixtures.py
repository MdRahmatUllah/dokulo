"""Generate the fictional sample documents in test/fixtures (DK-0023).

    python tools/make_fixtures.py [out dir]      # default: test/fixtures

Needs reportlab, pypdf and Pillow (dev tools only; nothing here ships). Every
name, address and number is fictional: IBAN DE00 0000 0000 0000 0000 00,
Steuer-ID 00 000 000 000, example.com addresses, 089 0000000.
"""

import io
import random
import re
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from pypdf import PdfReader, PdfWriter
from pypdf.generic import ArrayObject, BooleanObject, DecodedStreamObject, DictionaryObject, NameObject
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen.canvas import Canvas

IBAN = "DE00 0000 0000 0000 0000 00"
STEUER_ID = "00 000 000 000"
PASSWORD = "dokulo"  # the encrypted sample's user password; documented in the README
W, H = A4


def roboto() -> Path:
    """Roboto from the Flutter SDK (Apache-2.0; every dev machine has it): Latin,
    Greek and Cyrillic, with ß and umlauts, which Pillow's and the PDF base 14
    fonts lack (DK-1050, DK-0658)."""
    flutter = shutil.which("flutter")
    if not flutter:
        raise SystemExit("make_fixtures: the scanned letters and the corpus need Flutter's Roboto; put flutter on PATH")
    sdk = Path(flutter).resolve().parent.parent
    return sdk / "bin" / "cache" / "artifacts" / "material_fonts" / "roboto-regular.ttf"


def scan_font(size: int) -> ImageFont.FreeTypeFont:
    """Roboto for the scanned letters."""
    return ImageFont.truetype(str(roboto()), size)


def canvas(buffer: io.BytesIO, title: str, author: str = "Dokulo samples (fictional)") -> Canvas:
    c = Canvas(buffer, pagesize=A4, invariant=1)  # invariant: byte-identical on every run
    c.setTitle(title)
    c.setAuthor(author)
    c.setCreator("Dokulo tools/make_fixtures.py")
    return c


def text_block(c: Canvas, x: float, y: float, lines: list[str], size: int = 11, leading: float = 15) -> float:
    c.setFont("Helvetica", size)
    for line in lines:
        c.drawString(x, y, line)
        y -= leading
    return y


def mietvertrag() -> bytes:
    b = io.BytesIO()
    c = canvas(b, "Mietvertrag Musterstraße 12", "Anna Beispiel")
    sections = [
        ("§ 1 Mietsache", ["Vermietet wird die Wohnung im 2. OG der Musterstraße 12, 80331 München,",
                           "bestehend aus drei Zimmern, Küche, Bad und Balkon (ca. 78 m²)."]),
        ("§ 2 Mietzeit", ["Das Mietverhältnis beginnt am 1. November 2026 und läuft auf unbestimmte Zeit."]),
        ("§ 3 Miete", ["Die monatliche Grundmiete beträgt 1.240,00 EUR.",
                       "Die Vorauszahlung auf die Betriebskosten beträgt 210,00 EUR.",
                       f"Die Miete wird bis zum dritten Werktag auf das Konto IBAN {IBAN} überwiesen."]),
        ("§ 4 Kaution", ["Der Mieter leistet eine Kaution in Höhe von drei Grundmieten (3.720,00 EUR)."]),
        ("§ 5 Schönheitsreparaturen", ["Schönheitsreparaturen trägt der Mieter nach Maßgabe der gesetzlichen Regelungen."]),
        ("§ 6 Tierhaltung", ["Kleintiere sind erlaubt. Für Hunde und Katzen ist die Zustimmung der Vermieterin nötig."]),
        ("§ 7 Kündigung", ["Es gelten die gesetzlichen Kündigungsfristen."]),
        ("§ 8 Schlussbestimmungen", ["Änderungen bedürfen der Textform. Rückfragen: anna.beispiel@example.com,",
                                     "Telefon 089 0000000."]),
    ]
    for page in range(3):
        y = H - 30 * mm
        if page == 0:
            c.setFont("Helvetica-Bold", 18)
            c.drawString(25 * mm, y, "Mietvertrag für Wohnräume")
            c.bookmarkPage("start")
            c.addOutlineEntry("Mietvertrag für Wohnräume", "start", level=0)
            y = text_block(c, 25 * mm, y - 12 * mm, [
                "Zwischen Anna Beispiel (nachfolgend „Vermieterin“), Beispielweg 3, 80333 München,",
                "und Max Mustermann (nachfolgend „Mieter“), Musterstraße 12, 80331 München,",
                "wird folgender Vertrag geschlossen."]) - 8 * mm
        for heading, body in sections[page * 3:page * 3 + 3]:
            key = re.sub(r"\W", "", heading)
            c.bookmarkPage(key)
            c.addOutlineEntry(heading, key, level=1)
            c.setFont("Helvetica-Bold", 12)
            c.drawString(25 * mm, y, heading)
            y = text_block(c, 25 * mm, y - 7 * mm, body) - 8 * mm
        if page == 2:
            y -= 20 * mm
            text_block(c, 25 * mm, y, ["München, 7. Oktober 2026", "", "_______________________     _______________________",
                                       "Anna Beispiel (Vermieterin)     Max Mustermann (Mieter)"])
        c.setFont("Helvetica", 9)
        c.drawCentredString(W / 2, 15 * mm, f"Seite {page + 1} von 3")
        c.showPage()
    c.save()
    return b.getvalue()


def invoice() -> bytes:
    b = io.BytesIO()
    c = canvas(b, "Invoice INV-2026-014", "Beispiel Design GmbH")
    c.setFont("Helvetica-Bold", 20)
    c.drawString(25 * mm, H - 30 * mm, "Beispiel Design GmbH")
    text_block(c, 25 * mm, H - 38 * mm, ["Beispielweg 3 · 80333 München · hello@beispiel.example.com"], size=9)
    y = text_block(c, 25 * mm, H - 60 * mm, ["Bill to:", "Max Mustermann", "Musterstraße 12", "80331 München"])
    text_block(c, 125 * mm, H - 60 * mm, ["Invoice INV-2026-014", "Date: 7 Oct 2026", "Due: 21 Oct 2026",
                                          "VAT ID: DE000000000"])
    c.setFont("Helvetica-Bold", 16)
    c.drawString(25 * mm, y - 10 * mm, "Invoice")
    y -= 22 * mm
    items = [("Logo design", 1, 850.00), ("Business cards (500)", 2, 64.50), ("Letterhead template", 1, 220.00),
             ("Revisions (hours)", 3, 75.00)]
    c.setFont("Helvetica-Bold", 10)
    for x, label in ((25, "Item"), (115, "Qty"), (135, "Unit"), (165, "Amount")):
        c.drawString(x * mm, y, label)
    c.line(25 * mm, y - 3, 185 * mm, y - 3)
    c.setFont("Helvetica", 10)
    net = 0.0
    for name, qty, unit in items:
        y -= 7 * mm
        net += qty * unit
        for x, value in ((25, name), (115, str(qty)), (135, f"€{unit:,.2f}"), (165, f"€{qty * unit:,.2f}")):
            c.drawString(x * mm, y, value)
    vat = round(net * 0.19, 2)
    y -= 10 * mm
    for label, value in (("Net", net), ("VAT 19 %", vat), ("Total", net + vat)):
        c.setFont("Helvetica-Bold" if label == "Total" else "Helvetica", 10)
        c.drawString(135 * mm, y, label)
        c.drawString(165 * mm, y, f"€{value:,.2f}")
        y -= 6 * mm
    text_block(c, 25 * mm, 40 * mm, [f"Please pay to IBAN {IBAN} (BIC BEISDEMMXXX) by 21 Oct 2026.",
                                     "Reference: INV-2026-014. Thank you!"], size=9, leading=12)
    c.showPage()
    c.save()
    return b.getvalue()


def lebenslauf() -> bytes:
    b = io.BytesIO()
    c = canvas(b, "Lebenslauf Max Mustermann", "Max Mustermann")
    pages = [
        [("Persönliche Daten", ["Max Mustermann", "Musterstraße 12, 80331 München",
                                "max.mustermann@example.com · 089 0000000", "Geboren am 1. Januar 1990 in Musterstadt"]),
         ("Berufserfahrung", ["2022 – heute   Projektleiter, Beispiel Design GmbH, München",
                              "2017 – 2022   Grafikdesigner, Muster & Partner, Augsburg",
                              "2015 – 2017   Junior Designer, Beispielagentur, Nürnberg"])],
        [("Ausbildung", ["2011 – 2015   B.A. Kommunikationsdesign, Hochschule Musterstadt",
                         "2010   Abitur, Beispiel-Gymnasium Musterstadt"]),
         ("Kenntnisse", ["Sprachen: Deutsch (Muttersprache), Englisch (C1), Französisch (B1)",
                         "Software: Layout, Bildbearbeitung, Vektorgrafik"]),
         ("Interessen", ["Fotografie, Radfahren, Kochen"])],
    ]
    for i, sections in enumerate(pages):
        y = H - 30 * mm
        if i == 0:
            c.setFont("Helvetica-Bold", 22)
            c.drawString(25 * mm, y, "Lebenslauf")
            y -= 15 * mm
        for heading, body in sections:
            c.setFont("Helvetica-Bold", 13)
            c.drawString(25 * mm, y, heading)
            y = text_block(c, 25 * mm, y - 8 * mm, body) - 10 * mm
        if i == 1:
            text_block(c, 25 * mm, y - 10 * mm, ["München, 7. Oktober 2026", "Max Mustermann"])
        c.showPage()
    c.save()
    return b.getvalue()


def bescheid() -> bytes:
    b = io.BytesIO()
    c = canvas(b, "Finanzamt München – Bescheid 2025", "Finanzamt München (fictional sample)")
    c.setFont("Helvetica-Bold", 12)
    c.drawString(25 * mm, H - 25 * mm, "Finanzamt München")
    text_block(c, 25 * mm, H - 32 * mm, ["Steuernummer 143/000/00000 · Musterbehördenstraße 1 · 80335 München"], size=9)
    text_block(c, 25 * mm, H - 50 * mm, ["Herrn", "Max Mustermann", "Musterstraße 12", "80331 München"])
    text_block(c, 125 * mm, H - 50 * mm, ["Datum: 7. Oktober 2026", f"Steuer-ID: {STEUER_ID}"], size=10)
    c.setFont("Helvetica-Bold", 14)
    c.drawString(25 * mm, H - 90 * mm, "Bescheid für 2025 über Einkommensteuer")
    y = text_block(c, 25 * mm, H - 102 * mm, [
        "Die Festsetzung ist nach § 165 Abs. 1 AO teilweise vorläufig.",
        "",
        "Festgesetzt werden                               Einkommensteuer",
        "Steuerpflichtiges Einkommen                      48.300 €",
        "Festgesetzte Einkommensteuer                      9.214 €",
        "Abzüglich Lohnsteuer                             -9.876 €",
        "Erstattung                                         662 €",
        "",
        f"Der Erstattungsbetrag wird auf das Konto IBAN {IBAN} überwiesen.",
        "",
        "Rechtsbehelfsbelehrung: Gegen diesen Bescheid ist der Einspruch zulässig. Er ist",
        "innerhalb eines Monats nach Bekanntgabe beim Finanzamt München einzulegen.",
    ])
    c.setFont("Helvetica", 9)
    c.drawCentredString(W / 2, 15 * mm, "Fiktives Beispiel für Dokulo. Kein echter Bescheid.")
    c.showPage()
    c.save()
    return b.getvalue()


LETTERS = [  # Smart Split: three letters, different senders, "Seite x von y", a blank separator
    ("Stadtwerke Musterstadt", "Jahresabrechnung Strom 2025", 2),
    ("Beispiel Versicherung AG", "Ihre Kfz-Versicherung: Beitragsrechnung", 1),
    ("Hausverwaltung Muster", "Nebenkostenabrechnung 2025, Musterstraße 12", 2),
]


def scanned_page(sender: str, subject: str, page: int, pages: int, rng: random.Random) -> Image.Image:
    dpi = 110
    img = Image.new("L", (int(210 / 25.4 * dpi), int(297 / 25.4 * dpi)), 247)
    d = ImageDraw.Draw(img)
    big, normal = scan_font(30), scan_font(17)
    m = 80
    if page == 1:
        d.rectangle((m, m, img.width - m, m + 70), fill=210)
        d.text((m + 15, m + 18), sender, font=big, fill=30)
        d.text((m, 260), "Herrn Max Mustermann\nMusterstraße 12\n80331 München", font=normal, fill=25, spacing=6)
        d.text((m, 400), subject, font=big, fill=20)
    y = 470 if page == 1 else 160
    body = ("Sehr geehrter Herr Mustermann,\n\nanbei erhalten Sie die Unterlagen zu Ihrem Vertrag. Bitte prüfen Sie\n"
            "die Angaben und melden Sie sich bei Fragen unter 089 0000000 oder\nservice@example.com.\n\n"
            f"Zahlungen bitte auf IBAN {IBAN}.\n\nMit freundlichen Grüßen\n{sender}")
    d.text((m, y), body, font=normal, fill=30, spacing=8)
    d.text((img.width // 2 - 50, img.height - 70), f"Seite {page} von {pages}", font=normal, fill=60)
    noise = Image.effect_noise(img.size, 18).point(lambda v: v - 128)
    img = Image.blend(img, Image.merge("L", [noise]).convert("L"), 0.06)
    return img.rotate(rng.uniform(-1.2, 1.2), fillcolor=235, resample=Image.BICUBIC)


def scanned_letters() -> bytes:
    rng = random.Random(23)
    pages = []
    for i, (sender, subject, n) in enumerate(LETTERS):
        pages += [scanned_page(sender, subject, p, n, rng) for p in range(1, n + 1)]
        if i == 1:
            pages.append(Image.new("L", pages[-1].size, 245))  # blank separator sheet
    b = io.BytesIO()
    c = canvas(b, "Scanned letters bundle")
    for img in pages:
        jpg = io.BytesIO()
        img.save(jpg, "JPEG", quality=55)
        c.drawImage(ImageReader(io.BytesIO(jpg.getvalue())), 0, 0, W, H)
        c.showPage()
    c.save()
    return b.getvalue()


def acroform() -> bytes:
    b = io.BytesIO()
    c = canvas(b, "Anmeldung Sportverein (AcroForm)")
    c.setFont("Helvetica-Bold", 16)
    c.drawString(25 * mm, H - 30 * mm, "Anmeldung – Sportverein Musterstadt e. V.")
    form = c.acroForm
    y = H - 50 * mm
    for name, label in (("name", "Name"), ("address", "Anschrift"), ("email", "E-Mail"), ("birthdate", "Geburtsdatum")):
        c.setFont("Helvetica", 11)
        c.drawString(25 * mm, y + 2 * mm, label)
        form.textfield(name=name, tooltip=label, x=65 * mm, y=y, width=110 * mm, height=8 * mm, borderWidth=1)
        y -= 14 * mm
    c.drawString(25 * mm, y + 2 * mm, "Abteilung")
    form.choice(name="department", options=["Fußball", "Schwimmen", "Tennis", "Turnen"], value="Fußball",
                x=65 * mm, y=y, width=60 * mm, height=8 * mm)
    y -= 14 * mm
    c.drawString(25 * mm, y + 2 * mm, "Mitgliedschaft")
    for i, kind in enumerate(("Erwachsene", "Familie", "Ermäßigt")):
        form.radio(name="membership", value=kind, selected=i == 0, x=65 * mm + i * 35 * mm, y=y, size=12)
        c.drawString(65 * mm + i * 35 * mm + 16, y + 2, kind)
    y -= 14 * mm
    form.checkbox(name="consent", x=25 * mm, y=y, size=12, checked=False)
    c.drawString(25 * mm + 18, y + 2, "Ich stimme der Vereinssatzung zu.")
    form.checkbox(name="newsletter", x=25 * mm, y=y - 10 * mm, size=12, checked=True)
    c.drawString(25 * mm + 18, y - 10 * mm + 2, "Newsletter per E-Mail")
    c.showPage()
    c.save()
    return b.getvalue()


XDP = b"""<?xml version="1.0" encoding="UTF-8"?>
<xdp:xdp xmlns:xdp="http://ns.adobe.com/xdp/">
<template xmlns="http://www.xfa.org/schema/xfa-template/3.3/">
<subform name="form1" layout="tb"><field name="Name"><ui><textEdit/></ui></field></subform>
</template>
</xdp:xdp>
"""


def xfa() -> bytes:
    b = io.BytesIO()
    c = canvas(b, "XFA form (sample)")
    text_block(c, 25 * mm, H - 30 * mm, ["Please wait...", "",
                                         "This document is an XFA form. If this text is shown, the viewer",
                                         "cannot display XFA forms (Dokulo shows its XFA message)."])
    c.showPage()
    c.save()
    writer = PdfWriter(clone_from=PdfReader(io.BytesIO(b.getvalue())))
    stream = DecodedStreamObject()
    stream.set_data(XDP)
    writer._root_object[NameObject("/AcroForm")] = DictionaryObject({
        NameObject("/Fields"): ArrayObject(), NameObject("/XFA"): writer._add_object(stream)})
    writer._root_object[NameObject("/NeedsRendering")] = BooleanObject(True)
    out = io.BytesIO()
    writer.write(out)
    return out.getvalue()


def encrypted() -> bytes:
    writer = PdfWriter(clone_from=PdfReader(io.BytesIO(invoice())))
    writer.encrypt(user_password=PASSWORD, owner_password=PASSWORD + "-owner", algorithm="AES-256")
    out = io.BytesIO()
    writer.write(out)
    return out.getvalue()


def damaged() -> bytes:
    """The invoice with a wrong startxref and a zeroed xref table: repairable by
    rebuilding the xref (qpdf, PDFium), but not readable as is."""
    data = invoice()
    start = data.rindex(b"startxref")
    data = data[:start] + b"startxref\n999999\n%%EOF\n"
    return re.sub(rb"\d{10} 00000 n", b"0000000000 00000 n", data)


def long_document() -> bytes:
    b = io.BytesIO()
    c = canvas(b, "Handbuch (300 pages)")
    for n in range(1, 301):
        if n % 25 == 1:
            key = f"ch{n // 25 + 1}"
            c.bookmarkPage(key)
            c.addOutlineEntry(f"Kapitel {n // 25 + 1}", key, level=0)
        c.setFont("Helvetica-Bold", 16)
        c.drawString(25 * mm, H - 30 * mm, f"Kapitel {(n - 1) // 25 + 1} · Abschnitt {n}")
        text_block(c, 25 * mm, H - 45 * mm, [f"Dies ist Seite {n} des Beispielhandbuchs. Sie enthält Text für die Suche,"
                                             f" die Miniaturansichten und", "Leistungstests (Zusammenfügen, Teilen,"
                                             f" Komprimieren). Suchwort: Abschnitt{n:03d}."])
        c.setFont("Helvetica", 9)
        c.drawCentredString(W / 2, 15 * mm, f"Seite {n} von 300")
        c.showPage()
    c.save()
    return b.getvalue()


# The golden corpus's base files (DK-0658): what the samples above don't cover.
# packages/doc_tools/test/corpus/ turns them and the samples into ~100 variants
# with qpdf (encrypted, linearized, rotated, damaged, PDF/A, ...) and runs every
# tool over them.


def non_latin() -> bytes:
    """Greek, Cyrillic, Polish, Czech, Turkish and Vietnamese text in an
    embedded subset of Roboto (a TrueType font, not one of the base 14)."""
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont

    pdfmetrics.registerFont(TTFont("Roboto", str(roboto())))
    lines = [
        ("Ελληνικά", "Τιμολόγιο αρ. 14 · Οδός Παραδείγματος 12, Αθήνα · σύνολο 1.240,00 €"),
        ("Русский", "Счёт № 14 · ул. Примерная, 12, Москва · итого 1 240,00 €"),
        ("Українська", "Рахунок № 14 · вул. Прикладна, 12, Київ · разом 1 240,00 €"),
        ("Polski", "Faktura nr 14 · ul. Przykładowa 12, Łódź · razem 1 240,00 zł"),
        ("Čeština", "Faktura č. 14 · Příkladová 12, Brno · celkem 1 240,00 Kč"),
        ("Türkçe", "Fatura no. 14 · Örnek Sokağı 12, İstanbul · toplam 1.240,00 TL"),
        ("Tiếng Việt", "Hóa đơn số 14 · Đường Ví Dụ 12, Hà Nội · tổng cộng 1.240.000 đ"),
    ]
    b = io.BytesIO()
    c = canvas(b, "Non-Latin samples – Ελληνικά, Русский")
    for page in range(2):
        y = H - 30 * mm
        c.setFont("Roboto", 18)
        c.drawString(25 * mm, y, f"Beispieltexte · Παράδειγμα · Пример ({page + 1}/2)")
        for label, text in lines[page * 4:page * 4 + 4]:
            y -= 14 * mm
            c.setFont("Roboto", 12)
            c.drawString(25 * mm, y, label)
            c.setFont("Roboto", 11)
            c.drawString(25 * mm, y - 6 * mm, text)
        c.showPage()
    c.save()
    return b.getvalue()


def page_sizes() -> bytes:
    """Six page sizes, portrait and landscape, each page saying what it is."""
    from reportlab.lib.pagesizes import A3, A5, LEGAL, LETTER, landscape

    sizes = [("A4", A4), ("US Letter", LETTER), ("A3 landscape", landscape(A3)), ("A5", A5),
             ("US Legal", LEGAL), ("Square 140 mm", (140 * mm, 140 * mm))]
    b = io.BytesIO()
    c = canvas(b, "Page sizes")
    for name, size in sizes:
        c.setPageSize(size)
        c.rect(10 * mm, 10 * mm, size[0] - 20 * mm, size[1] - 20 * mm)
        c.setFont("Helvetica-Bold", 16)
        c.drawString(20 * mm, size[1] - 25 * mm, f"{name}: {size[0] / mm:.0f} × {size[1] / mm:.0f} mm")
        c.showPage()
    c.save()
    return b.getvalue()


def rotated_pages() -> bytes:
    """Four pages with /Rotate 0, 90, 180, 270, the last two with a CropBox
    smaller than the MediaBox."""
    b = io.BytesIO()
    c = canvas(b, "Rotated pages")
    for n in range(4):
        c.setFont("Helvetica-Bold", 20)
        c.drawString(25 * mm, H - 30 * mm, f"Seite {n + 1}: oben ist hier (Rotate {n * 90})")
        c.line(25 * mm, H - 35 * mm, 100 * mm, H - 35 * mm)
        c.showPage()
    c.save()
    writer = PdfWriter(clone_from=PdfReader(io.BytesIO(b.getvalue())))
    for n, page in enumerate(writer.pages):
        if n:
            page.rotate(n * 90)
        if n >= 2:
            page.cropbox.lower_left = (15 * mm, 15 * mm)
            page.cropbox.upper_right = (W - 15 * mm, H - 15 * mm)
    out = io.BytesIO()
    writer.write(out)
    return out.getvalue()


def images() -> bytes:
    """Pictures in every form a tool meets: a JPEG photo, a PNG with alpha,
    a CMYK JPEG, greyscale and a 1-bit bitmap."""
    rng = random.Random(58)
    photo = Image.new("RGB", (900, 600))
    photo.putdata([(x * 255 // 900, y * 255 // 600, (x + y) * 255 // 1500) for y in range(600) for x in range(900)])
    d = ImageDraw.Draw(photo)
    for _ in range(40):
        x, y = rng.randrange(900), rng.randrange(600)
        d.ellipse((x, y, x + rng.randrange(20, 120), y + rng.randrange(20, 120)),
                  fill=(rng.randrange(256), rng.randrange(256), rng.randrange(256)))
    alpha = Image.new("RGBA", (400, 400), (0, 0, 0, 0))
    ImageDraw.Draw(alpha).ellipse((40, 40, 360, 360), fill=(34, 81, 230, 160))
    kinds = [("JPEG photo", photo, "JPEG"), ("PNG with alpha", alpha, "PNG"), ("CMYK JPEG", photo.convert("CMYK"), "JPEG"),
             ("Greyscale", photo.convert("L"), "JPEG"), ("1-bit", photo.convert("1"), "PNG")]
    b = io.BytesIO()
    c = canvas(b, "Images")
    y = H - 25 * mm
    for n, (label, img, fmt) in enumerate(kinds):
        if n == 3:
            c.showPage()
            y = H - 25 * mm
        data = io.BytesIO()
        if fmt == "JPEG":
            img.save(data, fmt, quality=80)
        else:
            img.save(data, fmt)
        c.setFont("Helvetica", 10)
        c.drawString(25 * mm, y, label)
        c.drawImage(ImageReader(io.BytesIO(data.getvalue())), 25 * mm, y - 75 * mm, 100 * mm, 70 * mm, mask="auto")
        y -= 85 * mm
    c.showPage()
    c.save()
    return b.getvalue()


def links_annotations() -> bytes:
    """An outline, internal and web links, a highlight, a sticky note and a
    free-text comment."""
    from pypdf.annotations import FreeText, Highlight, Link, Text
    from pypdf.generic import ArrayObject as Arr, FloatObject as F

    b = io.BytesIO()
    c = canvas(b, "Links and annotations")
    for n in range(2):
        c.bookmarkPage(f"p{n}")
        c.addOutlineEntry(f"Teil {n + 1}", f"p{n}", level=0)
        c.setFont("Helvetica-Bold", 16)
        c.drawString(25 * mm, H - 30 * mm, f"Teil {n + 1}")
        text_block(c, 25 * mm, H - 45 * mm, ["Zu Teil 2 (interner Link) · www.example.com (Weblink)",
                                             "Dieser Satz ist markiert."])
        c.showPage()
    c.save()
    writer = PdfWriter(clone_from=PdfReader(io.BytesIO(b.getvalue())))
    y = H - 45 * mm
    writer.add_annotation(0, Link(rect=(25 * mm, y - 3, 75 * mm, y + 10), target_page_index=1))
    writer.add_annotation(0, Link(rect=(80 * mm, y - 3, 130 * mm, y + 10), url="https://www.example.com"))
    quad = Arr([F(25 * mm), F(y - 2), F(85 * mm), F(y - 2), F(25 * mm), F(y - 17), F(85 * mm), F(y - 17)])
    writer.add_annotation(0, Highlight(rect=(25 * mm, y - 17, 85 * mm, y - 2), quad_points=quad))
    writer.add_annotation(1, Text(rect=(150 * mm, H - 40 * mm, 160 * mm, H - 30 * mm), text="Notiz: bitte prüfen"))
    writer.add_annotation(1, FreeText(text="Freitext-Kommentar", rect=(25 * mm, 100 * mm, 120 * mm, 115 * mm)))
    out = io.BytesIO()
    writer.write(out)
    return out.getvalue()


def incremental() -> bytes:
    """The invoice plus an incremental update: a second revision appended after
    the first %%EOF, with its own xref section and a trailer whose /Prev points
    back, giving the document a new Info dictionary (title "… - paid")."""
    first = invoice()
    prev = int(re.search(rb"startxref\s+(\d+)", first[first.rindex(b"startxref"):]).group(1))
    trailer = first[first.rindex(b"trailer"):]
    size = int(re.search(rb"/Size (\d+)", trailer).group(1))
    root = re.search(rb"/Root (\d+ 0 R)", trailer).group(1)
    obj = f"{size} 0 obj\n<< /Title (Invoice INV-2026-014 - paid) /Producer (Dokulo samples) >>\nendobj\n".encode()
    offset = len(first)
    xref_at = offset + len(obj)
    update = obj + (f"xref\n{size} 1\n{offset:010d} 00000 n \n"
                    f"trailer\n<< /Size {size + 1} /Root {root.decode()} /Info {size} 0 R /Prev {prev} >>\n"
                    f"startxref\n{xref_at}\n%%EOF\n").encode()
    return first + update


def extreme_pages() -> bytes:
    """A 5 × 5 m page (PDF allows up to 5.08 m), a 25 mm stamp-sized page and
    an empty page."""
    b = io.BytesIO()
    c = canvas(b, "Extreme page sizes")
    for size, label in (((5000 * mm, 5000 * mm), "5 m × 5 m"), ((25 * mm, 25 * mm), "25 mm"), (A4, None)):
        c.setPageSize(size)
        if label:
            c.setFont("Helvetica-Bold", 6 if size[0] < 100 * mm else 400)
            c.drawString(size[0] * 0.1, size[1] / 2, label)
        c.showPage()
    c.save()
    return b.getvalue()


def vector_heavy() -> bytes:
    """One page of 6,000 thin strokes and 400 semi-transparent circles: slow
    to render, small to store."""
    rng = random.Random(6)
    b = io.BytesIO()
    c = canvas(b, "Vector drawing")
    c.setLineWidth(0.3)
    for _ in range(6000):
        c.line(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(0, W), rng.uniform(0, H))
    for _ in range(400):
        c.setFillColorRGB(rng.random(), rng.random(), rng.random(), alpha=0.4)
        c.circle(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(5, 40), stroke=0, fill=1)
    c.showPage()
    c.save()
    return b.getvalue()


CORPUS = {
    "non-latin.pdf": non_latin,
    "page-sizes.pdf": page_sizes,
    "rotated-pages.pdf": rotated_pages,
    "images.pdf": images,
    "links-annotations.pdf": links_annotations,
    "incremental-update.pdf": incremental,
    "extreme-pages.pdf": extreme_pages,
    "vector-heavy.pdf": vector_heavy,
}


FIXTURES = {
    "Mietvertrag Musterstraße 12.pdf": mietvertrag,
    "Invoice INV-2026-014.pdf": invoice,
    "Lebenslauf Max Mustermann.pdf": lebenslauf,
    "Finanzamt München – Bescheid 2025.pdf": bescheid,
    "scanned-letters-bundle.pdf": scanned_letters,
    "form-acroform.pdf": acroform,
    "form-xfa.pdf": xfa,
    "encrypted-aes256.pdf": encrypted,
    "damaged-xref.pdf": damaged,
    "long-300-pages.pdf": long_document,
}


def main() -> int:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "test/fixtures")
    out.mkdir(parents=True, exist_ok=True)
    for name, make in FIXTURES.items():
        (out / name).write_bytes(make())
        print(f"{name}: {(out / name).stat().st_size:,} bytes")
    (out / "corpus").mkdir(exist_ok=True)
    for name, make in CORPUS.items():
        (out / "corpus" / name).write_bytes(make())
        print(f"corpus/{name}: {(out / 'corpus' / name).stat().st_size:,} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
