# 04 — Offline PDF Toolkit: Frontend & UX Plan

Oct 7, 2026 · @Rahmat Ullah

## Purpose and the UX guides we build on

This document plans the frontend feature by feature (feature → sub-features → capabilities → user experience). It reuses Sogda's design system for structure and adds a scanner/PDF-specific UX layer from the research below.

**Guides found**

| Guide | Where | What we take from it |
| --- | --- | --- |
| Sogda design system and per-screen docs | Sogda project docs (chat of Oct 2026) | Token architecture (`DpTokens` theme extension, `DpSurface`), three modes (Light "Paper & Ink", Dark "Night Ink", Glass "Aurora Glass") with identical behaviour, glass fallback rules, `material_ui`/`cupertino_ui` 1.0 on Flutter 3.47, `go_router` with `StatefulShellRoute`, one Markdown spec per screen, "no telemetry" success measures |
| Sogda AI tutor spec | Project file `ai-tutor-gemma-feature.md` | Model download card, first-use AI disclaimer, model cards, RAM eligibility messages, accessibility rules for streamed AI text |
| Platform guidelines | Apple Human Interface Guidelines, Material 3 | Navigation patterns, permissions in context, share sheets, system document scanner conventions |
| Category research | Section "Research findings" | What users of Adobe Scan, CamScanner, iLovePDF and similar apps praise and complain about |

**Brand note:** this app should have its own palette and name, but the same token system, so the code (and later the letter assistant) can share components. Glass mode is optional here; a calm, document-first look fits a utility better than a playful one.

**Scope:** the 44 first-release features from the project doc. Office conversion, full text editing and other "later" items are out of scope.

## Research findings

Users of this category rarely complain about missing features; they complain about being surprised: paywalls after work is done, automation they can't turn off, files they can't find or export, and crashes on long documents.

### What 1–3 star reviews repeat

