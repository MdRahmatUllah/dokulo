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
| DK-0710 | `01-onboarding/onboarding-launch` | Match, 1 approved |
| DK-0711 | `01-onboarding/onboarding-o1` | Match, 1 approved |
| DK-0712 | `01-onboarding/onboarding-o2` | Match, 1 approved |
| DK-0713 | `01-onboarding/onboarding-o3` | Match |
| DK-0714 | `01-onboarding/onboarding-o1-iphone-se` (375 × 667) | Match, 1 approved |

## Onboarding (DK-0710..DK-0714)

Board: `test/qa/onboarding_qa_test.dart`; frames: [onboarding/](onboarding/).
Copy: every headline, body, card title and sub, Skip and Next match the UI
spec §14.2 in EN and DE (`onb_*`, `empty_action_scan`, `common_skip`,
`common_next`).

Approved:

- O1–O2: the illustration is centred at 22 % from the top, and the headline
  sits 24 below it, as §14.2 specifies. The frames place the illustration
  left of centre and the text block just above the dots. Docs win; the board
  follows the spec.
- Launch: the Dokulo symbol (DkLogo, the export's artwork, DK-1008) on
  `color.background`, as §14.1 and the native splash (`splash_icon`, DK-0073)
  show it. The frame shows the app icon's tile instead; the symbol matches what
  Android 12+ and iOS show before Flutter's first frame.
