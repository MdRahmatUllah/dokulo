# Dokulo — Developer guide

The "Developer guide" tab of the UI/UX guide (`Overview & foundations.md` →
How to use this guide). It says how the app is built: where code goes, how
state, routes and theming work, how it is tested, and when a screen is done.
**When code and this guide disagree, fix one of them the same day** (DK-0014).

## 1. Project structure

One repository, one pub workspace (root `pubspec.yaml`, one `pubspec.lock`),
five layer packages in `packages/`. The root [README](../README.md) lists what
each layer holds.

```text
pubspec.yaml            the workspace: its members, nothing else
packages/
  app_pdf/              layer 1: the Flutter app (android/, ios/, lib/, test/)
    lib/
      main.dart         runApp, nothing else
      screens/          one folder per screen ID: screens/h1_home/, screens/t2_tool/, …
      components/       the Dk* widgets (DkToolTile, DkFileCard, …), one file each
      patterns/         the interaction patterns of UI spec §12 (confirmations, undo, …)
      providers/        Riverpod providers that aren't private to one screen
      routes/           the go_router config and route names
      l10n/             app_en.arb, app_de.arb (DK-0009)
    test/               mirrors lib/; goldens next to their tests in goldens/
  doc_tools/            layer 2: one ToolJob per feature, work on worker isolates
  doc_core/             layer 3: PDFs: open, render, page ops, text, image pipeline;
                        the database (lib/src/db/schema.drift, drift_schemas/)
  doc_vision/           layer 3: scanner, OCR engines, layout, photo finder
  ai_core/              layer 4: models, LLM arbiter, translation, retrieval
tools/                  team.py, check_layers.py, licence_scan.py, … (Python, stdlib only)
docs/                   the specs; docs/compliance/ for licence and policy records
```

Rules:

- **Dependencies point one way:** `app_pdf → doc_tools → doc_core / doc_vision → ai_core`.
  `python tools/check_layers.py` fails on anything else.
- **The UI isolate never calls native code.** PDFium calls go through pdfrx,
  which runs every one of them on its own worker isolate; qpdf, OpenCV and ONNX
  run on their own isolates (DK-0007, DK-1044). A screen talks to a provider,
  the provider to a `ToolJob` or a `doc_core` service.
  - The `IsolatePool` (`ai_core`, the bottom layer, so every layer can reach it)
    runs jobs: `pool.run(lane, body, input)` gives a `Job` with `progress`,
    `result` and `cancel()`. `Lane.qpdf`, `Lane.opencv` and `Lane.onnx` start a
    fresh isolate per job, so they run in parallel.
  - **PDFium only through pdfrx.** pdfrx keeps one PDFium worker per Dart
    isolate, and the viewer uses it from the UI isolate; a second one would be a
    second thread in PDFium, which isn't thread-safe. So a `Lane.pdfium` job runs
    on the calling isolate and reaches PDFium only through pdfrx: its API,
    `PdfrxEntryFunctions.instance.compute`, or
    `PdfDocument.useNativeDocumentHandle` for raw `FPDF_*` calls. No other
    native call and no heavy Dart work belongs in a PDFium job.
  - A body is a top-level function `(input, JobContext context)`; on a worker
    lane its input and result must be sendable. Scratch files go in
    `context.tempDir`, which is deleted when the job ends; outputs go where the
    input says.
  - Cancelling kills a job on its own isolate at once. A PDFium job stops at its
    next `await context.checkCancelled()`, so check between pages (a cancel must
    stop the work within 1 s).
  - Every native binding of ours (qpdf, OpenCV, ONNX, llama.cpp) calls
    `assertWorkerIsolate()` before its first native call; in debug builds it
    fails on any isolate the pool did not start, the UI isolate included.
  - **qpdf** (DK-0391): `qpdf_ffi` builds qpdf 12.3.2 with zlib and
    libjpeg-turbo from source pinned by SHA-256 (`docs/versions.md`) in its
    build hook; the first build takes several minutes per target, later ones
    are cached. A tool calls it inside a `Lane.qpdf` job through `doc_core`:
    `QpdfService.run(() => Qpdf.encrypt(…))`, which checks the isolate and
    turns qpdf's errors into the catalogue's `DocError`s. `Qpdf.run(job)` takes
    any job in qpdf's job JSON; `encrypt`, `decrypt`, `repair`,
    `compressStructure`, `linearize`, `overlay`, `extract` and `check` cover
    the tools.
  - **Compress PDF** (DK-0392): `PdfCompress(pool).compress(input, output,
    CompressOptions(preset:, greyscale:, removeMetadata:, targetBytes:))`, from
    a `Lane.pdfium` job. Images above the preset's resolution are resized and
    re-encoded (Dart `image`, on a pool worker) into their own image objects;
    images already below it, transparent ones and 1-bit ones stay as they are;
    scan pages with an image that can't be re-encoded go through
    `RasterFallback` (rendered whole, OCR text kept). qpdf then compresses the
    structure, and drops the Info and XMP metadata if asked. `targetBytes` runs
    `searchSizeTarget` (quality 85…40 per resolution, sharpest first) and says
    when it can't get there.