An analysis of low-star reviews across Adobe Scan, CamScanner, Microsoft Lens, Genius Scan and SwiftScan ([Unstar, 2026](https://unstar.app/blog/adobe-scan-camscanner-microsoft-lens-genius-scan-swiftscan-pdf-scanner-apps-ranked-2026)) found the same complaints in every app:

| Complaint | What happens | Our answer |
| --- | --- | --- |
| Limits hidden until after the work | User scans 12 pages, taps Save, then hits a paywall for OCR, watermark removal or multi-page export | Pro badges visible on tools before starting; free tools never blocked at export; Pro tools offer one free trial run before any paywall |
| Ads between tasks | 15–30 s video ads before the next scan | No interstitial ads, ever |
| Unrelated permission prompts | Contacts and location requested by a scanner | Only camera and photos, asked at the moment of use, with a one-line reason |
| Export locked or tied to a cloud | Export to Drive/Dropbox needs premium; share gives a link instead of a file | Share and "Save to Files" always produce the real file, free |
| Crashes on long documents | Crash during OCR or PDF assembly of a lease or manual | Jobs are resumable and write to a new file; tested on 300-page inputs |
| Hard to find saved files | Files not visible from the computer or Files app | Files live in a visible app folder (iOS Files, Android Documents), plus recents and search |

### Scanner-specific findings (Adobe Scan community)

- **Auto-capture and auto-crop are tied together**, and users want them separate: crop suggestions yes, automatic shutter no ([Adobe community](https://community.adobe.com/t5/adobe-scan-discussions/turn-off-auto-scan/m-p/9157618)).
- **"Apply to all pages" is missing for crop**, so users turn off crop page by page on long imports ([Adobe community](https://community.adobe.com/t5/adobe-scan-discussions/need-an-option-to-disable-auto-crop-for-all-pages-at-once/m-p/11354563/highlight/true)).
- **Defaults can't be set**: users want a default colour mode and crop mode for gallery imports.
- **Manual corner adjustment is fiddly on small screens**: users ask for a bigger magnifier and corners that don't jump when the finger lifts ([Adobe community](https://community.adobe.com/questions-517/need-higher-precision-cropping-aid-11297)).
- **Updates that move controls** break habits; a stable layout matters for repeat users.

### Editor and viewer patterns

- Mobile annotation toolbars work best in **two levels**: a compact row of tool icons, with options (colour, thickness) opening only for the chosen tool; **selecting text pops up a small markup bar** (highlight, underline, strike) ([Nutrient](https://nutrient.io/guides/web/user-interface/annotation-toolbar/mobile-responsiveness)).
- A clear separation between **reading/pan mode and edit mode** avoids accidental marks.

### Waiting and progress

Use a looped indicator for operations of 2–10 seconds and a percent-done indicator for anything over about 10 seconds; when the total is unknown, show absolute progress such as pages done ([Smashing Magazine](https://www.smashingmagazine.com/2016/12/best-practices-for-animated-progress-indicators)).

### Paywall timing

Contextual paywalls (shown when a user reaches a gated feature) are the most common high-intent placement; Apple reviews paywalls for dark patterns and a missing Restore button is a rejection reason ([RevenueCat](https://www.revenuecat.com/blog/growth/guide-to-mobile-paywalls-subscription-apps.md)). For a one-time-price privacy app, trust is the product, so we use contextual paywalls only, never an onboarding hard paywall.

## UX principles

Ten rules every screen is checked against; each one answers a finding above.

1. **No surprises.** Every Pro tool shows its badge before the user starts. A free task is never blocked at the save step.
2. **The original is sacred.** Tools always write a new file; the source is never overwritten unless the user explicitly chooses "Replace original".
3. **Preview before commit.** Every tool shows the result (pages, size, redaction boxes) before saving, with Undo after.
4. **Smart defaults, easy override.** Auto-crop, auto-capture, colour mode and compression level have sensible defaults, can be changed per page, applied to all pages, and saved as the new default.
5. **Two taps to any tool.** From home: tool grid → pick file. From outside: share sheet → tool.
6. **Visible privacy.** A small "On this phone" indicator on tool screens; never a vague "secure" claim. Airplane mode works for everything except model downloads.
7. **Honest progress.** Show pages processed and an estimate for long jobs; allow cancel at any time; jobs survive leaving the app.
8. **Files belong to the user.** Real files in a visible folder; export as a file, never a link; no account.
9. **One-handed and thumb-first.** Primary actions in the bottom third; destructive actions never in the thumb's resting spot.
10. **Stable layout.** Tool positions don't move between versions; new tools are added, not reshuffled.

## Information architecture and navigation

Four tabs plus a raised Scan button in the centre of the tab bar; every tool is reachable from Home, Tools, a file's action menu or the share sheet.

### Tab bar

| Position | Tab | Purpose | Route |
| --- | --- | --- | --- |
| 1 | **Home** | Recent files, pinned tools, "continue" card for an unfinished job, quick actions | `/home` |
| 2 | **Tools** | Full tool grid grouped by category, search, Pro badges | `/tools` |
| centre | **Scan** (raised button) | Opens the camera scanner directly | `/scan` (full-screen, tab bar hidden) |
| 3 | **Files** | All files and folders, locked folder, search incl. OCR text | `/files` |
| 4 | **Me** | Signatures, workflows, AI models, Pro, settings, about/licences | `/me` |

Built with `go_router` `StatefulShellRoute.indexedStack` so each tab keeps its scroll position and stack (same pattern as Sogda).

### Entry points from outside the app

| Entry | Platform | Lands on |
| --- | --- | --- |
| Share sheet with one PDF | Both | "What do you want to do?" tool picker sheet, file preselected |
| Share sheet with several files/images | Both | Tool picker filtered to multi-file tools (Merge, Image to PDF, Batch) |
| "Open with" / tap a PDF in Files | Both | Viewer, with the tool bar one tap away |
| Files app action ("Compress with …") | iOS | Selected tool directly |
| App icon long-press shortcuts | Both | Scan, Merge, Compress, last used tool |
| Home-screen widget (small) | Both | Scan, or the last scan |

### Screen inventory (IDs used below)

| ID | Screen | Type |
| --- | --- | --- |
| H1 | Home | Tab |
| T1 | Tools grid | Tab |
| T2 | Tool screen (generic shell, one per tool) | Pushed page |
| T3 | Tool result / preview | Pushed page |
| S1 | Camera scanner | Full screen |
| S2 | Scan review (page tray, crop, filters) | Full screen |
| F1 | Files browser | Tab |
| F2 | Locked folder | Pushed page behind biometric |
| V1 | Viewer | Full screen |
| V2 | Viewer edit mode (annotate, sign, fill) | Mode of V1 |
| P1 | Page organiser (thumbnail grid) | Full screen |
| A1 | AI panel (summary, ask, translate) | Bottom sheet over V1, expands to full |
| M1 | Me | Tab |
| M2 | Model manager (model cards) | Pushed page |
| M3 | Settings | Pushed page |
| X1 | Tool picker sheet (from share sheet) | Bottom sheet |
| X2 | Job progress sheet | Bottom sheet / mini bar |
| X3 | Pro paywall | Sheet |

## The universal tool flow

Every one of the 30 PDF tools uses the same five-step shell (screen T2 → X2 → T3), so users learn it once and we build it once.

1. **Choose input.** If the user arrived with a file (share sheet, viewer, file menu), this step is skipped. Otherwise a picker shows recent files first, then the Files tab and "Browse device". Multi-file tools allow multi-select with drag-to-order.
2. **Set options.** One screen, smart defaults pre-selected, plain-language labels, and a live estimate where possible ("About 1.8 MB, 12 pages"). Advanced options are folded under "More options". The main button names the action and size: "Compress 12 pages".
3. **Run.** Under 2 s: no indicator. 2–10 s: looped indicator on the button. Over 10 s: progress sheet (X2) with "Page 7 of 40", time left, Cancel, and "Keep working" which shrinks it to a mini bar above the tab bar. Jobs continue in the background and notify when done.
4. **Preview result (T3).** Shows the new file with the key fact for this tool (new size and % saved, page count, redaction boxes, detected text) and a before/after toggle where it helps.
5. **Keep it.** Buttons: **Save** (to the same folder, auto-named "Original name – compressed.pdf"), **Share**, **Open**. A row of "Next" chips suggests common follow-ups (e.g. after Merge: Compress, Protect, Add page numbers); chaining here can be saved as a workflow.

**Rules for the shell**

| Rule | Detail |
| --- | --- |
| Original untouched | Output is always a new file; "Replace original" is an explicit option in the Save menu, with Undo for 10 s |
| Pro gating | Pro badge visible on the tool tile and in the T2 header. First run of each Pro tool is free and complete; from the second run, the paywall appears when tapping Run, before any work |
| Errors | Shown in the step where they happen, in plain words, with one recovery action ("This file is password-protected → Enter password") |
| Back behaviour | Back from step 2 keeps chosen options; back from step 4 discards the temp result after a confirm only if it took over 10 s to make |
| Accessibility | Every step has a heading, the main action is the last focusable element, progress announces at 25 % steps |

## Home, files, viewer and scanner

These four areas are where users spend most of their time; each table reads feature → sub-feature → capabilities → user experience.

### Home (H1)

| Sub-feature | Capabilities | User experience |
| --- | --- | --- |
| Recent files | Last 20 opened or created files, thumbnail, name, size, time; swipe for quick actions | First thing below the header; tap opens the viewer, long-press opens the file action sheet |
| Pinned tools | Up to 8 tools pinned by the user; defaults: Scan, Merge, Compress, Sign | Large tiles in a 4×2 grid; "Edit" to reorder by drag |
| Continue card | Shows an unfinished scan or a running/finished background job | Appears at the top only when relevant: "Scan of 6 pages not saved → Continue" |
| Quick drop | Pick or paste files straight into a tool | "Open a file" button under the grid |
| Privacy line | Static reassurance | Small line under the header: "Everything stays on this phone" |

### Files (F1, F2)

| Sub-feature | Capabilities | User experience |
| --- | --- | --- |
| Browser | Folders, sort (date, name, size), list/grid toggle, multi-select | Breadcrumb header; multi-select via long-press, then a bottom action bar (Share, Move, Merge, Compress, Delete) |
| Search | File names + OCR text + PDF text (FTS5) | Search field at the top; results show the matching line with the term highlighted and the page number |
| File action sheet | All tools that accept this file type, rename, duplicate, move, info, delete | Most used tools first; "All tools…" opens the full list |
| Folders | Create, rename, colour tag, move | Inline rename; drag files onto folders in grid view |
| Locked folder (F2) | Encrypted at rest, biometric or PIN, auto-lock after 1 min in background | Lock icon in Files header; app switcher shows a blurred snapshot while locked content is open |
| Trash | Deleted files kept 30 days | "Recently deleted" row at the bottom of Files; restore with one tap |
| Storage info | Space used by files and by AI models | In file info and in Me → Storage |

### Viewer (V1, V2)

| Sub-feature | Capabilities | User experience |
| --- | --- | --- |
| Reading | Continuous vertical scroll, pinch zoom, double-tap fit width, page jump, thumbnails strip, outline | Chrome hides on tap for a clean page; page number pill bottom-right |
| Search in document | Find with match count, next/previous, works on OCR text | Search bar at top, matches highlighted on page |
| Text selection | Select, copy, share text; markup bar on selection | Selecting text shows a small bar: Copy · Highlight · Underline · Strike · Ask AI |
| Night mode | Inverted page colours for reading in the dark | Toggle in the viewer menu; remembered per user, not per file |
| Tool bar | Context tools for this file | Bottom bar in read mode: Edit · Sign · AI · Tools · Share |
| Edit mode (V2) | Annotate, add text, shapes, sign, fill forms | Separate mode with a visible "Done" button so reading never creates accidental marks |
| Unsaved changes | Edits saved to a new version automatically | "Saved" toast; version history in file info (last 5 versions) |
| Password-protected files | Prompt for password on open | Inline field on the page placeholder, not a blocking dialog; "Remove password" offered after unlocking |

### Scanner (S1, S2)

| Sub-feature | Capabilities | User experience |
| --- | --- | --- |
| Capture | Live edge detection, quad overlay, flash, grid, haptic on capture | Opens in under 1 s from the Scan button; shutter bottom-centre; mode switcher above it: Document · ID card · Book · Batch |
| Auto-capture | Captures when the quad is steady \~0.5 s | **Separate toggles for auto-capture and auto-crop** (the top Adobe complaint); default: auto-crop on, auto-capture off for first use, then remembered |
| Batch | Continuous capture of many pages | Page counter on the thumbnail tray; tap tray to review |
| ID card mode | Front then back, placed on one A4 page | Guided prompts: "Front side" → "Turn the card over"; card-shaped frame guide |
| Book mode | Two-page spread split into two pages | Spine guide line in the viewfinder; result shows left/right pages |
| Import | From photos or files, same processing | "Import" button bottom-left of the camera |
| Review (S2) | Reorder, retake, delete, rotate, crop, filters | Page tray at the bottom, big preview above; every per-page change offers **"Apply to all pages"** |
| Crop | Corner handles, edge handles, auto-detect again | **4× magnifier loupe** above the finger while dragging; corners snap to detected edges but never move after the finger lifts |
| Filters | Original, Auto colour, Greyscale, B/W, Shadow removal, brightness/contrast | Filter strip with live previews; long-press a filter to set it as default |
| Defaults | Default filter, crop mode, page size, file name pattern | "Save as default" in S2 and in Settings → Scanning |
| Save | PDF or JPG, page size, name, folder, optional OCR | Final sheet: name field pre-filled ("Scan 2026-10-07 14.32"), "Make text searchable" switch (Pro after first use) |
| Find documents in photos | Background detection of documents in the photo library | Opt-in card on Home after a week of use; results grid with "Convert to PDF" multi-select; photo permission asked only then |

## PDF tools

All tools run inside the universal shell; the tables list only what is specific to each tool: its sub-features, capabilities and the UX details that matter.

### Organize

| Tool | Sub-features | Capabilities | UX specifics |
| --- | --- | --- | --- |
| Merge PDF | Order files, include page ranges per file, keep bookmarks | Up to 500 files, any size | Files as draggable cards with page count; tap a card to pick pages; total pages and size shown live |
| Split PDF | By range, every N pages, one file per page, by bookmarks | Range syntax "1–3, 5, 8–end" | Thumbnail strip with scissor markers you can tap between pages; result list shows each part's pages |
| Extract pages | Select pages, keep order or selection order | Visual multi-select | Thumbnail grid, tap to select, counter "4 selected"; "Select odd/even/range" shortcuts |
| Organize pages (P1) | Reorder, delete, duplicate, rotate, insert blank or from another file | Undo/redo stack | Full-screen thumbnail grid; drag to move with auto-scroll; multi-select toolbar; pinch to change thumbnail size |
| Rotate PDF | Per page or all, 90° steps | Instant preview | Tap a thumbnail to rotate it; "Rotate all" button; detects sideways scans and suggests a fix |

### Convert

| Tool | Sub-features | Capabilities | UX specifics |
| --- | --- | --- | --- |
| Image to PDF | Order, page size (A4, Letter, fit), margins, orientation, one PDF or one per image | JPG, PNG, HEIC, WebP | Same page tray as the scanner review; option to run scanner cleanup (crop/filters) on photos |
| PDF to images | All or selected pages, JPG/PNG, resolution (72/150/300 dpi) | Saves to Photos or Files | Size estimate per resolution; "Save to Photos" asks photo-add permission only then |
| Web/HTML to PDF | URL or HTML file, page size, include backgrounds | Loads page in a preview | Address field with paste button; live preview before converting |
| PDF to PDF/A | PDF/A-2b | Conformance check result | Plain explanation ("Archive format accepted by many authorities"); warns if pages were converted to images because of missing fonts |
| PDF to Markdown / text | Markdown or plain text, include page markers | Copy or save .md/.txt | Preview with headings rendered; "Copy all" button |

### Optimize

| Tool | Sub-features | Capabilities | UX specifics |
| --- | --- | --- | --- |
| Compress PDF | Levels: Light, Recommended, Strong; targets: under 1 / 2 / 5 MB or custom | Per-image downsampling, structure compression | Three level cards with estimated size each; target chips for upload portals; result shows "8.4 MB → 1.9 MB (−77 %)" and a zoomed before/after crop for quality check |
| Repair PDF | Automatic repair, fallback rebuild | Reports what was fixed | Single button; result explains in one line ("Rebuilt damaged page table") or says plainly it couldn't be repaired |
| OCR PDF | Language (auto, DE, EN, more), pages, keep or replace existing text layer | Searchable PDF with invisible text | After run: "Text found on 11 of 12 pages"; tap a page to see recognised text highlighted |

### Edit

| Tool | Sub-features | Capabilities | UX specifics |
| --- | --- | --- | --- |
| Add page numbers | Position (6 spots), format ("1", "Page 1 of N", "Seite 1 von N"), start number, skip first page, font size | Vector overlay | Tap a position on a page diagram; live preview on the first two pages |
| Add watermark | Text or image, opacity, angle, size, position, pages | Overlay or underlay | Live preview; presets: "Copy", "Confidential", "Kopie" |
| Crop PDF | Per page or all, auto-crop margins | CropBox, non-destructive | Drag handles on the page with magnifier; "Apply to all pages" |
| Annotate & add text | Highlight, underline, strike, pen, highlighter pen, shapes, arrows, text box, sticky note, eraser | Saved as standard PDF annotations | Two-level toolbar: tool row at the bottom, options sheet for the selected tool; colour presets; palm rejection with stylus; undo/redo always visible |
| Fill forms | Text fields, checkboxes, radio, dropdowns, date; flatten | AcroForm (no XFA) | "Next field" button above the keyboard; field list sheet for long forms; unsupported XFA forms explained clearly |

### Security

| Tool | Sub-features | Capabilities | UX specifics |
| --- | --- | --- | --- |
| Sign PDF | Draw, type (handwriting fonts), image of signature; initials; date; saved signatures | Stamp placed as image | Signature pad in landscape full screen; saved signatures listed in a sheet; place by tap, then drag/resize; "Sign here" for every page needing it |
| Protect PDF | Open password, optional permissions (print, copy, edit) | AES-256 | Password strength meter; reveal toggle; clear warning: "If you forget this password, the file can't be opened" |
| Unlock PDF | Remove password you know | Decrypt | Single password field; never offers to guess passwords |
| Redact PDF | Auto-detect (IBAN, tax ID, emails, phones, dates of birth, names via AI), manual box, search-and-redact | True removal; verification | Detected items listed by type with counts and checkboxes; boxes on the page editable; final confirm explains the change is permanent; result badge "Verified: no hidden text left" |
| Compare PDF | Text differences, visual overlay | Change list | Side-by-side or overlay toggle; change list with jump-to; additions green, deletions red, plus text labels for colour-blind users |

### Extract and automation

| Tool | Sub-features | Capabilities | UX specifics |
| --- | --- | --- | --- |
| PDF extract | Images, text | Original image quality where possible | Grid of found images with multi-select; text as copyable block |
| Batch processing | Same tool on many files | Queue, per-file status | Queue list with status icons; failures don't stop the rest; summary at the end |
| Workflows | Saved chains of tools with saved options | Run on one or many files | Builder: add steps as cards; each step shows its options summary; templates: "Scan → OCR → Compress", "Merge → Page numbers → Protect" |

## Intelligence, Me and settings

AI lives in one place, the AI panel (A1) over the viewer, so users always see which document it is working on; models are managed in Me → AI models with the same model cards as Sogda.

### AI panel (A1)

| Sub-feature | Capabilities | User experience |
| --- | --- | --- |
| Entry | From viewer bar "AI", text selection "Ask AI", tool grid | Sheet opens at half height over the document; drag up for full screen; document stays visible behind |
| Model check | Detects missing model, low RAM, ineligible device | If no model: download card (size, RAM need, Wi-Fi only switch). Ineligible device: AI entries hidden except the explanation in Me → AI models (same rule as Sogda) |
| First-use notice | One-time AI disclaimer | Full-screen notice before first AI use; afterwards a one-line reminder under every answer |
| Summary | Short / detailed, bullet or paragraph, language of output | Streams into the sheet; each point ends with page chips ("p. 3") that jump the viewer; Copy, Save as note, Regenerate |
| Ask | Free questions about this document; suggested questions | Chat-style thread per document; answers cite pages; "Not found in this document" when retrieval fails, never a guess |
| Translate | Engine (Auto, Bergamot, Hy-MT2, EuroLLM, Gemma), target language, pages | Side-by-side view (original left, translation right; stacked on phones in portrait); export as PDF or text; engine shown in small text with a link to change |
| Smart Split | Suggested document boundaries in a bundle of scans | Thumbnail strip with suggested cut lines and a reason label ("New letterhead", "Page 1 of 3"); user can add/remove cuts; then names each part with a suggestion from its first lines |
| Redaction suggestions | AI-proposed names/addresses inside the Redact tool | Shown as a separate "Suggested by AI" group, unchecked by default |
| Cancel and memory | Stop generation, unload model | Stop button while streaming; model unloads after idle timeout (Sogda arbiter rules) |

### Me (M1) and settings (M3)

| Sub-feature | Capabilities | User experience |
| --- | --- | --- |
| Pro | Status, restore purchase, Family Sharing note | Card at the top: "Pro – yours for good" or the unlock card; Restore always visible |
| Signatures | Saved signatures and initials | List with add/delete; stored in the encrypted store |
| Workflows | Saved workflows | List with run, edit, duplicate |
| AI models (M2) | Model cards: what it does, size, RAM, quality badge, licence, download/pause/delete | Same layout as Sogda's model manager; translation engine selector here too |
| Scanning defaults | Auto-capture, auto-crop, default filter, page size, file name pattern, OCR language | Each with a short description; changes apply to the next scan |
| Files & storage | Default save folder, trash period, storage breakdown | Bar chart of files vs models |
| Security | App lock, locked folder PIN, lock timeout, hide previews in app switcher | Biometric toggle uses the platform wording (Face ID / fingerprint) |
| Appearance | Light, Dark, System; optional Glass | Live preview tiles |
| Language | English, Deutsch (system default) | Changes immediately, no restart |
| Privacy & about | What stays on device, no analytics statement, open-source licences, contact | Plain-language page, generated licence list |

## Onboarding, permissions and Pro

Onboarding is three screens and skippable; permissions are asked only at the moment they're needed; the paywall only appears when a user reaches a Pro tool, never at launch.

### Onboarding

| Screen | Content | Action |
| --- | --- | --- |
| 1 | "All your PDF tools. Nothing uploaded." with an airplane-mode illustration | Next |
| 2 | "No watermark. No subscription." Free vs Pro in two short lists | Next |
| 3 | "Start with": Scan a document · Open a PDF · Explore tools | Lands directly in that action |

A "Skip" link on every screen. No account, no email, no rating prompt during onboarding.

### Permissions

| Permission | When asked | Pre-prompt line |
| --- | --- | --- |
| Camera | First tap on Scan | "The camera is used only to scan; images stay on this phone." |
| Photo library (read) | First Import from Photos, or when opting into "Find documents in photos" | Android/iOS photo picker used where possible, so full access is only needed for the background finder |
| Photo library (add) | First "Save to Photos" | System prompt only |
| Notifications | First time a job runs longer than 30 s in the background | "Get a notice when long jobs finish?" |
| Biometrics | When turning on app lock | System prompt only |
| Network | Never asked; only used for model downloads, shown in the download card | — |

If a permission is denied: an inline card explains what doesn't work and offers "Open settings", never a loop of prompts.

### Pro and paywall (X3)

| Moment | Behaviour |
| --- | --- |
| Discovery | Pro tools carry a small badge in the grid and tool header; free tools have none |
| First use of a Pro tool | Runs fully, once, on a real file, with a note "Free try – Pro unlocks unlimited use" |
| Next use | Paywall sheet when tapping Run, before any processing |
| Paywall content | Headline, 5 short benefit lines, one price (one-time), "Restore purchase", "Not now"; no countdowns, no fake discounts, close button always visible |
| After purchase | Returns to the exact step the user was in and runs the tool |
| Soft reminders | At most one gentle Pro card on Home per month, dismissible forever |
| Rating prompt | Only after the 5th successful save, max once per 4 months, via the system review API |

## States: empty, progress, errors, success

Every screen designs these five states up front; each error names the problem in plain words and offers exactly one way forward.

| State | Rule | Examples |
| --- | --- | --- |
| Empty | Explain what will appear and give the first action | Home with no files: "Your scans and PDFs will appear here" + Scan / Open a PDF. Search with no results: "No file contains “Mietvertrag”" + "Search inside scans needs OCR → Run OCR on 3 scans" |
| Loading | Skeletons for lists and thumbnails; never a blank screen | File list skeleton rows; page thumbnails fade in as they render |
| Progress | Under 2 s none; 2–10 s looped indicator; over 10 s percent-done with pages and time left; cancel always available | "Compressing page 18 of 40 · about 20 s left" |
| Success | Confirm the result in numbers, then offer next steps | "Saved · 1.9 MB (−77 %)" with Share / Open / Next chips; haptic tick |
| Partial success | Say what worked and what didn't | "Text found on 11 of 12 pages. Page 7 is too blurry → Retake page 7" |

### Error catalogue (first release)

| Situation | Message | Action |
| --- | --- | --- |
| Password-protected input | "This PDF is locked with a password." | Enter password |
| Damaged file | "This file is damaged and can't be opened." | Try Repair |
| Not enough storage | "Not enough space on this phone (needs about 120 MB)." | Open storage settings |
| File too large for available memory | "This file is too large to process at once on this phone." | Process in parts (split first) |
| XFA form | "This form type can't be filled on phones." | Open as read-only |
| Model not installed | "Translation needs a language model (440 MB)." | Download |
| Low memory for AI | "Close other apps to use AI – it needs about 2 GB free." | Try again |
| Job cancelled | "Cancelled. Your original file wasn't changed." | — |
| Unexpected failure | "Something went wrong on page 14." + error code | Try again · Skip this page (where possible) · Send report by email (user-initiated, no automatic upload) |

## Accessibility, localisation and design direction

The app reuses Sogda's token system and accessibility rules; the visual direction is calmer and document-first.

### Accessibility

| Area | Rule |
| --- | --- |
| Screen readers | Every control labelled; tool tiles read "Compress PDF, Pro"; page thumbnails read "Page 3 of 12, selected" |
| Streaming AI text | Announced once when complete, not token by token (Sogda rule) |
| Colour | Never colour alone: compare uses labels, redaction categories have icons and names, Pro badge has text |
| Text size | Layouts hold to 200 % text scaling; tool grid switches from 4 to 2 columns |
| Touch targets | Minimum 48 × 48 dp; crop handles 44 dp with magnifier |
| Motion | Respect "reduce motion": no page-flip or glass animations, cross-fades only |
| Scanner | Spoken guidance option: "Move closer", "Hold still", "Captured" (VoiceOver/TalkBack) |
| Contrast | 4.5:1 for text in all themes, checked on glass over the brightest backdrop |

### Localisation

- English and German at launch, ARB files, all strings externalised from day one.
- German strings run about 30 % longer: buttons wrap to two lines rather than truncate; tool names tested at 200 % text size in German.
- Date and number formats from the device locale; page size default A4 in Europe, Letter in the US/Canada.
- German terms users search for: "PDF zusammenfügen", "PDF verkleinern", "Schwärzen" for redact, "Seitenzahlen".

### Design direction

| Element | Direction |
| --- | --- |
| Tokens and surfaces | Sogda's `DpTokens` / `DpSurface` architecture with this app's own palette |
| Themes | Light and Dark at launch, following the system; Glass optional later (expensive blur on long thumbnail grids) |
| Palette | One calm primary (document-blue or ink-teal), neutral greys, one accent for Pro, red reserved for destructive actions and redaction |
| Typography | System fonts (SF Pro / Roboto) for speed and familiarity; tabular numbers for sizes and page counts |
| Iconography | One consistent outline icon set; each tool has a unique icon used everywhere (grid, header, share picker) |
| Motion | Short, functional: page thumbnails animate when reordered; success tick; no decorative loops |
| Haptics | Light tick on capture, on save and on drag-drop landing |

**Tablets:** two-pane layouts for Files (list + preview) and Organize pages (bigger grid); viewer supports split view on iPad.

## Open questions

- [ ] Palette and app icon for Dokulo (name chosen; blocks the visual design)
- [ ] Glass theme at launch or later
- [ ] Final Free/Pro split per tool (badges depend on it)
- [ ] Which tools are pinned on Home by default
- [ ] Next step: per-screen specs (one Markdown file per screen, as in Sogda) and a clickable prototype of Home, Scanner and the tool shell, tested with 5 users before building

## Sources

- [Low-star review analysis of five scanner apps (Unstar, 2026)](https://unstar.app/blog/adobe-scan-camscanner-microsoft-lens-genius-scan-swiftscan-pdf-scanner-apps-ranked-2026)
- [Adobe Scan community: auto-scan and auto-crop](https://community.adobe.com/t5/adobe-scan-discussions/turn-off-auto-scan/m-p/9157618)
- [Adobe Scan community: apply crop setting to all pages](https://community.adobe.com/t5/adobe-scan-discussions/need-an-option-to-disable-auto-crop-for-all-pages-at-once/m-p/11354563/highlight/true)
- [Adobe Scan community: precision cropping](https://community.adobe.com/questions-517/need-higher-precision-cropping-aid-11297)
- [Nutrient: mobile annotation toolbar](https://nutrient.io/guides/web/user-interface/annotation-toolbar/mobile-responsiveness)
- [Smashing Magazine: progress indicators](https://www.smashingmagazine.com/2016/12/best-practices-for-animated-progress-indicators)
- [RevenueCat: guide to mobile paywalls](https://www.revenuecat.com/blog/growth/guide-to-mobile-paywalls-subscription-apps.md)
- Sogda design system and per-screen documentation (Oct 2026 chat); project file `ai-tutor-gemma-feature.md`
