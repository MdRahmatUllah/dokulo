# Release regression checklist (DK-0670)

Every internal build (each phase's build, every release candidate) gets this
pass before it goes to the owner. SQA (agent-3) runs it on a Dokulo emulator
(`docs/qa/device-lab.md`) and, once they are connected, on the real phones
(DK-1066). A build passes when every row passes or has a filed bug the lead
accepts for that build; the sign-off goes in the log at the bottom.

## Before the pass

1. Build the APK of the commit under test: `flutter build apk --release
   --flavor prod` in `packages/app_pdf` (more than 4 GB free; `heavy: mine`).
   Note the short sha.
2. `python tools/check.py --apk <apk>`: the gate, plus the native-library and
   size checks on that APK.
3. The golden PDF corpus, full (DK-0658; the gate runs the quick one):
   `DK_CORPUS=full DK_CORPUS_REPORT=<file.md> flutter test test/corpus` in
   `packages/doc_tools` (about 5 minutes). Every tool's row must read
   "0 failed"; paste the table into the log below.
4. Hold `team.py device`, uninstall the old build, install, and confirm it with
   `adb -s emulator-555x shell dumpsys package app.dokulo | grep lastUpdateTime`.
4. Copy the sample set to `Download/` on the device: a text PDF (20+ pages),
   a scanned PDF without text, a password-protected PDF, a PDF form, a
   damaged PDF, two versions of one contract, three photos of a document.
   (`docs/compliance/network-uses.md` names `test/fixtures/`; that set is not
   in the repo yet, so SQA keeps its own in `.worktrees/agent-3/sqa-samples/`,
   with no personal data.)
6. Leave the emulator as found afterwards: language, theme, font scale,
   animations, airplane mode.

## The pass

Each row: open it, do the action, check the result opens and reads right.

### First run and shell

- [ ] Fresh install: onboarding (O1–O3), permissions asked only when needed.
- [ ] The four tabs and the raised Scan button; back from every pushed page.
- [ ] Cold start after a force-stop resumes cleanly (no stuck job, temp
      cleared: DK-0021).

### Scanner

- [ ] Each scan mode from the Scan menu: Document, ID card, Book, Batch (S1); auto-capture, flash, manual capture.
- [ ] S2 review: crop, filter, reorder, add page, delete page; save as PDF;
      the file opens in the viewer.
- [ ] Import photos; Find documents in photos (if on).

### The 30 tools (Tools tab, each on its sample file)

Each tool: options, run, progress, result card, open the result, Undo or
"Save as copy" where offered, Cancel mid-run on one long run.

| Group | Tools |
| --- | --- |
| Organize | [ ] Merge PDF · [ ] Split PDF · [ ] Extract pages · [ ] Organize pages · [ ] Rotate PDF · [ ] Smart Split |
| Convert | [ ] Image to PDF · [ ] PDF to images · [ ] Web page to PDF · [ ] Convert to PDF/A · [ ] PDF to text |
| Optimize | [ ] Compress PDF · [ ] Repair PDF · [ ] Make text searchable |
| Edit | [ ] Add page numbers · [ ] Add watermark · [ ] Crop pages · [ ] Mark up · [ ] Fill form · [ ] Sign PDF |
| Security | [ ] Add password · [ ] Remove password · [ ] Black out (redact) |
| More | [ ] Compare PDFs · [ ] Extract images & text · [ ] Batch · [ ] Workflows |
| AI | [ ] Summarize · [ ] Ask this PDF · [ ] Translate PDF |

- [ ] Black out: the redacted text is gone from the saved file (search and
      copy find nothing), not only covered.
- [ ] A tool on a locked PDF asks for its password; a damaged PDF shows the
      error from the catalogue, not a crash.

### Viewer and edit

- [ ] Open, scroll, zoom, thumbnail strip, go to page, search (text PDF and a
      scan without text), night mode.
- [ ] Edit mode: add text, mark up, sign; undo/redo; save and save as copy.

### Files, trash, locked folder

- [ ] Files: list and grid, sort, folders (create, rename, tag, move), search.
- [ ] Delete → Recently deleted → restore; empty trash.
- [ ] Locked folder: set up the PIN, move a file in, lock, unlock with PIN
      (and biometrics where the emulator has a fingerprint), move it out.
- [ ] Settings → Security: app lock on, background past "Lock after", the
      app asks again; the privacy cover in the app switcher.
- [ ] The files are visible in the system Files app under Documents/Dokulo.

### AI readiness

- [ ] Me → AI models: eligibility shown right for the device (not available
      on a 3 GB or armeabi-v7a phone, with the reason).
- [ ] Without a model, an AI tool offers the download; with one installed,
      Summarize, Ask and Translate run offline.

### Pro and the paywall (sandbox)

- [ ] A Pro tool on a free install opens the paywall (X3) with the context
      line; the close button works.
- [ ] Sandbox purchase, then restore on a fresh install; Me shows "Pro –
      yours for good".

### Theme, language, text size

- [ ] Light and dark (Me → Appearance): Home, a tool, the viewer, Me.
- [ ] Deutsch (Me → Language): the same screens; no clipped or English text.
- [ ] Font scale 200 % (system settings): Home, a tool's options, a sheet.

### Offline

- [ ] The airplane-mode test of `docs/compliance/network-uses.md` (DK-0664):
      scan, every tool but Web page to PDF, AI with an installed model, all
      in airplane mode.

## What a failure becomes

A failing row is a bug on the board (`team.py add … --lane <owner's lane>`,
the build sha, steps, expected, actual, a screenshot in
`.worktrees/agent-3/sqa-evidence/`), and a GitHub issue. P0/P1 go to the lead
at once. A row a feature not yet built can't pass is marked "n/b" (not built)
with the task id that builds it.

## Sign-off log

| Date | Build (sha, flavour) | Device | Result | Bugs / not built |
| --- | --- | --- | --- | --- |
