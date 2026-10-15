# V1 viewer: visual QA

The frames of `06-viewer` (light, dark, German) are in `docs/qa/viewer/`,
taken from `dokulo-design/` at 520 × 960 so the whole phone shows. The
implementation's boards are goldens in `packages/app_pdf/test/screens/goldens/`
(`viewer_*_{light,dark,deutsch}.png`), rendered by the real ViewerScreen on
the corpus files (`test/fixtures/`). Goldens use the test font, so text
reads as blocks; the layout, colours and icons are what they check.

## Locked, wrong password, after unlock, damaged (DK-0769, DK-0770, DK-0778, DK-0772)

Fixed in this pass:

- Locked: the card sat in the middle of the screen; the frame puts it 96
  under the top bar with 24 at the sides, and the password field focused
  (the keyboard opens below it). 12 between the title and the field.
- The top bar's file name (the rename target) covered the search button
  when the name was long: search was hidden and its taps renamed the file.
  The name now stops before search and the overflow button
  (viewer_chrome_test checks both taps).
- After unlock: "Unlocked for viewing · Remove password" covered the bottom
  bar. V1's bar is drawn in the body, so its toasts pass the bar's height
  (`showDkToast(above:)`) and sit 16 above it, as in the frame.
- Damaged: 12 between Close and Try Repair (was 8).

Approved deviations:

- Share in the bottom bar is dimmed until Share lands (DK-1077, share_plus).
- "This file can't be opened." keeps its full stop: it is the error
  catalogue's string, shared with T2 and F1.
- One-page files sit centred on the canvas (pdfrx's layout for a page
  shorter than the screen); the frame shows a 12-page file from its top.

## Default, hidden, loading, search, scan search, night, form, link, thumbnails (DK-0763 to DK-0777)

Board: `test/qa/viewer_qa_test.dart`, the real V1 at 393 × 852 on the corpus
lease (3 pages; the frames show 12), light, dark and German
(`qa_viewer_<state>_<theme>.png`); frames in [viewer/](viewer/). Copy checked
as values in EN and DE: "This PDF has fillable fields." / "Diese PDF hat
ausfüllbare Felder.", "This scan has no searchable text." / "Dieser Scan hat
keinen durchsuchbaren Text.", "Open {host} in your browser?" / "{host} im
Browser öffnen?", "This is the only step that leaves Dokulo." / "Das ist der
einzige Schritt, der Dokulo verlässt."

| Task | Frame | Result |
| --- | --- | --- |
| DK-0763 | `viewer-default` | **DK-1111**: page 1 opens under the top bar |
| DK-0764 | `viewer-hidden` | Match: only the page pill |
| DK-0765 | `viewer-loading` | Match, 2 approved |
| DK-0766 | `viewer-search` | Match, 1 approved |
| DK-0767 | `viewer-searchnotext` | Match |
| DK-0771 | `viewer-night` | Match (the bar overlap is DK-1111's) |
| DK-0773 | `viewer-form` | **DK-1111**: the banner's first row is under the top bar |
| DK-0775 | `viewer-link` | Match (`dk_viewer_dialogs_test`'s `viewer_link_*` golden over the canvas) |
| DK-0777 | `viewer-thumbs` | Match |

Deviation, **DK-1111** (lane C): the canvas starts at y = 0 under the
translucent top bar, so on open page 1's title is cut in half and the form
banner shows only "Fill form". The frames start the first page and the banner
below the bar (§17.1: pages may scroll under it later). Search is fine: its
bar is laid out above the canvas.

Approved:

- Loading: the skeleton is page-shaped and white with a small spinner over the
  canvas (DK-0297, DK-0620); the frame shows the spinner on the bare canvas.
  §17.1 asks for a page-shaped block and a small spinner, which this is.
- Loading and search show no page pill (the page count isn't known yet; in
  search the bar's counter says where you are); the frames keep "1 / 12".
- Thumbnails: the board shows the strip's frames (96 tall, the current page
  ringed, numbers under); the page images render asynchronously and show as
  placeholders in a widget test. `viewer_thumb_strip_test`'s goldens and the
  DK-0296 pass cover the images.
