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
