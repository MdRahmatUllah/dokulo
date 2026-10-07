# Versions (DK-0002)

The exact versions Dokulo builds with. Runtime dependencies are pinned
exactly in the `pubspec.yaml` that uses them (no caret ranges); dev tools may
use caret ranges, because `pubspec.lock` pins them anyway. Native libraries
are pinned by tag and SHA-256. Licences and obligations are in the
[licence register](compliance/licence-register.md).

**A package is added by the task that first uses it, at the version in this
table.** Adding it at another version means changing this table in the same
PR. Checked on pub.dev on 2026-10-07.

## Toolchain and platforms

| What | Version | Where it is set |
| --- | --- | --- |
| Flutter | ≥ 3.47.0 (the machines run 3.47.5) | `packages/app_pdf/pubspec.yaml` `environment.flutter`; the minimum set by pdfrx 2.6 |
| Dart | ^3.13.0 | `environment.sdk` in every pubspec |
| iOS | 16.0 minimum | `IPHONEOS_DEPLOYMENT_TARGET` in `ios/Runner.xcodeproj`; the ONNX Runtime plugin's minimum |
| Android | minSdk 26 (Android 8.0) | `android/app/build.gradle.kts`; camera/HEIC support and model performance |

## Dart packages

| Package | Version | Licence | Used for | Status |
| --- | --- | --- | --- | --- |
| flutter_localizations | SDK | BSD-3 | EN/DE | In use (DK-0009) |
| intl | 0.20.3 | BSD-3 | EN/DE formats, ARB | In use (DK-0009) |
| flutter_riverpod | 3.4.3 | MIT | State management | In use (DK-0003) |
| riverpod_annotation | 4.0.7 | MIT | Riverpod codegen annotations | In use (DK-0003) |
| riverpod_generator | ^4.0.9 (dev) | MIT | Riverpod codegen | In use (DK-0003) |
| build_runner | ^2.16.1 (dev) | BSD-3 | Code generation | In use (DK-0003) |
| go_router | 18.0.1 | BSD-3 | Routing | In use (DK-0004) |
| lints, flutter_lints, test | ^6.0.0, ^6.0.0, ^1.26.0 (dev) | BSD-3 | Analysis, tests | In use (DK-0001) |
| pdfrx | 2.6.5 | MIT | Viewer, render, text, page assembly, save; bundles PDFium via pdfium_flutter 0.3.1 and pdfrx_engine 0.6.1 | Planned |
| pdfrx_engine | 0.6.1 | MIT | doc_core's PDF API (pure Dart, PDFium through pdfrx's worker); pdfrx 2.6.5's engine | In use (DK-0390, doc_core) |
| pdfium_dart | 0.3.1 | MIT | Raw PDFium bindings for calls pdfrx doesn't wrap (image objects), run on pdfrx's worker | In use (DK-0390, doc_core) |
| ffi | 2.2.0 | BSD-3 | Native memory for the raw PDFium calls | In use (DK-0390, doc_core) |
| pdf | 3.13.1 | Apache-2.0 | New PDFs, overlays, OCR text layer | Planned |
| printing | 5.15.1 | Apache-2.0 | HTML → PDF | Planned |
| llamadart | 0.8.12 | MIT | Gemma via llama.cpp; Sogda's runtime version (0.11.0 exists: upgrade together with Sogda) | Planned |
| llamadart_llama_cpp_flutter | 0.0.8 | MIT | llama.cpp for iOS (SwiftPM); paired with llamadart 0.8.12 | Planned |
| flutter_onnxruntime | 1.8.4 | MIT | OCR models, embeddings, TTS (ONNX Runtime 1.23); 1.9.0 exists | Planned |
| opencv_dart | 2.2.2 | Apache-2.0 | Image pipeline; modules core, imgproc, imgcodecs only ([opencv-modules.md](compliance/opencv-modules.md)) | Planned |
| receive_sharing_intent | 1.9.0 | Apache-2.0 | Share sheet / "Open with" | Planned |
| drift | 2.35.0 | MIT | File index, recents, folders, OCR text (FTS5) | In use (DK-0005, doc_core) |
| drift_dev | ^2.35.0 (dev) | MIT | drift codegen | In use (DK-0005) |
| sqlite3 | 3.6.0 | MIT | SQLite with FTS5 via build hooks. `sqlite3_flutter_libs` and `sqlcipher_flutter_libs` are obsolete with sqlite3 3.x: not added | In use (DK-0005, doc_core) |
| cryptography | 2.9.0 | Apache-2.0 | AES-GCM for the locked folder | Planned |
| flutter_secure_storage | 11.2.0 | BSD-3 | Keys in Keychain / Keystore (the plan said 9.x; 11 is current) | Planned |
| local_auth | 3.0.2 | BSD-3 | Biometric unlock (the plan said 2.x; 3 is current) | Planned |
| background_downloader | 9.6.4 | BSD-3 | Model downloads | Planned |
| file_picker | 13.1.0 | MIT | Pick PDFs and images | Planned |
| share_plus | 13.3.1 | BSD-3 | Share results | Planned |
| path_provider | 2.1.6 | BSD-3 | Sandbox paths | In use (DK-0005, app_pdf) |
| photo_manager | 3.12.0 | Apache-2.0 | Find documents in photos | Planned |
| webview_flutter | 4.14.1 | BSD-3 | Web page to PDF | Planned |
| image | 4.10.1 | MIT | EXIF, HEIC fallback, thumbnails | Planned |
| in_app_purchase | 3.3.1 | BSD-3 | Pro unlock | Planned |
| camera | 0.12.1 | BSD-3 | Android scanner frames | Planned |
| material_symbols_icons | 4.2960.0 | Apache-2.0 | Icons (DK-0048) | Planned |
| phone_numbers_parser | 9.0.28 | MIT | Redaction: phone numbers | Planned |
| diff_match_patch | 0.4.1 | Apache-2.0 | Compare PDF text diff | Planned |
| google_mlkit_document_scanner | — | — | **Not used** ([ml-kit-scanner.md](compliance/ml-kit-scanner.md)) | Excluded |

