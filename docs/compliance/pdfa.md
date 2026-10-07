# PDF/A-2b: the writer and its check (DK-0395)

"Convert to PDF/A" (UI spec §21.10) writes **PDF/A-2b**, the archive format
authorities and courts ask for. `doc_core`'s `PdfaWriter` does it in two
steps, one per lane:

1. **`prepare` (PDFium):** every page that shows text in a font the file
   doesn't embed (`PdfEngine.usesUnembeddedFonts`, character by character, so
   stamps and overlays count; invisible OCR text doesn't) is rendered at
   200 dpi and replaced by that picture, with **its own text kept as an
   invisible layer** (`OcrTextLayer`), so it stays searchable. That is the
   result sheet's "2 pages were converted to images because their fonts
   weren't included". Files whose fonts are all embedded skip this step.
2. **`finish` (`Lane.qpdf`):** qpdf exports the file's structure as JSON
   (no stream data), Dart edits it, qpdf applies it (`updateFromJson`) and
   rewrites the file:
   - decrypts (the password the user gave);
   - removes JavaScript (the name tree, a JavaScript `/OpenAction`), embedded
     files, XFA (`/XFA`, `/NeedsRendering`) and the catalog's additional
     actions (`/AA`);
   - adds the **OutputIntent** with the ICC's `sRGB2014.icc` (DK-0678; kept
     byte-identical, its SHA-256 is tested) and **XMP metadata**: `pdfaid`
     part 2, conformance B; title, author and producer the same as the Info
     dictionary, which is rewritten to those three;
   - writes a newline before every `endstream`, as PDF/A requires.

## The check

`python tools/check_pdfa.py`, a step of `python tools/check.py`, converts the
sample documents (`test/fixtures`: born-digital pages with non-embedded
fonts, the scanned bundle, the encrypted file, the AcroForm, the XFA form)
and validates every output with **veraPDF** as PDF/A-2b. On 2026-10-07 all
six were compliant (veraPDF 1.30.3).

veraPDF is GPL/MPL Java software: a **test tool, never shipped**. It needs
Java 11+. Install it once per machine, into the folder the check looks in:

```bash
cd "$LOCALAPPDATA/dokulo-tools" && mkdir -p dl && cd dl
curl -sSfLO https://software.verapdf.org/releases/verapdf-installer.zip
python -c "import zipfile; zipfile.ZipFile('verapdf-installer.zip').extractall('.')"
cd verapdf-greenfield-*
python -c "import os,pathlib; open('opts.properties','w').write('INSTALL_PATH='+(pathlib.Path(os.environ['LOCALAPPDATA'])/'dokulo-tools'/'verapdf').as_posix()+chr(10))"
java -jar verapdf-izpack-installer-*.jar -options opts.properties
```

Elsewhere, set `VERAPDF` to the `verapdf` launcher.

## Known limits (v1)

- **Rasterised pages are pictures:** their form fields and annotations
  don't survive, and when any page is rasterised the document's bookmarks are
  lost too (PDFium rebuilds the file). The result sheet names the pages.
- The invisible layer of a rasterised page is Latin-1: other scripts become
  "?" (`OcrTextLayer`).
- **Not normalised yet:** DeviceCMYK content (an sRGB OutputIntent doesn't
  cover it), annotations without the print flag or an appearance stream,
  page-level actions. The sample documents don't have them. A real file
  that fails veraPDF this way is a bug report with the file's structure (no
  user content).
