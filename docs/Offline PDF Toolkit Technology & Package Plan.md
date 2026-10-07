# 04 — Offline PDF Toolkit: Technology & Package Plan

Oct 6, 2026 · @Rahmat Ullah

## Principles

Every feature runs on the phone using permissively licensed code or models we only download and run; where no such option exists, we build the library ourselves. We never train an LLM.

**Licence rules**

| Licence class | Examples | Rule |
| --- | --- | --- |
| Permissive | MIT, BSD-2/3, Apache-2.0, Zlib, ISC | Use freely; keep notices in the in-app licence screen |
| Weak copyleft (file-level) | MPL-2.0 (Bergamot), LGPL | Allowed only as unmodified, dynamically linked or separate files; publish any changes to those files. LGPL avoided on iOS (static linking problem) |
| Strong copyleft | GPL, AGPL (MuPDF, PyMuPDF, Ghostscript, BentoPDF, veraPDF parts) | Never in the app. Build our own instead |
| Commercial / community licence | Syncfusion, Apryse, Nutrient (PSPDFKit), Foxit | Not used; revenue caps and per-seat terms don't fit a solo app |
| Model licences | Gemma terms, Tencent Hy-MT licence, OpenRAIL-M | Allowed after a written check per model (territory, use restrictions, attribution) |

**Engineering rules**

1. **Reuse Sogda's AI platform as a shared package:** `ModelManager` (background\_downloader), `LlmRuntimeArbiter` (one llama.cpp model in memory), model catalogue JSON, device-capability checks.
2. **No training, only inference.** Allowed: prompting, retrieval (RAG), rule-based post-processing, and using ready-made embedding/OCR/layout models. Not allowed: fine-tuning or training LLMs. Small classic models (e.g. a document/not-document classifier) are only used if a ready permissive model exists.
3. **Native first for heavy work.** PDF parsing, image processing and OCR run in C/C++ or platform APIs via FFI or platform channels, always off the UI isolate.
4. **Pin versions.** Exact versions in `pubspec.lock`; native libs pinned by tag and SHA-256; review upgrades once a month.
5. **Everything optional is a download.** The base app stays small; AI, translation and extra OCR models are fetched on demand with hash checks.

## Stack at a glance

Five layers, top to bottom; everything below the UI lives in shared packages so the letter assistant (doc 03) and Sogda can reuse them.

| Layer | Our package | Contents | Built on |
| --- | --- | --- | --- |
| 1. App | `app_pdf` | Screens, tool grid, viewer, file manager, paywall, Riverpod providers | Flutter 3.47+, Dart 3.13+ |
| 2. Tool jobs | `doc_tools` | One `ToolJob` per feature (merge, compress, redact…), progress stream, cancel, undo snapshot, workflow runner | Pure Dart, runs in worker isolates |
| 3. Document core | `doc_core` | Open/save/render PDFs, page ops, text extraction, structure ops, image pipeline, OCR text layer writer | pdfrx / PDFium, qpdf (our FFI), Dart `pdf`, opencv\_dart |
| 4. Vision & OCR | `doc_vision` | Scanner flows, edge detection, dewarp-light, OCR engines, layout, document-in-photo detection | VisionKit / Vision (iOS), own CameraX + OpenCV scanner (Android), PP-OCRv5 on ONNX Runtime |
| 5. On-device AI | `ai_core` (from Sogda) | Model manager, LLM arbiter, translation engines, embeddings, retrieval | llamadart (llama.cpp), Bergamot (FFI), ONNX Runtime |

**Threading model:** PDFium is single-threaded, so pdfrx serialises all PDFium calls on one worker isolate. qpdf, OpenCV and ONNX jobs run on their own isolates. The UI isolate never touches native code directly.

**Data flow for a typical tool:** file in (share sheet / picker) → copy into app sandbox → `ToolJob` reads via `doc_core` → writes a new file (never in place) → user previews → save / share → temp files deleted.

## Core packages and versions

Versions marked ✓ were checked on pub.dev or the project page on 6 Oct 2026; the rest are well-established packages to pin at the latest stable when the repo is created.

