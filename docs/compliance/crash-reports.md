# Crash reports (DK-0011)

**The owner's decision (2026-10-07):** no crash-reporting SDK and no
automatic upload. Crashes are logged on the phone, only when the user has
turned that on, and a report leaves the phone only as an email the user sends.

## How it works

- **Off by default.** Settings → Privacy has a switch, "Keep crash reports"
  (`crashReportsEnabledProvider`). While it is off, nothing is written.
- **On:** an uncaught error (Flutter's and the platform's handlers,
  `installCrashHooks` in `main.dart`) adds one entry to a local log in app
  support (`crash_log.jsonl`), and only the newest 20 are kept. Turning the
  switch off doesn't delete the log; "Delete crash reports" (`CrashLog.clear`)
  does.
- **"Send report by email"** (the Unexpected error, "Something went wrong on
  page 14. (code DK-0142)"; and Settings → Privacy) opens the user's mail app
  with a prepared email (`reportEmail`). The user sees it and sends it, or
  doesn't. The recipient is left empty until the owner names a support address.

## Exactly what a report contains

This list is the source for the Privacy page.

| In a report | Example |
| --- | --- |
| The error code shown in the message | `DK-0142` |
| When it happened (UTC) | `2026-10-07T21:14:03Z` |
| The kind of error | `StateError` |
| Where in Dokulo's code it happened: the stack trace's code locations | `PdfEngine.text (package:doc_core/src/pdf/engine.dart:120:7)` |
| The device facts the report form adds | OS and version, memory, CPU architecture, app version |

**Never in a report:** file names, folder paths, any text or image from a
document, the error's message (it can quote a file name or document text, so
it is dropped as a whole rather than filtered), and anything that identifies
the user or the phone. A file-system path in a stack frame becomes `<path>`.
`packages/app_pdf/test/crash/crash_log_test.dart` checks this with a crash whose message names
`Mietvertrag Musterstraße 12.pdf` and quotes the contract.

## Symbols

Store builds are obfuscated (`docs/release.md`), so the code locations of a
report from a store build are addresses. The owner symbolises them with that
version's `--split-debug-info` files, which never leave the owner's machine.
