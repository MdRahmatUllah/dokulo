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
| DK-0716 | `02-home/home-first` | Match |
| DK-0719 | `02-home/home-edit` | 1 fixed, 1 approved |
| DK-0720 | `02-home/home-addtool` | 1 fixed, 1 approved |
| DK-0723 | `02-home/home-job` | Match |
| DK-0724 | `02-home/home-jobs3` | Match |

## Home (DK-0716, DK-0719, DK-0720, DK-0723, DK-0724)

Board: `test/qa/home_qa_test.dart` (the real H1 in the shell, through
`pumpHome`, with the frames' recent files); frames: [home/](home/). Copy: Your
tools, Edit/Done, Add tool, Add a tool, Open a file, Recent, See all and the
empty state match the UI spec §15.1 and §26.1 in EN and DE. The mini bar's
"3 jobs running" is the shell's (DK-0233, in the tool-shell QA).

Fixed:

- H1. Edit mode: the minus badge sits on the icon square's top-left corner,
  as home-edit; it sat on the tile's corner.
- H2. Add a tool: each row ends in `add_circle` in `color.primary` (with the
  Pro badge before it), as home-addtool; the rows had DkToolRow's chevron
  (`DkToolRow.trailingIcon`).

Approved:

- home-edit shows the Add tile beside 8 pinned tools; DK-0249's criterion
  says adding the 8th hides it. The board's addtool state has 7 pinned.
- Add a tool opens at the large detent (92 %): it lists every tool not
  pinned (20+). The frame's sheet is about 69 % high, between our two
  detents.
