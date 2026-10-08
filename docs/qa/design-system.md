# Design system: visual QA

| Task | Page | How it is checked | Result |
| --- | --- | --- | --- |
| DK-0982 | `00-design-system/foundations.html` | `packages/app_pdf/test/qa/design_parity_test.dart` (in the gate): the export's 27 colour variables in Light and Dark and its 9 type classes against `DkTokens` | Match, except 3 approved colour changes |
| DK-0986 | `00-design-system/motion.html` | The same test: the legend's durations (fast, standard, emphasis, reduced, capture flash) and the three easing curves | Match, except 2 approved curve changes |
| DK-0985, DK-0988..DK-1007 | `00-design-system/illustrations/` | `tools/qa_illustrations.py`, see [illustrations/](illustrations/README.md) | 40/40 match |
| DK-0984 | `00-design-system/components-part-2.html` (Light, Dark; 1440 wide) | Side by side with the catalogue entries' goldens (layout, colour, spacing) and the code (type tokens, copy); `tools/device_checks/catalogue_shots.py` screenshots the same entries on a device with real fonts | 6 deviations fixed (DK-1072), 3 approved, below |

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

