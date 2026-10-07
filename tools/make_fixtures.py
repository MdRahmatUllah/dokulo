"""Generate the fictional sample documents in test/fixtures (DK-0023).

    python tools/make_fixtures.py [out dir]      # default: test/fixtures

Needs reportlab, pypdf and Pillow (dev tools only; nothing here ships). Every
name, address and number is fictional: IBAN DE00 0000 0000 0000 0000 00,
Steuer-ID 00 000 000 000, example.com addresses, 089 0000000.
"""

import io
import random
import re
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
    big, normal = ImageFont.load_default(size=30), ImageFont.load_default(size=17)
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
    return 0


if __name__ == "__main__":
    sys.exit(main())
