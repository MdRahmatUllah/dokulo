# Design system: visual QA

| Task | Page | How it is checked | Result |
| --- | --- | --- | --- |
| DK-0982 | `00-design-system/foundations.html` | `packages/app_pdf/test/qa/design_parity_test.dart` (in the gate): the export's 27 colour variables in Light and Dark and its 9 type classes against `DkTokens` | Match, except 3 approved colour changes |
| DK-0986 | `00-design-system/motion.html` | The same test: the legend's durations (fast, standard, emphasis, reduced, capture flash) and the three easing curves | Match, except 2 approved curve changes |
| DK-0985, DK-0988..DK-1007 | `00-design-system/illustrations/` | `tools/qa_illustrations.py`, see [illustrations/](illustrations/README.md) | 40/40 match |
| DK-0983 | `00-design-system/components.html` (Light, Dark; 1440 × 2800) | Each of the frame's 12 panels next to the device screenshots of its catalogue entries (`tools/device_checks/catalogue_shots.py` on emulator-5554, real fonts), in [components/](components/) | 5 deviations fixed, 6 approved, below |
| DK-0984 | `00-design-system/components-part-2.html` (Light, Dark; 1440 wide) | Side by side with the catalogue entries' goldens (layout, colour, spacing) and the code (type tokens, copy); `tools/device_checks/catalogue_shots.py` screenshots the same entries on a device with real fonts | 6 deviations fixed (DK-1072), 3 approved, below |
| DK-0980 | `26-global-states/global-states.html` (Light, Dark; 1440 × 1700) | A QA board in the gate, `packages/app_pdf/test/qa/global_states_test.dart`: the frame's regions built from the real empty states, toasts, banners, error catalogue and skeleton, side by side with the frame's screenshots; the copy, icons and actions checked as values | 2 deviations fixed, 6 approved, below |
| DK-0838, DK-0842, DK-0843, DK-0844, DK-0847 | `12-tool-shell/` t2empty, lockedrow, btnloading, progress, failure (Light, Dark; phone) | A QA board in the gate, `packages/app_pdf/test/qa/tool_shell_test.dart`: the real T2 in each state at 393 × 852, side by side with the frames' screenshots | 6 deviations fixed, 3 approved, 1 follow-up, below |
| DK-0845, DK-0846, DK-0855, DK-0856 | `12-tool-shell/` minibar, canceldlg, discard, aftersave (Light, Dark; phone) | The same QA board: the shell at Tools with a running job, T2 after 30 s with Cancel, T3 closed unsaved after a long job, T3 after Save | 2 deviations fixed, 2 approved, below |
| DK-0853, DK-0854, DK-0857 | `12-tool-shell/` savemenu, replace, replaced (Light, Dark; phone) | The same QA board: T3's split Save menu (Save as copy · Replace original · Save to…), then Replace original (the dialog), then Replace (the toast and Done) | Match, 2 approved, below |
| DK-0799, DK-0800, DK-0801, DK-0802, DK-0803 | `09-organize-pages/` organize-drag, -selected, -insert, -deleted, -pinch (Light, Dark; phone) | Goldens in the gate, `organize_<state>_<theme>` in `packages/app_pdf/test/screens/organize_screen_test.dart`: P1 with 12 pages, page 5 long-pressed and held between 8 and 9, the navigator's overlay included; side by side with the frame in [organize/](organize/) | 5 deviations fixed, 3 approved, 1 follow-up, below |

The approved changes (the test lists them in `approved`, so a new difference fails the gate):

- `color.success` (light) #117A4B, and `color.outlineStrong` #828C9B light / #666E7B dark: WCAG contrast fixes in PR #1116. The UI spec and Overview & foundations agree; the export predates them.
- `motion.fast` uses `Curves.easeOut` and `motion.standard` uses `Curves.easeInOutCubic`, as Overview & foundations names them. The export's CSS has other `cubic-bezier`s: `0,0,.2,1` decelerates harder than CSS's own `ease-out` (`0,0,.58,1`, which is `Curves.easeOut`), up to 0.20 in value; `.65,0,.35,1` is within 0.025. Docs win; the test bounds both gaps.

## Components (DK-0983)

Every panel of the frame has its components in code and in the catalogue
(the §11 coverage is in `docs/design-library.md`). Each panel was put next
to the device screenshots of its entries, in both themes:
[components/](components/) holds the frame (`components-light.png`,
`components-dark.png`) and one image per panel, `<panel>-<theme>.png`, the
frame's panel on the left. Order, tokens and copy match, except:

Fixed:

- C1. DkModelCard's quality pill is tinted as every frame draws it:
  "Best quality" `color.successContainer` / `color.success` (`best: true`),
  "Fast" and "Small" `color.primaryContainer` / `color.onPrimaryContainer`;
  it was grey for all. The catalogue's first card is Gemma 4 E2B.