- **A tool is a `ToolJob`** (`doc_tools`, DK-0008): a const class with an `id`
  (as in `/tool/:toolId`), a `Lane`, `encode`/`decode` of its input as JSON,
  `chain` (its input from the previous step's output, for workflows) and
  `run(input, context)`, which reports a `JobProgress` at least once per page
  and returns a `JobOutput`: `OneFile`, `ManyFiles` or `TextOutput`. Register it
  in `allToolJobs` (`registry.dart`); the registry test checks it against the
  catalogue `toolJobIds`.
  - The app runs tools through the one `JobQueue`: `start(toolId, input)` gives
    a `ToolRun` (`progress` with time left, `result`, `cancel()`), and
    `runChain(steps, input)` runs JSON steps (`workflows.steps`). The queue
    keeps a `jobs` row while a job runs, records tool usage after a success
    (DK-0022), and calls `JobHooks` (`onStarted`, `onFinished`, `onFailed`) for
    notifications and the background service.
  - A `jobs` row found at launch is a job the OS killed: `unfinished()` lists
    them; `resume()` runs one again from the start; `forget()` drops it (DK-0021).
  - "Replace original" takes an `UndoSnapshot` first, so Undo can put it back.
- **Files are never written in place.** `FileStore` (`doc_core`, DK-0006) owns
  the moves. An incoming file is copied into the sandbox (`importIncoming`); a
  job writes its output to `newTempFile`; `save` moves it into the user's
  visible folder under a free name ("Scan (2).pdf"); `clearTemp` runs after a
  save or share. `reconcile` syncs the index with the folder (pull-to-refresh
  on Home and Files). The visible folder is iOS Documents (shown in the Files
  app) or Android `Documents/Dokulo` (`fileStoreProvider`).
- **No network during a tool run** (DK-0012). The only network uses are model
  downloads, Web page to PDF, and purchases (`docs/compliance/network-uses.md`).
  Every job runs inside `offline()`, where an `HttpClient` or a socket fails as
  in airplane mode; our own HTTP goes through `ai_core`'s `Network`, and
  `check_layers.py` fails on network code anywhere else.
- A new dependency needs a licence-register line in the same PR
  (`docs/compliance/licence-register.md`; `python tools/licence_scan.py`).

## 2. State

Riverpod 3 with code generation, the same versions as Sogda:
`flutter_riverpod` 3.4, `riverpod_annotation` and `riverpod_generator` 4.0,
`build_runner` (DK-0003). Generated `*.g.dart` files are not committed: run
`dart run build_runner build` in `packages/app_pdf` after `flutter pub get`
(and again after a `git stash` round trip).

- **Generated, never hand-written.** `@riverpod` on a function or a class
  (`part '<file>.g.dart';`). The example is `lib/providers/theme_providers.dart`.
- **One provider file per screen,** next to it: `screens/h1_home/home_providers.dart`.
  Providers that several screens share go in `lib/providers/<topic>_providers.dart`.
- **The database** is `DokuloDatabase` in `doc_core` (DK-0005): the schema
  is SQL in `lib/src/db/schema.drift`, opened on a background isolate in app
  support through `appDatabaseProvider`. Tests use `DokuloDatabase.memory()`.
  A schema change bumps `schemaVersion`, adds a migration step, and runs
  `dart run drift_dev make-migrations` in `doc_core`, which writes
  `drift_schemas/`, `database.steps.dart` and the test helpers. It puts the
  helpers in `test/db/dokulo/`: move `generated/*` into `test/db/generated/`
  and delete the rest (`database_test.dart` already checks that every version
  upgrades to the current one). Take the `db-schema` lock first.
- **Files search's index** (DK-0270): `TextIndexer(db)` puts every page's text
  (PDF text, OCR layers included) into `ocr_text` and sets `files.has_text`.
  A file is stale while `files.indexed_at` isn't its `modified`; each file is
  indexed in one transaction, so a kill leaves the old index and the next
  `catchUp()` finishes it. After a save: `FileStore.save`, `reconcile`, then
  `catchUp()`; `startupCleanup` runs both in the background
  (`StartupReport.indexing`).
- **Data from drift:** an async notifier (`AsyncNotifier` / `StreamNotifier`)
  that maps the drift watch stream. **Never await a watch's `.first`** in a
  provider: it hangs tests.
- **Per-file state:** a family provider keyed by the file id
  (`@riverpod Future<FileInfo> fileInfo(Ref ref, String fileId)`).
- **`autoDispose` is the default.** `@Riverpod(keepAlive: true)` only for
  long-lived services and what every frame reads: the job queue, the model
  manager, the Pro entitlement, the theme mode. Name the reason in the doc
  comment.
- **Widgets** read with `ref.watch` in `build` and act through a notifier's
  method with `ref.read(...notifier)` in callbacks. No business logic in widgets.
- **Jobs:** a screen never awaits a job's `Future`. It watches the job-queue
  provider (DK-0008), which exposes each `ToolJob`'s progress stream as state
  (`queued → running(page, of) → done | failed | cancelled`). The progress
  sheet, the mini bar and T3 all read the same provider.
- **The UI never touches native code.** No file in `app_pdf/lib` imports
  `dart:ffi`, `package:ffi` or a native binding (`opencv_dart`, `dartcv4`,
  `flutter_onnxruntime`, `llamadart`, `qpdf_ffi`). `tools/check_layers.py`
  fails the build on it. pdfrx's viewer widget is the one exception: it runs
  PDFium on pdfrx's own worker isolate.
- **Tests override providers** through `ProviderScope(overrides: [...])`:
  `fooProvider.overrideWithValue(x)` for a plain value,
  `fooProvider.overrideWith(...)` for a function provider, and
  `fooProvider.overrideWithBuild((ref, notifier) => x)` for a notifier's
  initial state. To drive a notifier mid-test, take the container with
  `ProviderScope.containerOf(tester.element(...))`. See
  `test/providers/theme_providers_test.dart`.

## 3. Routing

`go_router` 18 with a `StatefulShellRoute`, so each tab keeps its scroll
position and its pushed pages (DK-0004); its `DkFadingBranches` container
cross-fades the tabs in 120 ms (UI spec §13.4, DK-0229). Pages are explicit
`MaterialPage`s, so a push takes the theme's `DkPageTransitionsBuilder` (iOS
slide, Android shared axis X); the scanner (`dkSlideUpPage`), the viewer
(`dkViewerPage`) and T3 (`dkFadePage`) have their own (DK-0237). The code is
`app_pdf/lib/routes/routes.dart`: `Routes` holds every path, `buildRouter()`
the tree, and `appRouterProvider` the app's router (kept alive). Build paths
with `Routes`, never by hand: `context.push(Routes.tool('compress'))`.

