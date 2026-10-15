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
| DK-0715 | `02-home/home-default` | Match |
| DK-0716 | `02-home/home-first` | Match |
| DK-0718 | `02-home/home-contjob` | Match, 2 approved |
| DK-0719 | `02-home/home-edit` | 1 fixed, 1 approved |
| DK-0720 | `02-home/home-addtool` | 1 fixed, 1 approved |
| DK-0721 | `02-home/home-procard` | Match |
| DK-0723 | `02-home/home-job` | Match |
| DK-0724 | `02-home/home-jobs3` | Match |
| DK-0725 | `02-home/home-tilemenu` | Match, 2 approved |
| DK-0726 | `02-home/home-scanmenu` | 1 fixed, 1 approved |

## Home (DK-0715, DK-0716, DK-0718 to DK-0721, DK-0723 to DK-0726)

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
- H3. The Scan button's long-press opens a DkMenu (UI spec §11.7): the four
  modes, a divider, then Import photos, on `color.surfaceRaised` with
  `radius.m`, as home-scanmenu. It was Material's MenuAnchor: no divider, a
  dark outline, and the menu ran into the screen's edge.

Approved:

- home-edit shows the Add tile beside 8 pinned tools; DK-0249's criterion
  says adding the 8th hides it. The board's addtool state has 7 pinned.
- Add a tool opens at the large detent (92 %): it lists every tool not
  pinned (20+). The frame's sheet is about 69 % high, between our two
  detents.
- home-contjob: the title is "{tool} · {file}" until the tool's definition
  gives its own (`ToolDefinition.doneTitle`, DK-0247; Compress's says
  "Compressed Mietvertrag.pdf" when agent-2's DK-0463 registers it); the
  sub is `color.textSecondary` throughout, where the frame tints the delta
  green (§11.4 gives the card's sub one colour).
- home-tilemenu and home-scanmenu: DkMenu draws no scrim (§11.7); the
  frames dim the screen behind the menu. home-tilemenu's "Hold and drag to
  reorder" toast is not in the spec: dragging starts from Edit (DK-0249).
- home-scanmenu: the menu keeps DkMenu's placement (beside the anchor, on
  screen); the frame centres it over the button.
- home-procard: See Pro waits for the X3 paywall (DK-0579).
