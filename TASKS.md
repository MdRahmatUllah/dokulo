# Tasks

The task file: every task of the project (DK-NNNN), who has it, and what it
waits for; the shared locks; and, at the bottom, the handoffs: assignments,
review requests, reports and questions between agents.

**Edit it only with `python tools/team.py`** (run from your worktree). It
changes the board under a lock, commits every change to the `team` branch and
pushes it to origin as a backup. A hand edit skips the checks.

- **Status**: `open` (free) · `assigned` (reserved for the owner of the row) ·
  `in-progress` · `review` (PR open) · `done` · `needs-decision` (waits for the
  project owner: never guess these) · `later` (post-launch; `reopen` when the owner says).
- **Ready** = `open` and every task in *Blocked by* is `done`. `team.py status` lists them.
- **Ph**: the release phase (Ph1 Foundations … Ph7 Launch, Ph8 Post-launch).
- **Lane**: A agent-0 (lead) · B agent-1 · C agent-2 · Q agent-3 (SQA) · W agent-4 (website)
  · M agent-5 (marketing & media) · L later. Lanes are defaults, not fences: see PLAN.md.
- **The spec** of a planned task is its row in `dokulo-task-list.csv` on `main`; of an
  added one, `tasks/<id>.md` here. `team.py show <id>` prints either.

## Tasks

