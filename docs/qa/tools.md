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
| DK-0728 | `03-tools/tools-default` | 1 fixed |
| DK-0729 | `03-tools/tools-chip` | 1 fixed, 2 approved |
| DK-0730 | `03-tools/tools-search` | 2 fixed, 1 approved |
| DK-0731 | `03-tools/tools-searchempty` | Match, 1 approved |
| DK-0732 | `03-tools/tools-about` | Match |

## Tools (DK-0728..DK-0732)

Board: `test/qa/tools_qa_test.dart` (the real T1 through `pumpTools`, without
the shell's tab bar); frames: [tools/](tools/). Copy: the chips, the section
names and counts, the search hint, Cancel, "No tool for “{query}”", "Try
“compress” or “sign”." and About this tool's rows match the UI spec §15.2
and §21 in EN and DE.

Fixed:

- T1. A section's count ("6 tools") sits at the end of its header, as the
  frames; it followed the name.
- T2. Searching, the field moves up in the large title's place, as
  tools-search; the title stayed above it.
- T3. "About Compress PDF" under the results is a text action in
  `color.primary` with the info icon, no chevron, as the frame; it was a
  settings row.
- T4. The pinned chips draw a hairline (`color.outline`) once content
  scrolls under them, as tools-chip and the top bars.

Approved:

- tools-chip: the large title collapses as the sections scroll (§11.6,
  DkLargeTopBar), and the chip row scrolls to keep the selected chip in view;
  the frame keeps the header expanded and the chip row unscrolled.
- tools-search: "shrink" finds Compress PDF only. The frame also lists PDF to
  images through its description "Save pages as smaller JPG images"; the copy
  deck's (§21) is "Save PDF pages as JPG or PNG images." Docs win.
- tools-searchempty: ILL-07 (80) and the copy are centred, as every empty
  state (DkEmptyState); the frame has them high and left of centre.
