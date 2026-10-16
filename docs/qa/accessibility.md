# 200 % text: visual QA

The `27-accessibility/text-200-percent` frame (UI spec §28, §32.2): seven
phone panels at 200 % text, light and dark. The rule it shows: the tool grid
drops to 2 columns, level cards stack, buttons wrap to two lines instead of
truncating, content scrolls, nothing is clipped. Frames: [accessibility/](accessibility/),
headless Chrome at 3250 × 1250. Boards, at 393 × 852 with
`TextScaler.linear(2)`: `test/qa/text_200_qa_test.dart` (H1, T1;
`qa_text200_<panel>_<theme>.png`) and `test/qa/tool_shell_test.dart` (T3;
`tool_shell_result_200_<theme>.png`).

| Task | Panels | Result |
| --- | --- | --- |
| DK-0981 | H1 Home, T1 Tools, T3 Compress result | Match (T1 after DK-1100's fix, #1392) |
| DK-1099 | T2 Compress options, S2 Review, X3 Paywall, A1 Summary | Waits for DK-0463, DK-0352, DK-0580, DK-0561 |

## H1, T1, T3 (DK-0981)

- H1 matches: Your tools in 2 columns, the labels on two lines, the Edit
  link and the privacy line wrap; the page scrolls under the tab bar.
- T3 matches: the result card's headline and its line wrap, the file name
  field and the action bar keep their full labels; the content scrolls above
  the bar.
- T1 failed, DK-1100: the grid stayed 4 columns (73 px tiles) and every
  tile's label overflowed by 36 px. Fixed in DK-0657: H1 and T1 share
  `toolGrid` (2 across on a phone from 160 % text); the board's T1 case
  runs again (`qa_text200_tools_*`). The same pass found H1's tiles 5.6 px
  short at 375 dp and 100 % text: phone tiles are now 104 dp high at any
  width (`toolTileAspect`).

Not built on 2026-10-15, checked in DK-1099: T2 Compress's own options
(DK-0463), S2 Review (DK-0352, PR #1219), X3 Paywall (DK-0580), A1 Summary
(DK-0561).

## Screen readers (DK-0637)

Automated, in the gate:

- `test/a11y/screen_reader_test.dart`: every screen the router reaches (43:
  onboarding, the four tabs, F1 search, Recently deleted, F2, M1, M2,
  Signatures, M3 Security and Files & storage, S1, and T2 of every tool in
  the catalogue), as it first opens at 393 × 852, meets Flutter's
  `labeledTapTargetGuideline`: no control a screen reader can tap is
  unlabelled. All pass. (A probe with an unlabelled `GestureDetector` fails
  it, so the check is live.)
- Reading order on the three screens the UI spec names (§28: viewer,
  scanner, result), with the traversal TalkBack uses
  (`simulatedAccessibilityTraversal`). The spec asks for an order but gives
  none; the order checked is the visual one, top to bottom, which is what
  these tests now pin:
  - T3 (`tool_result_screen_test`): Close, the tool's name, the result card,
    File name, Save to, Share, Open, Save, More ways to save. Matches.
  - S1 (`s1_screen_test`): Close scanner, Flash, Auto-capture, Grid, Scanner
    settings, the hint, the four modes, Import from photos, Take photo.
    Matches.
  - V1 (`viewer_screen_test`): fails, **DK-1105** (lane C). The first stop
    is a full-screen focusable node with no label, then every text line of
    the visible pages, and only then Back, the name, Search and More, then
    the bottom bar. The test (expected: bar, pages, bottom bar, no empty
    stop) is skipped with the id until the fix.
- Already covered by component tests: a Pro tool tile reads "Black out
  (redact), Pro" (`dk_tool_tile_test`); a thumbnail reads "Page 3 of 12",
  selected, in EN and DE (`dk_page_thumb_test`); the components' labels and
  tap targets (`catalogue_test`).

Manual: TalkBack and VoiceOver passes need a device with them (TalkBack
is not on every emulator image; VoiceOver needs an iPhone): both are
in DK-1106 (Real-device checks).
