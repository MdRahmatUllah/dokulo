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
      providers/        Riverpod providers that aren't private to one screen
      routes/           the go_router config and route names
      l10n/             app_en.arb, app_de.arb (DK-0009)
    test/               mirrors lib/; goldens next to their tests in goldens/
  doc_tools/            layer 2: one ToolJob per feature (pure Dart)
  doc_core/             layer 3: PDFs: open, render, page ops, text, image pipeline
  doc_vision/           layer 3: scanner, OCR engines, layout, photo finder
  ai_core/              layer 4: models, LLM arbiter, translation, retrieval
tools/                  team.py, check_layers.py, licence_scan.py, … (Python, stdlib only)
docs/                   the specs; docs/compliance/ for licence and policy records
```

Rules:

- **Dependencies point one way:** `app_pdf → doc_tools → doc_core / doc_vision → ai_core`.
  `python tools/check_layers.py` fails on anything else.
- **The UI isolate never calls native code.** PDFium calls go through the one
  PDFium worker isolate; qpdf, OpenCV and ONNX run on their own isolates
  (DK-0007). A screen talks to a provider, the provider to a `ToolJob` or a
  `doc_core` service.
  - The `IsolatePool` (`ai_core`, the bottom layer, so every layer can reach it)
    runs it: `pool.run(Lane.pdfium, body, input)` gives a `Job` with
    `progress`, `result` and `cancel()`. `Lane.pdfium` is one long-lived
    isolate, one job at a time; `Lane.qpdf`, `Lane.opencv` and `Lane.onnx`
    start a fresh isolate per job.
  - A body is a top-level function `(input, JobContext context)`; its input and
    result must be sendable. Scratch files go in `context.tempDir`, which is
    deleted when the job ends; outputs go where the input says.
  - Cancelling kills a job on its own isolate at once. A PDFium job stops at its
    next `await context.checkCancelled()`, so keep native chunks well under a
    second (a cancel must stop native work within 1 s).
  - Every native binding calls `assertWorkerIsolate()` before its first native
    call; in debug builds it fails on any isolate the pool did not start.
- **Files are never written in place.** A job reads the input and writes a new
  file; the user saves, shares or discards it.
- **No network during a tool run** (DK-0012). The only network uses are model
  downloads, Web page to PDF, and purchases.
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

`go_router` 18 with `StatefulShellRoute.indexedStack`, so each tab keeps its
scroll position and its pushed pages (DK-0004). The code is
`app_pdf/lib/routes/routes.dart`: `Routes` holds every path, `buildRouter()`
the tree, and `appRouterProvider` the app's router (kept alive). Build paths
with `Routes`, never by hand: `context.push(Routes.tool('compress'))`.

| Route | Screen | Where | Notes |
| --- | --- | --- | --- |
| `/home` | H1 Home | tab 1 | The start route |
| `/tools` | T1 Tools | tab 2 | |
| `/files` | F1 Files | tab 3 | |
| `/files/locked` | F2 Locked folder | tab 3, pushed | Behind biometrics (its task adds the guard) |
| `/me` | M1 Me | tab 4 | |
| `/me/models` | M2 Model manager | tab 4, pushed | |
| `/me/settings/:page` | M3 Settings | tab 4, pushed | `:page` is the settings group, e.g. `appearance` |
| `/welcome` | Onboarding | full screen | Shown once |
| `/scan` | S1 Camera | full screen | The raised Scan button pushes it |
| `/scan/review` | S2 Review | full screen | |
| `/tool/:toolId` | T2 Tool options | full screen | `:toolId` is the tool's id (`compress`, `merge`, …) |
| `/tool/:toolId/result` | T3 Result | full screen | |
| `/viewer/:fileId` | V1 Viewer | full screen | `?mode=edit` opens V2 Edit mode |
| `/organize/:fileId` | P1 Organize pages | full screen | |

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
- Tapping the current tab again returns that tab to its root.
- Until a screen's task builds it, the route shows `PlaceholderScreen` with the
  screen ID. The task replaces the builder in `routes.dart`.

## 4. Theming

All colour, type, spacing, radius, elevation and motion values come from
**`DkTokens`**, a `ThemeExtension` (DK-0024, after Sogda's `DpTokens`), with a
Light and a Dark instance. The token names are those in
`Overview & foundations.md` → Design tokens and the UI spec §4–§9.

```dart
final t = Theme.of(context).extension<DkTokens>()!;
return Container(
  padding: EdgeInsets.all(t.spaceM),   // never EdgeInsets.all(16)
  decoration: BoxDecoration(
    color: t.surfaceRaised,            // never Color(0xFF…)
    borderRadius: BorderRadius.circular(t.radiusM),
  ),
  child: Text(label, style: t.typeLabelL),
);
```

DK-0024 may add a shorthand (for example `context.tokens`); when it does,
update this example the same day. No hex colours, raw font sizes or magic
numbers in widgets. A value that isn't a token is a gap: add the token first.

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
- [ ] **States:** empty, loading, error, success and Pro-gated, as the screen spec lists them.
- [ ] **Tests:** widget tests and goldens for the states above; unit tests for the logic; golden PDFs for a tool.
- [ ] **The basic check** passes (`CLAUDE.md`).
- [ ] **Docs:** a behaviour change updates the spec in the same PR; a spec gap you filled is named in the PR.
