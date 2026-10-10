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
