# Errors (DK-0609)

Every failure the user sees is a `DokuloError`
(`packages/app_pdf/lib/errors/dokulo_error.dart`): a situation from the error
catalogue (UI spec §26.3), its code, the page if known, the localised message
and its recovery actions. `DokuloError.from(error)` maps anything thrown:

- `DocError` (doc_core) by its kind, keeping the page;
- `JobCancelled` (ai_core) → Cancelled; a `FileSystemException` with ENOSPC
  (28) or ERROR_DISK_FULL (112) → Not enough storage; `OutOfMemoryError` →
  Too large for memory;
- failures from a worker isolate, which arrive as text (`JobFailed`), by the
  exception name in the message: `DocError(kind, page n: …)`,
  `QpdfException(password|damaged)`, `OcrException(notAnImage)`,
  `VisionOcrException(notAnImage)`, `WebToPdfException(loadFailed)`;
- anything else → Unexpected, with the original text kept in `detail` for
  logs and the user-sent report (never shown as the message).

## Codes

| Code | Situation | Message (EN) | Actions |
| --- | --- | --- | --- |
| DK-0100 | Locked input | This PDF is locked. | Enter password |
| DK-0110 | Damaged file | This file can't be opened. | Try Repair |
| DK-0120 | Not enough storage | Not enough space on this phone (needs about {mb} MB). | Manage storage |
| DK-0130 | Too large for memory | This file is too large to process at once on this phone. | Split it first |
| DK-0140 | Unsupported form | This form type can't be filled on phones. | Open read-only |
| DK-0150 | Model missing | Translation needs a language model ({mb} MB). | Download |
| DK-0160 | Low memory | Close other apps to use AI – it needs about 2 GB free. | Try again |
| DK-0170 | Cancelled | Cancelled. Your original file wasn't changed. | — |
| DK-0180 | Offline (web tool) | You're offline. | Try again |
| DK-0190 | Unexpected | Something went wrong on page {page}. (code DK-0190) | Try again · Skip this page (when a page is known) · Send report by email |

The German copy is in `app_de.arb` (the catalogue's DE column). A code is only
ever shown inside "Something went wrong…" and in a report, never alone.

## Where they are raised

`Preflight` (doc_tools, DK-0020) runs in `JobQueue.start` and `resume`
before a job starts: Not enough storage (the inputs × the tool's
`spaceFactor` against the free storage, with the bytes needed), Too large for
memory (the largest page at the tool's `renderDpi` × `pagesInMemory` against
60 % of the free memory) and Locked (an input that won't open without its
password). The device is read again for every check; an unknown value never
blocks. A killed job whose preflight fails at the next launch keeps its row
and is reported as "Couldn't finish".

Elsewhere: `PdfEngine.ensureFillable` raises Unsupported form for an XFA
form (Fill form calls it first; DK-0614); `aiLoadError(device, needs)` turns
AI's load check into Low memory (DK-0616); the web tool's `loadFailed` reads
as Offline (DK-0619); the model manager (M13) raises Model missing with the
model's size (DK-0615).

## Presentation

Inline where it happens, whenever possible: a field error (a wrong password),
a `DkBanner` in the step, or the failure state of the progress sheet for a
job (`DkProgressSheet.error`). Never a generic "Error" modal.

A new engine exception adds a row here, a case in `DokuloError.from`, and a
test in `test/errors/dokulo_error_test.dart`.
