# Design system: visual QA

| Task | Page | How it is checked | Result |
| --- | --- | --- | --- |
| DK-0982 | `00-design-system/foundations.html` | `packages/app_pdf/test/qa/design_parity_test.dart` (in the gate): the export's 27 colour variables in Light and Dark and its 9 type classes against `DkTokens` | Match, except 3 approved colour changes |
| DK-0986 | `00-design-system/motion.html` | The same test: the legend's durations (fast, standard, emphasis, reduced, capture flash) and the three easing curves | Match, except 2 approved curve changes |
| DK-0985, DK-0988..DK-1007 | `00-design-system/illustrations/` | `tools/qa_illustrations.py`, see [illustrations/](illustrations/README.md) | 40/40 match |
| DK-0984 | `00-design-system/components-part-2.html` (Light, Dark; 1440 wide) | Side by side with the catalogue entries' goldens (layout, colour, spacing) and the code (type tokens, copy); `tools/device_checks/catalogue_shots.py` screenshots the same entries on a device with real fonts | 6 deviations fixed (DK-1072), 3 approved, below |
| DK-0980 | `26-global-states/global-states.html` (Light, Dark; 1440 × 1700) | A QA board in the gate, `packages/app_pdf/test/qa/global_states_test.dart`: the frame's regions built from the real empty states, toasts, banners, error catalogue and skeleton, side by side with the frame's screenshots; the copy, icons and actions checked as values | 2 deviations fixed, 6 approved, below |
| DK-0838, DK-0842, DK-0843, DK-0844, DK-0847 | `12-tool-shell/` t2empty, lockedrow, btnloading, progress, failure (Light, Dark; phone) | A QA board in the gate, `packages/app_pdf/test/qa/tool_shell_test.dart`: the real T2 in each state at 393 × 852, side by side with the frames' screenshots | 6 deviations fixed, 3 approved, 1 follow-up, below |

The approved changes (the test lists them in `approved`, so a new difference fails the gate):

- `color.success` (light) #117A4B, and `color.outlineStrong` #828C9B light / #666E7B dark: WCAG contrast fixes in PR #1116. The UI spec and Overview & foundations agree; the export predates them.
- `motion.fast` uses `Curves.easeOut` and `motion.standard` uses `Curves.easeInOutCubic`, as Overview & foundations names them. The export's CSS has other `cubic-bezier`s: `0,0,.2,1` decelerates harder than CSS's own `ease-out` (`0,0,.58,1`, which is `Curves.easeOut`), up to 0.20 in value; `.65,0,.35,1` is within 0.025. Docs win; the test bounds both gaps.

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