## Native libraries (pinned by tag and SHA-256)

| Library | Tag | SHA-256 of the source archive | How it is built |
| --- | --- | --- | --- |
| qpdf | `v12.3.2` | `6cba2f9f2cd887d905faeb99e0e51a307b217920d1bbf3e9cfbb2e8178a2deda` (`qpdf-12.3.2.tar.gz`; matches qpdf's signed `qpdf-12.3.2.sha256`) | Our `qpdf_ffi`, native crypto only |
| OpenCV | `4.13.0` | `1d40ca017ea51c533cf9fd5cbde5b5fe7ae248291ddf2af99d4c17cf8e13017d` (GitHub's `4.13.0.tar.gz`) | Built from source by dartcv4 2.2.2 |
| PDFium | `chromium/7811` | pinned by pdfium_flutter 0.3.1 | Prebuilt by pdfrx |
| ONNX Runtime | 1.23 | pinned by flutter_onnxruntime 1.8.4 | Prebuilt by the plugin |
| llama.cpp | as pinned by llamadart 0.8.12 | pinned by the plugin | Prebuilt by the plugin |
| sRGB ICC profile | `sRGB2014.icc` | `384b832de3412066743b52a75ee906b6fb9fb8d9e09e936fc2c43223815c6e0a` | Bundled unchanged ([srgb-icc-profile.md](compliance/srgb-icc-profile.md)) |

## Monthly upgrade review

On the first working day of each month, one developer runs `flutter pub
outdated`, checks the native tags above for new releases, upgrades what is
safe (patch and minor first; majors get their own task), updates this table
and the licence register, and runs `python tools/check.py`. Each review adds
the next month's review task to the board (`team.py add`).
