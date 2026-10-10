# Home, Tools, Files and the locked folder: visual QA

Lane B's screens (M05, M06) against the design export. Each area has a QA
board in the gate (`packages/app_pdf/test/qa/<area>_qa_test.dart`): the real
screens in each frame's state at the frame's size, light and dark. The
boards' goldens (`test/qa/goldens/qa_<area>_<frame>_<theme>.png`) sit next to
the frames' screenshots in `docs/qa/<area>/` (headless Chrome, 520 × 940,
`--virtual-time-budget`, as `docs/qa/design-system.md`). The goldens draw text
as blocks (the test font), so the copy is checked as values against the UI
spec's tables.

| Task | Frame | Result |
| --- | --- | --- |
| DK-0733 | `04-files/files-list` | 2 fixed, 2 approved |
| DK-0734 | `04-files/files-grid` | 2 fixed |
| DK-0737 | `04-files/files-empty` | Match |
| DK-0741 | `04-files/files-sort` | Match |
| DK-0749 | `04-files/files-loading` | Match, 2 approved |

## Files: the root (DK-0733, DK-0734, DK-0737, DK-0741, DK-0749)

Board: `test/qa/files_qa_test.dart` (the real F1 in the shell, through
`pumpFiles`, with the frames' four tagged folders and their counts, three
files today and three in Recently deleted); frames: [files/](files/). Copy:
the search hint, Locked folder, Recently deleted, Folders, Files, the counts,
the sort menu's six options and the empty state match the UI spec §16.1 and
§26.1 in EN and DE.

Fixed:

- F1. A folder's icon is filled in its tag colour, in list and grid, as the
  frames; it was outlined (DkFolderCard).
- F2. A folder row without a menu ends in a chevron (it opens), as
  files-list.
- F3. A grid folder card has a sunken well (`color.surfaceSunken`, 3 : 2)
  around a 48 dp folder, the name and count below, as files-grid; the folder
  sat alone on a 3 : 4 card.

Approved:

- Folders are in name order; the frames show theirs unsorted. A folder has no
  date of its own to sort by.
- The Files header's "Select" comes with multi-select (DK-0263, which waits
  for Share, DK-1077).
- files-loading: the special rows show at once (they never load), and the
  skeleton rows are DkSkeleton's (DK-0620) without dividers; the frame
  shimmers the special rows too.
