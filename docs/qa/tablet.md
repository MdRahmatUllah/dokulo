# Tablets: Home, Tools and Files, visual QA

H1, T1 and F1 on tablets (UI spec §30) against the design export's
`24-tablet` frames, at the frames' sizes: portrait 820 × 1180, landscape
1366 × 1024. Boards: the goldens of `test/screens/home_tablet_test.dart`,
`tools_tablet_test.dart` and `files_tablet_test.dart` (the real screens in
the shell, light and dark); frames: [tablet/](tablet/), headless Chrome at
1460 × 1120 as `docs/qa/design-system.md`. The goldens draw text as blocks,
so the layout is what they check; the copy is the phone's.

| Task | Frame | Result |
| --- | --- | --- |
| DK-0959 | `24-tablet/tablet-home-landscape` | Match, 1 approved |
| DK-0960 | `24-tablet/tablet-home-portrait` | Match, 1 approved |
| DK-0961 | `24-tablet/tablet-tools-landscape` | Match |
| DK-0962 | `24-tablet/tablet-tools-portrait` | Match, 1 approved |
| DK-0964 | `24-tablet/tablet-files-portrait` | Match, 2 approved |
| DK-0972 | `24-tablet/tablet-compress-result-portrait` | Match, 3 approved, below |
| DK-0965 | `24-tablet/tablet-viewer-landscape` | Match, 1 fixed, 3 approved, below |
| DK-0966 | `24-tablet/tablet-viewer-portrait` | Match, 1 approved, below |

What matches: the navigation rail from 840 dp (DK-0168); Home's tools 6
across in portrait and 8 in landscape, Recent in 2 columns in portrait and
in a 360 column on the right in landscape, Open a file at its own width;
Tools 6 across in portrait and, in landscape, 8 across with the categories
as a 200 sidebar (the title, All and each category with its count, the
selected one tinted); Files in a 4-column grid in portrait. The landscape
Files frame (two panes, DK-0963) is checked by `files_tablet_test`'s two
panes golden, built in DK-0279.

Approved:

- Home shows 8 pinned tools on tablets too: pins stay capped at 8
  (DK-0249); the frames fill 12 (portrait) and 16 (landscape) tiles.
- Tools in portrait keeps the category chips under the search field; the
  frame leaves them out. §30 sets only the 6 columns for a medium tablet,
  and the chips are how a phone-width screen jumps to a section.
- Files in portrait keeps the Locked folder and Recently deleted rows
  (§16.1); the frame starts with the folders. Its folder tiles are the 3 : 4
  tiles of §11.2, as on phones ([files-root.md](files-root.md)).

## T3 on the small tablet (DK-0972)

Board: `tool_shell_tablet_result_portrait_<theme>` in
`test/qa/tool_shell_test.dart` (the real T3 after Compress, 820 × 1180);
frames: `tablet-compress-result-portrait-<theme>.png` in [tablet/](tablet/)
(the frame is 820 × 1180, but the export clips it at 1024 high: its action
bar, Share · Open over a full-width Save, is in the HTML only).
Matches: one 640-wide column centred (§30, `ToolLayout`), the result card,
File name, Save to with its chevron, the action bar with Open over the split
Save at the column's width. Approved:

- The top bar is × and the tool's name, as §20.4 row 1 and the phone T3
  frames; the tablet frame adds the tool icon and a More button.