| Package | Version | Licence | Used for | Notes |
| --- | --- | --- | --- | --- |
| Flutter / Dart | 3.47+ / 3.13+ | BSD-3 | Toolchain | Minimum set by pdfrx 2.6 ✓ |
| [pdfrx](https://pub.dev/packages/pdfrx/changelog) | 2.6.5 ✓ (18 Sep 2026) | MIT | Viewer, render, text, page assembly, save | Bundles PDFium via `pdfium_flutter` 0.3.1 and `pdfrx_engine` 0.6.1 |
| [pdf](https://pub.dev/packages/pdf/versions) | 3.13.1 ✓ (19 Sep 2026) | Apache-2.0 | Create PDFs, overlays, OCR text layer | Its encryption/signature add-on (pdf\_crypto) is separate and not used |
| [llamadart](https://pub.dev/packages/llamadart/versions/0.8.12) | 0.8.12+ ✓ | MIT | Gemma via llama.cpp (GGUF) | Same runtime as Sogda; add `llamadart_llama_cpp_flutter` ^0.0.8 for iOS SwiftPM |
| [flutter\_onnxruntime](https://pub.dev/documentation/flutter_onnxruntime/latest/) | 1.8.4 ✓ (Sep 2026) | MIT | OCR models, embeddings, Supertonic TTS | ONNX Runtime 1.23; iOS min 16, Android 16 KB pages OK |
| [opencv\_dart](https://pub.dev/documentation/opencv_dart/latest/) | 2.2.x ✓ | Apache-2.0 | Image filters, perspective, book split, contours | Uses Native Assets hooks; exclude unused modules (videoio, highgui, dnn, contrib) |
| [google\_mlkit\_document\_scanner](https://pub.dev/documentation/google_mlkit_document_scanner/latest/) | 0.6.0 ✓ (Aug 2026) | MIT (plugin) | **Not used** | Closed-source ML Kit with usage metrics; see [docs/compliance/ml-kit-scanner.md](compliance/ml-kit-scanner.md) |
| [receive\_sharing\_intent](https://pub.dev/documentation/receive_sharing_intent/1.9.0/) | 1.9.0 ✓ | Apache-2.0 | Share sheet / "Open with" input | Includes iOS Share Extension support via SwiftPM |
| flutter\_riverpod + riverpod\_generator | latest 3.x | MIT | State management | Same as Sogda |
| drift + sqlite3\_flutter\_libs | latest 2.x | MIT | File index, recents, folders, OCR text index (FTS5) |  |
| sqlcipher\_flutter\_libs | latest | BSD-style | Encrypted DB for locked folders | Alternative: encrypt files with `cryptography` and keep DB plain |
| cryptography | latest 2.x | Apache-2.0 | AES-GCM file encryption for locked folders | Uses platform crypto where available |
| flutter\_secure\_storage | latest 9.x | BSD-3 | Store encryption keys in Keychain / Keystore |  |
| local\_auth | latest 2.x | BSD-3 | Biometric unlock | Flutter team package |
| background\_downloader | latest | BSD-3 | Model downloads (resumable, hash-checked) | Same as Sogda's ModelManager |
| file\_picker | latest | MIT | Pick PDFs and images |  |
| share\_plus | latest | BSD-3 | Share results |  |
| path\_provider | latest | BSD-3 | Sandbox paths |  |
| photo\_manager | latest 3.x | Apache-2.0 | Read photo library for "find documents in photos" | Needs photo permission; on-device only |
| webview\_flutter | latest | BSD-3 | Load web pages for Web to PDF | Printing via platform channel (see feature table) |
| image | latest 4.x | MIT | Light image work in pure Dart (EXIF, HEIC fallback, thumbnails) | Heavy work goes to OpenCV |
| in\_app\_purchase | latest 3.x | BSD-3 | One-time Pro unlock (StoreKit 2 / Play Billing) | No server needed for a non-consumable |
| flutter\_localizations + intl | SDK / latest | BSD-3 | English and German |  |

## PDF engine layer

Three engines cover every PDF feature: PDFium for reading, rendering and page/annotation edits; qpdf for structure, encryption and repair; Dart `pdf` for writing new content. Only qpdf needs a binding we build ourselves.

| Engine | Version | Licence | Strengths | Gaps we cover elsewhere |
| --- | --- | --- | --- | --- |
| PDFium (via pdfrx) | chromium/7811 binaries (pdfrx 2.3+) | BSD-3 / Apache-2.0 | Fast render, text + character boxes, forms (fill, flatten), annotations, page import/reorder/rotate, save | Cannot encrypt on save; no object-stream optimisation; no linearisation |
| [qpdf](https://pkgs.alpinelinux.org/package/edge/community/x86_64/qpdf) | 12.3.2 (Jan 2026) | Apache-2.0 | Encrypt/decrypt (AES-256), repair by rewrite, object streams, linearise, page selection, structural checks | No rendering, no text extraction; no Dart binding exists |
| Dart `pdf` | 3.13.1 | Apache-2.0 | New pages from images, text, vector, fonts; invisible OCR text; stamps | Cannot edit existing PDFs (we stamp via PDFium overlay or qpdf overlay) |

### PDFium: what we call directly

pdfrx exposes the low-level PDFium bindings, so we call the C API for things its widget layer doesn't wrap:

| Need | PDFium API |
| --- | --- |
| Merge, extract, reorder, insert blank | `FPDF_ImportPagesByIndex`, `FPDFPage_New`, `FPDFPage_Delete`, `FPDF_MovePages` |
| Rotate | `FPDFPage_SetRotation` |
| Text + positions (search, redaction, compare, OCR check) | `FPDFText_LoadPage`, `FPDFText_GetCharBox`, `FPDFText_GetBoundedText` |
| Forms | `FPDFDOC_InitFormFillEnvironment`, `FPDFAnnot_SetStringValue`, `FPDFPage_Flatten` |
| Annotations (highlight, note, ink, shapes, signature image) | `FPDFPage_CreateAnnot`, `FPDFAnnot_SetAttachmentPoints`, `FPDFAnnot_AppendObject` |
| Watermark, page numbers, crop | `FPDFPageObj_CreateTextObj`, `FPDFPageObj_NewImageObj`, `FPDFPage_SetCropBox` |
| Embedded images (extract) | `FPDFImageObj_GetBitmap`, `FPDFImageObj_GetImageDataRaw` |
| Save | `FPDF_SaveAsCopy` (full rewrite; never incremental for redacted files) |

### qpdf: our own binding (`qpdf_ffi`)

- **Build:** CMake cross-compile for Android NDK (arm64-v8a, armeabi-v7a, x86\_64; 16 KB page alignment) and an iOS XCFramework (device + simulator). Ship through a Flutter FFI plugin using Native Assets hooks, the same way pdfrx and opencv\_dart do.
- **Crypto:** build with qpdf's built-in "native" crypto provider only, so no OpenSSL or GnuTLS is linked. Dependencies: zlib (zlib licence) and libjpeg-turbo (BSD-style / IJG).
- **API surface:** wrap the `qpdfjob` JSON interface (`qpdfjob_run_from_json`) plus a few C-API calls for checks. One JSON job per operation keeps the binding to about 10 functions.
- **Jobs we use:** encrypt (AES-256, R6), decrypt with password, repair (`--qdf` rewrite), compress structure (`--object-streams=generate`, `--compress-streams=y`, `--recompress-flate`), linearise, overlay/underlay pages (watermark from a generated PDF), split by ranges, `--check` for validation.
- **Effort:** about 1 week including CI builds.

## Feature mapping: PDF tools

All 26 non-AI PDF tools sit on permissive engines; the real custom work is in compression, redaction, PDF/A, OCR text layers, structure extraction and the annotation editor.

### Organize

| Feature | How it works | Engines / packages | Custom work |
| --- | --- | --- | --- |
| Merge PDF | Open each file, import pages into a new document in the chosen order, save | pdfrx page assembly (`PdfDocument` accepts pages from other documents) or `FPDF_ImportPagesByIndex` | Outline (bookmarks) merge: read with pdfrx `loadOutline`, rebuild with qpdf JSON. Small |
| Split PDF | By ranges, every N pages, or single pages | qpdf `--split-pages=N`, `--pages file 1-3,7 --` | Range parser + UI only |
| Extract pages | Selected pages → new PDF | qpdf `--pages` | None |
| Organize pages | Thumbnail grid: reorder, delete, duplicate, insert blank | pdfrx thumbnails; PDFium `FPDF_MovePages`, `FPDFPage_Delete`, `FPDFPage_New` | Drag-and-drop grid widget with undo (Flutter `ReorderableGridView` pattern, own code) |
| Rotate PDF | Per page or all | `FPDFPage_SetRotation` | None |

### Convert

| Feature | How it works | Engines / packages | Custom work |
| --- | --- | --- | --- |
| Image to PDF | Decode, auto-orient by EXIF, fit to A4/Letter/original, embed as JPEG (no re-encode when already JPEG) | Dart `pdf`; platform image decoders (HEIC native on iOS, Android 9+); `image` for EXIF | Page-size and margin logic |
| PDF to images | Render each page at 150/300 dpi, encode JPG/PNG | pdfrx `PdfPage.render`; `image` or `dart:ui` encoders | None |
| Web/HTML to PDF | HTML file → PDF; URL → load in WebView → print to PDF | `printing` (Apache-2.0) `Printing.convertHtml` for HTML strings; WebView + platform print for URLs | Small `web_to_pdf` plugin: iOS `WKWebView.createPDF`, Android `PrintDocumentAdapter` to file (about 3 days) |
| PDF to PDF/A | Convert to PDF/A-2b for archiving and authorities | qpdf + PDFium + Dart `pdf` | **Custom `pdfa_writer`** (see Custom libraries). veraPDF used only in CI for validation, never shipped |
| PDF to Markdown / text | Extract text in reading order with headings, lists and simple tables | PDFium text + font sizes; OCR for scanned pages | **Custom `pdf_structure`**: reading order, heading detection by font size/weight, list and table heuristics |

### Optimize

| Feature | How it works | Engines / packages | Custom work |
| --- | --- | --- | --- |
| Compress PDF | Downsample and re-encode images, then compress structure; "under X MB" uses a search over quality and DPI | PDFium image objects (`FPDFImageObj_GetBitmap`, `FPDFImageObj_LoadJpegFileInline`); OpenCV resize; libjpeg-turbo via OpenCV; qpdf object streams + flate recompress | **Custom `pdf_compress`** pipeline and size-target loop |
| Repair PDF | Rewrite through qpdf; if that fails, open in PDFium and save a clean copy | qpdf, PDFium | Fallback chain + user message |
| OCR PDF | Render page → OCR → write invisible text layer aligned to word boxes → overlay on original page | pdfrx render; OCR engine (Vision section); Dart `pdf` text render mode 3; qpdf `--overlay` | **Custom `ocr_text_layer`**: box-to-PDF coordinate mapping, font metrics fitting |

### Edit

| Feature | How it works | Engines / packages | Custom work |
| --- | --- | --- | --- |
| Add page numbers | Generate a transparent overlay PDF with numbers, overlay onto each page | Dart `pdf` + qpdf `--overlay` | Position/format options |
| Add watermark | Text or image overlay (or underlay), opacity and rotation | Dart `pdf` + qpdf `--overlay`/`--underlay` | None |
| Crop PDF | Set CropBox per page or all; optional auto-crop by content bounds | `FPDFPage_SetCropBox`; OpenCV for auto bounds | Crop handles UI |
| Annotate & add text | Highlight/underline from text selection, sticky notes, text boxes, shapes, freehand ink | pdfrx viewer overlays; PDFium annotation API | **Custom annotation editor** (largest UI component): tools palette, hit testing, undo, save as real PDF annotations |
| Fill forms | List and fill AcroForm fields, checkboxes, choices; optional flatten | PDFium form fill environment, `FPDFAnnot_SetStringValue`, `FPDFPage_Flatten` | Field list UI; XFA forms not supported (show message) |

### Security

| Feature | How it works | Engines / packages | Custom work |
| --- | --- | --- | --- |
| Sign PDF | Draw or reuse saved signature (PNG with alpha), place, resize, stamp; date and initials | Flutter `CustomPainter` pad (no dependency); PDFium image object or stamp annotation | Signature store (encrypted), placement UI |
| Protect PDF | AES-256 (R6) user password, optional permissions | qpdf `--encrypt` | None |
| Unlock PDF | Remove encryption when the user knows the password | qpdf `--password=… --decrypt` | None (we never crack passwords) |
| Redact PDF | Auto-detect sensitive data, user reviews boxes, true removal | PDFium char boxes or OCR boxes; regex + checksums; pdfrx render; OpenCV fill; qpdf cleanup | **Custom `pdf_redact`** (see Custom libraries) |
| Compare PDF | Text diff per page with highlights; optional visual overlay diff | PDFium text; `diff_match_patch` (Apache-2.0) or own Myers diff; OpenCV `absdiff` for visual mode | Side-by-side viewer with synced scrolling |

### Extract and automation

| Feature | How it works | Engines / packages | Custom work |
| --- | --- | --- | --- |
| PDF extract | Export embedded images (original encoding when possible) and plain text | PDFium `FPDFImageObj_GetImageDataRaw`, text API | None |
| Batch processing | Queue of `ToolJob`s across files with progress and cancel | Dart isolates | Job queue + notifications |
| Workflows | Saved chains (e.g. scan → OCR → compress → protect), stored as JSON | Our `ToolJob` interface | **Custom workflow runner** (small): typed inputs/outputs per job |

## Feature mapping: scanner and app features

On iOS the scanner uses Apple's built-in VisionKit and Vision (part of the OS, free, on-device). On Android we build our own scanner on CameraX + OpenCV, because Google's ML Kit scanner is closed-source, depends on Google Play services and sends usage metrics to Google; it is not used at all ([docs/compliance/ml-kit-scanner.md](compliance/ml-kit-scanner.md)).

### Scanner

| Feature | iOS | Android | Shared custom work |
| --- | --- | --- | --- |
| Document scan (edge detection, auto-capture, perspective fix) | VisionKit `VNDocumentCameraViewController` via a small platform channel (or `VNDetectDocumentSegmentationRequest` on our own camera view for full UI control) | Own `doc_scanner`: `camera` package (CameraX) frames → OpenCV pipeline: downscale, Canny + morphology, `findContours`, `approxPolyDP` quad, scoring | Quad tracker with stability check (auto-capture when quad is steady for \~0.5 s), manual corner editing, `warpPerspective` |
| Multi-page batch scan | VisionKit multi-page session | Continuous capture mode in `doc_scanner` | Page tray UI, reorder/retake |
| Filters & adjust | Core Image or OpenCV (same code on both) | OpenCV | B/W via adaptive threshold, greyscale, colour boost (CLAHE), **shadow removal** (background estimate by dilate + median blur, then divide), brightness/contrast |
| ID card mode | Same capture flow | Same capture flow | Crop to ID-1 ratio (85.6 × 54 mm), place front and back at true size on one A4 page |
| Book mode | Same capture flow | Same capture flow | Spine detection with vertical projection profile + Hough lines, split into two pages; deskew each. Full curve dewarping is a later feature |
| Find documents in photos | `photo_manager` + Vision rectangle/text detection | `photo_manager` + PP-OCRv5 detection model | **No training:** score each photo by text-area ratio (OCR detector) + document quad found + aspect ratio; runs in the background on thumbnails, results cached in drift |
| Import from gallery/files | `file_picker` / photo picker | same | Same pipeline as live scan on stills |
| Scan to PDF/JPG | Dart `pdf` | Dart `pdf` | Page size presets (A4, Letter, auto), JPEG quality 80–85 by default |

### App features

| Feature | How it works | Packages | Custom work |
| --- | --- | --- | --- |
| PDF viewer | Continuous scroll, zoom, search, thumbnails, outline, night mode (colour-inverting filter) | pdfrx `PdfViewer`, `PdfTextSearcher` | Toolbar, page jump, night mode |
| File manager | Index of all files with recents, folders, favourites, full-text search over names and OCR text | drift + sqlite FTS5 | Index updater after every tool job |
| Locked folders / app lock | Files encrypted at rest with AES-256-GCM; key in Keychain/Keystore, released after biometric or PIN | `cryptography`, `flutter_secure_storage`, `local_auth` | Key management, lock timeout, encrypted thumbnails |
| Share-sheet integration | Android: intent filters for `application/pdf` and `image/*` (VIEW + SEND + SEND\_MULTIPLE). iOS: Share Extension + document types (`CFBundleDocumentTypes`, open in place) | `receive_sharing_intent` 1.9.0 | iOS Action Extension for the Files app (native Swift target that hands the file to the app via an App Group) |
| Tool grid home | Grid of all tools, search, recently used | Flutter | None |
| Languages | English and German at launch | `flutter_localizations`, `intl`, ARB files | None |
| Pro unlock | Non-consumable purchase, restore, Family Sharing on iOS | `in_app_purchase` | Entitlement cache; no server |

## On-device AI models

Gemma 4 E2B and Bergamot cover all AI and translation features; PP-OCRv5 covers OCR on both platforms. **Hy-MT cannot be used in this app**: Tencent's licence excludes the EU, UK and South Korea, which are core markets (and the developer is in Germany).

| Model | Role in this app | Runtime | Size (approx.) | Licence | Decision |
| --- | --- | --- | --- | --- | --- |
| Gemma 4 E2B, GGUF Q4\_K\_M | Summarize, Ask your PDF, Smart Split decisions, high-quality translation | llamadart (llama.cpp) via Sogda's `LlmRuntimeArbiter` | \~1.3 GB disk, 2–3 GB RAM | Apache-2.0 (per Sogda model catalogue) | **Use**, optional download |
| Bergamot (Firefox Translations) | Fast standard translation | Bergamot via FFI (as in Sogda) | \~17–35 MB per language direction | MPL-2.0 (engine and models per Sogda catalogue) | **Use**, default translation engine |
| HY-MT1.5 / Hy-MT2 (Tencent) | Translation | llama.cpp | \~440 MB | [Tencent HY Community Licence](https://ollama.com/huihui_ai/hy-mt1.5-abliterated:7b/blobs/ebbd49dd8772): territory excludes EU, UK, South Korea | **Do not use.** Also re-check this for Sogda |
| PP-OCRv5 mobile det + Latin rec + angle cls (ONNX) | OCR for scans, redaction on scans, photo detection | flutter\_onnxruntime | det \~4.8 MB, Latin rec \~8 MB, cls \~0.6 MB | Apache-2.0 ([ONNX export example](https://github.com/gitakoos/ocr-models)) | **Use** on Android and as the uniform engine; bundle det + Latin rec in the app |
| PP-OCRv5 multilingual rec | Non-Latin scripts | flutter\_onnxruntime | \~16.5 MB | Apache-2.0 | Optional download |
| Apple Vision text recognition | OCR on iOS (fast, accurate, handwriting) | OS API via platform channel | 0 (built in) | Apple platform | **Use** on iOS as default, PP-OCRv5 as fallback |
| PP-DocLayout (small) | Layout regions for PDF → Markdown and Smart Split | flutter\_onnxruntime | a few MB | Apache-2.0 | Evaluate in phase 5; heuristics first |
| Embedding model | Semantic retrieval for Ask your PDF | ONNX | \~120 MB (e.g. multilingual-e5-small, MIT) | Check per model | **Not in v1**: BM25 keyword retrieval is enough for single documents |
| Supertonic 3 (TTS) | Optional "Read aloud" | ONNX Runtime (as in Sogda) | per Sogda spec | OpenRAIL-M (use restrictions apply) | Optional later; stack already exists |
| sherpa-onnx + Whisper/Parakeet (STT) | Optional voice notes on annotations | sherpa-onnx | 40–500 MB | Apache-2.0 (sherpa-onnx); per model | Later; shared with doc 06 dictation |

**Rules carried over from Sogda:** one llama.cpp model in memory at a time; RAM check before load (available RAM ≥ working set + 300 MB); Gemma eligibility per Sogda's device-capability rules (arm64, RAM threshold); all downloads resumable, Wi-Fi-only by default, SHA-256 verified.

## Feature mapping: intelligence features

All AI features are prompting, retrieval and rules on top of ready models; nothing is trained. Each one works on the extracted text first, so quality depends on good text extraction and OCR.

| Feature | Pipeline | Engines | Custom work |
| --- | --- | --- | --- |
| AI Summarizer | Extract text per page (PDFium, OCR for scans) → split into chunks of about 1,500 tokens with page numbers → summarise each chunk → combine into a final summary with page references → stream to the UI | Gemma 4 E2B via llamadart; token counting with llamadart `tokenize` | **`doc_summarizer`**: map-reduce, token budgeting, prompts in EN/DE, cancel/resume, KV-state reuse between follow-ups |
| Ask your PDF | Chunk text with page anchors → BM25 index in memory → top chunks within \~2,000 tokens → Gemma answers only from those chunks and cites pages → "not found in this document" when retrieval scores are low | Gemma 4 E2B; own BM25 (pure Dart) | **`doc_rag`**: tokeniser with German compound splitting, BM25 scoring, citation linking back to the viewer |
| Translate PDF | Extract blocks in reading order (`pdf_structure`) → sentence split → translate → show side by side; export as a new reflowed PDF (Dart `pdf`) or Markdown | Bergamot (default, fast); Gemma 4 E2B (optional, higher quality) | **`doc_translate`**: block mapping, glossary of untranslatable items (IBAN, names, numbers), progress per page. Layout-preserving overlay is a later feature |
| Smart Split | Score each page boundary using signals: blank separator pages, page-number resets ("Seite 1 von"), letterhead change (perceptual hash), date/sender change, layout change → ambiguous boundaries get a short Gemma check on two page summaries → user confirms before splitting | OpenCV pHash; PDFium/OCR text; Gemma 4 E2B | **`smart_split`** rules engine; works without Gemma (rules only) when the model isn't installed |
| Find documents in photos | See Scanner section | PP-OCRv5 detector / Vision | Scoring heuristics |
| Redaction auto-detect | Regex + checksum validation over extracted or OCR text; optional Gemma pass to suggest personal names and addresses, always shown for user review | Own detectors; `phone_numbers_parser` (MIT) for phone numbers; Gemma optional | Part of **`pdf_redact`**: IBAN (mod-97), German Steuer-ID (11 digits with check digit), email, phone, US SSN, UK NI number, dates of birth |

**Quality guardrails:** every AI output shows its page references; the summarizer and Q&A carry a one-line "AI can make mistakes" notice (same pattern as Sogda); prompts tell the model to answer only from the provided text.

## Custom libraries we build

Fourteen components have no permissive, complete option, so we build them. Together they add up to about 20 weeks, which is more than the 19-week plan in the project doc assumed once UI and integration are added; expect about 24–26 weeks, or move PDF/A, Smart Split, Web to PDF and the iOS Files extension (about 4.5 weeks) to a post-launch update.

| Library | Why we build it | Scope | Depends on | Effort |
| --- | --- | --- | --- | --- |
| `qpdf_ffi` | No Dart binding for qpdf exists | Native builds (Android ABIs, iOS XCFramework), JSON job API wrapper, error mapping | qpdf 12.3.2, zlib, libjpeg-turbo | 1 wk |
| `pdf_compress` | No permissive mobile compressor with size targets | Image inventory per page, downsample to 72/150/200 dpi, JPEG re-encode, replace image objects, qpdf structure pass, "under X MB" search (binary search over quality 40–85 and DPI), raster fallback for scans | PDFium, OpenCV, qpdf\_ffi | 1.5 wk |
| `pdf_redact` | Commercial SDKs only; must be verifiably true redaction | Detectors (regex + checksums + optional Gemma), review UI with editable boxes, apply: rasterise affected pages at 200–300 dpi, burn boxes, rebuild page as image + invisible OCR text minus redacted words, strip metadata/XMP/annotations/attachments/JavaScript, full rewrite; automated check that no redacted string can be extracted | PDFium, OCR, OpenCV, Dart `pdf`, qpdf\_ffi | 2 wk |
| `ocr_text_layer` | Needed by OCR PDF, redaction and PDF/A | Word boxes → PDF coordinates (rotation, CropBox), invisible text (render mode 3) with horizontal scaling to fit each word, overlay onto original | Dart `pdf`, qpdf\_ffi | 1 wk |
| `pdfa_writer` | Ghostscript/veraPDF are AGPL/GPL | PDF/A-2b: remove encryption, JavaScript and embedded files; check every font is embedded (PDFium `FPDFFont_GetIsEmbedded`) and rasterise pages with non-embedded fonts; add sRGB OutputIntent (ICC profile with redistribution rights); write XMP (`pdfaid:part=2`, `conformance=B`) and document ID; validate with veraPDF in CI only | qpdf\_ffi, PDFium, Dart `pdf` | 2 wk |
| `pdf_structure` | No permissive mobile layout extractor | Reading order (column detection by x-clustering), headings by font size/weight, lists, simple tables (aligned columns), header/footer removal; optional PP-DocLayout regions | PDFium text + font info, OCR | 1.5 wk |
| `doc_scanner` (Android) | ML Kit scanner is closed-source and needs Play services | Camera stream, quad detection, stability-based auto-capture, corner editor, perspective warp, filters incl. shadow removal, ID and book modes | `camera`, opencv\_dart | 2 wk |
| `vision_ocr` (iOS channel) | Thin bridge to Apple Vision | Text recognition with word boxes, language hints (de, en), confidence | Apple Vision | 2 days |
| `pp_ocr` (Dart) | Pre/post-processing for PP-OCRv5 | DB post-process (box extraction), crop/rotate lines, CTC decode with dictionary, batching | flutter\_onnxruntime, OpenCV | 1 wk |
| Annotation editor | Viewer packages don't include a full editor | Tools palette, highlight from selection, ink, shapes, text boxes, notes, selection/move/delete, undo, saving as standard PDF annotations | pdfrx, PDFium annot API | 2 wk |
| `web_to_pdf` plugin | No maintained plugin for URL → PDF on both platforms | iOS `WKWebView.createPDF`, Android `PrintDocumentAdapter` to file, page size options | WebView | 3 days |
| iOS Files Action Extension | Native target required | Accept PDFs/images from Files, hand off via App Group + URL scheme | Swift | 3 days |
| AI pipelines (`doc_summarizer`, `doc_rag`, `doc_translate`, `smart_split`) | App-specific logic | As described in the intelligence section | ai\_core, pdf\_structure | 3 wk |
| Job queue + workflow runner | App-specific | Isolate pool, progress/cancel, typed job chaining, JSON workflows | Dart | 1 wk |

**Open-source option:** `qpdf_ffi` and `pp_ocr` are generic and could be published under MIT later; this costs little and brings developer visibility, but it's optional.

## Licence register

Every shipped component is permissive or file-level copyleft used unmodified; the one blocked model (Hy-MT) and all AGPL engines stay out.

| Component | Licence | Ships in app | Obligations |
| --- | --- | --- | --- |
| PDFium | BSD-3 / Apache-2.0 | Yes | Notices in licence screen |
| pdfrx, pdfium\_flutter, pdfrx\_engine | MIT | Yes | Notice |
| qpdf 12.3.2 | Apache-2.0 | Yes | Notice + NOTICE file contents |
| zlib, libjpeg-turbo | zlib / BSD-style + IJG | Yes (via qpdf, OpenCV) | Notices; IJG requires the "based on the work of the Independent JPEG Group" credit |
| Dart `pdf` 3.13.1 | Apache-2.0 | Yes | Notice |
| OpenCV (via opencv\_dart) | Apache-2.0 | Yes | Notice; exclude videoio/highgui so no FFmpeg is linked |
| ONNX Runtime (via flutter\_onnxruntime) | MIT | Yes | Notice |
| llama.cpp (via llamadart) | MIT | Yes | Notice |
| Bergamot translator + models | MPL-2.0 | Yes (engine) / download (models) | Keep MPL files unmodified or publish changes to those files; notice |
| PP-OCRv5 models | Apache-2.0 | Bundled / download | NOTICE file; state that ONNX files are converted, not modified |
| Gemma 4 E2B | Apache-2.0 (per Sogda catalogue; re-confirm on the model card at release) | Download | Notice; follow any use policy on the model card |
| Supertonic 3 (optional, later) | OpenRAIL-M | Download | Pass use restrictions on in the app terms |
| Apple VisionKit / Vision | Apple platform | OS | None |
| Google ML Kit document scanner | Google proprietary terms, free | **No** | Excluded: closed source, usage metrics to Google ([decision](compliance/ml-kit-scanner.md)) |
| Hy-MT / HY-MT1.5 | Tencent HY Community Licence | **No** | Excluded: territory excludes EU, UK, South Korea |
| MuPDF, PyMuPDF, Ghostscript, BentoPDF | AGPL | **No** | Excluded |
| veraPDF | GPL / MPL dual | **No** (CI only) | Used only as a test tool |
| Syncfusion, Apryse, Nutrient, Foxit SDKs | Commercial | **No** | Excluded |

**Process:** run a licence scan in CI on every release (generate the in-app licence screen from `pubspec.lock` plus a hand-maintained list for native libs and models); any new dependency needs a licence line in this table before it's merged.

## Testing and device targets

Correctness of output files matters more than UI tests here: every tool gets a golden-file test suite, and redaction gets a security test that must pass on every build.

**Device targets**

| Platform | Minimum | Reason |
| --- | --- | --- |
| iOS | 16.0 | ONNX Runtime plugin minimum |
| Android | API 26 (Android 8.0), arm64-v8a primary | Camera/HEIC support and model performance; armeabi-v7a gets tools but no AI |
| AI features | Per Sogda device rules (arm64, RAM threshold) | Gemma 4 E2B needs 2–3 GB working RAM |
| Test devices | One low-end Android (3 GB), one mid Android (6–8 GB), one older iPhone (e.g. iPhone 11), one recent iPhone | Covers memory and speed extremes |

**Test suites**

| Suite | What it checks | Tooling |
| --- | --- | --- |
| Golden PDFs | A corpus of \~100 real-world PDFs (scans, forms, encrypted, broken, huge, PDF/A, non-Latin) run through every tool; output opens in PDFium and passes `qpdf --check` | Dart test + CI |
| Redaction security | After redaction, extracting text with PDFium and qpdf finds none of the redacted strings; metadata and annotations are empty; images contain black boxes at the right places | Automated, blocks release |
| PDF/A | Output validates as PDF/A-2b | veraPDF in CI (not shipped) |
| Compression | Size reduction and visual similarity (SSIM ≥ 0.9 on rendered pages at the "recommended" level) | OpenCV in tests |
| OCR accuracy | Character error rate on a German/English scan set, Vision vs PP-OCRv5 | Small labelled set we create by hand |
| Scanner | Quad detection success on a photo set (backgrounds, lighting, angles) | Photo corpus |
| AI | Summary and Q&A answers cite the right pages on a fixed question set; "not found" behaves correctly | Manual review checklist per release |
| Performance | Merge 200 pages < 3 s, compress 50-page scan < 20 s, OCR page < 1.5 s on mid Android | Benchmarks on test devices |
| Privacy | No network traffic during any tool run (except model downloads) | Proxy check in CI + airplane-mode manual test |

## Open questions

- [ ] Re-confirm the Gemma 4 E2B licence on the current model card before release
- [ ] Confirm the licence of the Bergamot/Firefox translation models and available language pairs (DE↔EN, others)
- [x] Decide whether the ML Kit scanner fast path is enabled at all on Android, after reading ML Kit's terms on data collection: not enabled ([docs/compliance/ml-kit-scanner.md](compliance/ml-kit-scanner.md))
- [ ] Pick a redistributable sRGB ICC profile for PDF/A output
- [ ] Decide: extend the plan to \~24–26 weeks, or move PDF/A, Smart Split, Web to PDF and the Files extension post-launch
- [ ] Check whether Sogda can keep Hy-MT given the EU/UK territory exclusion
- [ ] Pin exact versions for the packages listed as "latest" when the repo is created

## Sources

- [pdfrx changelog (2.6.5)](https://pub.dev/packages/pdfrx/changelog)
- [pdf package versions (3.13.1)](https://pub.dev/packages/pdf/versions)
- [llamadart 0.8.12](https://pub.dev/packages/llamadart/versions/0.8.12)
- [flutter\_onnxruntime docs](https://pub.dev/documentation/flutter_onnxruntime/latest/)
- [opencv\_dart docs](https://pub.dev/documentation/opencv_dart/latest/)
- [google\_mlkit\_document\_scanner docs](https://pub.dev/documentation/google_mlkit_document_scanner/latest/)
- [receive\_sharing\_intent 1.9.0](https://pub.dev/documentation/receive_sharing_intent/1.9.0/)
- [qpdf 12.3.2 package details](https://pkgs.alpinelinux.org/package/edge/community/x86_64/qpdf)
- [PP-OCRv5 ONNX models (Apache-2.0)](https://github.com/gitakoos/ocr-models)
- [PP-OCRv5 mobile ONNX bundle notes](https://github.com/ben-milanko/dart-pdf/releases/tag/ocr-models-v1)
- [Tencent HY-MT1.5 licence text](https://ollama.com/huihui_ai/hy-mt1.5-abliterated:7b/blobs/ebbd49dd8772)
- Sogda AI tutor spec (project file `ai-tutor-gemma-feature.md`) for Gemma, Bergamot, Supertonic and runtime rules
