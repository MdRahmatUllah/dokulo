# Licence register

The one list of everything Dokulo ships, downloads or deliberately keeps out,
with the licence and what it obliges us to do. It replaces the table in the
Technology & Package Plan (→ Licence register); the licence *rules* stay there
(→ Principles → Licence rules). DK-0672.

**The rule:** a new dependency (a Dart package, a native library, a model, a
font) needs a line here **in the same PR** that adds it. `tools/licence_scan.py`
enforces it for every `pubspec.lock` in the repo; native libraries, models and
fonts are checked by the reviewer against the tables below. DK-0673 builds the
in-app licence screen from `pubspec.lock` plus the native, model and font
tables here.

## What the scan does

`python tools/licence_scan.py` (part of the basic check whenever a `pubspec.yaml`
or `pubspec.lock` changes; a step of the local gate `tools/check.py`, DK-0010) reads every
`pubspec.lock` in the repo and, for each package:

1. **Fails** when its name matches a denied engine or SDK (the *Excluded* table).
2. **Fails** when it is a direct dependency with no line in the *Dart packages* table.
3. Reads its `LICENSE` from the pub cache (run `flutter pub get` first) and
   classifies it: MIT, BSD, Apache-2.0, Zlib or ISC pass; AGPL, GPL, LGPL, MPL
   and anything unrecognised **fail**, unless the package has a line in the
   *Dart packages* table that says what it is and why it may ship.

SDK packages (`flutter`, `flutter_test`, …) and our own path packages are skipped.

## Dart packages (direct dependencies)

The scan reads this table: the first column is the package name in backticks.
Versions live in `pubspec.lock`; DK-0002 pins them.

| Package | Licence | Ships | Used for | Obligations |
| --- | --- | --- | --- | --- |
| `pdfrx` | MIT | Yes | Viewer, render, text, page assembly, save (bundles PDFium via `pdfium_flutter`, `pdfrx_engine`) | Notice |
| `pdfium_flutter` | MIT | Yes | PDFium binaries for pdfrx | Notice; PDFium's own notice (native table) |
| `pdfrx_engine` | MIT | Yes | pdfrx's engine layer | Notice |
| `pdfium_dart` | MIT | Yes | PDFium FFI bindings (pdfrx's, and doc_core's raw calls) | Notice |
| `ffi` | BSD-3 | Yes | Native memory for FFI calls | Notice |
| `pdf` | Apache-2.0 | Yes | Create PDFs, overlays, OCR text layer (`pdf_crypto` not used) | Notice |
| `printing` | Apache-2.0 | Yes | HTML → PDF (`Printing.convertHtml`) | Notice |
| `llamadart` | MIT | Yes | Gemma via llama.cpp (GGUF) | Notice; llama.cpp notice (native table) |
| `llamadart_llama_cpp_flutter` | MIT | Yes | llama.cpp for iOS (SwiftPM) | Notice |
| `flutter_onnxruntime` | MIT | Yes | OCR models, embeddings, TTS | Notice; ONNX Runtime notice (native table) |
| `opencv_dart` | Apache-2.0 | Yes | Image filters, perspective, contours | Notice; exclude videoio/highgui/dnn/contrib (DK-0680) |
| `receive_sharing_intent` | Apache-2.0 | Yes | Share sheet / "Open with" input | Notice |
| `flutter_riverpod` | MIT | Yes | State management | Notice |
| `riverpod_annotation` | MIT | Yes | Riverpod codegen annotations | Notice |
| `riverpod_generator` | MIT | Dev | Riverpod codegen | None (not shipped) |
| `build_runner` | BSD-3 | Dev | Code generation | None (not shipped) |
| `go_router` | BSD-3 | Yes | Routing | Notice |
| `drift` | MIT | Yes | File index, recents, folders, OCR text (FTS5) | Notice |
| `drift_dev` | MIT | Dev | drift codegen | None (not shipped) |
| `lints` | BSD-3 | Dev | Lint rules for the Dart packages | None (not shipped) |
| `flutter_lints` | BSD-3 | Dev | Lint rules for `app_pdf` | None (not shipped) |
| `test` | BSD-3 | Dev | Unit tests in the Dart packages | None (not shipped) |
| `crypto` | BSD-3 | Dev | SHA-256 in tests (original files are never modified) | None (not shipped) |
| `sqlite3` | MIT | Yes | SQLite with FTS5 via build hooks (3.x; SQLite itself is public domain). `sqlite3_flutter_libs` and `sqlcipher_flutter_libs` are obsolete with 3.x (their `+eol` releases do nothing): don't add them | Notice |
| `cryptography` | Apache-2.0 | Yes | AES-GCM file encryption | Notice |
| `flutter_secure_storage` | BSD-3 | Yes | Keys in Keychain / Keystore | Notice |
| `local_auth` | BSD-3 | Yes | Biometric unlock | Notice |
| `background_downloader` | BSD-3 | Yes | Model downloads (resumable, hash-checked) | Notice |
| `file_picker` | MIT | Yes | Pick PDFs and images | Notice |
| `share_plus` | BSD-3 | Yes | Share results | Notice |
| `path_provider` | BSD-3 | Yes | Sandbox paths | Notice |
| `photo_manager` | Apache-2.0 | Yes | "Find documents in photos" | Notice |
| `webview_flutter` | BSD-3 | Yes | Web to PDF | Notice |
| `image` | MIT | Yes | EXIF, HEIC fallback, thumbnails | Notice |
| `in_app_purchase` | BSD-3 | Yes | One-time Pro unlock | Notice |
| `flutter_localizations` | BSD-3 (Flutter SDK) | Yes | EN/DE | Notice (from the SDK) |
| `intl` | BSD-3 | Yes | EN/DE formatting, ARB | Notice |
| `material_symbols_icons` | Apache-2.0 | Yes | Material Symbols Rounded (DK-0048) | Notice |
| `phone_numbers_parser` | MIT | Yes | Phone detection in redaction | Notice |
| `diff_match_patch` | Apache-2.0 | Yes, if Compare uses it | Text diff in Compare PDF | Notice |
| `camera` | BSD-3 | Yes | Android scanner frames (CameraX) | Notice |