- C2. A DkToolStrip item is at least 56 wide and grows to its label: with
  real fonts "Highlight" (and "Textmarker") was cut to "Highligh…". The
  strip scrolls, so a label is never cut.
- C3. DkLevelCards' title is `type.labelM` on one line, as every frame
  draws it (`.l-m`, nowrap): in `type.titleS` "Recommended" broke mid-word
  ("Recomm / ended") in a third of a 393 dp phone. The UI spec §11.2 says
  so now.
- C4. The selected DkLevelCard's check sits on the card's top-right corner
  (−9 / −9, a 2 dp `color.surface` ring), as the export's `.lv .ck`; it
  took 24 dp from the title.
- C5. DkFolderCard's folder glyph is filled, as every frame draws it
  (`FILL 1`); it was outlined. §11.2 says "filled".

Also fixed, in the screenshot tool: `catalogue_shots_test.dart` pumps twice
before each shot. MaterialApp's theme blends in from the last entry's
theme, and an implicit animation (DkIconButton's tonal fill, DkSegmented's
thumb) started from that blend: the first shots showed a dark navy tonal
button in Light.

Approved (the UI spec decides; the frame is a sketch there):

- DkModelCard's Download is a compact secondary button on the right
  (§11.2 "Action"); the frame shows a text link under the progress bar,
  mixing the available and downloading states in one card.
