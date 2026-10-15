# Scanner detection suite

DK-0662 (Technology & Package Plan → Testing and device targets → Test
suites): how well the scanner finds the page (`detectQuad`, DK-0337) across
backgrounds, lighting and angles, recorded per release.

## The suite

`packages/doc_vision/test/scan/detection_suite_test.dart`, part of
doc_vision's tests and so of the gate (`tools/check.py`). It draws its own
photos (the repository is public and holds no one's documents): a 960 ×
1280 desk with a text page, in 4 backgrounds × 7 lightings × 5 placements =
140 cases, plus "no page" on each background.

- Backgrounds: dark wood, a blue cloth, a checked cloth, a light grey desk.
- Lighting: even, dim, bright (over-exposed), a gradient, a hand's shadow
  over the page, a lamp's glare, a shaky-hand blur.
- Placements: straight, tilted, in perspective, small (13 % of the frame),
  large (85 %).

A case passes when every corner is within 25 px (≈ 1.6 % of the photo's
diagonal) of the drawn page: the crop screen shows the corners and the user
can nudge them.

**Blocking cases** (a failure blocks the release; the test fails): dark wood
and the blue cloth, in even, dim and bright light, straight, tilted and in
perspective (18 cases). **Recorded cases** (the other 122): together at least
80 % must pass. "No page" must find nothing on every background.

## Per release

1. Run `flutter test test/scan/detection_suite_test.dart` in
   `packages/doc_vision` (the gate runs it too).
2. It writes `packages/doc_vision/build/detection_suite.md`: the pass rate
   and one row per case with its worst corner. Copy the summary and the
   failing rows into the table below with the release's version.
3. A blocking failure stops the release; a drop in the recorded rate is
   looked at before it ships.
4. On a phone (real-device checks), scan a handful of real pages on the
   same backgrounds and note anything the synthetic set misses.

## Results

### 2026-10-10 (main, before 1.0)

Recorded cases: 98 of 122 pass (80 %, floor 80 %).
 All 18 blocking cases pass; no false page on any background.

The cases that fail (worst corner, or not found):

| Case | Worst corner |
| --- | --- |
| checker · bright · large | not found |
| checker · gradient · large | 34.4 px |
| checker · gradient · perspective | 258.2 px |
| checker · shadow · large | 144.7 px |
| checker · shadow · perspective | 40.1 px |
| checker · shadow · small | 459.8 px |
| checker · shadow · straight | 172.0 px |
| darkWood · shadow · small | 468.3 px |
| darkWood · shadow · straight | 194.5 px |
| darkWood · shadow · tilted | 271.3 px |
| lightDesk · bright · large | not found |
| lightDesk · bright · small | not found |
| lightDesk · dim · large | not found |
| lightDesk · even · large | not found |
| lightDesk · gradient · large | 578.8 px |
| lightDesk · gradient · perspective | 386.0 px |
| lightDesk · gradient · small | 521.6 px |
| lightDesk · gradient · straight | 324.1 px |
| lightDesk · gradient · tilted | 382.2 px |
| lightDesk · shadow · large | 601.0 px |
| lightDesk · shadow · perspective | 194.0 px |
| lightDesk · shadow · small | 188.7 px |
| lightDesk · shadow · straight | 174.7 px |
| lightDesk · shadow · tilted | 212.2 px |

What these say: a shadow across the page's edge is the hardest case (the
shadow's edge outlines a wrong quad); a light desk is found now through the
brightness pass (below), except where a gradient or the over-exposure takes
the page's contrast away.

### What the suite changed in the detector

The first run found a white page on a light desk in no lighting at all: the
edge pass's thresholds follow the frame's brightness, too high for a page
only ~45 grey levels brighter than the desk. `detectQuad` now tries a
second pass when the edges find nothing sure: the text closed over, a
threshold halfway between the desk and the paper (the 40th and 95th
percentiles), the brightest large quad, kept only if it is clearly brighter
than around it and not the whole frame. The recorded rate went from 58 % to
80 %; the blocking cases and doc_vision's other tests are unchanged.