## Native libraries (bundled by plugins or by our own FFI packages)

| Component | Licence | Ships | Obligations |
| --- | --- | --- | --- |
| PDFium (chromium/7811 via pdfrx) | BSD-3 / Apache-2.0 | Yes | Notices in the licence screen |
| qpdf 12.3.2 (our `qpdf_ffi`, native crypto only: no OpenSSL/GnuTLS) | Apache-2.0 | Yes | Notice + the NOTICE file's contents |
| zlib | Zlib | Yes (via qpdf, OpenCV) | Notice |
| libjpeg-turbo | BSD-3 + IJG | Yes (via qpdf, OpenCV) | Notices; the IJG credit "this software is based in part on the work of the Independent JPEG Group" |
| OpenCV 4.13 (via `opencv_dart` / `dartcv4`): core, imgproc, imgcodecs only | Apache-2.0 | Yes | Notice; every other module excluded, so no FFmpeg ([opencv-modules.md](opencv-modules.md), DK-0680) |
| libpng (via OpenCV) | libpng licence (permissive) | Yes | Notice |
| libwebp (via OpenCV) | BSD-3 | Yes | Notice |
| libtiff (via OpenCV) | libtiff licence (BSD-style) | Yes (Android only) | Notice |
| OpenJPEG (via OpenCV) | BSD-2 | Yes (Android only) | Notice |
| Carotene, KleidiCV (OpenCV's ARM HAL) | BSD-3 / Apache-2.0 | Yes (arm builds) | Notices |
| ONNX Runtime 1.23 (via `flutter_onnxruntime`) | MIT | Yes | Notice |
| llama.cpp / ggml (via `llamadart`) | MIT | Yes | Notice |
| Bergamot translator (FFI, from Sogda) | MPL-2.0 | Yes | Keep the MPL files unmodified or publish our changes to those files; notice (DK-0681) |
| SQLite | Public domain | Yes | None (credit in the licence screen anyway) |
| Apple VisionKit / Vision | Apple platform | OS | None |

## Models (bundled or downloaded)

Every model needs a written licence check before it is added (territory, use
restrictions, attribution): the intake checklist in [ai-models.md](ai-models.md) (DK-0683).

| Model | Licence | Ships | Obligations |
| --- | --- | --- | --- |
| PP-OCRv5 mobile det + Latin rec + angle cls (ONNX) | Apache-2.0 | Bundled | NOTICE file; state that the ONNX files are converted, not modified |
| PP-OCRv5 multilingual rec | Apache-2.0 | Download | As above |
| Gemma 4 E2B, GGUF Q4_K_M | Apache-2.0 (confirmed 2026-10-07, [ai-models.md](ai-models.md); re-confirm at release) | Download | Notice; follow Google's Gemma Prohibited Use Policy, linked from the app terms |
| Bergamot models (DE↔EN, …) | MPL-2.0 ([ai-models.md](ai-models.md), DK-0675) | Download | Notice |
| Hy-MT2 (1.8B, GGUF) | Apache-2.0, from Tencent's own repo only (some repackages carry the community licence) ([ai-models.md](ai-models.md), DK-0676) | Download, if offered | Notice |
| Supertonic 3 (optional, later) | OpenRAIL-M | Download | Pass the use restrictions on in the app terms |

## Colour profiles

| Profile | Licence | Ships | Obligations |
| --- | --- | --- | --- |
| ICC `sRGB2014.icc` (sRGB IEC 61966-2.1, ICC v2), the PDF/A OutputIntent | ICC profile licence: copy, distribute and embed without restriction; altered copies must drop the ICC identification | Yes (`doc_core` assets; embedded in every PDF/A we write) | Never alter it (SHA-256 test); credit in the licence screen ([srgb-icc-profile.md](srgb-icc-profile.md), DK-0678) |

## Fonts

| Font | Licence | Ships | Obligations |
| --- | --- | --- | --- |
| Material Symbols Rounded | Apache-2.0 | Yes | Notice |
| Caveat, Dancing Script, Homemade Apple (signature styles) | SIL OFL 1.1 (re-confirm per family when added) | Yes | OFL text in the licence screen; never sell the fonts on their own |

## Excluded (the scan fails on these names)

| Component | Licence | Why |
| --- | --- | --- |
| MuPDF, PyMuPDF | AGPL-3.0 | Strong copyleft: never in the app |
| Ghostscript | AGPL-3.0 | Strong copyleft |
| BentoPDF | AGPL-3.0 | Strong copyleft |
| Syncfusion PDF / Flutter SDKs | Commercial / community licence | Revenue caps and per-seat terms don't fit a solo app |
| Apryse (PDFTron) | Commercial | As above |
| Nutrient (PSPDFKit) | Commercial | As above |
| Foxit PDF SDK | Commercial | As above |
| Google ML Kit (document scanner, text recognition, any ML Kit API) | Google proprietary terms | Closed source, delivered by Play services, sends usage metrics to Google ([decision](ml-kit-scanner.md), DK-0677) |
| HY-MT1.5 / Hunyuan-MT 1.x | Tencent HY Community Licence | Territory excludes the EU, UK and South Korea (DK-0676; Hy-MT2 is Apache-2.0 and allowed, see Models) |
| veraPDF | GPL / MPL dual | Local test tool only, as a PDF/A validator; never shipped |

The scan's deny patterns (`tools/licence_scan.py`, `DENIED`): `mupdf`,
`ghostscript`, `bentopdf`, `syncfusion`, `apryse`, `pdftron`, `pspdfkit`,
`nutrient`, `foxit`, `google_mlkit`, `verapdf`. Models are not pub packages; the reviewer checks them against the Models table and [ai-models.md](ai-models.md).