- DkContinueCard and DkProCard have a close × (§11.2: "close × top-right
  (dismiss)"); the frame leaves it out. The Me tab's Pro card has none
  (§ Me, "no close button here").
- The tool tile's Pro badge is `DkProBadge` small, top-right of the icon
  container (§11.2); the frame draws a medal over the icon.
- The tool strip has Undo and Redo as icon buttons after a divider at the
  far right (§11.8: "Undo/Redo at the far right separated by a divider");
  the frame draws Undo as a sixth labelled tool.
- The camera top bar's flash shows its mode under the icon (S1: "icon +
  tiny label"); the frame shows only the crossed-out flash.
- The skeleton panel's spinner on a `color.primary` square is the
  catalogue's on-primary sample, not a layout.

## Components, part 2 (DK-0984)

Every region of the frame has its component: DkSettingsRow and its group,
DkCheckboxRow, DkRadioRow, DkDropdown, DkPinPad, DkEmptyState,
DkPositionPicker, DkPageTray, DkPageGrid, DkCropOverlay, DkMagnifier,
DkToolOptionsSheet, DkSelectionBar, DkViewerBar, DkNavRail, the DkActionSheet
header, DkSignatureCard, the streaming DkChatBubble, DkDetectionGroup,
DkLoadingSpinner and DkStatusDot. Order, tokens and copy match in both
themes, except:

Fixed (DK-1072):

- D1. An unchecked DkCheckboxRow's count badge is muted (`iconSecondary`), and
  both are DkCountBadge (18 dp), as the export's `.cb`; it was always primary.
- D2. A DkDropdown option can end in a trailing item with its own words for
  screen readers (`optionTrailing`): the export's language menu shows "French
  · 18 MB" to download.
- D3. The highlighter offers its four colours (yellow, green, blue, pink), no
  custom, and opacity 30–60 %, with no thickness or stroke preview (UI spec
  §17.2: it follows the text's lines); it had the pen's palette, a thickness
  and 10–100 %.
- D4. DkSlider draws no tick marks; the export's track is plain.
- D5. The pen offers black, blue ink, red and custom, 1–8 pt (§17.2).
- D6. Text sizes run 8–24 pt (§17.2); the stepper allowed 6–72.

Approved:

- In Dark the on switch's thumb is `color.onPrimary` (dark), not the export's
  white: white on `#8AA8FF` is 2.3:1.
- The pin pad's biometric key takes the screen's icon (`biometricIcon`: face
  where the phone unlocks by face); the catalogue shows the fingerprint, the
  export the face.
- The action sheet's Open · Share row is the screen's (`DkActionSheet.top`),
  and the selection bar's actions are each screen's; the catalogue shows other
  examples. The row's tonal buttons are DkButton's `tonal` (D8).

Fixed (DK-1073, agent-2's second pass):

- D7. DkPositionPicker's watermark-only centre target is a 2 dp dashed
  `color.outlineStrong` circle until it's chosen, as the export's
  `2px dashed var(--ols)`; it was solid. `DkDashedBorder` takes a width.
- D8. DkButton has a `tonal` variant (`color.primaryContainer`,
  `color.onPrimaryContainer`): the file action sheet's Open and Share are "two
  large tonal buttons" (§16.3, the export's `.btn.ton2`), and §11.1's variant
  table had none. `DkIcons.open` is `open_in_new`. The button golden now shows
  every variant (it had been cropped after the third).
- D9. A QA board in the gate, `packages/app_pdf/test/qa/components_part2_test.dart`:
  the frame's components built from the real ones with its data, in its three
  columns at 1440 wide. Side by side: the frame,
  [light](components-part-2/design-light.png) and
  [dark](components-part-2/design-dark.png), and the board,
  [light](../../packages/app_pdf/test/qa/goldens/components_part2_light.png) and
  [dark](../../packages/app_pdf/test/qa/goldens/components_part2_dark.png).
  Text is the test font (Ahem): type is DK-0982's parity test, and the
  components' own strings are checked as text.

Also approved (the spec decides; the export is a sketch there):

- DkPositionPicker's page is `color.pageWhite` in Dark too (§11.4); the frame
  draws it in the surface colour.
- DkEmptyState is a centred column (§11.7); the frame sets the illustration
  to the left.
- DkCropOverlay has four edge handles (§11.5); the frame draws only the top
  one.
- DkSettingsGroup is an inset `color.surface` card without an outline
  (§11.2); the frame's 1 dp outline only shows on its white panel.

## Global states (DK-0980)

Side by side: the frame, [light](global-states/design-light.png) and
[dark](global-states/design-dark.png), and the board,
[light](../../packages/app_pdf/test/qa/goldens/global_states_light.png) and
[dark](../../packages/app_pdf/test/qa/goldens/global_states_dark.png). Every
region has its implementation: the eight empty states (`DkEmptyStates`), the
toasts (`showDkToast`, the theme's SnackBar style), the banners (`DkBanners`,
`DkPermissionBanner`), the error catalogue (`DokuloError`) and the loading
skeleton (`DkSkeleton.fileRows`). Order, tokens and the EN copy match in both
themes (the test checks every title, action and banner string), except:

Fixed:

- G1. Each error situation has the frame's icon and colour
  (`DkErrorSituation.icon` and `iconColor`): lock, broken_image, storage,
  memory, assignment_late in warning or danger, download in primary, cancel
  and cloud_off in `iconSecondary`. New `DkIcons`: `damaged`, `storage`,
  `memory`, `formUnsupported`, `cancelled`, for every screen that shows an
  error (the progress sheet's error state, M10).
- G2. The "no searchable text" banner shows `manage_search` and the camera
  permission banner `no_photography`, as the frame; DkBanner takes an `icon`
  over its variant's. The other permissions keep the warning icon (the frame
  shows none of them).

Approved:

- The Files root and Workflows cards add their second action (Open a file;
  Use a template), as UI spec §26.1 lists them; the frame shows one button.
- The Folder and Photo finder cards' buttons are secondary, and the photo
  finder's illustration is 80, as their own artboards
  (`04-files/files-emptyfolder`, `11-photo-finder/photo-finder-empty`); the
  overview frame draws them primary and full size.
- Banner text is `color.textPrimary` with the icon in the variant's colour
  (§11.7 names no text colour; the frame's tinted inks `--dgf`, `--wrf` and
  `--prof` aren't tokens of Overview & foundations).
- In Dark the toast's action is `inversePrimary` (#2251E6) on the light toast;
  the frame's #8AA8FF is under 3:1 there.
- "Something went wrong on page 14" ends with the situation's own code
  (DK-0190); the frame and §26.3 show an example code.
- The frame's "2 pages deleted" toast is the plural of the copy deck's
  `toast_page_deleted`; P1's multi-delete task adds the plural with its copy.

## Tool shell: T2 and X2 (DK-0838, DK-0842, DK-0843, DK-0844, DK-0847)

Side by side: the frames in [docs/qa/tool-shell/](tool-shell/) (`<frame>-light.png`,
`<frame>-dark.png`, taken with `--virtual-time-budget` so the sheets have
slid in) and the board's goldens,
`packages/app_pdf/test/qa/goldens/tool_shell_<frame>_<theme>.png`, rendered by
the real T2 with the frames' file names and a simulated job. The options
region is each tool's own (Compress's levels come with DK-0463), so the boards
show the shell.

Fixed:

- T1. t2empty: Browse device (and Choose photos) are full width in the picker
  card, which is a 1 dp outlined `color.surface` card with dividers between
  the recent files; it was a raised card with a content-wide button.
- T2. t2empty: with no input the main button says the tool's name ("Compress
  PDF"); it said "Compress 0 pages".
- T3. lockedrow: the locked file's row is a `color.warningContainer` band
  under the card from the file name's edge: the lock and "This file is
  locked" in `color.warning`, then the password field (placeholder
  "Password"; `DkPasswordField.hint`) and a primary compact Unlock on one
  line. It was a label, a full-width field and a secondary button below.
- T4. progress: Cancel and Keep working are sized to their labels from the
  start (they wrap on a narrow sheet); they were two equal halves.
- T5. failure: the title has no code; "Code DK-0190" is its own monospace
  line under "Your original file wasn't changed." (`DokuloError.headline`,
  `DkProgressError.code`, `error_code_line`).
- T6. btnloading: as the frame ("Compressing…" in the button from 2 s).

Approved:

- The failure state's illustration is ILL-20 as the illustration board draws
  it (QA'd in DK-0985/DK-1007) and centred like its text; the frame tints its
  circle danger and sets it to the left.
- A file's meta reads "8.4 MB · 12 pages" in every tool; Merge's "Pages: All"
  link is Merge's own (its task).
- The code is the situation's own (DK-0190 for Unexpected); the frame shows
  the spec's example.

Follow-up: the failure state's Skip this page and Send report by email
(DK-1080): sending needs `url_launcher` (the pubspec lock), skipping a job
that can go on past a page.

### The mini bar, the dialogs and after Save (DK-0845, DK-0846, DK-0855, DK-0856)

Frames: `minibar`, `canceldlg`, `discard`, `aftersave` in
[docs/qa/tool-shell/](tool-shell/); boards: `tool_shell_<frame>_<theme>.png`.

Fixed:

- M1. The mini job bar reads "Compressing · 18 of 40": the tool's busy verb
  (its `busyLabel` without the ellipsis; the tool's name until its definition
  has one) and "18 of 40" (`progress_of`); it read "Compress PDF · Page 18 of
  40".
- M2. "Stop compressing?" is destructive: Stop in `color.danger` beside Keep
  going, as the frame (`DkConfirmation.cancelJob`); it was a primary button.

Approved:

- The mini bar sits above the raised Scan button, clear of it; the frame lets
  it cover the button (decided in DK-0233: it never covers primary buttons).
- With the test font the dialog's two buttons stack (they don't fit side by
  side in Ahem); with the app's fonts they sit side by side as the frames
  (the discard board shows it with shorter labels).

The discard dialog and the after-Save state (the toast "Saved to Files › …"
with Open, then Done) match. After Save's Share · Open row comes with DK-1077
(Share).

### The Save menu and Replace original (DK-0853, DK-0854, DK-0857)

The menu (Save as copy · Replace original · Save to…, above the chevron),
the dialog (danger icon circle with `swap_horiz`, "Replace the original
file?", the Versions line, Cancel and a danger Replace) and the toast
("Replaced · Undo", 10 s) match the frames. Approved:

- After Replace the bar shows Done, as after Save (§20.4 "After Save"); the
  replaced frame still shows the split Save. A replace is a save.
- In the goldens the dialog's buttons stack: the test font (Ahem) is too
  wide for them side by side; with real fonts they sit side by side as in
  the frame (DkConfirmDialog stacks only when the labels don't fit).

Share, beside Open, comes with DK-1077.
## Organize pages: drag, selected, insert, deleted, pinch (DK-0799..DK-0803)

The frame: the sub-bar still says "12 pages", the lifted page floats over
the grid just above the finger, its place stays empty, and a 2 dp
`color.primary` insertion line with end caps shows where it lands. Fixed:

- O1. Lifting a page no longer selects it: P1 selects by tap, and the
  long-press only lifts, so mid-drag the screen stays out of selection mode
  (it showed "1 selected" and the selection bar).
- O2. DkPageGrid leaves the lifted page's place empty while it's dragged;
  it showed the page at 40 %.

Thumbnails are skeletons in the goldens (PDFium doesn't render in widget
tests); the layout, the line and the bars are what the golden checks.

Selected, insert, deleted and pinch (DK-0800..DK-0803), the goldens beside
the frames in [organize/](organize/):

- O3. In selection mode an unselected page shows an empty 20 dp circle
  (`color.surface`, 2 dp `color.outlineStrong`) where the check goes
  (`DkPageThumb.selecting`, from DkPageGrid when anything is selected); it
  showed nothing.
- O4. The insert sheet has "From photos": the photos become pages, one
  each, written by Image to PDF's writer on a worker and inserted at the
  chosen place. "From a scan" needs the scanner to hand its pages back:
  follow-up DK-1082 (#1269).
- O5. The + leaves while the selection bar shows (it did; the first golden
  caught its exit animation).

Approved:

- The selection bar's Delete is `color.danger`, as in Files and the
  components frame; organize-selected draws it neutral.
- The pinch frame shows a hint toast, "Pinch to change thumbnail size";
  neither the UI spec (§18) nor the copy deck has it, so there is none.
- The insert sheet has no "From a scan" row until DK-1082.