| Route | Screen | Where | Notes |
| --- | --- | --- | --- |
| `/launch` | Launch | full screen | The app's first frame: the native splash again (symbol 72 on `color.background`, DK-0073), then Home, or `/welcome` on the first launch |
| `/home` | H1 Home | tab 1 | Where the launch screen goes; tests start here |
| `/tools` | T1 Tools | tab 2 | |
| `/files` | F1 Files | tab 3 | |
| `/files/locked` | F2 Locked folder | tab 3, pushed | Behind biometrics (its task adds the guard) |
| `/me` | M1 Me | tab 4 | |
| `/me/models` | M2 Model manager | tab 4, pushed | |
| `/me/settings/:page` | M3 Settings | tab 4, pushed | `:page` is the settings group, e.g. `appearance` |
| `/welcome` | Onboarding | full screen | O1–O3, shown once (DK-0238): `onboardingDoneProvider` is a marker file in app support; Skip and the O3 cards set it. Tests that start the whole app override it with `test/onboarding_seen.dart` |
| `/scan` | S1 Camera | full screen | The raised Scan button pushes it; `?mode=` a scan mode (`document`, `idCard`, …) |
| `/scan/review` | S2 Review | full screen | |
| `/tool/:toolId` | T2 Tool options | full screen | `:toolId` is the tool's id (`compress`, `merge`, …); `?file=<fileId>` preselects a file |
| `/tool/:toolId/result` | T3 Result | full screen | |
| `/viewer/:fileId` | V1 Viewer | full screen | `?mode=edit` opens V2 Edit mode |
| `/organize/:fileId` | P1 Organize pages | full screen | |
| `/job/:jobId` | Home + X2 Progress | tab 1 | A notification's link: Home with the running job's progress sheet; a toast if the job has ended |
| `/dev/catalogue` | Component catalogue | full screen | Debug builds only: a list of components; each opens its variants and states in Light and Dark (`lib/catalogue/`) |

