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
| DK-0981 | H1 Home, T1 Tools, T3 Compress result | H1 and T3 match; T1: DK-1100 |
| DK-1099 | T2 Compress options, S2 Review, X3 Paywall, A1 Summary | Waits for DK-0463, DK-0352, DK-0580, DK-0561 |

## H1, T1, T3 (DK-0981)

- H1 matches: Your tools in 2 columns, the labels on two lines, the Edit
  link and the privacy line wrap; the page scrolls under the tab bar.
- T3 matches: the result card's headline and its line wrap, the file name
  field and the action bar keep their full labels; the content scrolls above
  the bar.
- T1 fails, DK-1100 (lane B): the grid stays 4 columns (73 px tiles) and
  every tile's label overflows by 36 px. H1 already switches to 2 columns
  from 1.5× text (`pinned_tools.dart`); T1 needs the same. The board's T1
  case is skipped with that id until the fix.

Not built on 2026-10-15, checked in DK-1099: T2 Compress's own options
(DK-0463), S2 Review (DK-0352, PR #1219), X3 Paywall (DK-0580), A1 Summary
(DK-0561).

## Never colour alone (DK-0639)

Checked on 2026-10-15 for every built component and screen: each state a
colour shows is also a shape, an icon or a word.

| Where | The colour | What else says it |
| --- | --- | --- |
| Pro badge (`DkProBadge`) | `color.pro` on `proContainer` | the word "Pro" |
| Banners and errors (`DkBanner`, error sheets) | info, warning, danger tones | an icon per tone and the message text |
| Selected file, page, chip, level card, colour swatch | primary ring or tint | a check (`DkIcons.check` / check circle) |
| Segmented control | the selected segment's surface | raised with a shadow, and its semantics say selected |
| Position picker | primary fill | filled versus outline |
| Editor tool strip | primary icon | a tonal pill behind the selected tool |
| Icon toggles (`DkIconButton.selected`) | primary | the icon filled |
| Tab bar and rail | primary label and icon | the filled icon (outlined when not selected) |
| Storage bar (M3 Files & storage) | segment colours | the legend names each with its size |
| Status dot | green, amber, red | always beside its words ("Ready", "Running") |

Not built yet, owners keep the rule when they land: Compare's change
colours (labels and icons per change, DK-0529), Black out's categories
(named, DK-0520).