| Task | Ph | Lane | Pri | Size | Title | Status | Owner | Blocked by | PR |
|---|---|---|---|---|---|---|---|---|---|
| DK-0001 | Ph1 | A | P0 | M | Create the Flutter monorepo with the five layer packages | in-progress | agent-0 |  |  |
| DK-0002 | Ph1 | A | P0 | S | Pin Flutter 3.47+ / Dart 3.13+ and the core package versions | open |  | DK-0001 |  |
| DK-0003 | Ph1 | A | P0 | S | Set up Riverpod 3 with code generation and provider conventions | open |  | DK-0001 |  |
| DK-0004 | Ph1 | A | P0 | M | Implement go_router with StatefulShellRoute.indexedStack for the four tabs | open |  | DK-0003 |  |
| DK-0005 | Ph1 | A | P0 | L | Create the drift database: files index, recents, folders, favourites, versions, OCR text (FTS5) | open |  | DK-0001 |  |
| DK-0006 | Ph1 | A | P0 | M | Store user files in a visible app folder (iOS Files, Android Documents) | open |  | DK-0005 |  |
| DK-0007 | Ph1 | A | P0 | L | Implement the worker-isolate model (PDFium serialised on one isolate; qpdf/OpenCV/ONNX on their own) | open |  | DK-0001 |  |
| DK-0008 | Ph1 | A | P0 | L | Define the ToolJob interface, job queue and progress model in doc_tools | open |  | DK-0007 DK-0005 |  |
| DK-0009 | Ph1 | A | P0 | M | Set up flutter_localizations, intl and ARB files for EN and DE | assigned | agent-1 | DK-0001 |  |
| DK-0010 | Ph1 | A | P0 | L | Set up CI: analyze, unit/widget/golden tests, native builds, licence scan, privacy network check | open |  | DK-0001 |  |
| DK-0011 | Ph3 | A | P1 | S | Add opt-in crash reporting without any document content | open |  | DK-0001 |  |
| DK-0012 | Ph1 | A | P0 | S | Enforce "no network traffic during any tool run" and document allowed network uses | open |  | DK-0010 |  |
| DK-0013 | Ph1 | A | P0 | S | Implement device capability detection (RAM, arm64, free storage, OS version) | assigned | agent-1 | DK-0001 |  |
| DK-0014 | Ph1 | A | P1 | M | Write the Developer guide tab: structure, state, routing, theming code, testing, a11y checklist, definition of done | assigned | agent-2 | DK-0001 |  |
| DK-0015 | Ph1 | A | P0 | M | Build flavors (dev / staging / prod), bundle IDs, code signing and release configuration | open |  | DK-0001 DK-0010 |  |
| DK-0016 | Ph1 | A | P0 | S | Declare platform capabilities: iOS Info.plist usage strings (EN/DE), document types; Android manifest permissions and intent filters | assigned | agent-2 | DK-0001 |  |
| DK-0017 | Ph1 | A | P1 | S | App size budget: keep the base app small; everything optional is a download | open |  | DK-0010 |  |
| DK-0018 | Ph1 | A | P0 | S | Verify 16 KB page-size alignment for every native library (Android) | open |  | DK-0010 |  |
| DK-0019 | Ph6 | A | P1 | S | Backup rules: include user files, exclude models, caches and temp; keys device-only | open |  | DK-0006 DK-0282 DK-0545 |  |
| DK-0020 | Ph3 | A | P0 | M | Preflight checks before every job: free storage, memory guard, encryption, file type | open |  | DK-0008 DK-0013 DK-0609 |  |
| DK-0021 | Ph3 | A | P1 | S | Startup cleanup and job recovery: purge orphaned temp files, report or resume killed jobs | open |  | DK-0008 DK-0006 |  |
| DK-0022 | Ph3 | A | P1 | S | Local tool-usage tracking (never uploaded) for suggestions and shortcuts | open |  | DK-0005 |  |
| DK-0023 | Ph1 | A | P0 | S | Create the fictional sample-document set for demos, tests and store screenshots | assigned | agent-2 | DK-0001 |  |
| DK-0024 | Ph1 | B | P0 | M | Create the DkTokens ThemeExtension (Sogda DpTokens architecture) with light and dark sets | open |  | DK-0001 DK-0708 |  |
| DK-0025 | Ph1 | B | P0 | S | Implement colour tokens: primary family | open |  | DK-0024 |  |
| DK-0026 | Ph1 | B | P0 | S | Implement colour tokens: surfaces and background | open |  | DK-0024 |  |
| DK-0027 | Ph1 | B | P0 | S | Implement colour tokens: outlines | open |  | DK-0024 |  |
| DK-0028 | Ph1 | B | P0 | S | Implement colour tokens: text and icons | open |  | DK-0024 |  |
| DK-0029 | Ph1 | B | P0 | S | Implement colour tokens: status colours | open |  | DK-0024 |  |
| DK-0030 | Ph1 | B | P0 | S | Implement colour tokens: overlay and camera colours | open |  | DK-0024 |  |
| DK-0031 | Ph1 | B | P0 | S | Implement colour tokens: document colours | open |  | DK-0024 |  |
| DK-0032 | Ph1 | B | P0 | S | Implement colour tokens: markup colours | open |  | DK-0024 |  |
| DK-0033 | Ph1 | B | P0 | S | Implement colour tokens: compare colours | open |  | DK-0024 |  |
| DK-0034 | Ph1 | B | P0 | S | Implement colour tokens: state overlays | open |  | DK-0024 |  |
| DK-0035 | Ph1 | Q | P0 | S | Run and document the contrast audit for every token pair (light, dark, camera chrome) | open |  | DK-0024 |  |
| DK-0036 | Ph1 | B | P0 | S | Implement the 11 typography tokens with system fonts (SF Pro / Roboto) | open |  | DK-0024 |  |
| DK-0037 | Ph1 | B | P0 | S | Implement text rules: middle truncation for file names, 70-char line length, German wrapping, 200 % scaling | open |  | DK-0036 |  |
| DK-0038 | Ph1 | B | P0 | S | Implement spacing, radius, elevation and border tokens | open |  | DK-0024 |  |
| DK-0039 | Ph1 | B | P0 | S | Implement motion tokens, reduce-motion handling and the haptics service | open |  | DK-0024 |  |
| DK-0040 | Ph3 | B | P1 | S | Build signature motion: Scan capture | open |  | DK-0039 |  |
| DK-0041 | Ph3 | B | P1 | S | Build signature motion: Success tick | open |  | DK-0039 |  |
| DK-0042 | Ph3 | B | P1 | S | Build signature motion: Tile reorder | open |  | DK-0039 |  |
| DK-0043 | Ph3 | B | P1 | S | Build signature motion: Page drop in grid | open |  | DK-0039 |  |
| DK-0044 | Ph3 | B | P1 | S | Build signature motion: Sheet | open |  | DK-0039 |  |
| DK-0045 | Ph3 | B | P1 | S | Build signature motion: Mini job bar | open |  | DK-0039 |  |
| DK-0046 | Ph3 | B | P2 | S | Build signature motion: Viewer open | open |  | DK-0039 |  |
| DK-0047 | Ph1 | B | P0 | M | Theme switching: Light, Dark, System (default), and dark-mode rules | open |  | DK-0024 |  |
| DK-0048 | Ph1 | B | P0 | S | Integrate Material Symbols Rounded (material_symbols_icons) with size tokens | open |  | DK-0024 |  |
| DK-0049 | Ph1 | B | P0 | S | Create the tool icon registry: one icon per tool used everywhere | open |  | DK-0048 |  |
| DK-0050 | Ph3 | B | P1 | XS | Ship ILL-01 illustration (Onboarding 1) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0051 | Ph3 | B | P1 | XS | Ship ILL-02 illustration (Onboarding 2) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0052 | Ph3 | B | P1 | XS | Ship ILL-03 illustration (Onboarding 3) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0053 | Ph3 | B | P1 | XS | Ship ILL-04 illustration (Home empty) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0054 | Ph1 | B | P1 | XS | Ship ILL-05 illustration (Files empty) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0055 | Ph1 | B | P1 | XS | Ship ILL-06 illustration (Folder empty) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0056 | Ph3 | B | P1 | XS | Ship ILL-07 illustration (Search no results) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0057 | Ph1 | B | P1 | XS | Ship ILL-08 illustration (Trash empty) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0058 | Ph3 | B | P1 | XS | Ship ILL-09 illustration (Locked folder intro) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0059 | Ph2 | B | P1 | XS | Ship ILL-10 illustration (Camera permission denied) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0060 | Ph3 | B | P1 | XS | Ship ILL-11 illustration (AI model needed) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0061 | Ph3 | B | P1 | XS | Ship ILL-12 illustration (AI first-use notice) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0062 | Ph3 | B | P1 | XS | Ship ILL-13 illustration (Device not eligible for AI) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0063 | Ph3 | B | P1 | XS | Ship ILL-14 illustration (Damaged file) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0064 | Ph3 | B | P1 | XS | Ship ILL-15 illustration (No signatures yet) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0065 | Ph3 | B | P1 | XS | Ship ILL-16 illustration (No workflows yet) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0066 | Ph3 | B | P1 | XS | Ship ILL-17 illustration (Find documents in photos intro) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0067 | Ph3 | B | P1 | XS | Ship ILL-18 illustration (Paywall header) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0068 | Ph3 | B | P1 | XS | Ship ILL-19 illustration (Offline (Web to PDF only)) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0069 | Ph3 | B | P1 | XS | Ship ILL-20 illustration (Generic error) as light and dark vector assets | open |  | DK-0024 |  |
| DK-0070 | Ph1 | B | P1 | S | Integrate the Dokulo symbol, wordmark and lockups (monochrome, minimum sizes, clear space) | open |  | DK-0024 DK-1008 |  |
| DK-0071 | Ph7 | B | P0 | S | Produce and integrate app icons for iOS (light/dark/tinted) and Android (adaptive + themed) | open |  | DK-0070 DK-1013 |  |
| DK-0072 | Ph3 | B | P1 | XS | Android notification small icon (white silhouette 24 dp) | open |  | DK-0070 |  |
| DK-0073 | Ph1 | B | P1 | S | Native splash/launch screens matching the in-app launch screen | open |  | DK-0070 |  |
| DK-0074 | Ph1 | B | P0 | M | Build DkButton with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0075 | Ph1 | B | P1 | S | Golden + accessibility tests for DkButton | open |  | DK-0074 |  |
| DK-0076 | Ph1 | B | P0 | S | Build DkIconButton with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0077 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkIconButton | open |  | DK-0076 |  |
| DK-0078 | Ph1 | B | P0 | S | Build DkScanButton with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0079 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkScanButton | open |  | DK-0078 |  |
| DK-0080 | Ph2 | B | P0 | S | Build DkShutterButton with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0081 | Ph2 | B | P1 | XS | Golden + accessibility tests for DkShutterButton | open |  | DK-0080 |  |
| DK-0082 | Ph1 | B | P0 | S | Build DkToolTile with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0102 DK-0048 |  |
| DK-0083 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkToolTile | open |  | DK-0082 |  |
| DK-0084 | Ph1 | B | P0 | XS | Build DkToolRow with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0102 DK-0048 |  |
| DK-0085 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkToolRow | open |  | DK-0084 |  |
| DK-0086 | Ph1 | B | P0 | M | Build DkFileCard with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0150 DK-0048 |  |
| DK-0087 | Ph1 | B | P1 | S | Golden + accessibility tests for DkFileCard | open |  | DK-0086 |  |
| DK-0088 | Ph1 | B | P0 | S | Build DkFolderCard with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0089 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkFolderCard | open |  | DK-0088 |  |
| DK-0090 | Ph3 | B | P0 | M | Build DkResultCard with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0130 DK-0048 |  |
| DK-0091 | Ph3 | B | P1 | S | Golden + accessibility tests for DkResultCard | open |  | DK-0090 |  |
| DK-0092 | Ph2 | B | P0 | S | Build DkLevelCard with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0093 | Ph3 | B | P1 | XS | Golden + accessibility tests for DkLevelCard | open |  | DK-0092 |  |
| DK-0094 | Ph6 | B | P1 | M | Build DkModelCard with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0074 DK-0048 |  |
| DK-0095 | Ph6 | B | P1 | S | Golden + accessibility tests for DkModelCard | open |  | DK-0094 |  |
| DK-0096 | Ph1 | B | P0 | S | Build DkContinueCard with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0074 DK-0048 |  |
| DK-0097 | Ph3 | B | P1 | XS | Golden + accessibility tests for DkContinueCard | open |  | DK-0096 |  |
| DK-0098 | Ph1 | B | P1 | XS | Build DkProCard with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0074 DK-0102 DK-0048 |  |
| DK-0099 | Ph7 | B | P1 | XS | Golden + accessibility tests for DkProCard | open |  | DK-0098 |  |
| DK-0100 | Ph1 | B | P0 | S | Build DkSettingsRow with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0101 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkSettingsRow | open |  | DK-0100 |  |
| DK-0102 | Ph1 | B | P0 | XS | Build DkProBadge with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0103 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkProBadge | open |  | DK-0102 |  |
| DK-0104 | Ph1 | B | P0 | S | Build DkChip with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0105 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkChip | open |  | DK-0104 |  |
| DK-0106 | Ph3 | B | P0 | XS | Build DkNextChip with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0107 | Ph3 | B | P1 | XS | Golden + accessibility tests for DkNextChip | open |  | DK-0106 |  |
| DK-0108 | Ph4 | B | P1 | XS | Build DkPageChip with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0109 | Ph6 | B | P1 | XS | Golden + accessibility tests for DkPageChip | open |  | DK-0108 |  |
| DK-0110 | Ph1 | B | P0 | XS | Build DkPrivacyLine with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0111 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkPrivacyLine | open |  | DK-0110 |  |
| DK-0112 | Ph1 | B | P0 | XS | Build DkStatusDot with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0113 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkStatusDot | open |  | DK-0112 |  |
| DK-0114 | Ph2 | B | P0 | XS | Build DkCountBadge with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0115 | Ph2 | B | P1 | XS | Golden + accessibility tests for DkCountBadge | open |  | DK-0114 |  |
| DK-0116 | Ph2 | B | P0 | XS | Build DkHintPill with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0117 | Ph2 | B | P1 | XS | Golden + accessibility tests for DkHintPill | open |  | DK-0116 |  |
| DK-0118 | Ph1 | B | P0 | XS | Build DkPagePill with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0119 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkPagePill | open |  | DK-0118 |  |
| DK-0120 | Ph1 | B | P0 | S | Build DkTextField with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0121 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkTextField | open |  | DK-0120 |  |
| DK-0122 | Ph3 | B | P1 | S | Build DkPasswordField with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0120 DK-0048 |  |
| DK-0123 | Ph4 | B | P1 | XS | Golden + accessibility tests for DkPasswordField | open |  | DK-0122 |  |
| DK-0124 | Ph3 | B | P0 | S | Build DkRangeField with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0120 DK-0048 |  |
| DK-0125 | Ph3 | B | P1 | XS | Golden + accessibility tests for DkRangeField | open |  | DK-0124 |  |
| DK-0126 | Ph1 | B | P0 | XS | Build DkSearchField with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0127 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkSearchField | open |  | DK-0126 |  |
| DK-0128 | Ph1 | B | P0 | XS | Build DkSwitch with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0129 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkSwitch | open |  | DK-0128 |  |
| DK-0130 | Ph1 | B | P0 | S | Build DkSegmented with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0131 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkSegmented | open |  | DK-0130 |  |
| DK-0132 | Ph3 | B | P0 | XS | Build DkSlider with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0133 | Ph3 | B | P1 | XS | Golden + accessibility tests for DkSlider | open |  | DK-0132 |  |
| DK-0134 | Ph3 | B | P0 | XS | Build DkStepper with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0135 | Ph3 | B | P1 | XS | Golden + accessibility tests for DkStepper | open |  | DK-0134 |  |
| DK-0136 | Ph3 | B | P0 | S | Build DkDropdown with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0120 DK-0182 DK-0048 |  |
| DK-0137 | Ph3 | B | P1 | XS | Golden + accessibility tests for DkDropdown | open |  | DK-0136 |  |
| DK-0138 | Ph3 | B | P0 | S | Build DkOptionRow with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0128 DK-0048 |  |
| DK-0139 | Ph3 | B | P1 | XS | Golden + accessibility tests for DkOptionRow | open |  | DK-0138 |  |
| DK-0140 | Ph3 | B | P0 | S | Build DkPositionPicker with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0141 | Ph3 | B | P1 | XS | Golden + accessibility tests for DkPositionPicker | open |  | DK-0140 |  |
| DK-0142 | Ph4 | B | P1 | S | Build DkColorRow with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0143 | Ph4 | B | P1 | XS | Golden + accessibility tests for DkColorRow | open |  | DK-0142 |  |
| DK-0144 | Ph1 | B | P0 | XS | Build DkCheckboxRow with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0145 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkCheckboxRow | open |  | DK-0144 |  |
| DK-0146 | Ph1 | B | P0 | XS | Build DkRadioRow with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0147 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkRadioRow | open |  | DK-0146 |  |
| DK-0148 | Ph4 | B | P1 | M | Build DkPinPad with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0149 | Ph4 | B | P1 | S | Golden + accessibility tests for DkPinPad | open |  | DK-0148 |  |
| DK-0150 | Ph1 | B | P0 | M | Build DkPageThumb with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0390 DK-0048 |  |
| DK-0151 | Ph1 | B | P1 | S | Golden + accessibility tests for DkPageThumb | open |  | DK-0150 |  |
| DK-0152 | Ph2 | B | P0 | M | Build DkPageTray with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0150 DK-0048 |  |
| DK-0153 | Ph2 | B | P1 | S | Golden + accessibility tests for DkPageTray | open |  | DK-0152 |  |
| DK-0154 | Ph3 | B | P0 | L | Build DkPageGrid with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0150 DK-0048 |  |
| DK-0155 | Ph3 | B | P1 | S | Golden + accessibility tests for DkPageGrid | open |  | DK-0154 |  |
| DK-0156 | Ph2 | B | P0 | L | Build DkCropOverlay with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0074 DK-0048 |  |
| DK-0157 | Ph2 | B | P1 | S | Golden + accessibility tests for DkCropOverlay | open |  | DK-0156 |  |
| DK-0158 | Ph2 | B | P0 | M | Build DkMagnifier with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0159 | Ph2 | B | P1 | S | Golden + accessibility tests for DkMagnifier | open |  | DK-0158 |  |
| DK-0160 | Ph4 | B | P1 | M | Build DkRedactionBox with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0161 | Ph4 | B | P1 | S | Golden + accessibility tests for DkRedactionBox | open |  | DK-0160 |  |
| DK-0162 | Ph4 | B | P1 | S | Build DkSignatureStamp with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0163 | Ph4 | B | P1 | XS | Golden + accessibility tests for DkSignatureStamp | open |  | DK-0162 |  |
| DK-0164 | Ph1 | B | P0 | M | Build DkTopBar with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0076 DK-0048 |  |
| DK-0165 | Ph1 | B | P1 | S | Golden + accessibility tests for DkTopBar | open |  | DK-0164 |  |
| DK-0166 | Ph1 | B | P0 | S | Build DkTabBar with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0078 DK-0048 |  |
| DK-0167 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkTabBar | open |  | DK-0166 |  |
| DK-0168 | Ph1 | B | P0 | S | Build DkNavRail with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0078 DK-0048 |  |
| DK-0169 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkNavRail | open |  | DK-0168 |  |
| DK-0170 | Ph1 | B | P0 | S | Build DkActionBar with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0074 DK-0048 |  |
| DK-0171 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkActionBar | open |  | DK-0170 |  |
| DK-0172 | Ph1 | B | P0 | S | Build DkSelectionBar with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0076 DK-0048 |  |
| DK-0173 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkSelectionBar | open |  | DK-0172 |  |
| DK-0174 | Ph3 | B | P0 | M | Build DkMiniJobBar with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0112 DK-0048 |  |
| DK-0175 | Ph3 | B | P1 | S | Golden + accessibility tests for DkMiniJobBar | open |  | DK-0174 |  |
| DK-0176 | Ph4 | B | P1 | M | Build DkToolStrip with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0076 DK-0048 |  |
| DK-0177 | Ph4 | B | P1 | S | Golden + accessibility tests for DkToolStrip | open |  | DK-0176 |  |
| DK-0178 | Ph1 | B | P0 | S | Build DkViewerBar with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0076 DK-0048 |  |
| DK-0179 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkViewerBar | open |  | DK-0178 |  |
| DK-0180 | Ph2 | B | P0 | S | Build DkCameraTopBar with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0076 DK-0048 |  |
| DK-0181 | Ph2 | B | P1 | XS | Golden + accessibility tests for DkCameraTopBar | open |  | DK-0180 |  |
| DK-0182 | Ph1 | B | P0 | M | Build DkSheet with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0183 | Ph1 | B | P1 | S | Golden + accessibility tests for DkSheet | open |  | DK-0182 |  |
| DK-0184 | Ph1 | B | P0 | S | Build DkActionSheet with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0182 DK-0048 |  |
| DK-0185 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkActionSheet | open |  | DK-0184 |  |
| DK-0186 | Ph1 | B | P0 | S | Build DkConfirmDialog with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0074 DK-0048 |  |
| DK-0187 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkConfirmDialog | open |  | DK-0186 |  |
| DK-0188 | Ph1 | B | P0 | S | Build DkMenu with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0189 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkMenu | open |  | DK-0188 |  |
| DK-0190 | Ph1 | B | P0 | S | Build DkToast with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0191 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkToast | open |  | DK-0190 |  |
| DK-0192 | Ph1 | B | P0 | S | Build DkBanner with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0074 DK-0048 |  |
| DK-0193 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkBanner | open |  | DK-0192 |  |
| DK-0194 | Ph3 | B | P0 | M | Build DkProgressSheet with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0182 DK-0074 DK-0048 DK-0069 |  |
| DK-0195 | Ph3 | B | P1 | S | Golden + accessibility tests for DkProgressSheet | open |  | DK-0194 |  |
| DK-0196 | Ph1 | B | P0 | S | Build DkEmptyState with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0074 DK-0048 |  |
| DK-0197 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkEmptyState | open |  | DK-0196 |  |
| DK-0198 | Ph1 | B | P0 | XS | Build DkSkeleton with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0199 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkSkeleton | open |  | DK-0198 |  |
| DK-0200 | Ph1 | B | P0 | XS | Build DkLoadingSpinner with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0201 | Ph1 | B | P1 | XS | Golden + accessibility tests for DkLoadingSpinner | open |  | DK-0200 |  |
| DK-0202 | Ph4 | B | P1 | S | Build DkMarkupBar with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0076 DK-0048 |  |
| DK-0203 | Ph4 | B | P1 | XS | Golden + accessibility tests for DkMarkupBar | open |  | DK-0202 |  |
| DK-0204 | Ph4 | B | P1 | M | Build DkToolOptionsSheet with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0182 DK-0142 DK-0132 DK-0130 DK-0134 DK-0048 |  |
| DK-0205 | Ph4 | B | P1 | S | Golden + accessibility tests for DkToolOptionsSheet | open |  | DK-0204 |  |
| DK-0206 | Ph4 | B | P1 | L | Build DkSignaturePad with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0130 DK-0074 DK-0048 |  |
| DK-0207 | Ph4 | B | P1 | S | Golden + accessibility tests for DkSignaturePad | open |  | DK-0206 |  |
| DK-0208 | Ph4 | B | P1 | XS | Build DkSignatureCard with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0209 | Ph4 | B | P1 | XS | Golden + accessibility tests for DkSignatureCard | open |  | DK-0208 |  |
| DK-0210 | Ph6 | B | P1 | S | Build DkChatBubble with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0108 DK-0048 |  |
| DK-0211 | Ph6 | B | P1 | XS | Golden + accessibility tests for DkChatBubble | open |  | DK-0210 |  |
| DK-0212 | Ph6 | B | P1 | XS | Build DkSuggestionChip with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0213 | Ph6 | B | P1 | XS | Golden + accessibility tests for DkSuggestionChip | open |  | DK-0212 |  |
| DK-0214 | Ph6 | B | P1 | XS | Build DkAIFooter with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0215 | Ph6 | B | P1 | XS | Golden + accessibility tests for DkAIFooter | open |  | DK-0214 |  |
| DK-0216 | Ph3 | B | P0 | S | Build DkSplitMarker with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0048 |  |
| DK-0217 | Ph3 | B | P1 | XS | Golden + accessibility tests for DkSplitMarker | open |  | DK-0216 |  |
| DK-0218 | Ph4 | B | P1 | S | Build DkDiffRow with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0108 DK-0048 |  |
| DK-0219 | Ph4 | B | P1 | XS | Golden + accessibility tests for DkDiffRow | open |  | DK-0218 |  |
| DK-0220 | Ph4 | B | P1 | M | Build DkDetectionGroup with all variants and states | open |  | DK-0024 DK-0036 DK-0038 DK-0144 DK-0108 DK-0048 |  |
| DK-0221 | Ph4 | B | P1 | S | Golden + accessibility tests for DkDetectionGroup | open |  | DK-0220 |  |
| DK-0222 | Ph1 | B | P0 | M | Implement the selection mode pattern as a reusable behaviour | open |  | DK-0172 DK-0086 |  |
| DK-0223 | Ph3 | B | P0 | M | Implement the drag and drop pattern as a reusable behaviour | open |  | DK-0154 DK-0190 |  |
| DK-0224 | Ph1 | B | P0 | M | Implement the swipe actions pattern as a reusable behaviour | open |  | DK-0086 DK-0190 |  |
| DK-0225 | Ph1 | B | P0 | M | Implement the confirmations pattern as a reusable behaviour | open |  | DK-0186 |  |
| DK-0226 | Ph1 | B | P0 | M | Implement the undo pattern as a reusable behaviour | open |  | DK-0190 |  |
| DK-0227 | Ph1 | B | P0 | M | Implement the keyboard pattern as a reusable behaviour | open |  | DK-0170 DK-0182 |  |
| DK-0228 | Ph3 | B | P0 | M | Implement the pull to refresh pattern as a reusable behaviour | open |  | DK-0200 |  |
| DK-0229 | Ph1 | A | P0 | M | Build the app shell: 4 tabs + raised centre Scan button | open |  | DK-0004 DK-0166 DK-0078 |  |
| DK-0230 | Ph2 | A | P2 | S | Long-press on the Scan button opens the scan-mode popover | open |  | DK-0229 DK-0188 DK-0078 |  |
| DK-0231 | Ph1 | A | P1 | S | Implement iOS vs Android shell differences | open |  | DK-0229 DK-0164 DK-0128 DK-0182 DK-0186 |  |
| DK-0232 | Ph1 | A | P1 | S | Tablet (≥ 840 dp): replace tab bar with DkNavRail | open |  | DK-0229 DK-0168 |  |
| DK-0233 | Ph3 | A | P0 | M | Global overlay host: mini job bar and toast queue above any screen | open |  | DK-0229 DK-0174 DK-0190 DK-0008 |  |
| DK-0234 | Ph6 | A | P0 | S | Show a privacy cover in the app switcher when locked content is open or "Hide previews" is on | open |  | DK-0229 DK-0070 |  |
| DK-0235 | Ph1 | A | P0 | L | Receive files from the share sheet / "Open with" (receive_sharing_intent 1.9.0) | open |  | DK-0004 DK-0006 DK-0016 |  |
| DK-0236 | Ph3 | A | P1 | S | Deep-link scheme for widgets, shortcuts, notifications and extensions | open |  | DK-0004 |  |
| DK-0237 | Ph3 | A | P2 | S | Implement route transitions per spec | open |  | DK-0004 DK-0039 |  |
| DK-0238 | Ph7 | B | P0 | M | Build the onboarding pager (/welcome) shown once, skippable | open |  | DK-0004 DK-0074 |  |
| DK-0239 | Ph7 | B | P0 | S | O1 Onboarding: implement the "content" state | open |  | DK-0238 DK-0050 |  |
| DK-0240 | Ph7 | B | P0 | S | O2 Onboarding: implement the "content" state | open |  | DK-0238 DK-0051 |  |
| DK-0241 | Ph7 | B | P0 | S | O3 Onboarding: implement the "start-with cards" state | open |  | DK-0238 |  |
| DK-0242 | Ph1 | B | P0 | L | Build H1 Home layout (regions 1–10) | open |  | DK-0229 DK-0082 DK-0086 DK-0110 DK-0005 DK-0164 DK-0166 DK-0096 DK-0098 DK-0074 |  |
| DK-0243 | Ph1 | B | P0 | M | Recent files data: last 20 opened or created files with swipe quick actions | open |  | DK-0242 DK-0005 DK-0224 DK-0086 |  |
| DK-0244 | Ph3 | B | P0 | S | Pinned tools: default 8, persisted order, tap → T2, long-press menu | open |  | DK-0242 DK-0049 DK-0082 DK-0188 DK-0702 |  |
| DK-0245 | Ph3 | B | P0 | S | H1 Home: implement the "First launch" state | open |  | DK-0242 DK-0053 |  |
| DK-0246 | Ph3 | B | P0 | S | H1 Home: implement the "Continue: unsaved scan" state | open |  | DK-0242 DK-0096 |  |
| DK-0247 | Ph3 | B | P0 | S | H1 Home: implement the "Continue: job finished" state | open |  | DK-0242 DK-0096 |  |
| DK-0248 | Ph3 | B | P0 | S | H1 Home: implement the "Edit pinned tools" state | open |  | DK-0242 |  |
| DK-0249 | Ph3 | B | P0 | S | H1 Home: implement the "Add-tool sheet" state | open |  | DK-0242 DK-0182 DK-0084 |  |
| DK-0250 | Ph3 | B | P0 | S | H1 Home: implement the "Job running" state | open |  | DK-0242 DK-0174 |  |
| DK-0251 | Ph7 | B | P0 | S | H1 Home: implement the "Pro card visible" state | open |  | DK-0242 DK-0098 |  |
| DK-0252 | Ph3 | B | P0 | S | H1 Home: implement the "Find documents banner" state | open |  | DK-0242 DK-0192 |  |
| DK-0253 | Ph7 | B | P0 | S | H1 Home: implement the "Rating prompt" state | open |  | DK-0242 |  |
| DK-0254 | Ph7 | B | P1 | S | H1 at 200 % text and screen-reader order | open |  | DK-0242 |  |
| DK-0255 | Ph3 | B | P2 | M | Quick drop: pick, paste or drag files straight into a tool | open |  | DK-0242 DK-0387 |  |
| DK-0256 | Ph1 | B | P0 | M | Build T1 Tools: large title, search, category chips, sectioned 4-column grid | open |  | DK-0229 DK-0049 DK-0104 DK-0082 DK-0126 DK-0164 |  |
| DK-0257 | Ph3 | B | P1 | S | Tool search with synonyms (EN + DE) and result rows | open |  | DK-0256 DK-0084 |  |
| DK-0258 | Ph3 | B | P0 | S | T1 Tools grid: implement the "Search empty" state | open |  | DK-0256 DK-0056 |  |
| DK-0259 | Ph3 | B | P2 | S | About this tool sheet (from tile long-press and T2 overflow) | open |  | DK-0049 DK-0182 DK-0102 |  |
| DK-0260 | Ph1 | B | P0 | L | Build F1 Files root: top bar actions, search, special rows, folders, files | open |  | DK-0229 DK-0005 DK-0006 DK-0086 DK-0088 DK-0164 DK-0172 DK-0126 |  |
| DK-0261 | Ph1 | B | P1 | S | Sort menu: date modified/name/size/date created + ascending/descending | open |  | DK-0260 DK-0188 |  |
| DK-0262 | Ph1 | B | P0 | M | Folder screen with breadcrumb and overflow (rename, colour, delete) | open |  | DK-0260 DK-0188 DK-0164 |  |
| DK-0263 | Ph3 | B | P0 | M | Files multi-select with selection bar actions | open |  | DK-0260 DK-0222 DK-0188 DK-0172 |  |
| DK-0264 | Ph3 | B | P2 | S | Grid view: drag a file onto a folder card to move it | open |  | DK-0260 DK-0223 |  |
| DK-0265 | Ph1 | B | P0 | S | F1 Files: implement the "Empty root" state | open |  | DK-0260 DK-0054 |  |
| DK-0266 | Ph1 | B | P0 | S | F1 Files: implement the "Empty folder" state | open |  | DK-0260 DK-0055 |  |
| DK-0267 | Ph1 | B | P0 | S | F1 Files: implement the "Loading" state | open |  | DK-0260 DK-0198 |  |
| DK-0268 | Ph1 | B | P0 | S | F1 Files: implement the "Swipe actions" state | open |  | DK-0260 |  |
| DK-0269 | Ph5 | B | P0 | L | Search names + OCR text + PDF text (FTS5) with grouped results | open |  | DK-0260 DK-0005 DK-0086 DK-0192 DK-0126 DK-0108 DK-0056 |  |
| DK-0270 | Ph5 | B | P0 | M | Index updater: extract PDF text and OCR text into FTS5 after every tool job | open |  | DK-0005 DK-0008 |  |
| DK-0271 | Ph3 | B | P0 | M | File action sheet (medium): header, Open/Share, suggested tools, All tools…, file actions, Delete | open |  | DK-0260 DK-0184 DK-0084 DK-0022 |  |
| DK-0272 | Ph1 | B | P0 | S | F1 Files: implement the "Rename dialog" state | open |  | DK-0260 DK-0186 DK-0182 DK-0120 |  |
| DK-0273 | Ph1 | B | P0 | S | F1 Files: implement the "New folder dialog" state | open |  | DK-0260 DK-0186 DK-0182 |  |
| DK-0274 | Ph1 | B | P0 | S | F1 Files: implement the "Move sheet" state | open |  | DK-0260 DK-0186 DK-0182 |  |
| DK-0275 | Ph1 | B | P0 | S | F1 Files: implement the "Info sheet" state | open |  | DK-0260 DK-0186 DK-0182 |  |
| DK-0276 | Ph1 | B | P0 | S | F1 Files: implement the "Duplicate" state | open |  | DK-0260 DK-0186 DK-0182 |  |
| DK-0277 | Ph3 | B | P1 | M | Version history: keep last 5 versions per file (edits, replace original) | open |  | DK-0005 |  |
| DK-0278 | Ph1 | B | P0 | M | Recently deleted (trash): 30-day retention, restore, delete for good, empty | open |  | DK-0260 DK-0186 DK-0196 DK-0192 DK-0057 |  |
| DK-0279 | Ph7 | B | P2 | M | Files two-pane on tablets: list (360) + preview pane | open |  | DK-0260 DK-0232 |  |
| DK-0280 | Ph3 | B | P2 | S | Favourites: mark files as favourite and filter by them | open |  | DK-0260 DK-0271 |  |
| DK-0281 | Ph3 | B | P2 | S | Storage info: space used by files vs AI models (file info + Me → Files & storage bar chart) | open |  | DK-0260 |  |
| DK-0282 | Ph4 | B | P0 | L | Encrypt locked files at rest with AES-256-GCM; keys in Keychain/Keystore released by biometrics/PIN | open |  | DK-0005 DK-0016 |  |
| DK-0283 | Ph6 | B | P0 | S | F2 Locked folder: implement the "L1 Intro" state | open |  | DK-0282 DK-0148 DK-0192 DK-0058 |  |
| DK-0284 | Ph6 | B | P0 | S | F2 Locked folder: implement the "L2 Create PIN" state | open |  | DK-0282 DK-0148 |  |
| DK-0285 | Ph6 | B | P0 | S | F2 Locked folder: implement the "L3 Confirm PIN" state | open |  | DK-0282 DK-0148 |  |
| DK-0286 | Ph6 | B | P0 | S | F2 Locked folder: implement the "L4 Biometrics" state | open |  | DK-0282 DK-0148 |  |
| DK-0287 | Ph6 | B | P0 | S | F2 Locked folder: implement the "Unlock screen" state | open |  | DK-0282 DK-0148 |  |
| DK-0288 | Ph6 | B | P0 | S | F2 Locked folder: implement the "Content" state | open |  | DK-0282 DK-0148 |  |
| DK-0289 | Ph6 | B | P0 | M | Move files into and out of the locked folder (encrypt/decrypt jobs) | open |  | DK-0282 DK-0260 |  |
| DK-0290 | Ph6 | B | P1 | M | Global app lock (optional): lock on resume after timeout | open |  | DK-0282 DK-0234 DK-0148 |  |
| DK-0291 | Ph6 | B | P0 | S | Security tests for the locked folder | open |  | DK-0282 |  |
| DK-0292 | Ph6 | B | P1 | S | Change locked-folder PIN (Settings → Security) | open |  | DK-0282 DK-0148 |  |
| DK-0293 | Ph1 | C | P0 | L | Viewer core with pdfrx PdfViewer: continuous scroll, pinch zoom, double-tap fit width, progressive render | open |  | DK-0004 DK-0007 |  |
| DK-0294 | Ph1 | C | P0 | M | Viewer chrome: top bar, page pill, bottom bar, auto-hide behaviour | open |  | DK-0293 DK-0178 DK-0118 DK-0164 |  |
| DK-0295 | Ph3 | C | P1 | M | Viewer overflow menu (10 items) | open |  | DK-0294 DK-0188 |  |
| DK-0296 | Ph1 | C | P0 | S | V1 Viewer: implement the "Thumbnail strip" state | open |  | DK-0293 DK-0294 DK-0150 |  |
| DK-0297 | Ph1 | C | P0 | S | V1 Viewer: implement the "Loading" state | open |  | DK-0293 DK-0294 |  |
| DK-0298 | Ph3 | C | P0 | S | V1 Viewer: implement the "Search active" state | open |  | DK-0293 DK-0294 |  |
| DK-0299 | Ph5 | C | P0 | S | V1 Viewer: implement the "Search on scan without text" state | open |  | DK-0293 DK-0294 DK-0192 |  |
| DK-0300 | Ph4 | C | P0 | S | V1 Viewer: implement the "Text selected" state | open |  | DK-0293 DK-0294 DK-0202 |  |
| DK-0301 | Ph3 | C | P0 | S | V1 Viewer: implement the "Locked PDF" state | open |  | DK-0293 DK-0294 DK-0122 |  |
| DK-0302 | Ph3 | C | P0 | S | V1 Viewer: implement the "Wrong password" state | open |  | DK-0293 DK-0294 |  |
| DK-0303 | Ph3 | C | P0 | S | V1 Viewer: implement the "After unlock" state | open |  | DK-0293 DK-0294 |  |
| DK-0304 | Ph3 | C | P0 | S | V1 Viewer: implement the "Night mode" state | open |  | DK-0293 DK-0294 |  |
| DK-0305 | Ph3 | C | P0 | S | V1 Viewer: implement the "Damaged file" state | open |  | DK-0293 DK-0294 DK-0063 |  |
| DK-0306 | Ph4 | C | P0 | S | V1 Viewer: implement the "Form detected" state | open |  | DK-0293 DK-0294 DK-0192 |  |
| DK-0307 | Ph3 | C | P0 | S | V1 Viewer: implement the "Go to page" state | open |  | DK-0293 DK-0294 |  |
| DK-0308 | Ph3 | C | P0 | S | V1 Viewer: implement the "External link dialog" state | open |  | DK-0293 DK-0294 |  |
| DK-0309 | Ph3 | C | P2 | S | Document outline (bookmarks) navigation | open |  | DK-0293 |  |
| DK-0310 | Ph7 | C | P2 | M | Tablet viewer: thumbnail sidebar (120) + pages + AI pane (400), inline actions | open |  | DK-0293 |  |
| DK-0311 | Ph3 | C | P2 | S | Viewer overflow actions: Share as images, Share text, Print | open |  | DK-0293 DK-0390 |  |
| DK-0312 | Ph4 | C | P0 | XL | Annotation editor core: tool palette, hit testing, selection, undo/redo, save as real PDF annotations | open |  | DK-0293 DK-0007 |  |
| DK-0313 | Ph4 | C | P0 | M | V2 edit-mode shell: editing top bar, tool strip, 2 dp primary canvas border | open |  | DK-0312 DK-0176 DK-0277 DK-0164 DK-0186 |  |
| DK-0314 | Ph4 | C | P0 | M | V2 Pan tool with its options sheet | open |  | DK-0313 DK-0204 DK-0132 DK-0142 DK-0176 |  |
| DK-0315 | Ph4 | C | P0 | M | V2 Pen tool with its options sheet | open |  | DK-0313 DK-0204 DK-0132 DK-0142 DK-0176 |  |
| DK-0316 | Ph4 | C | P0 | M | V2 Highlighter tool with its options sheet | open |  | DK-0313 DK-0204 DK-0132 DK-0142 DK-0176 |  |
| DK-0317 | Ph4 | C | P0 | M | V2 Text tool with its options sheet | open |  | DK-0313 DK-0204 DK-0132 DK-0142 DK-0176 |  |
| DK-0318 | Ph4 | C | P1 | M | V2 Shapes tool with its options sheet | open |  | DK-0313 DK-0204 DK-0132 DK-0142 DK-0176 |  |
| DK-0319 | Ph4 | C | P1 | M | V2 Note tool with its options sheet | open |  | DK-0313 DK-0204 DK-0132 DK-0142 DK-0176 |  |
| DK-0320 | Ph4 | C | P1 | M | V2 Eraser tool with its options sheet | open |  | DK-0313 DK-0204 DK-0132 DK-0142 DK-0176 |  |
| DK-0321 | Ph4 | C | P0 | S | Highlight / Underline / Strike from text selection | open |  | DK-0312 DK-0202 |  |
| DK-0322 | Ph4 | C | P1 | S | Selected annotation: handles + mini bar (Colour · Duplicate · Note · Delete) | open |  | DK-0312 DK-0202 |  |
| DK-0323 | Ph4 | C | P0 | L | AcroForm filling with PDFium form environment; flatten option; XFA detection | open |  | DK-0293 DK-0007 |  |
| DK-0324 | Ph4 | C | P0 | M | Form filling UI: field highlight, accessory bar, dropdown sheet, field list for long forms | open |  | DK-0323 DK-0313 DK-0227 |  |
| DK-0325 | Ph4 | C | P0 | M | Encrypted signature store (images + initials) with Me → Signatures management | open |  | DK-0282 |  |
| DK-0326 | Ph4 | C | P0 | M | Signatures sheet: grid of saved signatures, Add signature, date/initials toggles, empty state | open |  | DK-0325 DK-0208 DK-0182 DK-0064 |  |
| DK-0327 | Ph4 | C | P0 | L | Signature pad (landscape full screen): Draw / Type / Image | open |  | DK-0325 DK-0206 |  |
| DK-0328 | Ph4 | C | P0 | M | Signature placement: centred stamp, drag/resize, date stamp, "Sign here" pills | open |  | DK-0312 DK-0325 DK-0162 |  |
| DK-0329 | Ph3 | C | P0 | L | P1 Organize pages screen: top bar, sub-bar, page grid, FAB, selection bar | open |  | DK-0154 DK-0293 DK-0164 DK-0172 |  |
| DK-0330 | Ph3 | C | P0 | M | Page operations engine: move, delete, duplicate, rotate, insert blank/from file (PDFium) | open |  | DK-0007 |  |
| DK-0331 | Ph3 | C | P0 | S | P1 Organize pages: implement the "Dragging" state | open |  | DK-0329 DK-0330 |  |
| DK-0332 | Ph3 | C | P0 | S | P1 Organize pages: implement the "Insert sheet" state | open |  | DK-0329 DK-0330 |  |
| DK-0333 | Ph3 | C | P0 | S | P1 Organize pages: implement the "After delete" state | open |  | DK-0329 DK-0330 |  |
| DK-0334 | Ph3 | C | P0 | S | P1 Organize pages: implement the "Pinch to 5 columns" state | open |  | DK-0329 DK-0330 |  |
| DK-0335 | Ph3 | C | P0 | S | P1 Organize pages: implement the "300-page document" state | open |  | DK-0329 DK-0330 |  |
| DK-0336 | Ph2 | C | P0 | L | iOS scanner engine with VisionKit / Vision (VNDetectDocumentSegmentationRequest on our own camera view) | open |  | DK-0007 |  |
| DK-0337 | Ph2 | C | P0 | XL | Android doc_scanner: CameraX + OpenCV pipeline (Canny, morphology, findContours, approxPolyDP, scoring) | open |  | DK-0007 DK-0677 |  |
| DK-0338 | Ph2 | C | P0 | M | Separate auto-capture and auto-crop: stability-based capture (~0.5 s steady quad) | open |  | DK-0336 DK-0337 DK-0080 |  |
| DK-0339 | Ph2 | C | P0 | M | Image filters: Original, Auto colour (CLAHE), Greyscale, B/W (adaptive threshold), Remove shadows, brightness/contrast | open |  | DK-0007 |  |
| DK-0340 | Ph2 | C | P1 | S | ID card mode engine: crop to ID-1 (85.6 × 54 mm), front + back on one A4 at true size | open |  | DK-0336 DK-0337 |  |
| DK-0341 | Ph2 | C | P1 | M | Book mode engine: spine detection (projection profile + Hough), split into two pages, deskew each | open |  | DK-0336 DK-0337 |  |
| DK-0342 | Ph2 | C | P0 | S | Camera permission pre-prompt sheet and denied state | open |  | DK-0182 DK-0059 DK-0016 |  |
| DK-0343 | Ph2 | C | P0 | L | S1 camera UI: top bar, hint pill, viewfinder quad, mode switcher, bottom row | open |  | DK-0336 DK-0337 DK-0180 DK-0080 DK-0342 DK-0114 DK-0116 |  |
| DK-0344 | Ph2 | C | P0 | M | Hint pill logic with priority order and spoken guidance | open |  | DK-0343 |  |
| DK-0345 | Ph2 | C | P0 | S | S1 Scanner: implement the "Flash menu" state | open |  | DK-0343 |  |
| DK-0346 | Ph2 | C | P0 | S | S1 Scanner: implement the "ID card mode" state | open |  | DK-0343 |  |
| DK-0347 | Ph2 | C | P0 | S | S1 Scanner: implement the "Book mode" state | open |  | DK-0343 |  |
| DK-0348 | Ph2 | C | P0 | S | S1 Scanner: implement the "Batch mode" state | open |  | DK-0343 |  |
| DK-0349 | Ph2 | C | P0 | S | S1 Scanner: implement the "Capture feedback" state | open |  | DK-0343 |  |
| DK-0350 | Ph2 | C | P0 | S | S1 Scanner: implement the "Retake label" state | open |  | DK-0343 |  |
| DK-0351 | Ph2 | C | P0 | M | Import from photos or files with the same processing pipeline | open |  | DK-0343 |  |
| DK-0352 | Ph2 | C | P0 | L | S2 Review: top bar, large preview, edit row, context area, page tray | open |  | DK-0343 DK-0152 DK-0164 |  |
| DK-0353 | Ph2 | C | P0 | S | S2 Scanner: implement the "Crop mode" state | open |  | DK-0352 DK-0339 DK-0156 DK-0158 |  |
| DK-0354 | Ph2 | C | P0 | S | S2 Scanner: implement the "Filter mode" state | open |  | DK-0352 DK-0339 DK-0156 DK-0158 |  |
| DK-0355 | Ph2 | C | P0 | S | S2 Scanner: implement the "Apply-to-all chip" state | open |  | DK-0352 DK-0339 DK-0156 DK-0158 |  |
| DK-0356 | Ph2 | C | P0 | S | S2 Scanner: implement the "Rotate" state | open |  | DK-0352 DK-0339 DK-0156 DK-0158 |  |
| DK-0357 | Ph2 | C | P0 | S | S2 Scanner: implement the "Delete page" state | open |  | DK-0352 DK-0339 DK-0156 DK-0158 |  |
| DK-0358 | Ph2 | C | P0 | S | S2 Scanner: implement the "Discard dialog" state | open |  | DK-0352 DK-0339 DK-0156 DK-0158 |  |
| DK-0359 | Ph2 | C | P0 | M | Save sheet: name, format, page size, quality, folder, Make text searchable | open |  | DK-0352 DK-0092 DK-0120 DK-0182 DK-0102 DK-0128 DK-0130 |  |
| DK-0360 | Ph2 | C | P0 | S | Scan result screen with Next chips (Compress · Add password · Sign · Summarize · Share) | open |  | DK-0359 |  |
| DK-0361 | Ph2 | C | P1 | S | Scanning defaults: filter, crop mode, page size, file-name pattern ("Save as default") | open |  | DK-0352 |  |
| DK-0362 | Ph6 | C | P1 | L | Find documents in photos: on-device scoring (text-area ratio + quad + aspect), background, cached | open |  | DK-0007 DK-0005 DK-0016 |  |
| DK-0363 | Ph6 | C | P0 | S | Photo finder: implement the "Intro sheet" state | open |  | DK-0362 DK-0066 |  |
| DK-0364 | Ph6 | C | P0 | S | Photo finder: implement the "Scanning card" state | open |  | DK-0362 |  |
| DK-0365 | Ph6 | C | P0 | S | Photo finder: implement the "Results grid" state | open |  | DK-0362 |  |
| DK-0366 | Ph6 | C | P0 | S | Photo finder: implement the "Convert options" state | open |  | DK-0362 |  |
| DK-0367 | Ph6 | C | P0 | S | Photo finder: implement the "Not a document" state | open |  | DK-0362 |  |
| DK-0368 | Ph6 | C | P0 | S | Photo finder: implement the "Empty" state | open |  | DK-0362 |  |
| DK-0369 | Ph2 | C | P1 | S | Scanner quick settings sheet from the top-bar settings (tune) button | open |  | DK-0343 DK-0338 |  |
| DK-0370 | Ph3 | C | P0 | L | Generic T2 tool options shell (one shell for all 30 tools) | open |  | DK-0004 DK-0008 DK-0170 DK-0138 DK-0049 DK-0164 DK-0122 DK-0086 DK-0110 |  |
| DK-0371 | Ph3 | C | P0 | M | T2 empty input state: picker card with recent compatible files, Browse device, Choose photos | open |  | DK-0370 |  |
| DK-0372 | Ph3 | C | P0 | S | Inline password row for locked input files | open |  | DK-0370 DK-0122 |  |
| DK-0373 | Ph3 | C | P1 | S | Live estimate caption ("About 1.8 MB · 12 pages") | open |  | DK-0370 |  |
| DK-0374 | Ph7 | C | P0 | M | Pro gating in T2: header badge, free-try caption, paywall before run on second use | open |  | DK-0370 DK-0580 DK-0579 |  |
| DK-0375 | Ph3 | C | P0 | M | X2 progress: none < 2 s, button loading 2–10 s, progress sheet > 10 s | open |  | DK-0370 DK-0194 DK-0233 DK-0174 DK-0074 |  |
| DK-0376 | Ph3 | C | P0 | S | Cancel a running job (confirm if > 30 s done) | open |  | DK-0375 |  |
| DK-0377 | Ph3 | C | P0 | M | Job failure state inside the progress sheet with one recovery action | open |  | DK-0375 DK-0069 |  |
| DK-0378 | Ph3 | C | P1 | S | Notifications permission pre-prompt the first time a job runs > 30 s in the background | open |  | DK-0375 |  |
| DK-0379 | Ph3 | C | P0 | L | Generic T3 result: result card, preview strip, name, save location, Next chips, action bar | open |  | DK-0370 DK-0090 DK-0106 DK-0170 DK-0120 DK-0086 |  |
| DK-0380 | Ph3 | C | P0 | S | T3 result: implement the "Replace original" state | open |  | DK-0379 DK-0277 |  |
| DK-0381 | Ph3 | C | P0 | S | T3 result: implement the "After save" state | open |  | DK-0379 |  |
| DK-0382 | Ph3 | C | P0 | S | T3 result: implement the "Discard result" state | open |  | DK-0379 |  |
| DK-0383 | Ph3 | C | P0 | S | T3 result: implement the "Partial success" state | open |  | DK-0379 |  |
| DK-0384 | Ph3 | C | P0 | S | T3 result: implement the "Multi-file result" state | open |  | DK-0379 |  |
| DK-0385 | Ph3 | C | P0 | S | T3 result: implement the "Save to…" state | open |  | DK-0379 |  |
| DK-0386 | Ph5 | C | P1 | S | Chaining via Next chips and "Save as workflow" | open |  | DK-0379 |  |
| DK-0387 | Ph3 | C | P0 | M | X1 tool picker (share sheet / viewer Tools) | open |  | DK-0370 DK-0235 DK-0084 DK-0082 DK-0182 DK-0126 DK-0022 |  |
| DK-0388 | Ph7 | C | P2 | M | Tablet T2/T3: options left (480) + live preview right; medium: max width 640 | open |  | DK-0370 DK-0379 |  |
| DK-0389 | Ph7 | C | P1 | S | T2 Compress and T3 at 200 % text | open |  | DK-0370 DK-0379 |  |
| DK-0390 | Ph1 | A | P0 | L | Build `doc_core`: Document core API | open |  | DK-0007 |  |
| DK-0391 | Ph1 | A | P0 | L | Build `qpdf_ffi`: qpdf binding (1 wk) | open |  | DK-0007 DK-0010 |  |
| DK-0392 | Ph3 | A | P0 | L | Build `pdf_compress`: Compression pipeline (1.5 wk) | open |  | DK-0390 DK-0391 |  |
| DK-0393 | Ph4 | A | P0 | XL | Build `pdf_redact`: True redaction library (2 wk) | open |  | DK-0390 DK-0391 DK-0394 |  |
| DK-0394 | Ph4 | A | P0 | L | Build `ocr_text_layer`: Invisible OCR text layer (1 wk) | open |  | DK-0390 DK-0391 |  |
| DK-0395 | Ph5 | A | P0 | XL | Build `pdfa_writer`: PDF/A-2b writer (2 wk) | open |  | DK-0390 DK-0391 DK-0678 |  |
| DK-0396 | Ph5 | A | P0 | L | Build `pdf_structure`: Structure extraction (1.5 wk) | open |  | DK-0390 |  |
| DK-0397 | Ph4 | A | P0 | S | Build `vision_ocr`: iOS Vision OCR bridge (2 days) | open |  | DK-0007 |  |
| DK-0398 | Ph4 | A | P0 | L | Build `pp_ocr`: PP-OCRv5 pipeline (1 wk) | open |  | DK-0007 |  |
| DK-0399 | Ph3 | A | P0 | M | Build `web_to_pdf`: Web page to PDF plugin (3 days) | open |  | DK-0007 |  |
| DK-0400 | Ph4 | A | P0 | M | OCR facade: Apple Vision on iOS, PP-OCRv5 on Android/fallback; language handling | open |  | DK-0397 DK-0398 |  |
| DK-0401 | Ph5 | A | P2 | M | Evaluate PP-DocLayout (small) for pdf_structure and Smart Split | open |  | DK-0396 DK-0023 |  |
| DK-0402 | Ph3 | A | P0 | M | Merge PDF: implement the merge ToolJob (engine) | open |  | DK-0390 DK-0391 DK-0008 |  |
| DK-0403 | Ph3 | C | P0 | M | Merge PDF: T2 options UI | open |  | DK-0370 DK-0402 DK-0124 |  |
| DK-0404 | Ph3 | C | P0 | S | Merge PDF: T3 result card, naming and Next chips | open |  | DK-0379 DK-0403 |  |
| DK-0405 | Ph3 | C | P1 | S | Merge PDF: errors and edge states | open |  | DK-0403 DK-0609 DK-0020 |  |
| DK-0406 | Ph3 | B | P1 | XS | Merge PDF: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0407 | Ph3 | C | P1 | S | Merge PDF: golden-PDF and widget tests | open |  | DK-0402 DK-0658 |  |
| DK-0408 | Ph3 | A | P0 | M | Split PDF: implement the split ToolJob (engine) | open |  | DK-0391 DK-0008 |  |
| DK-0409 | Ph3 | C | P0 | M | Split PDF: T2 options UI | open |  | DK-0370 DK-0408 DK-0124 DK-0216 DK-0134 DK-0130 |  |
| DK-0410 | Ph3 | C | P0 | S | Split PDF: T3 result card, naming and Next chips | open |  | DK-0379 DK-0409 |  |
| DK-0411 | Ph3 | C | P1 | S | Split PDF: errors and edge states | open |  | DK-0409 DK-0609 DK-0020 |  |
| DK-0412 | Ph3 | B | P1 | XS | Split PDF: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0413 | Ph3 | C | P1 | S | Split PDF: golden-PDF and widget tests | open |  | DK-0408 DK-0658 |  |
| DK-0414 | Ph3 | A | P0 | M | Extract pages: implement the extract ToolJob (engine) | open |  | DK-0391 DK-0008 |  |
| DK-0415 | Ph3 | C | P0 | M | Extract pages: T2 options UI | open |  | DK-0370 DK-0414 DK-0154 |  |
| DK-0416 | Ph3 | C | P0 | S | Extract pages: T3 result card, naming and Next chips | open |  | DK-0379 DK-0415 |  |
| DK-0417 | Ph3 | C | P1 | S | Extract pages: errors and edge states | open |  | DK-0415 DK-0609 DK-0020 |  |
| DK-0418 | Ph3 | B | P1 | XS | Extract pages: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0419 | Ph3 | C | P1 | S | Extract pages: golden-PDF and widget tests | open |  | DK-0414 DK-0658 |  |
| DK-0420 | Ph3 | A | P0 | M | Rotate PDF: implement the rotate ToolJob (engine) | open |  | DK-0390 DK-0008 |  |
| DK-0421 | Ph3 | C | P0 | M | Rotate PDF: T2 options UI | open |  | DK-0370 DK-0420 DK-0154 DK-0192 |  |
| DK-0422 | Ph3 | C | P0 | S | Rotate PDF: T3 result card, naming and Next chips | open |  | DK-0379 DK-0421 |  |
| DK-0423 | Ph3 | C | P1 | S | Rotate PDF: errors and edge states | open |  | DK-0421 DK-0609 DK-0020 |  |
| DK-0424 | Ph3 | B | P1 | XS | Rotate PDF: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0425 | Ph3 | C | P1 | S | Rotate PDF: golden-PDF and widget tests | open |  | DK-0420 DK-0658 |  |
| DK-0426 | Ph6 | A | P1 | M | Smart Split: implement the smartsplit ToolJob (engine) | open |  | DK-0391 DK-0396 DK-0008 |  |
| DK-0427 | Ph6 | C | P1 | M | Smart Split: T2 options UI | open |  | DK-0370 DK-0426 DK-0216 |  |
| DK-0428 | Ph6 | C | P1 | S | Smart Split: T3 result card, naming and Next chips | open |  | DK-0379 DK-0427 |  |
| DK-0429 | Ph6 | C | P1 | S | Smart Split: errors and edge states | open |  | DK-0427 DK-0192 DK-0609 DK-0020 |  |
| DK-0430 | Ph6 | B | P1 | XS | Smart Split: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0431 | Ph6 | C | P1 | S | Smart Split: golden-PDF and widget tests | open |  | DK-0426 DK-0658 |  |
| DK-0432 | Ph3 | A | P0 | M | Image to PDF: implement the img2pdf ToolJob (engine) | open |  | DK-0390 DK-0339 DK-0008 |  |
| DK-0433 | Ph3 | C | P0 | M | Image to PDF: T2 options UI | open |  | DK-0370 DK-0432 DK-0152 |  |
| DK-0434 | Ph3 | C | P0 | S | Image to PDF: T3 result card, naming and Next chips | open |  | DK-0379 DK-0433 |  |
| DK-0435 | Ph3 | C | P1 | S | Image to PDF: errors and edge states | open |  | DK-0433 DK-0609 DK-0020 |  |
| DK-0436 | Ph3 | B | P1 | XS | Image to PDF: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0437 | Ph3 | C | P1 | S | Image to PDF: golden-PDF and widget tests | open |  | DK-0432 DK-0658 |  |
| DK-0438 | Ph3 | A | P0 | M | PDF to images: implement the pdf2img ToolJob (engine) | open |  | DK-0390 DK-0008 |  |
| DK-0439 | Ph3 | C | P0 | M | PDF to images: T2 options UI | open |  | DK-0370 DK-0438 DK-0092 |  |
| DK-0440 | Ph3 | C | P0 | S | PDF to images: T3 result card, naming and Next chips | open |  | DK-0379 DK-0439 |  |
| DK-0441 | Ph3 | C | P1 | S | PDF to images: errors and edge states | open |  | DK-0439 DK-0609 DK-0020 |  |
| DK-0442 | Ph3 | B | P1 | XS | PDF to images: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0443 | Ph3 | C | P1 | S | PDF to images: golden-PDF and widget tests | open |  | DK-0438 DK-0658 |  |
| DK-0444 | Ph3 | A | P0 | M | Web page to PDF: implement the web ToolJob (engine) | open |  | DK-0399 DK-0012 DK-0008 |  |
| DK-0445 | Ph3 | C | P0 | M | Web page to PDF: T2 options UI | open |  | DK-0370 DK-0444 DK-0192 |  |
| DK-0446 | Ph3 | C | P0 | S | Web page to PDF: T3 result card, naming and Next chips | open |  | DK-0379 DK-0445 |  |
| DK-0447 | Ph3 | C | P1 | S | Web page to PDF: errors and edge states | open |  | DK-0445 DK-0068 DK-0609 DK-0020 |  |
| DK-0448 | Ph3 | B | P1 | XS | Web page to PDF: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0449 | Ph3 | C | P1 | S | Web page to PDF: golden-PDF and widget tests | open |  | DK-0444 DK-0658 |  |
| DK-0450 | Ph5 | A | P1 | M | Convert to PDF/A: implement the pdfa ToolJob (engine) | open |  | DK-0395 DK-0008 |  |
| DK-0451 | Ph5 | C | P1 | M | Convert to PDF/A: T2 options UI | open |  | DK-0370 DK-0450 |  |
| DK-0452 | Ph5 | C | P1 | S | Convert to PDF/A: T3 result card, naming and Next chips | open |  | DK-0379 DK-0451 |  |
| DK-0453 | Ph5 | C | P1 | S | Convert to PDF/A: errors and edge states | open |  | DK-0451 DK-0609 DK-0020 |  |
| DK-0454 | Ph5 | B | P1 | XS | Convert to PDF/A: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0455 | Ph5 | C | P1 | S | Convert to PDF/A: golden-PDF and widget tests | open |  | DK-0450 DK-0658 |  |
| DK-0456 | Ph5 | A | P1 | M | PDF to text: implement the text ToolJob (engine) | open |  | DK-0396 DK-0008 |  |
| DK-0457 | Ph5 | C | P1 | M | PDF to text: T2 options UI | open |  | DK-0370 DK-0456 |  |
| DK-0458 | Ph5 | C | P1 | S | PDF to text: T3 result card, naming and Next chips | open |  | DK-0379 DK-0457 |  |
| DK-0459 | Ph5 | C | P1 | S | PDF to text: errors and edge states | open |  | DK-0457 DK-0609 DK-0020 |  |
| DK-0460 | Ph5 | B | P1 | XS | PDF to text: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0461 | Ph5 | C | P1 | S | PDF to text: golden-PDF and widget tests | open |  | DK-0456 DK-0658 |  |
| DK-0462 | Ph3 | A | P0 | M | Compress PDF: implement the compress ToolJob (engine) | open |  | DK-0392 DK-0008 |  |
| DK-0463 | Ph3 | C | P0 | M | Compress PDF: T2 options UI | open |  | DK-0370 DK-0462 DK-0092 DK-0104 |  |
| DK-0464 | Ph3 | C | P0 | S | Compress PDF: T3 result card, naming and Next chips | open |  | DK-0379 DK-0463 |  |
| DK-0465 | Ph3 | C | P1 | S | Compress PDF: errors and edge states | open |  | DK-0463 DK-0609 DK-0020 |  |
| DK-0466 | Ph3 | B | P1 | XS | Compress PDF: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0467 | Ph3 | C | P1 | S | Compress PDF: golden-PDF and widget tests | open |  | DK-0462 DK-0658 |  |
| DK-0468 | Ph3 | A | P0 | M | Repair PDF: implement the repair ToolJob (engine) | open |  | DK-0391 DK-0390 DK-0008 |  |
| DK-0469 | Ph3 | C | P0 | M | Repair PDF: T2 options UI | open |  | DK-0370 DK-0468 |  |
| DK-0470 | Ph3 | C | P0 | S | Repair PDF: T3 result card, naming and Next chips | open |  | DK-0379 DK-0469 |  |
| DK-0471 | Ph3 | C | P1 | S | Repair PDF: errors and edge states | open |  | DK-0469 DK-0063 DK-0609 DK-0020 |  |
| DK-0472 | Ph3 | B | P1 | XS | Repair PDF: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0473 | Ph3 | C | P1 | S | Repair PDF: golden-PDF and widget tests | open |  | DK-0468 DK-0658 |  |
| DK-0474 | Ph5 | A | P1 | M | Make text searchable: implement the ocr ToolJob (engine) | open |  | DK-0400 DK-0394 DK-0270 DK-0008 |  |
| DK-0475 | Ph5 | C | P1 | M | Make text searchable: T2 options UI | open |  | DK-0370 DK-0474 |  |
| DK-0476 | Ph5 | C | P1 | S | Make text searchable: T3 result card, naming and Next chips | open |  | DK-0379 DK-0475 |  |
| DK-0477 | Ph5 | C | P1 | S | Make text searchable: errors and edge states | open |  | DK-0475 DK-0609 DK-0020 |  |
| DK-0478 | Ph5 | B | P1 | XS | Make text searchable: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0479 | Ph5 | C | P1 | S | Make text searchable: golden-PDF and widget tests | open |  | DK-0474 DK-0658 |  |
| DK-0480 | Ph3 | A | P0 | M | Add page numbers: implement the pagenum ToolJob (engine) | open |  | DK-0391 DK-0008 |  |
| DK-0481 | Ph3 | C | P0 | M | Add page numbers: T2 options UI | open |  | DK-0370 DK-0480 DK-0140 DK-0134 |  |
| DK-0482 | Ph3 | C | P0 | S | Add page numbers: T3 result card, naming and Next chips | open |  | DK-0379 DK-0481 |  |
| DK-0483 | Ph3 | C | P1 | S | Add page numbers: errors and edge states | open |  | DK-0481 DK-0609 DK-0020 |  |
| DK-0484 | Ph3 | B | P1 | XS | Add page numbers: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0485 | Ph3 | C | P1 | S | Add page numbers: golden-PDF and widget tests | open |  | DK-0480 DK-0658 |  |
| DK-0486 | Ph3 | A | P0 | M | Add watermark: implement the watermark ToolJob (engine) | open |  | DK-0391 DK-0008 |  |
| DK-0487 | Ph3 | C | P0 | M | Add watermark: T2 options UI | open |  | DK-0370 DK-0486 DK-0132 |  |
| DK-0488 | Ph3 | C | P0 | S | Add watermark: T3 result card, naming and Next chips | open |  | DK-0379 DK-0487 |  |
| DK-0489 | Ph3 | C | P1 | S | Add watermark: errors and edge states | open |  | DK-0487 DK-0609 DK-0020 |  |
| DK-0490 | Ph3 | B | P1 | XS | Add watermark: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0491 | Ph3 | C | P1 | S | Add watermark: golden-PDF and widget tests | open |  | DK-0486 DK-0658 |  |
| DK-0492 | Ph3 | A | P0 | M | Crop pages: implement the crop ToolJob (engine) | open |  | DK-0390 DK-0008 |  |
| DK-0493 | Ph3 | C | P0 | M | Crop pages: T2 options UI | open |  | DK-0370 DK-0492 DK-0156 DK-0158 |  |
| DK-0494 | Ph3 | C | P0 | S | Crop pages: T3 result card, naming and Next chips | open |  | DK-0379 DK-0493 |  |
| DK-0495 | Ph3 | C | P1 | S | Crop pages: errors and edge states | open |  | DK-0493 DK-0609 DK-0020 |  |
| DK-0496 | Ph3 | B | P1 | XS | Crop pages: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0497 | Ph3 | C | P1 | S | Crop pages: golden-PDF and widget tests | open |  | DK-0492 DK-0658 |  |
| DK-0498 | Ph4 | A | P0 | M | Add password: implement the protect ToolJob (engine) | open |  | DK-0391 DK-0008 |  |
| DK-0499 | Ph4 | C | P0 | M | Add password: T2 options UI | open |  | DK-0370 DK-0498 DK-0122 DK-0192 |  |
| DK-0500 | Ph4 | C | P0 | S | Add password: T3 result card, naming and Next chips | open |  | DK-0379 DK-0499 |  |
| DK-0501 | Ph4 | C | P1 | S | Add password: errors and edge states | open |  | DK-0499 DK-0609 DK-0020 |  |
| DK-0502 | Ph4 | B | P1 | XS | Add password: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0503 | Ph4 | C | P1 | S | Add password: golden-PDF and widget tests | open |  | DK-0498 DK-0658 |  |
| DK-0504 | Ph4 | A | P0 | M | Remove password: implement the unlock ToolJob (engine) | open |  | DK-0391 DK-0008 |  |
| DK-0505 | Ph4 | C | P0 | M | Remove password: T2 options UI | open |  | DK-0370 DK-0504 |  |
| DK-0506 | Ph4 | C | P0 | S | Remove password: T3 result card, naming and Next chips | open |  | DK-0379 DK-0505 |  |
| DK-0507 | Ph4 | C | P1 | S | Remove password: errors and edge states | open |  | DK-0505 DK-0609 DK-0020 |  |
| DK-0508 | Ph4 | B | P1 | XS | Remove password: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0509 | Ph4 | C | P1 | S | Remove password: golden-PDF and widget tests | open |  | DK-0504 DK-0658 |  |
| DK-0510 | Ph3 | A | P0 | M | Extract images & text: implement the extractassets ToolJob (engine) | open |  | DK-0390 DK-0008 |  |
| DK-0511 | Ph3 | C | P0 | M | Extract images & text: T2 options UI | open |  | DK-0370 DK-0510 |  |
| DK-0512 | Ph3 | C | P0 | S | Extract images & text: T3 result card, naming and Next chips | open |  | DK-0379 DK-0511 |  |
| DK-0513 | Ph3 | C | P1 | S | Extract images & text: errors and edge states | open |  | DK-0511 DK-0609 DK-0020 |  |
| DK-0514 | Ph3 | B | P1 | XS | Extract images & text: copy deck EN/DE and accessibility labels | open |  | DK-0009 |  |
| DK-0515 | Ph3 | C | P1 | S | Extract images & text: golden-PDF and widget tests | open |  | DK-0510 DK-0658 |  |
| DK-0516 | Ph3 | C | P0 | XS | Organize pages tool entry: opens P1 directly (toast instead of T3) | open |  | DK-0329 |  |
| DK-0517 | Ph4 | C | P0 | XS | Mark up tool entry: opens V2 with the Highlighter selected; saved as a new version | open |  | DK-0313 |  |
| DK-0518 | Ph4 | C | P0 | S | Fill form tool: V2 with form filling + "Lock form values?" dialog, no-fields and XFA dialogs | open |  | DK-0323 DK-0313 |  |
| DK-0519 | Ph4 | C | P0 | XS | Sign PDF tool: V2 with the signatures sheet; toast "Signed on page 3 · Undo" | open |  | DK-0313 DK-0325 |  |
| DK-0520 | Ph4 | C | P0 | L | Black out: detectors (IBAN mod-97, German Steuer-ID check digit, email, phone, DOB, US SSN, UK NI) + AI name/address suggestions | open |  | DK-0393 DK-0400 |  |
| DK-0521 | Ph4 | C | P0 | S | Black out: implement the "Screen & step indicator" state | open |  | DK-0520 DK-0220 DK-0160 |  |
| DK-0522 | Ph4 | C | P0 | S | Black out: implement the "Find panel" state | open |  | DK-0520 DK-0220 DK-0160 |  |
| DK-0523 | Ph4 | C | P0 | S | Black out: implement the "Review" state | open |  | DK-0520 DK-0220 DK-0160 |  |
| DK-0524 | Ph4 | C | P0 | S | Black out: implement the "Apply confirm" state | open |  | DK-0520 DK-0220 DK-0160 |  |
| DK-0525 | Ph4 | C | P0 | S | Black out: implement the "Result verified" state | open |  | DK-0520 DK-0220 DK-0160 |  |
| DK-0526 | Ph4 | C | P0 | S | Black out: implement the "OCR step for scans" state | open |  | DK-0520 DK-0220 DK-0160 |  |
| DK-0527 | Ph4 | C | P0 | S | Black out: implement the "Verification failed" state | open |  | DK-0520 DK-0220 DK-0160 |  |
| DK-0528 | Ph4 | C | P0 | M | Redaction security test suite (release blocker) | open |  | DK-0393 DK-0010 |  |
| DK-0529 | Ph4 | C | P1 | L | Compare engine: text diff per page (Myers / diff_match_patch) + visual diff (OpenCV absdiff) | open |  | DK-0390 |  |
| DK-0530 | Ph4 | C | P0 | S | Compare: implement the "Setup" state | open |  | DK-0529 DK-0218 |  |
| DK-0531 | Ph4 | C | P0 | S | Compare: implement the "Single view (phone)" state | open |  | DK-0529 DK-0218 |  |
| DK-0532 | Ph4 | C | P0 | S | Compare: implement the "Change list" state | open |  | DK-0529 DK-0218 |  |
| DK-0533 | Ph4 | C | P0 | S | Compare: implement the "Side by side" state | open |  | DK-0529 DK-0218 |  |
| DK-0534 | Ph4 | C | P0 | S | Compare: implement the "Scans banner" state | open |  | DK-0529 DK-0218 |  |
| DK-0535 | Ph5 | C | P0 | L | Batch: tool choice → file choice → shared options → queue → result | open |  | DK-0008 DK-0370 |  |
| DK-0536 | Ph5 | C | P1 | M | Workflow runner: typed chaining of ToolJobs, JSON storage, templates | open |  | DK-0008 |  |
| DK-0537 | Ph5 | C | P0 | S | Workflows: implement the "List" state | open |  | DK-0536 DK-0065 |  |
| DK-0538 | Ph5 | C | P0 | S | Workflows: implement the "Builder" state | open |  | DK-0536 |  |
| DK-0539 | Ph5 | C | P0 | S | Workflows: implement the "Run" state | open |  | DK-0536 |  |
| DK-0540 | Ph3 | C | P0 | S | Encode the Free/Pro split per tool and keep it configurable | open |  | DK-0049 DK-0699 |  |
| DK-0541 | Ph6 | C | P0 | S | Summarize tool entry: file picker (if needed) → V1 with the AI panel on the Summary tab | open |  | DK-0559 |  |
| DK-0542 | Ph6 | C | P0 | S | Ask this PDF tool entry: file picker (if needed) → V1 with the AI panel on the Ask tab | open |  | DK-0559 |  |
| DK-0543 | Ph6 | C | P0 | S | Translate PDF tool entry: file picker (if needed) → V1 with the AI panel on the Translate tab | open |  | DK-0559 |  |
| DK-0544 | Ph5 | C | P1 | S | Workflows: edit, duplicate, rename and delete saved workflows | open |  | DK-0536 |  |
| DK-0545 | Ph6 | A | P0 | L | Integrate Sogda ai_core: ModelManager, LlmRuntimeArbiter, model catalogue JSON | open |  | DK-0013 DK-0012 DK-0683 |  |
| DK-0546 | Ph6 | A | P0 | M | Gemma 4 E2B via llamadart (llama.cpp) incl. iOS SwiftPM package | open |  | DK-0545 DK-0674 |  |
| DK-0547 | Ph6 | A | P0 | M | Bergamot translation engine via FFI (default translation engine) | open |  | DK-0545 DK-0675 |  |
| DK-0548 | Ph6 | A | P0 | S | AI text source: per-page text from PDFium or OCR with page anchors | open |  | DK-0390 DK-0270 DK-0396 |  |
| DK-0549 | Ph6 | A | P0 | L | doc_summarizer: map-reduce summary with page references, EN/DE prompts, cancel/resume | open |  | DK-0546 DK-0548 |  |
| DK-0550 | Ph6 | A | P0 | L | doc_rag: BM25 retrieval with German compound splitting, citations, "not found" behaviour | open |  | DK-0546 DK-0548 |  |
| DK-0551 | Ph6 | A | P0 | L | doc_translate: block mapping, glossary of protected items, per-page progress, export | open |  | DK-0547 DK-0396 |  |
| DK-0552 | Ph6 | A | P1 | M | smart_split rules engine with optional Gemma check | open |  | DK-0396 |  |
| DK-0553 | Ph6 | A | P0 | S | A1 AI readiness: implement the "Device not eligible" state | open |  | DK-0545 DK-0062 |  |
| DK-0554 | Ph6 | A | P0 | S | A1 AI readiness: implement the "Model not installed" state | open |  | DK-0545 DK-0094 DK-0060 |  |
| DK-0555 | Ph6 | A | P0 | S | A1 AI readiness: implement the "Downloading" state | open |  | DK-0545 |  |
| DK-0556 | Ph6 | A | P0 | S | A1 AI readiness: implement the "First-use notice" state | open |  | DK-0545 DK-0061 |  |
| DK-0557 | Ph6 | A | P0 | S | A1 AI readiness: implement the "No text in document" state | open |  | DK-0545 DK-0192 |  |
| DK-0558 | Ph6 | A | P0 | S | A1 AI readiness: implement the "Low memory now" state | open |  | DK-0545 |  |
| DK-0559 | Ph6 | A | P0 | M | A1 AI panel: sheet over V1 (medium → large), Summary · Ask · Translate tabs, footer | open |  | DK-0293 DK-0182 DK-0545 DK-0214 DK-0130 |  |
| DK-0560 | Ph6 | A | P0 | S | A1 AI panel: implement the "Summary options & streaming" state | open |  | DK-0559 DK-0549 |  |
| DK-0561 | Ph6 | A | P0 | S | A1 AI panel: implement the "Summary output" state | open |  | DK-0559 DK-0549 |  |
| DK-0562 | Ph6 | A | P0 | S | A1 AI panel: implement the "Ask empty" state | open |  | DK-0559 DK-0550 |  |
| DK-0563 | Ph6 | A | P0 | S | A1 AI panel: implement the "Ask thread" state | open |  | DK-0559 DK-0550 DK-0210 |  |
| DK-0564 | Ph6 | A | P0 | S | A1 AI panel: implement the "Ask not found" state | open |  | DK-0559 DK-0550 |  |
| DK-0565 | Ph6 | A | P0 | S | A1 AI panel: implement the "Ask from selection" state | open |  | DK-0559 DK-0550 |  |
| DK-0566 | Ph6 | A | P0 | S | A1 AI panel: implement the "Translate options" state | open |  | DK-0559 DK-0551 DK-0676 |  |
| DK-0567 | Ph6 | A | P0 | S | A1 AI panel: implement the "Translate view" state | open |  | DK-0559 DK-0551 |  |
| DK-0568 | Ph6 | A | P0 | M | M2 AI models: storage summary, grouped model cards, model detail sheet | open |  | DK-0545 DK-0094 |  |
| DK-0569 | Ph6 | A | P1 | S | AI guardrails and review checklist | open |  | DK-0549 DK-0550 |  |
| DK-0570 | Ph1 | B | P0 | M | M1 Me: Pro card, Your things, Settings, About, footer | open |  | DK-0229 DK-0100 DK-0098 |  |
| DK-0571 | Ph3 | B | P0 | S | M3 Scanning settings page | open |  | DK-0570 DK-0338 DK-0339 DK-0128 DK-0100 |  |
| DK-0572 | Ph3 | B | P1 | S | M3 Files & storage settings page | open |  | DK-0570 DK-0260 DK-0128 DK-0100 |  |
| DK-0573 | Ph6 | B | P0 | S | M3 Security settings page | open |  | DK-0570 DK-0282 DK-0234 DK-0128 DK-0100 |  |
| DK-0574 | Ph3 | B | P1 | S | M3 Appearance settings page | open |  | DK-0570 DK-0047 DK-0128 DK-0100 |  |
| DK-0575 | Ph3 | B | P0 | S | M3 Language settings page | open |  | DK-0570 DK-0009 DK-0128 DK-0100 |  |
| DK-0576 | Ph3 | B | P1 | S | M3 Privacy settings page | open |  | DK-0570 DK-0011 DK-0012 DK-0128 DK-0100 |  |
| DK-0577 | Ph7 | B | P0 | S | M3 Open-source licences settings page | open |  | DK-0570 DK-0673 DK-0128 DK-0100 |  |
| DK-0578 | Ph7 | B | P2 | XS | About rows: Replay intro, Contact (mailto), Rate Dokulo (store review) | open |  | DK-0570 DK-0238 |  |
| DK-0579 | Ph7 | B | P0 | L | One-time Pro unlock with in_app_purchase (StoreKit 2 / Play Billing), entitlement cache, restore, Family Sharing | open |  | DK-0001 |  |
| DK-0580 | Ph7 | B | P0 | M | X3 paywall sheet: close, ILL-18, headline, context line, 5 benefits, reassurance, price button, footer | open |  | DK-0579 DK-0182 DK-0067 DK-0699 |  |
| DK-0581 | Ph7 | B | P0 | S | X3 Paywall: implement the "Purchasing" state | open |  | DK-0580 |  |
| DK-0582 | Ph7 | B | P0 | S | X3 Paywall: implement the "Success" state | open |  | DK-0580 |  |
| DK-0583 | Ph7 | B | P0 | S | X3 Paywall: implement the "Error" state | open |  | DK-0580 |  |
| DK-0584 | Ph7 | B | P0 | S | X3 Paywall: implement the "Restore" state | open |  | DK-0580 |  |
| DK-0585 | Ph7 | Q | P1 | S | Enforce the Pro touchpoint inventory (no other placements) | open |  | DK-0580 DK-0374 |  |
| DK-0586 | Ph7 | Q | P0 | M | Verify Pro gating on every Pro feature (first free try, paywall before work, auto-run after purchase) | open |  | DK-0374 DK-0427 DK-0451 DK-0457 DK-0475 DK-0559 DK-0362 DK-0282 DK-0359 DK-0535 DK-0536 DK-0529 DK-0520 DK-0323 |  |
| DK-0587 | Ph3 | B | P0 | M | Local notifications service (iOS + Android channels) with deep links | open |  | DK-0236 DK-0016 |  |
| DK-0588 | Ph3 | B | P1 | XS | Notification: Job finished | open |  | DK-0587 DK-0008 |  |
| DK-0589 | Ph3 | B | P1 | XS | Notification: Job failed | open |  | DK-0587 DK-0008 DK-0609 |  |
| DK-0590 | Ph5 | B | P1 | XS | Notification: Batch finished | open |  | DK-0587 DK-0535 |  |
| DK-0591 | Ph6 | B | P1 | XS | Notification: Model downloaded | open |  | DK-0587 DK-0545 |  |
| DK-0592 | Ph6 | B | P1 | XS | Notification: Photo finder done | open |  | DK-0587 DK-0362 |  |
| DK-0593 | Ph3 | B | P0 | S | Android progress notification for long jobs (foreground service) | open |  | DK-0587 DK-0008 |  |
| DK-0594 | Ph7 | B | P2 | M | Home-screen widget: Scan | open |  | DK-0236 |  |
| DK-0595 | Ph7 | B | P2 | M | Home-screen widget: Quick tools | open |  | DK-0236 |  |
| DK-0596 | Ph7 | B | P2 | M | Home-screen widget: Last scan | open |  | DK-0236 |  |
| DK-0597 | Ph7 | B | P2 | S | App-icon long-press shortcuts: Scan · Merge PDF · Compress PDF · {last used tool} | open |  | DK-0236 DK-0022 |  |
| DK-0598 | Ph3 | B | P0 | M | iOS Share Extension UI: "Open in Dokulo" card with 6 quick tools | open |  | DK-0235 DK-0236 |  |
| DK-0599 | Ph7 | B | P2 | M | iOS Files Action Extension ("Dokulo") opening the X1 picker (3 days) | open |  | DK-0387 DK-0707 |  |
| DK-0600 | Ph3 | B | P1 | S | Android share target + direct-share shortcuts ("Compress with Dokulo", "Merge with Dokulo") | open |  | DK-0235 |  |
| DK-0601 | Ph3 | C | P1 | XS | Empty state: Home recents | open |  | DK-0196 DK-0053 |  |
| DK-0602 | Ph3 | C | P1 | XS | Empty state: Files root | open |  | DK-0196 DK-0054 |  |
| DK-0603 | Ph3 | C | P1 | XS | Empty state: Folder | open |  | DK-0196 DK-0055 |  |
| DK-0604 | Ph3 | C | P1 | XS | Empty state: Search | open |  | DK-0196 DK-0056 |  |
| DK-0605 | Ph3 | C | P1 | XS | Empty state: Trash | open |  | DK-0196 DK-0057 |  |
| DK-0606 | Ph3 | C | P1 | XS | Empty state: Signatures | open |  | DK-0196 DK-0064 |  |
| DK-0607 | Ph3 | C | P1 | XS | Empty state: Workflows | open |  | DK-0196 DK-0065 |  |
| DK-0608 | Ph3 | C | P1 | XS | Empty state: Photo finder | open |  | DK-0196 DK-0066 |  |
| DK-0609 | Ph3 | C | P0 | M | Error model: typed DokuloError with codes, messages and one recovery action | open |  | DK-0008 |  |
| DK-0610 | Ph3 | C | P1 | XS | Error: Locked input | open |  | DK-0609 |  |
| DK-0611 | Ph3 | C | P1 | XS | Error: Damaged file | open |  | DK-0609 |  |
| DK-0612 | Ph3 | C | P1 | XS | Error: Not enough storage | open |  | DK-0609 |  |
| DK-0613 | Ph3 | C | P1 | XS | Error: Too large for memory | open |  | DK-0609 |  |
| DK-0614 | Ph3 | C | P1 | XS | Error: Unsupported form | open |  | DK-0609 |  |
| DK-0615 | Ph3 | C | P1 | XS | Error: Model missing | open |  | DK-0609 |  |
| DK-0616 | Ph3 | C | P1 | XS | Error: Low memory | open |  | DK-0609 |  |
| DK-0617 | Ph3 | C | P1 | XS | Error: Cancelled | open |  | DK-0609 |  |
| DK-0618 | Ph3 | C | P1 | XS | Error: Unexpected | open |  | DK-0609 |  |
| DK-0619 | Ph3 | C | P1 | XS | Error: Offline (web tool) | open |  | DK-0609 |  |
| DK-0620 | Ph3 | C | P1 | S | Loading states: skeletons for lists, grids, thumbnails, model cards; page skeleton in viewer | open |  | DK-0198 |  |
| DK-0621 | Ph3 | C | P0 | S | Permissions denied: inline warning banner with "Open settings", never repeated prompts | open |  | DK-0192 |  |
| DK-0622 | Ph3 | C | P2 | XS | Global banner (info/warning/error/Pro) and toast-with-action examples wired to real cases | open |  | DK-0192 DK-0190 |  |
| DK-0623 | Ph3 | B | P0 | S | ARB strings: Common actions | open |  | DK-0009 |  |
| DK-0624 | Ph3 | B | P0 | S | ARB strings: Common labels and toasts | open |  | DK-0009 |  |
| DK-0625 | Ph3 | B | P0 | S | ARB strings: Tool names, buttons, suffixes | open |  | DK-0009 |  |
| DK-0626 | Ph7 | B | P0 | S | ARB strings: Onboarding and Home | open |  | DK-0009 |  |
| DK-0627 | Ph3 | B | P0 | S | ARB strings: Files, trash, locked folder | open |  | DK-0009 |  |
| DK-0628 | Ph3 | B | P0 | S | ARB strings: Viewer and edit mode | open |  | DK-0009 |  |
| DK-0629 | Ph3 | B | P0 | S | ARB strings: Scanner | open |  | DK-0009 |  |
| DK-0630 | Ph3 | B | P0 | S | ARB strings: Tool shell and tools | open |  | DK-0009 |  |
| DK-0631 | Ph3 | B | P0 | S | ARB strings: AI | open |  | DK-0009 |  |
| DK-0632 | Ph3 | B | P0 | S | ARB strings: Me, settings, Pro | open |  | DK-0009 |  |
| DK-0633 | Ph3 | B | P0 | S | ARB strings: System and errors | open |  | DK-0009 |  |
| DK-0634 | Ph3 | B | P0 | S | Locale formats: decimal comma, thin-space units, date formats, A4 vs Letter defaults | open |  | DK-0009 |  |
| DK-0635 | Ph7 | Q | P1 | M | German layout QA at 100 % and 200 % text on all DE-marked frames | open |  | DK-0009 DK-0623 DK-0624 DK-0625 DK-0626 DK-0627 DK-0628 DK-0629 DK-0630 DK-0631 DK-0632 DK-0633 |  |
| DK-0636 | Ph3 | B | P1 | S | In-app language switch (System · English · Deutsch) without restart | open |  | DK-0009 |  |
| DK-0637 | Ph7 | B | P0 | M | Accessibility: screen-reader labels | open |  | DK-0024 DK-0229 |  |
| DK-0638 | Ph7 | B | P0 | S | Accessibility: streaming ai text | open |  | DK-0024 DK-0210 DK-0549 |  |
| DK-0639 | Ph7 | B | P0 | S | Accessibility: never colour alone | open |  | DK-0024 DK-0218 DK-0220 DK-0102 |  |
| DK-0640 | Ph7 | B | P0 | M | Accessibility: text size 200 % | open |  | DK-0024 DK-0036 |  |
| DK-0641 | Ph7 | B | P0 | S | Accessibility: touch targets | open |  | DK-0024 |  |
| DK-0642 | Ph7 | B | P1 | S | Accessibility: focus rings | open |  | DK-0024 |  |
| DK-0643 | Ph7 | B | P0 | S | Accessibility: reduce motion | open |  | DK-0024 DK-0039 |  |
| DK-0644 | Ph7 | B | P1 | S | Accessibility: scanner guidance | open |  | DK-0024 DK-0343 |  |
| DK-0645 | Ph7 | B | P1 | S | Accessibility: progress announcements | open |  | DK-0024 DK-0375 |  |
| DK-0646 | Ph7 | B | P0 | S | Accessibility: contrast in all themes | open |  | DK-0024 |  |
| DK-0647 | Ph7 | B | P1 | S | Accessibility: errors next to fields | open |  | DK-0024 DK-0120 |  |
| DK-0648 | Ph7 | Q | P0 | M | Full accessibility audit before release (both platforms) | open |  | DK-0665 DK-0637 DK-0638 DK-0639 DK-0640 DK-0641 DK-0642 DK-0643 DK-0644 DK-0645 DK-0646 DK-0647 |  |
| DK-0649 | Ph7 | B | P2 | M | Tablet layout: H1 Home | open |  | DK-0232 DK-0242 |  |
| DK-0650 | Ph7 | B | P2 | M | Tablet layout: T1 Tools | open |  | DK-0232 DK-0256 |  |
| DK-0651 | Ph7 | B | P2 | M | Tablet layout: P1 Organize | open |  | DK-0232 DK-0329 |  |
| DK-0652 | Ph7 | B | P2 | M | Tablet layout: S1 Scanner landscape | open |  | DK-0232 DK-0343 |  |
| DK-0653 | Ph7 | B | P2 | M | Tablet layout: Compare | open |  | DK-0232 DK-0529 |  |
| DK-0654 | Ph7 | B | P2 | M | Tablet layout: X3 Paywall | open |  | DK-0232 DK-0580 |  |
| DK-0655 | Ph7 | B | P2 | M | Tablet layout: Sheets | open |  | DK-0232 DK-0182 |  |
| DK-0656 | Ph4 | B | P1 | S | Phone orientation locks: portrait except Viewer, Signature pad (landscape-only), Compare, Translate side-by-side, Scanner | open |  | DK-0004 |  |
| DK-0657 | Ph1 | B | P0 | M | Breakpoint system (compact/medium/expanded) and safe-area/thumb-zone rules | open |  | DK-0024 |  |
| DK-0658 | Ph3 | B | P0 | L | Test suite: Golden PDF corpus | open |  | DK-0010 DK-0023 |  |
| DK-0659 | Ph5 | B | P0 | S | Test suite: PDF/A validation | open |  | DK-0010 DK-0395 |  |
| DK-0660 | Ph3 | B | P0 | S | Test suite: Compression quality | open |  | DK-0010 DK-0392 |  |
| DK-0661 | Ph5 | B | P0 | M | Test suite: OCR accuracy | open |  | DK-0010 DK-0023 DK-0400 |  |
| DK-0662 | Ph2 | B | P0 | M | Test suite: Scanner detection | open |  | DK-0010 DK-0023 DK-0336 DK-0337 |  |
| DK-0663 | Ph7 | B | P0 | M | Test suite: Performance benchmarks | open |  | DK-0010 DK-0402 DK-0462 DK-0474 DK-0343 DK-0293 DK-0668 |  |
| DK-0664 | Ph7 | B | P0 | S | Test suite: Privacy network check | open |  | DK-0010 DK-0012 DK-0008 |  |
| DK-0665 | Ph7 | B | P0 | L | Test suite: Integration tests for prototype flows | open |  | DK-0010 DK-0238 DK-0352 DK-0359 DK-0463 DK-0387 DK-0235 DK-0499 DK-0403 DK-0375 DK-0587 DK-0379 DK-0293 DK-0559 DK-0550 DK-0580 DK-0374 DK-0260 DK-0282 DK-0222 DK-0233 DK-0524 |  |
| DK-0666 | Ph7 | B | P0 | L | Test suite: Widget golden suite | open |  | DK-0010 DK-0047 DK-0009 |  |
| DK-0667 | Ph7 | B | P0 | M | Test suite: Large file robustness | open |  | DK-0010 DK-0668 DK-0658 |  |
| DK-0668 | Ph1 | Q | P0 | S | Device lab: low-end Android (3 GB), mid Android (6–8 GB), older iPhone (11), recent iPhone; tablets | assigned | agent-3 |  |  |
| DK-0669 | Ph1 | B | P1 | M | Usability test of Home, Scanner and the tool shell with 5 users before building further | open |  | DK-1012 |  |
| DK-0670 | Ph7 | Q | P0 | M | Release regression checklist per phase build | open |  | DK-0668 DK-0015 |  |
| DK-0671 | Ph7 | Q | P0 | M | Audit every screen against the 10 UX principles | open |  | DK-0665 |  |
| DK-0672 | Ph1 | A | P0 | S | Compliance: Licence register | in-progress | agent-1 |  |  |
| DK-0673 | Ph7 | A | P0 | S | Compliance: In-app licence screen generation | open |  | DK-0672 |  |
| DK-0674 | Ph6 | A | P0 | S | Compliance: Gemma licence confirmation | assigned | agent-2 |  |  |
| DK-0675 | Ph6 | A | P0 | S | Compliance: Bergamot models and language pairs | assigned | agent-2 |  |  |
| DK-0676 | Ph6 | A | P0 | S | Compliance: Exclude Hy-MT | assigned | agent-2 |  |  |
| DK-0677 | Ph2 | A | P1 | S | Compliance: ML Kit scanner decision | review | agent-2 |  | #96 |
| DK-0678 | Ph5 | A | P0 | S | Compliance: sRGB ICC profile | assigned | agent-1 |  |  |
| DK-0679 | Ph7 | A | P0 | S | Compliance: Privacy policy & store labels | open |  | DK-0700 DK-0011 DK-0012 |  |
| DK-0680 | Ph1 | A | P1 | S | Compliance: OpenCV module exclusion | assigned | agent-1 |  |  |
| DK-0681 | Ph6 | A | P1 | S | Compliance: MPL/LGPL handling | assigned | agent-1 |  |  |
| DK-0682 | Ph7 | A | P0 | S | Compliance: iOS privacy manifest (PrivacyInfo.xcprivacy) and third-party SDK manifests | open |  | DK-0015 |  |
| DK-0683 | Ph6 | A | P1 | XS | Compliance: inference-only AI policy (no training or fine-tuning) and model intake checklist | assigned | agent-2 |  |  |
| DK-0684 | Ph7 | M | P0 | S | Store screenshot 1: "All your PDF tools. Nothing uploaded." | open |  | DK-0242 DK-0244 DK-0023 DK-1013 DK-0047 DK-0009 |  |
| DK-0685 | Ph7 | M | P0 | S | Store screenshot 2: "Scan anything in seconds" | open |  | DK-0343 DK-0023 DK-1013 DK-0047 DK-0009 |  |
| DK-0686 | Ph7 | M | P0 | S | Store screenshot 3: "Under 2 MB for any upload portal" | open |  | DK-0464 DK-0023 DK-1013 DK-0047 DK-0009 |  |
| DK-0687 | Ph7 | M | P0 | S | Store screenshot 4: "Black out what others shouldn't see" | open |  | DK-0523 DK-0023 DK-1013 DK-0047 DK-0009 |  |
| DK-0688 | Ph7 | M | P0 | S | Store screenshot 5: "Sign without printing" | open |  | DK-0328 DK-0023 DK-1013 DK-0047 DK-0009 |  |
| DK-0689 | Ph7 | M | P0 | S | Store screenshot 6: "Summarize and translate – offline" | open |  | DK-0561 DK-0023 DK-1013 DK-0047 DK-0009 |  |
| DK-0690 | Ph7 | M | P0 | S | Store screenshot 7: "No watermark. No subscription." | open |  | DK-0256 DK-0023 DK-1013 DK-0047 DK-0009 |  |
| DK-0691 | Ph7 | M | P2 | S | Launch: Feature graphic | open |  | DK-0070 DK-1013 |  |
| DK-0692 | Ph7 | M | P2 | S | Launch: Preview video (optional) | open |  | DK-1013 |  |
| DK-0693 | Ph7 | M | P0 | M | Launch: Store listings EN/DE | open |  | DK-0698 DK-0699 DK-0684 DK-0685 DK-0686 DK-0687 DK-0688 DK-0689 DK-0690 |  |
| DK-0694 | Ph7 | M | P0 | S | Launch: Closed testing | open |  | DK-0670 DK-0665 DK-0015 |  |
| DK-0695 | Ph7 | M | P0 | M | Launch: Release | open |  | DK-0694 DK-0693 DK-0679 DK-0673 DK-0674 DK-0676 DK-0682 DK-0648 DK-0635 DK-0071 DK-0579 DK-0580 DK-0586 DK-0663 DK-0664 DK-0528 DK-0017 DK-0018 DK-0011 DK-0671 DK-0016 DK-0667 DK-0659 DK-0666 |  |
| DK-0696 | Ph7 | M | P2 | S | Launch: Launch channels | open |  | DK-0695 DK-0693 |  |
| DK-0697 | Ph7 | M | P2 | S | Launch: Additional listing languages | open |  | DK-0695 |  |
| DK-0698 | Ph1 | A | P0 | XS | Decision: App name | needs-decision |  |  |  |
| DK-0699 | Ph1 | A | P0 | XS | Decision: Free/Pro split and price | needs-decision |  |  |  |
| DK-0700 | Ph1 | A | P1 | XS | Decision: Ads | needs-decision |  |  |  |
| DK-0701 | Ph1 | A | P1 | XS | Decision: Glass theme | needs-decision |  |  |  |
| DK-0702 | Ph1 | A | P1 | XS | Decision: Default pinned tools | needs-decision |  |  |  |
| DK-0703 | Ph1 | A | P0 | XS | Decision: Schedule scope | needs-decision |  |  |  |
| DK-0704 | Ph1 | A | P1 | XS | Decision: Launch languages | needs-decision |  |  |  |
| DK-0705 | Ph1 | A | P1 | XS | Decision: Order vs letter assistant | needs-decision |  |  |  |
| DK-0706 | Ph1 | A | P1 | XS | Decision: Per-screen specs | needs-decision |  |  |  |
| DK-0707 | Ph3 | A | P1 | XS | Decision: iOS Files action lands on the X1 picker (UI spec) or directly on the chosen tool (UX plan) | needs-decision |  |  |  |
| DK-0708 | Ph1 | A | P0 | XS | Decision: confirm the palette together with the app-icon design | needs-decision |  |  |  |
| DK-0709 | Ph1 | A | P2 | XS | Document the not-planned scope so it is not built by accident | open |  |  |  |
| DK-0710 | Ph7 | Q | P2 | XS | Visual QA: onboarding-launch (Launch) | open |  | DK-0073 |  |
| DK-0711 | Ph7 | Q | P2 | XS | Visual QA: onboarding-o1 (no uploads) | open |  | DK-0238 DK-0239 |  |
| DK-0712 | Ph7 | Q | P2 | XS | Visual QA: onboarding-o2 (no watermark) | open |  | DK-0240 |  |
| DK-0713 | Ph7 | Q | P2 | XS | Visual QA: onboarding-o3 (start with) | open |  | DK-0241 |  |
| DK-0714 | Ph7 | Q | P2 | XS | Visual QA: onboarding-o1-iphone-se (no uploads · iPhone SE) | open |  | DK-0238 |  |
| DK-0715 | Ph7 | Q | P2 | XS | Visual QA: home-default (default) | open |  | DK-0229 DK-0242 DK-0243 DK-0244 DK-0255 |  |
| DK-0716 | Ph7 | Q | P2 | XS | Visual QA: home-first (first launch) | open |  | DK-0245 |  |
| DK-0717 | Ph7 | Q | P2 | XS | Visual QA: home-contscan (continue (unsaved scan)) | open |  | DK-0246 |  |
| DK-0718 | Ph7 | Q | P2 | XS | Visual QA: home-contjob (continue (job finished)) | open |  | DK-0247 |  |
| DK-0719 | Ph7 | Q | P2 | XS | Visual QA: home-edit (edit pinned tools) | open |  | DK-0248 |  |
| DK-0720 | Ph7 | Q | P2 | XS | Visual QA: home-addtool (add-tool sheet) | open |  | DK-0249 |  |
| DK-0721 | Ph7 | Q | P2 | XS | Visual QA: home-procard (Pro card (scrolled)) | open |  | DK-0251 |  |
| DK-0722 | Ph7 | Q | P2 | XS | Visual QA: home-photobanner (find documents banner) | open |  | DK-0252 |  |
| DK-0723 | Ph7 | Q | P2 | XS | Visual QA: home-job (mini job bar) | open |  | DK-0233 DK-0250 |  |
| DK-0724 | Ph7 | Q | P2 | XS | Visual QA: home-jobs3 (3 jobs running) | open |  | DK-0233 |  |
| DK-0725 | Ph7 | Q | P2 | XS | Visual QA: home-tilemenu (tile long-press menu) | open |  | DK-0244 |  |
| DK-0726 | Ph7 | Q | P2 | XS | Visual QA: home-scanmenu (Scan button long-press modes) | open |  | DK-0229 DK-0230 |  |
| DK-0727 | Ph7 | Q | P2 | XS | Visual QA: home-rating (rating prompt (system)) | open |  | DK-0253 |  |
| DK-0728 | Ph7 | Q | P2 | XS | Visual QA: tools-default (default) | open |  | DK-0049 DK-0256 |  |
| DK-0729 | Ph7 | Q | P2 | XS | Visual QA: tools-chip (scrolled, Security selected) | open |  | DK-0256 |  |
| DK-0730 | Ph7 | Q | P2 | XS | Visual QA: tools-search (search results (synonym)) | open |  | DK-0257 |  |
| DK-0731 | Ph7 | Q | P2 | XS | Visual QA: tools-searchempty (search, no result) | open |  | DK-0258 |  |
| DK-0732 | Ph7 | Q | P2 | XS | Visual QA: tools-about (About this tool sheet) | open |  | DK-0259 |  |
| DK-0733 | Ph7 | Q | P2 | XS | Visual QA: files-list (root list) | open |  | DK-0228 DK-0260 |  |
| DK-0734 | Ph7 | Q | P2 | XS | Visual QA: files-grid (root grid) | open |  | DK-0260 |  |
| DK-0735 | Ph7 | Q | P2 | XS | Visual QA: files-folder (folder with breadcrumb) | open |  | DK-0262 |  |
| DK-0736 | Ph7 | Q | P2 | XS | Visual QA: files-select (selection mode) | open |  | DK-0222 DK-0263 |  |
| DK-0737 | Ph7 | Q | P2 | XS | Visual QA: files-empty (empty root) | open |  | DK-0265 |  |
| DK-0738 | Ph7 | Q | P2 | XS | Visual QA: files-emptyfolder (empty folder) | open |  | DK-0266 |  |
| DK-0739 | Ph7 | Q | P2 | XS | Visual QA: files-search (search results) | open |  | DK-0269 |  |
| DK-0740 | Ph7 | Q | P2 | XS | Visual QA: files-searchempty (search empty + OCR banner) | open |  | DK-0269 |  |
| DK-0741 | Ph7 | Q | P2 | XS | Visual QA: files-sort (sort menu) | open |  | DK-0261 |  |
| DK-0742 | Ph7 | Q | P2 | XS | Visual QA: files-action (file action sheet) | open |  | DK-0271 DK-0276 |  |
| DK-0743 | Ph7 | Q | P2 | XS | Visual QA: files-info (info sheet) | open |  | DK-0275 DK-0281 |  |
| DK-0744 | Ph7 | Q | P2 | XS | Visual QA: files-rename (rename dialog (error)) | open |  | DK-0272 |  |
| DK-0745 | Ph7 | Q | P2 | XS | Visual QA: files-move (move sheet) | open |  | DK-0274 |  |
| DK-0746 | Ph7 | Q | P2 | XS | Visual QA: files-newfolder (new folder dialog) | open |  | DK-0273 |  |
| DK-0747 | Ph7 | Q | P2 | XS | Visual QA: files-trash (recently deleted) | open |  | DK-0278 |  |
| DK-0748 | Ph7 | Q | P2 | XS | Visual QA: files-emptytrash (empty-trash dialog) | open |  | DK-0225 DK-0278 |  |
| DK-0749 | Ph7 | Q | P2 | XS | Visual QA: files-loading (loading skeleton) | open |  | DK-0267 DK-0620 |  |
| DK-0750 | Ph7 | Q | P2 | XS | Visual QA: files-swipe (swipe actions) | open |  | DK-0224 DK-0268 |  |
| DK-0751 | Ph7 | Q | P2 | XS | Visual QA: files-dragfolder (grid – drag file onto folder) | open |  | DK-0223 DK-0264 |  |
| DK-0752 | Ph7 | Q | P2 | XS | Visual QA: files-selmore (selection – More menu) | open |  | DK-0263 DK-0289 |  |
| DK-0753 | Ph7 | Q | P2 | XS | Visual QA: files-trashaction (deleted file – Restore / Delete for good) | open |  | DK-0278 |  |
| DK-0754 | Ph7 | Q | P2 | XS | Visual QA: files-foldermenu (folder overflow – rename, colour, delete) | open |  | DK-0262 |  |
| DK-0755 | Ph7 | Q | P2 | XS | Visual QA: locked-folder-l1 (L1 intro) | open |  | DK-0283 |  |
| DK-0756 | Ph7 | Q | P2 | XS | Visual QA: locked-folder-l2 (L2 create PIN) | open |  | DK-0284 DK-0292 |  |
| DK-0757 | Ph7 | Q | P2 | XS | Visual QA: locked-folder-l3 (L3 PIN mismatch) | open |  | DK-0285 DK-0292 |  |
| DK-0758 | Ph7 | Q | P2 | XS | Visual QA: locked-folder-l4 (L4 biometrics) | open |  | DK-0286 |  |
| DK-0759 | Ph7 | Q | P2 | XS | Visual QA: locked-folder-unlock (unlock screen) | open |  | DK-0287 |  |
| DK-0760 | Ph7 | Q | P2 | XS | Visual QA: locked-folder-content (content + move toast) | open |  | DK-0288 DK-0289 |  |
| DK-0761 | Ph7 | Q | P2 | XS | Visual QA: locked-folder-applock (app lock screen) | open |  | DK-0290 |  |
| DK-0762 | Ph7 | Q | P2 | XS | Visual QA: locked-folder-cover (app-switcher privacy cover) | open |  | DK-0234 |  |
| DK-0763 | Ph7 | Q | P2 | XS | Visual QA: viewer-default (default) | open |  | DK-0293 DK-0294 |  |
| DK-0764 | Ph7 | Q | P2 | XS | Visual QA: viewer-hidden (chrome hidden) | open |  | DK-0294 |  |
| DK-0765 | Ph7 | Q | P2 | XS | Visual QA: viewer-loading (loading) | open |  | DK-0297 DK-0620 |  |
| DK-0766 | Ph7 | Q | P2 | XS | Visual QA: viewer-search (search active) | open |  | DK-0298 |  |
| DK-0767 | Ph7 | Q | P2 | XS | Visual QA: viewer-searchnotext (search, scan without text) | open |  | DK-0299 |  |
| DK-0768 | Ph7 | Q | P2 | XS | Visual QA: viewer-select (text selected + markup bar) | open |  | DK-0300 DK-0321 |  |
| DK-0769 | Ph7 | Q | P2 | XS | Visual QA: viewer-locked (locked PDF) | open |  | DK-0301 |  |
| DK-0770 | Ph7 | Q | P2 | XS | Visual QA: viewer-wrongpw (wrong password) | open |  | DK-0302 |  |
| DK-0771 | Ph7 | Q | P2 | XS | Visual QA: viewer-night (night mode) | open |  | DK-0304 |  |
| DK-0772 | Ph7 | Q | P2 | XS | Visual QA: viewer-damaged (damaged file) | open |  | DK-0305 |  |
| DK-0773 | Ph7 | Q | P2 | XS | Visual QA: viewer-form (form detected) | open |  | DK-0306 |  |
| DK-0774 | Ph7 | Q | P2 | XS | Visual QA: viewer-goto (go to page) | open |  | DK-0307 |  |
| DK-0775 | Ph7 | Q | P2 | XS | Visual QA: viewer-link (external link dialog) | open |  | DK-0308 |  |
| DK-0776 | Ph7 | Q | P2 | XS | Visual QA: viewer-menu (overflow menu) | open |  | DK-0295 DK-0311 |  |
| DK-0777 | Ph7 | Q | P2 | XS | Visual QA: viewer-thumbs (thumbnail strip) | open |  | DK-0296 |  |
| DK-0778 | Ph7 | Q | P2 | XS | Visual QA: viewer-unlocked (after unlock toast) | open |  | DK-0303 |  |
| DK-0779 | Ph7 | Q | P2 | XS | Visual QA: edit-pen (pen selected) | open |  | DK-0313 DK-0314 |  |
| DK-0780 | Ph7 | Q | P2 | XS | Visual QA: edit-penopts (pen options sheet) | open |  | DK-0315 |  |
| DK-0781 | Ph7 | Q | P2 | XS | Visual QA: edit-highlight (highlighter on text) | open |  | DK-0321 DK-0517 |  |
| DK-0782 | Ph7 | Q | P2 | XS | Visual QA: edit-text (text box editing) | open |  | DK-0047 |  |
| DK-0783 | Ph7 | Q | P2 | XS | Visual QA: edit-shapes (shapes) | open |  | DK-0047 |  |
| DK-0784 | Ph7 | Q | P2 | XS | Visual QA: edit-note (note sheet) | open |  | DK-0319 |  |
| DK-0785 | Ph7 | Q | P2 | XS | Visual QA: edit-annsel (annotation selected) | open |  | DK-0322 |  |
| DK-0786 | Ph7 | Q | P2 | XS | Visual QA: edit-form (form filling + accessory bar) | open |  | DK-0227 DK-0324 |  |
| DK-0787 | Ph7 | Q | P2 | XS | Visual QA: edit-discard (discard dialog) | open |  | DK-0313 |  |
| DK-0788 | Ph7 | Q | P2 | XS | Visual QA: edit-hiopts (highlighter options) | open |  | DK-0316 |  |
| DK-0789 | Ph7 | Q | P2 | XS | Visual QA: edit-textopts (text options) | open |  | DK-0317 |  |
| DK-0790 | Ph7 | Q | P2 | XS | Visual QA: edit-shapesopts (shapes options) | open |  | DK-0318 |  |
| DK-0791 | Ph7 | Q | P2 | XS | Visual QA: edit-eraser (eraser) | open |  | DK-0320 |  |
| DK-0792 | Ph7 | Q | P2 | XS | Visual QA: sign-list (2 saved) | open |  | DK-0326 DK-0519 |  |
| DK-0793 | Ph7 | Q | P2 | XS | Visual QA: sign-empty (empty) | open |  | DK-0326 |  |
| DK-0794 | Ph7 | Q | P2 | XS | Visual QA: sign-placed (Placed signature with date) | open |  | DK-0328 DK-0519 |  |
| DK-0795 | Ph7 | Q | P2 | XS | Visual QA: signature-pad-draw (Draw) | open |  | DK-0327 |  |
| DK-0796 | Ph7 | Q | P2 | XS | Visual QA: signature-pad-type (Type) | open |  | DK-0327 |  |
| DK-0797 | Ph7 | Q | P2 | XS | Visual QA: signature-pad-image (Image) | open |  | DK-0327 |  |
| DK-0798 | Ph7 | Q | P2 | XS | Visual QA: organize-default (default) | open |  | DK-0329 DK-0516 |  |
| DK-0799 | Ph7 | Q | P2 | XS | Visual QA: organize-drag (page lifted mid-drag) | open |  | DK-0331 |  |
| DK-0800 | Ph7 | Q | P2 | XS | Visual QA: organize-selected (3 selected) | open |  | DK-0329 |  |
| DK-0801 | Ph7 | Q | P2 | XS | Visual QA: organize-insert (insert sheet) | open |  | DK-0332 |  |
| DK-0802 | Ph7 | Q | P2 | XS | Visual QA: organize-deleted (after delete toast) | open |  | DK-0333 |  |
| DK-0803 | Ph7 | Q | P2 | XS | Visual QA: organize-pinch (pinch to 5 columns) | open |  | DK-0334 |  |
| DK-0804 | Ph7 | Q | P2 | XS | Visual QA: organize-large (300-page document, thumbnails loading) | open |  | DK-0335 |  |
| DK-0805 | Ph7 | Q | P2 | XS | Visual QA: organize-savemenu (Save menu – copy or replace) | open |  | DK-0329 |  |
| DK-0806 | Ph7 | Q | P2 | XS | Visual QA: scanner-camera-prompt (camera pre-prompt) | open |  | DK-0342 |  |
| DK-0807 | Ph7 | Q | P2 | XS | Visual QA: scanner-camera-denied (permission denied) | open |  | DK-0342 DK-0621 |  |
| DK-0808 | Ph7 | Q | P2 | XS | Visual QA: scanner-camera-nodoc (no document) | open |  | DK-0343 DK-0344 |  |
| DK-0809 | Ph7 | Q | P2 | XS | Visual QA: scanner-camera-quad (document detected) | open |  | DK-0343 DK-0349 DK-0369 |  |
| DK-0810 | Ph7 | Q | P2 | XS | Visual QA: scanner-camera-countdown (auto-capture countdown) | open |  | DK-0338 |  |
| DK-0811 | Ph7 | Q | P2 | XS | Visual QA: scanner-camera-flash (flash menu open) | open |  | DK-0345 |  |
| DK-0812 | Ph7 | Q | P2 | XS | Visual QA: scanner-camera-idfront (ID card – front) | open |  | DK-0340 DK-0346 |  |
| DK-0813 | Ph7 | Q | P2 | XS | Visual QA: scanner-camera-idback (ID card – turn over) | open |  | DK-0340 |  |
| DK-0814 | Ph7 | Q | P2 | XS | Visual QA: scanner-camera-book (Book mode) | open |  | DK-0341 DK-0347 |  |
| DK-0815 | Ph7 | Q | P2 | XS | Visual QA: scanner-camera-batch (Batch – 12 pages) | open |  | DK-0348 |  |
| DK-0816 | Ph7 | Q | P2 | XS | Visual QA: scanner-camera-retake (retake page 3) | open |  | DK-0350 |  |
| DK-0817 | Ph7 | Q | P2 | XS | Visual QA: scanner-camera-far (hint – move closer) | open |  | DK-0344 |  |
| DK-0818 | Ph7 | Q | P2 | XS | Visual QA: scanner-camera-dark (hint – more light needed) | open |  | DK-0344 |  |
| DK-0819 | Ph7 | Q | P2 | XS | Visual QA: scanner-camera-cutoff (hint – fit the whole page) | open |  | DK-0344 |  |
| DK-0820 | Ph7 | Q | P2 | XS | Visual QA: scanner-camera-quad-iphone-se (document detected · iPhone SE) | open |  | DK-0343 |  |
| DK-0821 | Ph7 | Q | P2 | XS | Visual QA: scanner-review-review (S2 – default) | open |  | DK-0352 DK-0356 |  |
| DK-0822 | Ph7 | Q | P2 | XS | Visual QA: scanner-review-crop (S2 – crop + magnifier) | open |  | DK-0353 |  |
| DK-0823 | Ph7 | Q | P2 | XS | Visual QA: scanner-review-filter (S2 – filter strip) | open |  | DK-0339 DK-0354 |  |
| DK-0824 | Ph7 | Q | P2 | XS | Visual QA: scanner-review-applyall (S2 – apply-to-all chip) | open |  | DK-0355 |  |
| DK-0825 | Ph7 | Q | P2 | XS | Visual QA: scanner-review-deleted (S2 – page deleted toast) | open |  | DK-0357 |  |
| DK-0826 | Ph7 | Q | P2 | XS | Visual QA: scanner-review-discard (S2 – discard dialog) | open |  | DK-0358 |  |
| DK-0827 | Ph7 | Q | P2 | XS | Visual QA: scanner-review-save (Save sheet) | open |  | DK-0359 |  |
| DK-0828 | Ph7 | Q | P2 | XS | Visual QA: scanner-review-result (Scan result) | open |  | DK-0360 |  |
| DK-0829 | Ph7 | Q | P2 | XS | Visual QA: scanner-review-reorder (S2 – reordering in tray) | open |  | DK-0352 |  |
| DK-0830 | Ph7 | Q | P2 | XS | Visual QA: scanner-review-jpg (Save sheet – JPG format) | open |  | DK-0359 |  |
| DK-0831 | Ph7 | Q | P2 | XS | Visual QA: scanner-review-book (S2 – Book mode, left/right pages) | open |  | DK-0341 |  |
| DK-0832 | Ph7 | Q | P2 | XS | Visual QA: photo-finder-intro (intro sheet) | open |  | DK-0363 |  |
| DK-0833 | Ph7 | Q | P2 | XS | Visual QA: photo-finder-scanning (scanning card on Home) | open |  | DK-0364 |  |
| DK-0834 | Ph7 | Q | P2 | XS | Visual QA: photo-finder-results (results grid with selection) | open |  | DK-0365 |  |
| DK-0835 | Ph7 | Q | P2 | XS | Visual QA: photo-finder-convert (convert sheet) | open |  | DK-0366 |  |
| DK-0836 | Ph7 | Q | P2 | XS | Visual QA: photo-finder-empty (no documents found) | open |  | DK-0368 |  |
| DK-0837 | Ph7 | Q | P2 | XS | Visual QA: photo-finder-notdoc (long-press – Not a document) | open |  | DK-0367 |  |
| DK-0838 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-t2empty (T2 – empty input) | open |  | DK-0371 |  |
| DK-0839 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-compress (T2 Compress – options) | open |  | DK-0370 DK-0373 DK-0463 DK-0464 DK-0465 |  |
| DK-0840 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-merge (T2 Merge – 4 files) | open |  | DK-0370 DK-0403 DK-0404 DK-0405 |  |
| DK-0841 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-protry (T2 – Pro first-try caption) | open |  | DK-0374 |  |
| DK-0842 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-lockedrow (T2 – locked input row) | open |  | DK-0372 |  |
| DK-0843 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-btnloading (X2 – button loading (2–10 s)) | open |  | DK-0375 |  |
| DK-0844 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-progress (X2 – progress sheet) | open |  | DK-0375 |  |
| DK-0845 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-minibar (X2 – mini job bar) | open |  | DK-0233 DK-0375 |  |
| DK-0846 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-canceldlg (X2 – cancel dialog) | open |  | DK-0376 |  |
| DK-0847 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-failure (X2 – failure state) | open |  | DK-0377 |  |
| DK-0848 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-x1single (X1 – picker, single PDF) | open |  | DK-0235 DK-0387 |  |
| DK-0849 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-x1multi (X1 – picker, 4 files) | open |  | DK-0235 DK-0387 DK-0255 |  |
| DK-0850 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-result (T3 Compress – result) | open |  | DK-0379 DK-0386 DK-0463 DK-0464 DK-0465 |  |
| DK-0851 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-split (T3 – multi-file result (Split)) | open |  | DK-0384 DK-0410 DK-0411 |  |
| DK-0852 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-partial (T3 – partial success (OCR)) | open |  | DK-0383 DK-0475 DK-0476 DK-0477 |  |
| DK-0853 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-savemenu (T3 – save menu) | open |  | DK-0379 DK-0385 |  |
| DK-0854 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-replace (T3 – replace original dialog) | open |  | DK-0380 |  |
| DK-0855 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-discard (T3 – discard dialog) | open |  | DK-0382 |  |
| DK-0856 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-aftersave (T3 – after Save) | open |  | DK-0381 |  |
| DK-0857 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-replaced (T3 – replaced, Undo) | open |  | DK-0226 DK-0380 |  |
| DK-0858 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-mergerange (T2 Merge – page-range sheet) | open |  | DK-0403 DK-0404 DK-0405 |  |
| DK-0859 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-mergefew (T2 Merge – fewer than 2 files) | open |  | DK-0404 DK-0405 |  |
| DK-0860 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-moreopts (T2 Compress – More options open) | open |  | DK-0370 |  |
| DK-0861 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-prosecond (T2 – Pro tool second use (opens paywall)) | open |  | DK-0374 |  |
| DK-0862 | Ph7 | Q | P2 | XS | Visual QA: tool-shell-notifprompt (X2 – notifications pre-prompt) | open |  | DK-0378 |  |
| DK-0863 | Ph7 | Q | P2 | XS | Visual QA: tools-organize-split (ranges + visual markers) | open |  | DK-0409 DK-0410 DK-0411 |  |
| DK-0864 | Ph7 | Q | P2 | XS | Visual QA: tools-organize-extract (grid) | open |  | DK-0415 DK-0416 DK-0417 |  |
| DK-0865 | Ph7 | Q | P2 | XS | Visual QA: tools-organize-rotate (grid + sideways banner) | open |  | DK-0421 DK-0422 DK-0423 |  |
| DK-0866 | Ph7 | Q | P2 | XS | Visual QA: tools-organize-smartsplit (review) | open |  | DK-0427 DK-0428 DK-0429 |  |
| DK-0867 | Ph7 | Q | P2 | XS | Visual QA: tools-organize-splitn (every N pages) | open |  | DK-0409 DK-0410 DK-0411 |  |
| DK-0868 | Ph7 | Q | P2 | XS | Visual QA: tools-organize-splitinvalid (invalid range) | open |  | DK-0410 DK-0411 |  |
| DK-0869 | Ph7 | Q | P2 | XS | Visual QA: tools-organize-smartinput (input) | open |  | DK-0427 DK-0428 DK-0429 |  |
| DK-0870 | Ph7 | Q | P2 | XS | Visual QA: tools-organize-smartprogress (checking uncertain pages) | open |  | DK-0428 DK-0429 |  |
| DK-0871 | Ph7 | Q | P2 | XS | Visual QA: tools-convert-img2pdf (Image to PDF) | open |  | DK-0433 DK-0434 DK-0435 |  |
| DK-0872 | Ph7 | Q | P2 | XS | Visual QA: tools-convert-pdf2img (PDF to images) | open |  | DK-0439 DK-0440 DK-0441 |  |
| DK-0873 | Ph7 | Q | P2 | XS | Visual QA: tools-convert-web (preview) | open |  | DK-0445 DK-0446 DK-0447 |  |
| DK-0874 | Ph7 | Q | P2 | XS | Visual QA: tools-convert-weboffline (offline) | open |  | DK-0445 DK-0446 DK-0447 |  |
| DK-0875 | Ph7 | Q | P2 | XS | Visual QA: tools-convert-pdfa (result with warning) | open |  | DK-0451 DK-0452 DK-0453 |  |
| DK-0876 | Ph7 | Q | P2 | XS | Visual QA: tools-convert-text (result) | open |  | DK-0457 DK-0458 DK-0459 |  |
| DK-0877 | Ph7 | Q | P2 | XS | Visual QA: tools-convert-pdfaopts (options + info sheet) | open |  | DK-0451 DK-0452 DK-0453 |  |
| DK-0878 | Ph7 | Q | P2 | XS | Visual QA: tools-convert-textopts (options) | open |  | DK-0457 DK-0458 DK-0459 |  |
| DK-0879 | Ph7 | Q | P2 | XS | Visual QA: tools-convert-textnotext (no text yet) | open |  | DK-0458 DK-0459 |  |
| DK-0880 | Ph7 | Q | P2 | XS | Visual QA: tools-optimize-ocr (result) | open |  | DK-0475 DK-0476 DK-0477 |  |
| DK-0881 | Ph7 | Q | P2 | XS | Visual QA: tools-optimize-small (already small) | open |  | DK-0464 DK-0465 |  |
| DK-0882 | Ph7 | Q | P2 | XS | Visual QA: tools-optimize-target (target unreachable) | open |  | DK-0464 DK-0465 |  |
| DK-0883 | Ph7 | Q | P2 | XS | Visual QA: tools-optimize-repair (options) | open |  | DK-0469 DK-0470 DK-0471 |  |
| DK-0884 | Ph7 | Q | P2 | XS | Visual QA: tools-optimize-repaired (result) | open |  | DK-0469 DK-0470 DK-0471 |  |
| DK-0885 | Ph7 | Q | P2 | XS | Visual QA: tools-optimize-repairfail (too damaged) | open |  | DK-0470 DK-0471 |  |
| DK-0886 | Ph7 | Q | P2 | XS | Visual QA: tools-security-addpw (mismatch error) | open |  | DK-0499 DK-0500 DK-0501 |  |
| DK-0887 | Ph7 | Q | P2 | XS | Visual QA: tools-security-removepw (wrong password) | open |  | DK-0505 DK-0506 DK-0507 |  |
| DK-0888 | Ph7 | Q | P2 | XS | Visual QA: tools-security-nopw (file has no password) | open |  | DK-0505 DK-0506 DK-0507 |  |
| DK-0889 | Ph7 | Q | P2 | XS | Visual QA: tools-edit-pagenum (Add page numbers) | open |  | DK-0481 DK-0482 DK-0483 |  |
| DK-0890 | Ph7 | Q | P2 | XS | Visual QA: tools-edit-watermark (Add watermark) | open |  | DK-0487 DK-0488 DK-0489 |  |
| DK-0891 | Ph7 | Q | P2 | XS | Visual QA: tools-edit-crop (Crop pages) | open |  | DK-0493 DK-0494 DK-0495 |  |
| DK-0892 | Ph7 | Q | P2 | XS | Visual QA: tools-edit-formlock (lock values dialog) | open |  | DK-0518 |  |
| DK-0893 | Ph7 | Q | P2 | XS | Visual QA: tools-edit-noform (no fields dialog) | open |  | DK-0518 |  |
| DK-0894 | Ph7 | Q | P2 | XS | Visual QA: tools-edit-xfa (XFA not supported) | open |  | DK-0518 |  |
| DK-0895 | Ph7 | Q | P2 | XS | Visual QA: black-out-find (1 Find) | open |  | DK-0521 DK-0522 |  |
| DK-0896 | Ph7 | Q | P2 | XS | Visual QA: black-out-review (2 Review boxes) | open |  | DK-0523 |  |
| DK-0897 | Ph7 | Q | P2 | XS | Visual QA: black-out-confirm (3 Confirm) | open |  | DK-0524 |  |
| DK-0898 | Ph7 | Q | P2 | XS | Visual QA: black-out-result (Result – verified) | open |  | DK-0525 |  |
| DK-0899 | Ph7 | Q | P2 | XS | Visual QA: black-out-failed (Verification failed) | open |  | DK-0527 |  |
| DK-0900 | Ph7 | Q | P2 | XS | Visual QA: black-out-ocrstep (Scan without text – recognising text first) | open |  | DK-0526 |  |
| DK-0901 | Ph7 | Q | P2 | XS | Visual QA: compare-setup (setup) | open |  | DK-0530 |  |
| DK-0902 | Ph7 | Q | P2 | XS | Visual QA: compare-single (single view, overlay) | open |  | DK-0531 |  |
| DK-0903 | Ph7 | Q | P2 | XS | Visual QA: compare-list (change list) | open |  | DK-0532 |  |
| DK-0904 | Ph7 | Q | P2 | XS | Visual QA: compare-scans (scans banner (suggest Visual)) | open |  | DK-0534 |  |
| DK-0905 | Ph7 | Q | P2 | XS | Visual QA: compare-side-by-side (compare-side-by-side) | open |  | DK-0533 |  |
| DK-0906 | Ph7 | Q | P2 | XS | Visual QA: automation-assets (Extract images & text – result) | open |  | DK-0511 DK-0512 DK-0513 |  |
| DK-0907 | Ph7 | Q | P2 | XS | Visual QA: automation-batchtool (Batch – choose tool) | open |  | DK-0535 |  |
| DK-0908 | Ph7 | Q | P2 | XS | Visual QA: automation-queue (Batch – queue) | open |  | DK-0535 |  |
| DK-0909 | Ph7 | Q | P2 | XS | Visual QA: automation-batchresult (Batch – result) | open |  | DK-0535 |  |
| DK-0910 | Ph7 | Q | P2 | XS | Visual QA: automation-wflist (Workflows – list) | open |  | DK-0537 DK-0544 |  |
| DK-0911 | Ph7 | Q | P2 | XS | Visual QA: automation-builder (Workflows – builder) | open |  | DK-0538 DK-0544 |  |
| DK-0912 | Ph7 | Q | P2 | XS | Visual QA: automation-wfrun (Workflows – run) | open |  | DK-0539 |  |
| DK-0913 | Ph7 | Q | P2 | XS | Visual QA: automation-extractopts (Extract images & text – options) | open |  | DK-0511 DK-0512 DK-0513 |  |
| DK-0914 | Ph7 | Q | P2 | XS | Visual QA: automation-noimages (Extract – no images found) | open |  | DK-0512 DK-0513 |  |
| DK-0915 | Ph7 | Q | P2 | XS | Visual QA: automation-batchfiles (Batch – choose files) | open |  | DK-0535 |  |
| DK-0916 | Ph7 | Q | P2 | XS | Visual QA: automation-batchopts (Batch – shared options) | open |  | DK-0535 |  |
| DK-0917 | Ph7 | Q | P2 | XS | Visual QA: automation-wfpick (Workflows – pick files to run) | open |  | DK-0539 |  |
| DK-0918 | Ph7 | Q | P2 | XS | Visual QA: ai-noteligible (not eligible) | open |  | DK-0553 |  |
| DK-0919 | Ph7 | Q | P2 | XS | Visual QA: ai-download (model download) | open |  | DK-0554 |  |
| DK-0920 | Ph7 | Q | P2 | XS | Visual QA: ai-downloading (downloading) | open |  | DK-0555 |  |
| DK-0921 | Ph7 | Q | P2 | XS | Visual QA: ai-firstuse (first-use notice) | open |  | DK-0556 |  |
| DK-0922 | Ph7 | Q | P2 | XS | Visual QA: ai-streaming (summary streaming) | open |  | DK-0560 |  |
| DK-0923 | Ph7 | Q | P2 | XS | Visual QA: ai-done (summary done) | open |  | DK-0559 DK-0561 DK-0541 |  |
| DK-0924 | Ph7 | Q | P2 | XS | Visual QA: ai-detailed (summary detailed) | open |  | DK-0561 |  |
| DK-0925 | Ph7 | Q | P2 | XS | Visual QA: ai-askempty (Ask – empty) | open |  | DK-0562 DK-0542 |  |
| DK-0926 | Ph7 | Q | P2 | XS | Visual QA: ai-ask (Ask – thread) | open |  | DK-0563 |  |
| DK-0927 | Ph7 | Q | P2 | XS | Visual QA: ai-notfound (Ask – not found) | open |  | DK-0564 |  |
| DK-0928 | Ph7 | Q | P2 | XS | Visual QA: ai-tropts (Translate – options) | open |  | DK-0566 DK-0543 |  |
| DK-0929 | Ph7 | Q | P2 | XS | Visual QA: ai-trboth (Translate – both view) | open |  | DK-0567 |  |
| DK-0930 | Ph7 | Q | P2 | XS | Visual QA: ai-engine (engine sheet) | open |  | DK-0566 |  |
| DK-0931 | Ph7 | Q | P2 | XS | Visual QA: ai-lang (language sheet) | open |  | DK-0566 |  |
| DK-0932 | Ph7 | Q | P2 | XS | Visual QA: ai-notext (no-text banner) | open |  | DK-0557 |  |
| DK-0933 | Ph7 | Q | P2 | XS | Visual QA: ai-lowmem (low-memory banner) | open |  | DK-0558 |  |
| DK-0934 | Ph7 | Q | P2 | XS | Visual QA: ai-askselection (Ask – prefilled from text selection) | open |  | DK-0565 |  |
| DK-0935 | Ph7 | Q | P2 | XS | Visual QA: ai-dlbar (model downloading – mini bar) | open |  | DK-0555 |  |
| DK-0936 | Ph7 | Q | P2 | XS | Visual QA: me-me (M1 Me – free) | open |  | DK-0570 DK-0578 |  |
| DK-0937 | Ph7 | Q | P2 | XS | Visual QA: me-mepro (M1 Me – Pro) | open |  | DK-0570 |  |
| DK-0938 | Ph7 | Q | P2 | XS | Visual QA: me-models (M2 AI models) | open |  | DK-0568 |  |
| DK-0939 | Ph7 | Q | P2 | XS | Visual QA: me-modeldetail (M2 model detail) | open |  | DK-0568 |  |
| DK-0940 | Ph7 | Q | P2 | XS | Visual QA: me-scanning (M3 Scanning) | open |  | DK-0361 DK-0571 DK-0369 |  |
| DK-0941 | Ph7 | Q | P2 | XS | Visual QA: me-files (M3 Files & storage) | open |  | DK-0572 DK-0281 |  |
| DK-0942 | Ph7 | Q | P2 | XS | Visual QA: me-security (M3 Security) | open |  | DK-0573 DK-0292 |  |
| DK-0943 | Ph7 | Q | P2 | XS | Visual QA: me-appearance (M3 Appearance) | open |  | DK-0047 DK-0574 |  |
| DK-0944 | Ph7 | Q | P2 | XS | Visual QA: me-language (M3 Language) | open |  | DK-0575 DK-0636 |  |
| DK-0945 | Ph7 | Q | P2 | XS | Visual QA: me-privacy (M3 Privacy) | open |  | DK-0576 |  |
| DK-0946 | Ph7 | Q | P2 | XS | Visual QA: me-licences (Licences list) | open |  | DK-0577 |  |
| DK-0947 | Ph7 | Q | P2 | XS | Visual QA: me-licence (Licence detail) | open |  | DK-0577 |  |
| DK-0948 | Ph7 | Q | P2 | XS | Visual QA: me-signatures (Me – Signatures) | open |  | DK-0325 |  |
| DK-0949 | Ph7 | Q | P2 | XS | Visual QA: me-filename (Scanning – file name editor) | open |  | DK-0361 DK-0571 |  |
| DK-0950 | Ph7 | Q | P2 | XS | Visual QA: me-filter (Scanning – default filter picker) | open |  | DK-0361 DK-0571 |  |
| DK-0951 | Ph7 | Q | P2 | XS | Visual QA: paywall-tool (se) | open |  | DK-0580 |  |
| DK-0952 | Ph7 | Q | P2 | XS | Visual QA: paywall-me (me) | open |  | DK-0580 |  |
| DK-0953 | Ph7 | Q | P2 | XS | Visual QA: paywall-purchasing (purchasing) | open |  | DK-0581 |  |
| DK-0954 | Ph7 | Q | P2 | XS | Visual QA: paywall-success (success) | open |  | DK-0582 |  |
| DK-0955 | Ph7 | Q | P2 | XS | Visual QA: paywall-error (error) | open |  | DK-0583 |  |
| DK-0956 | Ph7 | Q | P2 | XS | Visual QA: paywall-restore (restore) | open |  | DK-0584 |  |
| DK-0957 | Ph7 | Q | P2 | XS | Visual QA: paywall-restored (restored) | open |  | DK-0584 |  |
| DK-0958 | Ph7 | Q | P2 | XS | Visual QA: paywall-tool-iphone-se (se · iPhone SE) | open |  | DK-0580 |  |
| DK-0959 | Ph7 | Q | P2 | XS | Visual QA: tablet-home-landscape (tablet-home-landscape) | open |  | DK-0232 DK-0649 |  |
| DK-0960 | Ph7 | Q | P2 | XS | Visual QA: tablet-home-portrait (tablet-home-portrait) | open |  | DK-0649 |  |
| DK-0961 | Ph7 | Q | P2 | XS | Visual QA: tablet-tools-landscape (tablet-tools-landscape) | open |  | DK-0650 |  |
| DK-0962 | Ph7 | Q | P2 | XS | Visual QA: tablet-tools-portrait (tablet-tools-portrait) | open |  | DK-0650 |  |
| DK-0963 | Ph7 | Q | P2 | XS | Visual QA: tablet-files-landscape (tablet-files-landscape) | open |  | DK-0232 DK-0279 DK-0655 |  |
| DK-0964 | Ph7 | Q | P2 | XS | Visual QA: tablet-files-portrait (tablet-files-portrait) | open |  | DK-0279 |  |
| DK-0965 | Ph7 | Q | P2 | XS | Visual QA: tablet-viewer-landscape (tablet-viewer-landscape) | open |  | DK-0310 |  |
| DK-0966 | Ph7 | Q | P2 | XS | Visual QA: tablet-viewer-portrait (tablet-viewer-portrait) | open |  | DK-0310 |  |
| DK-0967 | Ph7 | Q | P2 | XS | Visual QA: tablet-organize-landscape (tablet-organize-landscape) | open |  | DK-0651 |  |
| DK-0968 | Ph7 | Q | P2 | XS | Visual QA: tablet-organize-portrait (tablet-organize-portrait) | open |  | DK-0651 |  |
| DK-0969 | Ph7 | Q | P2 | XS | Visual QA: tablet-compress-options-landscape (options) | open |  | DK-0388 |  |
| DK-0970 | Ph7 | Q | P2 | XS | Visual QA: tablet-compress-result-landscape (result) | open |  | DK-0388 |  |
| DK-0971 | Ph7 | Q | P2 | XS | Visual QA: tablet-compress-options-portrait (options) | open |  | DK-0388 |  |
| DK-0972 | Ph7 | Q | P2 | XS | Visual QA: tablet-compress-result-portrait (result) | open |  | DK-0232 |  |
| DK-0973 | Ph7 | Q | P2 | XS | Visual QA: tablet-compare-landscape (tablet-compare-landscape) | open |  | DK-0533 DK-0653 |  |
| DK-0974 | Ph7 | Q | P2 | XS | Visual QA: tablet-compare-portrait (tablet-compare-portrait) | open |  | DK-0653 |  |
| DK-0975 | Ph7 | Q | P2 | XS | Visual QA: tablet-paywall-landscape (tablet-paywall-landscape) | open |  | DK-0580 DK-0654 |  |
| DK-0976 | Ph7 | Q | P2 | XS | Visual QA: tablet-paywall-portrait (tablet-paywall-portrait) | open |  | DK-0654 |  |
| DK-0977 | Ph7 | Q | P2 | XS | Visual QA: tablet-scanner-landscape (tablet-scanner-landscape) | open |  | DK-0652 |  |
| DK-0978 | Ph7 | Q | P2 | XS | Visual QA: tablet-scanner-portrait (tablet-scanner-portrait) | open |  | DK-0652 |  |
| DK-0979 | Ph7 | Q | P2 | XS | Visual QA: system-surfaces (system-surfaces) | open |  | DK-0072 DK-0587 DK-0588 DK-0589 DK-0590 DK-0591 DK-0592 DK-0593 |  |
| DK-0980 | Ph7 | Q | P2 | XS | Visual QA: global-states (global-states) | open |  | DK-0601 DK-0602 DK-0603 DK-0604 DK-0605 DK-0606 DK-0607 DK-0608 |  |
| DK-0981 | Ph7 | Q | P2 | XS | Visual QA: text-200-percent (text-200-percent) | open |  | DK-0037 |  |
| DK-0982 | Ph7 | Q | P2 | XS | Visual QA: foundations (foundations) | open |  | DK-0024 DK-0025 DK-0026 DK-0027 DK-0028 DK-0029 DK-0030 DK-0031 DK-0032 DK-0033 DK-0034 DK-0036 DK-0038 DK-0047 DK-0048 DK-1009 |  |
| DK-0983 | Ph7 | Q | P2 | XS | Visual QA: components (components) | open |  | DK-0048 DK-0049 DK-0074 DK-0076 DK-0078 DK-0080 DK-0082 DK-0084 DK-0086 DK-0088 DK-0090 DK-0092 DK-0096 DK-0098 DK-0102 DK-0104 DK-0106 DK-0108 DK-0110 DK-0112 DK-0114 DK-0116 DK-0118 DK-0120 DK-0122 DK-0124 DK-0126 DK-0128 DK-0130 DK-0132 DK-0134 DK-0136 DK-0138 DK-0144 DK-0146 DK-0164 DK-0166 DK-0168 DK-0170 DK-0172 DK-0174 DK-0178 DK-0182 DK-0184 DK-0186 DK-0188 DK-0190 DK-0192 DK-0194 DK-0196 DK-0198 DK-0200 DK-0231 DK-1009 |  |
| DK-0984 | Ph7 | Q | P2 | XS | Visual QA: components-part-2 (components-part-2) | open |  | DK-0094 DK-0100 DK-0140 DK-0142 DK-0148 DK-0150 DK-0152 DK-0154 DK-0156 DK-0158 DK-0160 DK-0162 DK-0176 DK-0180 DK-0202 DK-0204 DK-0206 DK-0208 DK-0210 DK-0212 DK-0214 DK-0216 DK-0218 DK-0220 |  |
| DK-0985 | Ph7 | Q | P2 | XS | Visual QA: illustrations-overview (illustrations-overview) | open |  | DK-0050 DK-0051 DK-0052 DK-0053 DK-0054 DK-0055 DK-0056 DK-0057 DK-0058 DK-0059 DK-0060 DK-0061 DK-0062 DK-0063 DK-0064 DK-0065 DK-0066 DK-0067 DK-0068 DK-0069 |  |
| DK-0986 | Ph7 | Q | P2 | XS | Visual QA: motion (motion) | open |  | DK-0039 DK-0040 DK-0041 DK-0042 DK-0043 DK-0044 DK-0045 DK-0046 |  |
| DK-0987 | Ph7 | Q | P2 | XS | Visual QA: app-icon-and-store-assets (app-icon-and-store-assets) | open |  | DK-0070 DK-0071 DK-0072 DK-0684 DK-0685 DK-0686 DK-0687 DK-0688 |  |
| DK-0988 | Ph7 | Q | P2 | XS | Visual QA: ill-01-onboarding-1 (ILL-01 · Onboarding 1 — Phone in airplane mode with a page and a check) | open |  | DK-0050 |  |
| DK-0989 | Ph7 | Q | P2 | XS | Visual QA: ill-02-onboarding-2 (ILL-02 · Onboarding 2 — Clean page and a one-time tag) | open |  | DK-0051 |  |
| DK-0990 | Ph7 | Q | P2 | XS | Visual QA: ill-03-onboarding-3 (ILL-03 · Onboarding 3 — Camera, folder, toolbox as card icons) | open |  | DK-0052 |  |
| DK-0991 | Ph7 | Q | P2 | XS | Visual QA: ill-04-home-empty (ILL-04 · Home empty — Two pages with a soft scan frame) | open |  | DK-0053 |  |
| DK-0992 | Ph7 | Q | P2 | XS | Visual QA: ill-05-files-empty (ILL-05 · Files empty — Open folder, page sliding in) | open |  | DK-0054 |  |
| DK-0993 | Ph7 | Q | P2 | XS | Visual QA: ill-06-folder-empty (ILL-06 · Folder empty — Empty folder outline) | open |  | DK-0055 |  |
| DK-0994 | Ph7 | Q | P2 | XS | Visual QA: ill-07-search-no-results (ILL-07 · Search no results — Magnifier over a blank page) | open |  | DK-0056 |  |
| DK-0995 | Ph7 | Q | P2 | XS | Visual QA: ill-08-trash-empty (ILL-08 · Trash empty — Empty bin with a check) | open |  | DK-0057 |  |
| DK-0996 | Ph7 | Q | P2 | XS | Visual QA: ill-09-locked-folder-intro (ILL-09 · Locked folder intro — Folder with lock and fingerprint) | open |  | DK-0058 |  |
| DK-0997 | Ph7 | Q | P2 | XS | Visual QA: ill-10-camera-denied (ILL-10 · Camera denied — Camera with a slash and a page) | open |  | DK-0059 |  |
| DK-0998 | Ph7 | Q | P2 | XS | Visual QA: ill-11-ai-model-needed (ILL-11 · AI model needed — Page with a chip and download arrow) | open |  | DK-0060 |  |
| DK-0999 | Ph7 | Q | P2 | XS | Visual QA: ill-12-ai-first-use-notice (ILL-12 · AI first-use notice — Page, speech bubble and check magnifier) | open |  | DK-0061 |  |
| DK-1000 | Ph7 | Q | P2 | XS | Visual QA: ill-13-device-not-eligible (ILL-13 · Device not eligible — Phone with a memory chip, dashed) | open |  | DK-0062 |  |
| DK-1001 | Ph7 | Q | P2 | XS | Visual QA: ill-14-damaged-file (ILL-14 · Damaged file — Page with a torn corner) | open |  | DK-0063 |  |
| DK-1002 | Ph7 | Q | P2 | XS | Visual QA: ill-15-no-signatures-yet (ILL-15 · No signatures yet — Signature line with a pen) | open |  | DK-0064 |  |
| DK-1003 | Ph7 | Q | P2 | XS | Visual QA: ill-16-no-workflows-yet (ILL-16 · No workflows yet — Three connected cards) | open |  | DK-0065 |  |
| DK-1004 | Ph7 | Q | P2 | XS | Visual QA: ill-17-find-documents-in-photos (ILL-17 · Find documents in photos — Photo grid, two marked as documents) | open |  | DK-0066 |  |
| DK-1005 | Ph7 | Q | P2 | XS | Visual QA: ill-18-paywall-header (ILL-18 · Paywall header — Dokulo symbol with a Pro ribbon) | open |  | DK-0067 |  |
| DK-1006 | Ph7 | Q | P2 | XS | Visual QA: ill-19-offline-web-to-pdf (ILL-19 · Offline (Web to PDF) — Globe with cloud-off) | open |  | DK-0068 |  |
| DK-1007 | Ph7 | Q | P2 | XS | Visual QA: ill-20-generic-error (ILL-20 · Generic error — Page with a small warning triangle) | open |  | DK-0069 |  |
| DK-1008 | Ph1 | A | P0 | M | Design: Final logo, wordmark and lockups | open |  | DK-0708 DK-0698 |  |
| DK-1009 | Ph1 | A | P0 | L | Design: Design library (Figma or the Dokulo design canvas) | open |  | DK-0708 |  |
| DK-1010 | Ph1 | A | P0 | L | Design: All phone frames from the inventory | open |  | DK-1009 |  |
| DK-1011 | Ph1 | A | P1 | M | Design: Tablet frames | open |  | DK-1010 |  |
| DK-1012 | Ph1 | A | P0 | M | Design: Clickable prototype of the 6 flows with signature motions | open |  | DK-1010 |  |
| DK-1013 | Ph7 | M | P0 | L | Design: Production assets: app icons, notification icon, widgets, store screenshots, feature graphic | open |  | DK-1008 |  |
| DK-1014 | Ph1 | A | P1 | L | Design: Redlines / Dev Mode annotations on every screen | open |  | DK-1010 |  |
| DK-1015 | Ph1 | A | P0 | S | Design: Design acceptance checklist sign-off | open |  | DK-1010 DK-1011 DK-1014 |  |
| DK-1016 | Ph8 | L | P3 | L | Backlog: PDF → Word / Excel / PowerPoint | later |  |  |  |
| DK-1017 | Ph8 | L | P3 | L | Backlog: Word / Excel / PowerPoint → PDF | later |  |  |  |
| DK-1018 | Ph8 | L | P3 | L | Backlog: Full editing of existing PDF text | later |  |  |  |
| DK-1019 | Ph8 | L | P3 | L | Backlog: Certificate-based (advanced) e-signature | later |  |  |  |
| DK-1020 | Ph8 | L | P3 | L | Backlog: Curved-page straightening (dewarping) | later |  |  |  |
| DK-1021 | Ph8 | L | P3 | L | Backlog: Magic eraser | later |  |  |  |
| DK-1022 | Ph8 | L | P3 | L | Backlog: Business card → contacts | later |  |  |  |
| DK-1023 | Ph8 | L | P3 | L | Backlog: Desktop version (Mac / Windows) | later |  |  |  |
| DK-1024 | Ph8 | L | P3 | L | Backlog: Read aloud (Supertonic 3 TTS) | later |  |  |  |
| DK-1025 | Ph8 | L | P3 | L | Backlog: Voice notes on annotations (STT) | later |  |  |  |
| DK-1026 | Ph8 | L | P3 | L | Backlog: Layout-preserving translation overlay | later |  |  |  |
| DK-1027 | Ph8 | L | P3 | L | Backlog: Semantic retrieval for Ask | later |  |  |  |
| DK-1028 | Ph8 | L | P3 | L | Backlog: Glass theme ("Aurora Glass") | later |  |  |  |
| DK-1029 | Ph8 | L | P3 | L | Backlog: Tablet store screenshots | later |  |  |  |
| DK-1030 | Ph8 | L | P3 | L | Backlog: Open-source qpdf_ffi and pp_ocr | later |  |  |  |
| DK-1031 | Ph8 | L | P3 | L | Backlog: Hy-MT for Sogda | later |  |  |  |
| DK-1032 | Ph1 | W | P1 | S | Decision: the website's domain, hosting and launch date | needs-decision |  |  |  |
| DK-1033 | Ph1 | W | P1 | M | Scaffold the Dokulo website in website/ (EN/DE, the brand's tokens, static export) | assigned | agent-4 |  |  |
| DK-1034 | Ph3 | W | P1 | M | Landing page EN/DE: the tagline, the seven store claims, the tools, the privacy promise | open |  | DK-1033 |  |
| DK-1035 | Ph7 | W | P0 | S | Privacy policy page EN/DE (the URL the store listings need, DK-0679) | open |  | DK-1033 |  |
| DK-1036 | Ph7 | W | P1 | S | Impressum, terms and the open-source licences page EN/DE | open |  | DK-1033 |  |
| DK-1037 | Ph7 | W | P2 | S | Support and FAQ page EN/DE | open |  | DK-1034 |  |
| DK-1038 | Ph7 | W | P1 | S | Deploy the website to the owner's domain | open |  | DK-1032 DK-1034 DK-1035 |  |
| DK-1039 | Ph1 | M | P1 | M | Marketing plan: positioning, audiences, channels, launch calendar (docs/marketing/plan.md) | assigned | agent-5 |  |  |
| DK-1040 | Ph1 | M | P2 | M | Store and keyword research EN/DE: the top PDF apps' listings, keywords, screenshots | assigned | agent-5 |  |  |

## Locks

One holder at a time; `team.py lock <resource> -m why` / `unlock <resource>`.

- `pubspec`: adding or bumping a dependency in any package's `pubspec.yaml` / the lock file.
- `db-schema`: a drift schema change (a new schema version and its migration).
- `shared-look`: a change to the tokens, theme or shared components that re-renders OTHER screens' goldens.
- `l10n`: renaming or deleting ARB keys (adding your own keys needs no lock).
- `ci-config`: CI workflows and the gate scripts.
- `adr-number`: writing the next architecture decision record.

The emulator lock is local, not here: `team.py device`.

| Resource | Owner | Since | Why |
|---|---|---|---|
| pubspec |  |  |  |
| db-schema |  |  |  |
| shared-look |  |  |  |
| l10n |  |  |  |
| ci-config |  |  |  |
| adr-number |  |  |  |

## Handoffs

Newest last. `team.py status` shows yours; `team.py ack` marks them read.

### H-1 · 2026-10-07 20:48 · agent-0 → all · note

The board is set up: 1,031 planned tasks from `dokulo-task-list.csv` plus the website's and marketing's first (DK-1032…DK-1040). Read PLAN.md for the lanes and the order, MEMORY.md for the owner's rules. Everything waits for DK-0001 (the monorepo, agent-0); until it merges, the developers take the compliance tasks assigned below.

### H-2 · 2026-10-07 20:48 · agent-0 → agent-0 · assign · DK-0001

Please take DK-0001 (Create the Flutter monorepo with the five layer packages). `team.py show <id>` prints the spec.

### H-3 · 2026-10-07 20:48 · agent-0 → agent-1 · assign

Please take DK-0672 (Compliance: Licence register); DK-0680 (Compliance: OpenCV module exclusion); DK-0681 (Compliance: MPL/LGPL handling); DK-0678 (Compliance: sRGB ICC profile). `team.py show <id>` prints the spec.

### H-4 · 2026-10-07 20:48 · agent-0 → agent-2 · assign

Please take DK-0674 (Compliance: Gemma licence confirmation); DK-0675 (Compliance: Bergamot models and language pairs); DK-0676 (Compliance: Exclude Hy-MT); DK-0677 (Compliance: ML Kit scanner decision); DK-0683 (Compliance: inference-only AI policy (no training or fine-tuning) and model intake checklist). `team.py show <id>` prints the spec.

### H-5 · 2026-10-07 20:48 · agent-0 → agent-3 · assign · DK-0668

Please take DK-0668 (Device lab: low-end Android (3 GB), mid Android (6–8 GB), older iPhone (11), recent iPhone; tablets). `team.py show <id>` prints the spec.

### H-6 · 2026-10-07 20:48 · agent-0 → agent-4 · assign · DK-1033

Please take DK-1033 (Scaffold the Dokulo website in website/ (EN/DE, the brand's tokens, static export)). `team.py show <id>` prints the spec.

### H-7 · 2026-10-07 20:48 · agent-0 → agent-5 · assign

Please take DK-1039 (Marketing plan: positioning, audiences, channels, launch calendar (docs/marketing/plan.md)); DK-1040 (Store and keyword research EN/DE: the top PDF apps' listings, keywords, screenshots). `team.py show <id>` prints the spec.

### H-8 · 2026-10-07 21:35 · agent-1 → agent-1 · assign · DK-0009

owner's goal: complete M01; agent-1 takes the l10n/platform-strings/device/sample-docs slice

### H-9 · 2026-10-07 21:36 · agent-1 → agent-1 · assign · DK-0016

owner's goal: complete M01; agent-1 takes the l10n/platform-strings/device/sample-docs slice

### H-10 · 2026-10-07 21:36 · agent-1 → agent-1 · assign · DK-0013

owner's goal: complete M01; agent-1 takes the l10n/platform-strings/device/sample-docs slice

### H-11 · 2026-10-07 21:36 · agent-1 → agent-1 · assign · DK-0023

owner's goal: complete M01; agent-1 takes the l10n/platform-strings/device/sample-docs slice

### H-12 · 2026-10-07 21:36 · agent-1 → agent-0 · question

The owner gave me the goal: complete milestone M01 (Platform & engine foundation) together. I've assigned myself DK-0009 (l10n ARB EN/DE), DK-0016 (Info.plist/manifest strings EN/DE), DK-0013 (device capability detection), DK-0023 (fictional sample documents); I start them the moment DK-0001 merges. Until then I finish the M17 compliance tasks (DK-0672 first) that M01 depends on. Suggested split for the rest: you keep the critical path DK-0002/0003/0005/0007/0008/0010 + the CI-gated DK-0012/0015/0017/0018; agent-2 takes DK-0004 (go_router), DK-0006 (visible files folder), DK-0021/0022. Reassign as you see fit. Please ping me (and request my review) as soon as DK-0001 is up as a PR; I'll review it first thing.

### H-13 · 2026-10-07 21:36 · agent-1 → agent-2 · heads-up

The owner wants M01 (Platform & engine foundation) completed. I took DK-0009/0013/0016/0023 and proposed to agent-0 that you take DK-0004 (go_router), DK-0006 (visible files folder), DK-0021, DK-0022 once DK-0001 merges; agent-0 decides. Ask me for reviews any time.

### H-14 · 2026-10-07 21:36 · agent-2 → agent-0 · question

The owner gave me milestone M01 (Platform & engine foundation) to drive with you. Proposed split once DK-0001 merges — you keep the critical path: DK-0002, DK-0003, DK-0004, DK-0005, DK-0006, DK-0007, DK-0008, DK-0010, DK-0015, DK-0390, DK-0391. I take the side branches: DK-0009 (l10n/ARB), DK-0013 (device capability), DK-0016 (Info.plist/manifest), DK-0023 (sample-document set), DK-0014 (developer guide), then DK-0397/DK-0398/DK-0399 after DK-0007. I'll assign those to myself now; reassign with team.py assign if you want it different. Until DK-0001 lands I finish DK-0677 (M17, which M01 depends on). Please ping me the moment DK-0001's PR is up — I'll review it straight away. Is the full M01 issue list (incl. PDF-engine rows) written down anywhere?

### H-15 · 2026-10-07 21:36 · agent-2 → agent-2 · assign · DK-0009

M01 split (owner's goal); see H-14

### H-16 · 2026-10-07 21:36 · agent-2 → agent-2 · assign · DK-0013

M01 split (owner's goal); see H-14

### H-17 · 2026-10-07 21:36 · agent-2 → agent-2 · assign · DK-0016

M01 split (owner's goal); see H-14

### H-18 · 2026-10-07 21:36 · agent-2 → agent-2 · assign · DK-0023

M01 split (owner's goal); see H-14

### H-19 · 2026-10-07 21:36 · agent-2 → agent-2 · assign · DK-0014

M01 split (owner's goal); see H-14

### H-20 · 2026-10-07 21:38 · agent-1 → agent-0 · heads-up

For DK-0002/DK-0005: package:sqlite3 is at 3.x (3.6.0 in the pub cache) and builds SQLite via build hooks; sqlite3_flutter_libs (0.6.0+eol) and sqlcipher_flutter_libs (0.7.0+eol) are obsolete no-ops with 3.x (README: 'remove this package after adopting 3.x'). The plan's 'drift + sqlite3_flutter_libs' and 'sqlcipher_flutter_libs' lines are out of date; SQLCipher for the locked folder would be a sqlite3 hooks option instead. My licence register (DK-0672) records this.

### H-21 · 2026-10-07 21:38 · agent-2 → all · review-request · DK-0677

PR #96 for DK-0677 (Compliance: ML Kit scanner decision) is up. Review it on GitHub and answer with `team.py msg agent-2 --kind review`.

### H-22 · 2026-10-07 21:38 · agent-2 → agent-1 · review · DK-0677

Could you review PR #96 (DK-0677, docs only: ML Kit scanner not used)? It touches the licence-register row of the Technology plan your DK-0672 also edits.

### H-23 · 2026-10-07 21:39 · agent-2 → agent-1 · assign · DK-0009

back to agent-1 per H-13 (we both grabbed it)

### H-24 · 2026-10-07 21:39 · agent-2 → agent-1 · assign · DK-0013

back to agent-1 per H-13 (we both grabbed it)
