# S1 camera: visual QA

S1 (UI spec §19.2) and its camera permission gate (DK-0342) against the
design export's `10-scanner/scanner-camera-*` frames. Board:
`packages/app_pdf/test/qa/scanner_qa_test.dart`, the real
`CameraPermissionGate` + `S1Screen` at 393 × 852 (375 × 667 for the SE
frame), light, dark and German, on the fake camera of `s1_screen_test`
(a light page on a desk, 3:4, so the preview is letterboxed under the top
bar as on a phone); goldens `test/qa/goldens/qa_scanner_<frame>_<theme>.png`.
Frames in [scanner/](scanner/) (headless Chrome, 520 × 960, a 10 s render
budget: the pre-prompt sheet slides in). The frames show three pages already
taken (badge 3); the board starts with none.

Copy, EN and DE, matches §19.2's hint table and the frames: Point at a
document / Richte die Kamera auf ein Dokument, Move closer / Näher
herangehen, Hold steady, More light needed / Mehr Licht nötig, Fit the whole
page in view / Ganze Seite ins Bild bringen, Capturing… / Wird aufgenommen…,
Turn the card over / Karte umdrehen, Retake page 3 / Seite 3 neu aufnehmen,
Allow camera access / Kamerazugriff erlauben (+ body, Continue / Fortfahren,
Not now / Nicht jetzt), Camera access is off / Kamerazugriff ist aus (+
body, Open settings / Einstellungen öffnen).

| Task | Frame | Result |
| --- | --- | --- |
| DK-0806 | `scanner-camera-prompt` | **DK-1120** (P1): no Material, error-styled text |
| DK-0807 | `scanner-camera-denied` | **DK-1120** (P1); the export's frame is broken, below |
| DK-0808 | `scanner-camera-nodoc` | Match |
| DK-0810 | `scanner-camera-countdown` | Match, 1 approved |
| DK-0811 | `scanner-camera-flash` | Match |
| DK-0813 | `scanner-camera-idback` | Match |
| DK-0816 | `scanner-camera-retake` | **DK-1121** (P3): the label isn't the primary pill |
| DK-0817 | `scanner-camera-far` | Match, 1 approved |
| DK-0818 | `scanner-camera-dark` | Match |
| DK-0819 | `scanner-camera-cutoff` | Match |
| DK-0820 | `scanner-camera-quad-iphone-se` | Match |
| DK-0809 | `scanner-camera-quad` | Match (`s1_quad_*` in `test/screens/goldens`) |
| DK-0812 | `scanner-camera-idfront` | Match (`s1_mode_idfront`) |
| DK-0814 | `scanner-camera-book` | Match (`s1_mode_book`) |
| DK-0815 | `scanner-camera-batch` | Match (`s1_mode_batch`) |
| DK-0821 | `scanner-review-review` | Match (`s2_review_*`) |
| DK-0822 | `scanner-review-crop` | Match, 2 approved (`s2_crop_*`) |

**DK-1120** (P1, lane C): the pre-prompt sheet and the "Camera access is
off" screen sit on a bare `ColoredBox`, and neither the gate nor its route
(`dkSlideUpPage`) adds a `Material`. Every text inherits WidgetsApp's error
style: yellow double underlines, in release builds too. Every new user meets
the pre-prompt on their first scan. `camera_permission_gate_test` missed it:
it wraps the gate in a `Scaffold`.

**DK-1121** (P3, lane C): "Retake page 3" is drawn as a hint (`color.cameraChrome`,
invisible on the black band); the frame makes it a `color.primary` pill, so it
reads as a mode (DK-0350's acceptance is the frame).

Approved:

- Countdown: the hint says "Capturing…" with the arc on the shutter, as
  §19.2's table ("Auto capturing"); the frame's pill says "Hold steady".
- Far: the detected quad is drawn on the small page too (§19.2 row 3 draws a
  detected document); the frame shows the page without it.
- The mode switcher sits above the shutter in every state (§19.2 row 4); the
  camera frames with three pages taken leave it out.
- `scanner-camera-denied`'s export is broken: the illustration's wrapper is
  100 % high, so ILL-10 sits at the top left over Close. Its HTML (and the
  gate's doc) is a centred column: the 120 illustration, the title, the body,
  Open settings and Import from photos, which is what the app draws.

## S1 modes and S2 review, crop (DK-0809, DK-0812, DK-0814, DK-0815, DK-0821, DK-0822)

agent-2's goldens of S1 and S2 (`test/screens/goldens/s1_*`, `s2_*`, light,
dark, German) beside the frames in [scanner/](scanner/). Match: the quad
with its rounded stroke and fill; ID front's dashed card guide and "Front
side"; Book's dashed spine and "Align the spine with the line"; Batch's
locked Auto pill, "12 pages" above the tray and the stack; S2's top bar (Add
pages, "Review 6 pages", Save), the large page, "3 of 6", the five edit
actions and the tray with the current page ringed; Crop's overlay with
corner and edge handles over the uncropped page and Cancel / Apply.

Approved (crop):

- "Auto" shows only when the page has a detected quad (the golden's page has
  none; the frame's has one): resetting to a detection that doesn't exist
  would do nothing.
- Cancel and Apply share the bar half and half, as every two-button
  `DkActionBar`; the frame sets them at their own widths on the left.

The S2 states without a golden (apply to all, deleted, discard, reorder,
JPG) and the small deviations of filter, save and result (DK-1125) follow in
the next pass; Book's two pages are DK-1124.

## S2 states, save and result (DK-0823 to DK-0831)

New goldens in `test/screens/s2_screen_test.dart`'s "visual QA" group
(`s2_qa_<frame>_<theme>.png`: apply to all, deleted, discard, reorder, JPG,
light, dark, German); filter, save and result on agent-2's `s2_filter_*`,
`s2_save_*`, `scan_result_*`. Frames in [scanner/](scanner/).

| Task | Frame | Result |
| --- | --- | --- |
| DK-0823 | `scanner-review-filter` | **DK-1125**: the Adjust sliders are stacked |
| DK-0824 | `scanner-review-applyall` | Match: a rotation offers "Apply to all pages" |
| DK-0825 | `scanner-review-deleted` | **DK-1127**: the toast covers the tray |
| DK-0826 | `scanner-review-discard` | **DK-1127**: no danger icon in the dialog |
| DK-0827 | `scanner-review-save` | **DK-1125**: no dividers; Folder on one line |
| DK-0828 | `scanner-review-result` | **DK-1125**: no page strip; the name as text |
| DK-0829 | `scanner-review-reorder` | Match: the lifted page and its empty slot |
| DK-0830 | `scanner-review-jpg` | Match, 1 approved |
| DK-0831 | `scanner-review-book` | **DK-1124**: a spread isn't split into two pages |

Approved: in JPG the save sheet has no "Make text searchable" row (the
frame keeps it): images carry no text layer, and `s2_screen_test` asserts
it on purpose. The filter strip's wide gaps in the goldens are the test
font's wide names, not the layout.