- **Full-screen routes** sit on the root navigator, above the shell: the tab
  bar is hidden, and back returns to the tab they were pushed from. That covers
  the scanner, viewer, organizer, tool shell and onboarding. The signature pad
  is a full-screen route of V2 when its task adds it.
- **Sheets aren't routes:** A1 AI panel, X1 Tool picker, X2 Progress / mini bar,
  X3 Paywall.
- **Deep links:** `dokulo://open/<route>` (Android intent filter, iOS
  `CFBundleURLTypes`). For example, `adb -s emulator-5562 shell am start -a
  android.intent.action.VIEW -d "dokulo://open/tool/compress"` or `xcrun simctl
  openurl booted "dokulo://open/viewer/f42?mode=edit"`.
  `test/routes/routes_test.dart` cold-starts the router at every route.
  A link that leads nowhere never crashes (DK-0236): an unknown route or
  tool shows `LinkErrorScreen` ("This link doesn't work any more", Go to
  Home), a file handle that's malformed or gone shows "This file isn't in
  Dokulo any more" (`LinkedFileGate`), a job that has ended a toast
  (`test/routes/deep_links_test.dart`).
  On a device, `python tools/deeplinks_check.py` fires every route from a
  cold start (all 15 passed on emulator-5554, 2026-10-08, DK-1041).
- **The privacy cover (DK-0234)** wraps the whole app (`MaterialApp.builder`,
  `DkPrivacyCover`): while locked content is open or Settings → Security →
  Hide previews is on (`privacyCoverProvider`), the app switcher shows
  `color.background` with the symbol, as the launch screen, and Android sets
  FLAG_SECURE (blank recents card, no screenshots); otherwise screenshots are
  allowed. A screen with locked-folder content wraps its body in
  `DkLockedContent`; the Security screen sets `hidePreviewsProvider`.
- **Back from a deep-linked full-screen page goes to Home** (nothing is
  beneath it, so leaving the app would be the surprise); pushed from a tab,
  it returns to that tab.
- Tapping the current tab again returns that tab to its root.
- Until a screen's task builds it, the route shows `PlaceholderScreen` with the
  screen ID. The task replaces the builder in `routes.dart`.

## 4. Theming

