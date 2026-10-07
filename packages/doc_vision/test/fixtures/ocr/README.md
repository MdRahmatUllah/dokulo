# OCR test set (DK-0400)

Scanned pages with their exact text, for the character error rate (CER) of
each OCR engine: edit distance over the reference length, words joined by
spaces. Fictional, like `test/fixtures`. Made by `tools/make_ocr_fixtures.py`:
change the generator, not the files.

| Page | What | Truth |
| --- | --- | --- |
| `letter-de.jpg` | German letter, 110 dpi grey scan, slight skew (page 1 of `scanned-letters-bundle.pdf`) | `letter-de.txt`, 13 lines |
| `receipt-en.jpg` | English receipt, 110 dpi, slight skew, drawn by the generator | `receipt-en.txt`, 8 lines |

## Measured

| Engine | letter-de | receipt-en | Where |
| --- | ---: | ---: | --- |
| PP-OCRv5 (mobile det, Latin rec) | 0.25 % | 0.53 % | Development machine, Python onnxruntime 1.20, 2026-10-07 |
| Apple Vision | — | — | DK-1053 (an iPhone) |

`doc_vision/test/ocr/ocr_engine_test.dart` fails if PP-OCRv5 gets worse than
1 % on either page. The one German slip left is "Bite" for "Bitte". (Before
DK-1050 fixed the scan's ß and ü, the German rate was 0.99 %.)

Blur: `sharpness()` (variance of the Laplacian at ≤ 800 px) is 2,731 for
`letter-de.jpg` and 14.8 for the same page with a Gaussian blur of radius 4;
the limit is 60.
