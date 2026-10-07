# Dokulo

An offline, iLovePDF-style PDF toolkit and scanner for iOS and Android
(Flutter, EN/DE). Everything runs on the phone: no uploads, no account.

The specs are in [`docs/`](docs/), the screens in
[`dokulo-design/`](dokulo-design/index.html), the plan in
[`dokulo-task-list.csv`](dokulo-task-list.csv). The team's guide is
[`CLAUDE.md`](CLAUDE.md) and [`developer-agents/`](developer-agents/README.md).

## The five layers

One repository, one [pub workspace](https://dart.dev/tools/pub/workspaces)
(the root `pubspec.yaml`, one `pubspec.lock`). Everything below the UI lives in
shared packages so the letter assistant (doc 03) and Sogda can reuse them.
From the Technology & Package Plan, "Stack at a glance":

| Layer | Package | Contents | Built on |
| --- | --- | --- | --- |
| 1. App | [`app_pdf`](packages/app_pdf) | Screens, tool grid, viewer, file manager, paywall, Riverpod providers | Flutter 3.47+, Dart 3.13+ |
| 2. Tool jobs | [`doc_tools`](packages/doc_tools) | One `ToolJob` per feature (merge, compress, redact…), progress stream, cancel, undo snapshot, workflow runner | Pure Dart, runs in worker isolates |
| 3. Document core | [`doc_core`](packages/doc_core) | Open/save/render PDFs, page ops, text extraction, structure ops, image pipeline, OCR text layer writer | pdfrx / PDFium, qpdf (our FFI), Dart `pdf`, opencv\_dart |
| 4. Vision & OCR | [`doc_vision`](packages/doc_vision) | Scanner flows, edge detection, dewarp-light, OCR engines, layout, document-in-photo detection | VisionKit / Vision (iOS), own CameraX + OpenCV scanner (Android), PP-OCRv5 on ONNX Runtime |
| 5. On-device AI | [`ai_core`](packages/ai_core) (from Sogda) | Model manager, LLM arbiter, translation engines, embeddings, retrieval | llamadart (llama.cpp), Bergamot (FFI), ONNX Runtime |

**Dependencies point one way only:** `app_pdf → doc_tools → doc_core / doc_vision → ai_core`.
A package may depend on a lower layer, skipping layers is fine, but never on
its own layer or a higher one. `doc_core` and `doc_vision` share a layer.
`python tools/check_layers.py` enforces it.

**Threading model:** PDFium is single-threaded, so pdfrx serialises all PDFium
calls on one worker isolate. qpdf, OpenCV and ONNX jobs run on their own
isolates. The UI isolate never touches native code directly.

`app_pdf/lib/` is laid out as the Developer guide says: `screens/`,
`components/`, `providers/`, `routes/`, `l10n/`.

## Build and check

```bash
flutter pub get                 # once, at the root: resolves every package
cd packages/app_pdf && flutter run
```

The basic check (`python tools/check.py`, the only check a PR gets: there is no CI/CD) is in
[`CLAUDE.md`](CLAUDE.md#the-basic-check).

How the code is organised, state, routing, theming, testing, the
accessibility checklist and the definition of done:
[`docs/Developer guide.md`](docs/Developer%20guide.md).
