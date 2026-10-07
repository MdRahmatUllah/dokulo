# App size budget (DK-0017)

The base app stays small: everything optional is an on-demand download
(Technology plan, engineering rule 5). This page sets the budget and how it is
checked.

## The budget

**At most 90 MB per ABI** for the prod APK a phone gets (`tools/size_check.py`,
`BUDGET_MB`). That is the universal APK minus the other ABIs' libraries: what
a per-ABI split, or the APK Google Play builds from our AAB for one phone,
carries. Native libraries are stored uncompressed in the APK (Android maps
them straight from it, and 16 KB alignment needs that), so the Play download,
which is compressed, is smaller than this number.

| Part (arm64-v8a) | Now | Planned | Source |
| --- | --- | --- | --- |
| Flutter engine + our Dart code (`libflutter`, `libapp`) | 16.7 MB | grows with the screens | measured, 2026-10-07 |
| PDFium (pdfrx) | 6.4 MB | | measured |
| SQLite (sqlite3) | 1.7 MB | | measured |
| OpenCV: core, imgproc, imgcodecs (`libdartcv`) | | 10.5 MB | the DK-0680 probe build |
| ONNX Runtime (`flutter_onnxruntime`) | | about 15–20 MB | estimate |
| llama.cpp (`llamadart`) | | about 5–10 MB | estimate |
| qpdf (`qpdf_ffi`), Bergamot engine | | about 5–8 MB | estimate |
| PP-OCRv5 det + Latin rec + angle cls (bundled) | | 13.4 MB | Technology plan |
| **Total** | **25.5 MB** | **about 80–90 MB** | |

The budget leaves little room on purpose: a new bundled library or asset has
to argue for its place. When a task adds one, it updates this table in the
same PR. Raising the budget is a change to this page and to `BUDGET_MB`,
named in the PR.

## What keeps it small

- **Models:** only the PP-OCRv5 det, Latin rec and angle cls models ship in
  the app. Gemma, Hy-MT2, EuroLLM, Bergamot language packs, the multilingual
  OCR rec and anything later are downloads with hash checks.
  `size_check.py` fails on any other bundled model file.
- **OpenCV:** core, imgproc and imgcodecs only (DK-0680).
- **Per-ABI delivery:** the store gets an AAB (`flutter build appbundle`), so
  each phone downloads one ABI's libraries. Side-loaded test builds can use
  `flutter build apk --split-per-abi`.
- **Debug symbols:** release builds strip native symbols, and Dart symbols go
  to `--split-debug-info` outside the app (`docs/release.md`).
- **Icon fonts** are tree-shaken in release builds (Flutter's default; keep
  it: don't pass `--no-tree-shake-icons`).

## How it is checked

`python tools/check.py --apk <the prod apk>` runs `tools/size_check.py`, which
prints each ABI's size against the budget and fails over it, or on a bundled
model other than the OCR det/rec/cls. There is no CI (the owner, DK-0010), so
whoever builds a release runs it, as `docs/release.md` says.
