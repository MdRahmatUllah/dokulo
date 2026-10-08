# Design system: visual QA

| Task | Page | How it is checked | Result |
| --- | --- | --- | --- |
| DK-0982 | `00-design-system/foundations.html` | `packages/app_pdf/test/qa/design_parity_test.dart` (in the gate): the export's 27 colour variables in Light and Dark and its 9 type classes against `DkTokens` | Match, except 3 approved colour changes |
| DK-0986 | `00-design-system/motion.html` | The same test: the legend's durations (fast, standard, emphasis, reduced, capture flash) and the three easing curves | Match, except 2 approved curve changes |
| DK-0985, DK-0988..DK-1007 | `00-design-system/illustrations/` | `tools/qa_illustrations.py`, see [illustrations/](illustrations/README.md) | 40/40 match |

The approved changes (the test lists them in `approved`, so a new difference fails the gate):

- `color.success` (light) #117A4B, and `color.outlineStrong` #828C9B light / #666E7B dark: WCAG contrast fixes in PR #1116. The UI spec and Overview & foundations agree; the export predates them.
- `motion.fast` uses `Curves.easeOut` and `motion.standard` uses `Curves.easeInOutCubic`, as Overview & foundations names them. The export's CSS has other `cubic-bezier`s: `0,0,.2,1` decelerates harder than CSS's own `ease-out` (`0,0,.58,1`, which is `Curves.easeOut`), up to 0.20 in value; `.65,0,.35,1` is within 0.025. Docs win; the test bounds both gaps.
