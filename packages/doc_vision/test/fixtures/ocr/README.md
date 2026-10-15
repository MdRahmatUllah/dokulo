# OCR test set (DK-0400, DK-0661)

Scanned pages with their exact text, for the character error rate (CER) of
each OCR engine: edit distance over the reference length, words joined by
spaces. Fictional, like `test/fixtures`. Made by `tools/make_ocr_fixtures.py`:
change the generator, not the files.

| Page | What | Truth |
| --- | --- | --- |
| `letter-de.jpg` | German letter, 110 dpi grey scan, slight skew (page 1 of `scanned-letters-bundle.pdf`) | `letter-de.txt`, 13 lines |
| `receipt-en.jpg` | English receipt, 110 dpi, slight skew, drawn by the generator | `receipt-en.txt`, 8 lines |
| `invoice-de-300dpi.jpg` | German invoice, clean 300 dpi scan: positions, amounts, %, dates, IBAN | 10 lines |
| `letter-en-lowcontrast.jpg` | English letter, grey ink on grey paper (contrast about 2.8:1), 150 dpi | 8 lines |
| `smallprint-de.jpg` | German terms in 7.5 pt at 200 dpi (§ signs, umlauts) | 7 lines |
| `statement-mixed.jpg` | Bank statement, German and English, signed amounts in columns, IBAN and BIC | 7 lines |
| `receipt-de-faded.jpg` | Narrow faded receipt (80 mm), light ink, slight blur, umlauts and ß | 8 lines |

The pages after the first two (DK-0661) use Roboto from the Flutter SDK. A
truth line has one space between words, whatever gap the page draws.

## Measured

| Engine | letter-de | receipt-en | invoice-de-300dpi | letter-en-lowcontrast | smallprint-de | statement-mixed | receipt-de-faded | Where |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| PP-OCRv5 (mobile det, Latin rec) | 0.25 % | 0.53 % | 0.00 % | 0.00 % | 0.00 % | 0.00 % | 0.00 % | Development machine, Python onnxruntime 1.20, 2026-10-07 (first two), 2026-10-15 |
| Apple Vision | — | — | — | — | — | — | — | DK-1053 (an iPhone) |

`doc_vision/test/ocr/ocr_engine_test.dart` fails if PP-OCRv5 gets worse than
1 % on any page; the gate runs it, so a worse model or post-processing
can't merge. Per release the rates are copied into this table (the
regression checklist, DK-0670). The one German slip left is "Bite" for "Bitte". (Before
DK-1050 fixed the scan's ß and ü, the German rate was 0.99 %.)

Blur: `sharpness()` (variance of the Laplacian at ≤ 800 px) is 2,731 for
`letter-de.jpg` and 14.8 for the same page with a Gaussian blur of radius 4;
the limit is 60.