All colour, type, spacing, radius, elevation and motion values come from
**`DkTokens`**, a `ThemeExtension` (DK-0024, after Sogda's `DpTokens`), with a
Light and a Dark instance. The token names are those in
`Overview & foundations.md` → Design tokens and the UI spec §4–§9.

```dart
final t = context.tokens;                 // package:app_pdf/theme/dk_tokens.dart
return Container(
  padding: EdgeInsets.all(t.space.m),     // never EdgeInsets.all(12)
  decoration: BoxDecoration(
    color: t.color.surfaceRaised,         // never Color(0xFF…)
    borderRadius: BorderRadius.circular(t.radius.m),
    boxShadow: t.elevation.raised,
  ),
  child: Text(label, style: t.text.labelL),  // the spec's type.labelL
);
```

Groups: `color`, `text` (the spec's `type.*`; not `type`, which
`ThemeExtension` uses as its lookup key), `space`, `radius`, `elevation`,
`motion`. `dokuloTheme(DkTokens.light / .dark)` in `lib/theme/app_theme.dart`
builds the MaterialApp themes. No hex colours, raw font sizes or magic
numbers in widgets; `python tools/check_tokens.py` (a gate step) fails on a
raw colour in `lib/screens` or `lib/components`. A value that isn't a token
is a gap: add the token first.

Icons are `DkIcon(DkIcons.…)` (`components/dk_icon.dart`, DK-0048): Material
Symbols Rounded at the spec's five sizes (`DkIconSize.s` 16 … `xxl` 32),
outlined, `filled: true` only for the selected tab and toggled states.
`DkIcons` names every icon by purpose (`DkIcons.tool('compress')`,
`DkIcons.back(context)` switches with the platform), so a screen never names
a glyph or uses `Icons.*`. A new icon is a new `DkIcons` entry: copy its
codepoint from material_symbols_icons' `Symbols.<name>_rounded`, and keep it
a const `IconData` (the release build's tree-shaker needs that).

**iOS and Android (UI spec §13.2, DK-0231).** The components switch on
`Theme.of(context).platform`, never on `dart:io`'s `Platform`, so a test
sets `ThemeData(platform: …)`. Back, overflow, share and biometric icons come
from `DkIcons.back/overflow/share/biometrics(context)`; DkTopBar centres its
title on iOS; DkSwitch and DkLoadingSpinner are Cupertino on iOS and
Material 3 on Android; DkConfirmDialog and DkSheet look the same on both;
the push transition is the theme's (§13.4). Back is the chevron alone on
iOS, as every artboard draws it (the spec also allows the previous title).
A screen adds nothing platform-specific of its own;
`test/components/platform_differences_test.dart` holds one screen per
platform as goldens and fails on a Cupertino widget on Android or a
Material switch or spinner on iOS.

**The component catalogue (DK-0150).** Every `Dk` component shows each
variant and state in Light and Dark at `/dev/catalogue` (debug builds only;
`dokulo://open/dev/catalogue` on the emulator). A component task adds a
states widget to `lib/catalogue/` and one `CatalogueEntry` to
`lib/catalogue/catalogue.dart`, and its golden test renders that same widget,
so the catalogue shows exactly what is tested. `test/flutter_test_config.dart`
loads the icon font for every test, so goldens show the glyphs; text stays in
the test font.

Everything about a tool comes from **`ToolCatalogue.of(id)`**
(`lib/tools/tool_catalogue.dart`, DK-0049): its icon (from `DkIcons.tools`),
its fixed EN/DE name, its one-line description (UI spec §21), its tier and its
Tools-tab section. The grid, the T2 header, the X1 picker, search, About this
tool and the notifications all read it, so they never disagree. A new tool is
a new entry there, an icon in `DkIcons.tools` and two ARB strings each.

**Motion and haptics (DK-0039).** Animate with `context.motion(DkMotionKind.fast
/ standard / emphasis)`, never raw durations: it returns the spec's duration
and curve, or, when the platform's Reduce Motion is on, a 120 ms linear
cross-fade (`crossFade: true`: fade instead of moving, scaling or sliding).
Flashes (the capture flash) check `tokens.motion.flashAllowed(reduce:
context.reduceMotion)`. Haptics go through `hapticsProvider`: `selected()`,
`captured()`, `dropped()`, `saved()`; there is no error haptic on purpose.

The signature motions (UI spec §9) are ready-made in
`lib/components/motion/`; use them, don't rebuild them. Each has its Reduce
Motion variant built in:

| Motion | Use |
|---|---|
| Scan capture (DK-0040) | `DkCaptureFlash(captures:)` over the viewfinder, `flyCapturedPage(context, page:, from:, to:)`, then `DkPop(value: count)` on the badge |
| Success tick (DK-0041) | `DkSuccessTick()` and `DkCountUp(from:, to:, format:)` on result cards |
| Tile reorder (DK-0042) | `DkLift(lifted:)` on the picked tile, `DkSlot(rect:)` for every other tile in the `Stack` |
| Page drop (DK-0043) | `DkInsertionLine(length:)` where the page will land; `DkSlot` settles it |
| Sheet (DK-0044) | `DkSheetRoute.of(context, builder:)` (DkSheet's `showDkSheet` pushes it); detents with `animateDkSheetTo(context, controller, size)` |
| Mini job bar (DK-0045) | `DkJobMorph(collapsed:, sheet:, bar:)` |
| Viewer open (DK-0046) | `DkHero(tag: 'file-$id')` on the thumbnail and the viewer's first page; the viewer route uses `dkViewerPage` |

**Drag and drop (UI spec §12.2; `lib/patterns/dk_drag.dart`).** A 300 ms
press lifts (`dkLiftDelay`, not the platform's 500 ms) and a list or grid
scrolls while the finger is within 48 dp of its edge (`DkEdgeScroller`).
Files onto folders: `DkDraggable` and `DkDropTarget` (the haptics are
built in; a move offers Undo). A `ReorderableListView` takes
`buildDefaultDragHandles: false`, `DkReorderStartListener` around each
item and `proxyDecorator: dkReorderProxy`. DkPageGrid and DkPageTray use
them already.

Numbers the user compares as they change (sizes, page counts, times,
percentages) are `DkNumberText` or `t.text.numberXL`: tabular figures
(DK-0036). Surfaces take `t.surfaceAt(DkLevel.raised, radius: …)`, which is
shadows in light and a lighter surface plus an outline in dark. Borders are
`t.divider`, `t.inputRest/Focused/Error` and `t.selectionRing`, and the grid
is `DkGrid.forWidth(width)` (`theme/dk_layout.dart`, DK-0038).

**Ask or undo (UI spec §12.4, §12.6; `lib/patterns/`).** Only what can't be
undone asks first: `confirmDk(context, DkConfirmation.x)` with its EN/DE copy
(delete forever, empty trash, apply redaction, replace original, discard a
scan or edits, cancel a job running > 30 s, remove a saved signature). Every
other change happens at once and offers Undo: `showDkUndo(context, DkUndo.x,
message, onUndo: …)` (4 s; Replace original 10 s), where `onUndo` restores
the exact state before (order, folder, pages). Don't call `showDkConfirm` for
anything else.

**The keyboard (UI spec §12.7).** DkSheet and DkActionBar ride the keyboard
by themselves. A form screen wraps its Scaffold body in
`DkFormAccessory(child: …)`: while the keyboard is open, Previous field ·
Next field · Done sit on top of it (they move the focus without closing the
keyboard).

**Light, Dark, System (DK-0047; UI spec §29).** The theme follows the system
unless Settings → Appearance overrides it (`appThemeModeProvider`,
`lib/providers/theme_providers.dart`); `MaterialApp` watches it, so a change
applies to every screen at once. `dokuloTheme` also maps the tokens onto
Material's `ColorScheme`, so stock Material widgets match. The dark-mode
rules, for every screen and component:

- Golden tests in both themes for every screen state.
- Elevation in Dark is `surfaceRaised` plus an outline (`elevation.raised` has
  no shadow there).
- PDF pages stay white; only the viewer's night mode inverts them. Thumbnails
  keep a 1 dp `color.outline` and wrap the page image in
  `ColorFiltered(colorFilter: t.thumbnailFilter)` (92 % brightness in Dark).
- `DkIllustration` and the camera chrome need nothing: the illustrations
  recolour from the tokens, and the camera tokens are dark in both themes.
- Toasts use `inverseSurface` / `onInverseSurface` / `inversePrimary`.

Strings come from the ARB files (`l10n/app_en.arb`, `app_de.arb`), with keys
`screen_element_purpose` (e.g. `compress_button_run`). Tool names are the fixed
EN/DE names in `Overview & foundations.md`. German uses "du".

```dart
final l10n = AppLocalizations.of(context);   // package:app_pdf/l10n/app_localizations.dart
Text(l10n.meta_pages(12));                    // "12 pages" / "12 Seiten"
Text(formatBytes(size, l10n.localeName));     // "1.9 MB" / "1,9 MB" (l10n/formats.dart)
```

- Add a string to `app_en.arb` (with an `@key` description and typed
  placeholders) **and** to `app_de.arb` in the same change; `flutter pub get`
  regenerates `AppLocalizations` (the generated files are gitignored).
- Sizes and dates go through `formatBytes` / `formatDate`, never string
  concatenation: the unit is joined with a narrow no-break space (U+202F).
- The language follows the system unless Settings → Language overrides it
  (`appLanguageSettingProvider`, `lib/providers/language_providers.dart`);
  `MaterialApp` watches it, so a change applies to every screen at once.
- `python tools/check_l10n.py` fails on a key missing in German, a placeholder
  mismatch, or a hard-coded string in `Text(...)` or a label-like argument.
  A deliberate literal (the brand name) carries `// l10n-ignore` on its line.

## 5. Testing

| Kind | Where | What |
| --- | --- | --- |
| Unit | `packages/<p>/test/` | Logic, jobs, parsers. `dart test` in pure-Dart packages, `flutter test` in Flutter ones |
| Golden PDFs | `doc_tools`, `doc_core` | Every tool runs over the sample corpus (DK-0023); the output opens in PDFium and passes `qpdf --check`. Redaction's security test blocks every release |
| Widget + golden images | `app_pdf/test/` | Every screen and component: Light and Dark, EN and DE, phone (393 × 852) and iPhone SE (375 × 667), and 200 % text where the spec marks it (§28, §32) |
| Integration | `app_pdf/integration_test/` | Flows on `emulator-5562`, held with `team.py device` and released at once |
| Offline | per tool | A test proves the tool makes no network call |

Practicalities (from MEMORY.md):

- Wrap test batches in `timeout`. Never `taskkill /IM flutter_tester.exe`.
- Widget-test keyboard insets are physical pixels (× `devicePixelRatio`).
- After a `git stash` round trip, re-run code generation (l10n, build_runner)
  before trusting goldens.
- After `adb install`, check `dumpsys package <id> | grep lastUpdateTime`.

## 6. Accessibility checklist

From the UI spec §28. Every screen, every PR:

- [ ] Contrast: 4.5:1 for text; 3:1 for large text, meaningful icons, input borders and focus rings. Checked in Light, Dark and on the camera chrome.
- [ ] Never colour alone: Pro says "Pro", errors have an icon and text, selection has a check, compare and redaction categories have labels.
- [ ] Touch targets ≥ 48 × 48 dp (crop handles: a 44+ invisible hit area plus the magnifier).
- [ ] Works at 200 % text: no clipping, grids drop to 2 columns, buttons wrap (≤ 2 lines).
- [ ] A visible 2 dp focus ring on every interactive element (keyboard, switch access).
- [ ] Reduced motion: every signature motion has a cross-fade version; no flashing above 3 Hz; no capture flash.
- [ ] Screen readers: every icon-only button has a label; complex screens (viewer, scanner, result) set the reading order; the scanner speaks its hints and "Page 3 captured".
- [ ] Page numbers are text under thumbnails; error text sits next to its field.

## 7. Definition of done (per screen)

A screen or component is done when all of these hold. The same list is the PR
template's checklist (`.github/pull_request_template.md`).

- [ ] **Tokens only:** no hex colours, raw sizes or magic numbers.
- [ ] **Light and Dark** both match the artboards (`dokulo-design/light/…`, `dark/…`).
- [ ] **EN and DE:** every string from the ARB files; German checked for wrapping (`dokulo-design/deutsch/…`).
- [ ] **200 % text** where the spec marks it, without clipping.
- [ ] **Screen-reader labels** and reading order (checklist above).
- [ ] **States:** empty, loading, error, success and Pro-gated, as the screen spec lists them. Loading is a
      `DkSkeleton` (its presets, V1's `ViewerPageSkeleton`), never a blank screen; a spinner only inside a
      button or for a wait under 2 s in a sheet; thumbnails fade in (`DkThumbFade`) (UI spec §26.2).
- [ ] **Tests:** widget tests and goldens for the states above; unit tests for the logic; golden PDFs for a tool.
- [ ] **The basic check** passes (`CLAUDE.md`).
- [ ] **Docs:** a behaviour change updates the spec in the same PR; a spec gap you filled is named in the PR.