- No "Processed on this tablet" line: §20.4 has none on T3, nor do the phone
  T3 frames (the line is T2's, `privacy_line_tool_tablet`).
- The preview strip (§20.4 row 3) is there; the tablet frame leaves it out.
  Spec wins.

Not on the board: the Next chips (Add password, Share) come with Compress's
own definition (DK-0463: the board's test tool lists no next tools), and
Share beside Open with DK-1077, as on the phone (`design-system.md`).

## Compress on tablets (DK-0969, DK-0970, DK-0971)

Boards: `test/qa/compress_qa_test.dart` (Compress's T2, DK-0463, on the
frame's 12-page 8.4 MB lease: `qa_compress_tablet_landscape_*` at
1366 × 1024, `qa_compress_tablet_portrait_*` at 820 × 1180) and
`tool_shell_test`'s `tablet_result_landscape_*` (T3 at 1366 × 1024); frames
`tablet-compress-*` in [tablet/](tablet/) (the exports clip the frames at
1024 high: their action bars are in the HTML only).

| Task | Frame | Result |
| --- | --- | --- |
| DK-0969 | `tablet-compress-options-landscape` | **DK-1118**: the preview pane isn't Compress's live preview |
| DK-0970 | `tablet-compress-result-landscape` | **DK-1118**: no Before/After or 200 % crop (with DK-0464) |
| DK-0971 | `tablet-compress-options-portrait` | Match |

What matches: the options column at 480 (landscape) beside the pane, and the
640 column centred (portrait); the privacy line, File with Add files, the
level cards with their estimates, the target chips, More options, the
estimate line and the button in the action bar at the column's width.

**DK-1118** (lane C, after DK-0464): on the large tablet the right pane is
DK-0388's generic preview (the input page in T2, the output in T3). The
frames and §30/§21.12 want Compress's own pane: "Live preview ·
Recommended" following the selected level (T2) or "Result preview" (T3), a
Before · After toggle and a 200 % crop of the same area with its caption.
The More options row's colour is DK-1119 (below, `design-system.md`).

## Scanner (S1) on tablets

S1 on tablets (DK-0652, §30) against `tablet-scanner-portrait` and
`-landscape`. Board: `s1_screen_test`'s `s1_tablet_portrait` (820 × 1180) and
`s1_tablet_landscape` (1366 × 1024); frames `tablet-scanner-*` in
[tablet/](tablet/). The portrait export is clipped at 1024 high and drawn
left of its box, like the Compress ones; its HTML has the phone's layout,
the shutter row under the modes.

| Task | Frame | Result |
| --- | --- | --- |
| DK-0977 | `tablet-scanner-landscape` | **DK-1137**: the preview is a 3:4 column with black bars |
| DK-0978 | `tablet-scanner-portrait` | Match |

What matches: portrait keeps the phone's S1 (top bar with flash, Auto, grid
and settings, the Ready hint, the modes above the shutter row with import,
shutter and the page stack); landscape has the 160 dp rail on the right
(page stack, shutter, import) and the modes beside it.

**DK-1137** (P3, lane C): the preview takes the camera's portrait ratio in
landscape too, so a 768 dp column sits between black bars, and the top bar
covers only the column; the frame fills the area left of the rail.

## V1 on tablets (DK-0965, DK-0966)

Board: `viewer_tablet_landscape_<theme>` (1366 × 1024) and
`viewer_tablet_portrait_<theme>` (820 × 1180) in
`test/screens/v1_viewer/goldens/` (`viewer_tablet_test.dart`, the real V1
with its tablet chrome, DK-0310); frames: `tablet-viewer-<orientation>-<theme>.png`
in [tablet/](tablet/). Matches: one top bar with back, the sidebar toggle,
the file name, Search, Edit · Sign · AI · Tools as labelled buttons, Share
and More; no bottom bar; the thumbnail sidebar (120) open in landscape and
closed in portrait; the page pill bottom right; the pages on
`color.surfaceSunken`.

Fixed: AI was a tonal button. In the frames it's tonal only while its pane
is open (landscape) and plain in portrait; with no pane yet it's plain.

Approved:

- No AI pane (400, right) in landscape: A1 is M13 and waits for ai_core
  (DK-0545). AI opens Summarize full-screen until then; the pane lands with
  A1 and AI turns tonal while it's open.
- The page is wider than the frame's: without the pane the canvas is the
  full width, and DkPdfCanvas fits the page to it (fit width, at most 1.3×,
  centred), where the frame leaves about 50 on each side.
- Share uses the platform's icon (Android's in the goldens), as on phones
  (DK-1077); the frame draws iOS's.
