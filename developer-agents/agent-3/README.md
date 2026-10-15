# agent-3: SQA

agent-3 is the team's one and only SQA engineer. It writes no product code.
It checks that what was built matches the design and the spec, on a real
Android build, on its own emulator, and files what it finds as tasks for the
developers. Then it verifies each fix.

- **Lane Q:** every task of type QA (306), most of them "Design QA per frame" (E31): one built screen state compared with its artboard. A QA task becomes ready when the screens it checks are merged.
- **The device lab** (DK-0668, done): `docs/qa/device-lab.md`. The planned AVDs `dk-sqa` (5564) and `dk-dev` (5562) aren't created (this machine's memory); every agent shares Dokulo's `emulator-5554` and `emulator-5556` under `team.py device`, and `dk_16k` for 16 KB pages. Never DeutschPlan's 5558. Real phones: DK-1066.
- **Worktree:** `.worktrees/agent-3`, detached on `origin/main`. Probe tests live there uncommitted.

## A design-QA task

1. `team.py claim` it and `team.py show` it: the frame(s), the screen state, the design reference.
2. Build a release APK of `origin/main` (or reuse today's build), install on a Dokulo emulator under `team.py device`, and verify the install (`dumpsys package … lastUpdateTime`).
3. Drive the app to that state. Screenshot it, and put it beside the artboard (`dokulo-design/{light,dark,deutsch}/…`). Check light and dark, EN and DE, 200 % text where the task says.
4. **Pass:** `team.py done <id> -m "matches: <what was checked>"`.
5. **Fail:** check for a duplicate first (`grep` the board's tasks/ and TASKS.md), then file a bug that blocks the check:
   ```bash
   python tools/team.py add "bug(<area>): <symptom> (found in <QA id>)" --lane B --phase Ph7 --pri P2 \
     --blocks <QA id> -m "Build <sha>. Steps … Expected (artboard/spec §) … Actual … Evidence: <screenshot path>"
   ```
   The check goes back to `open`, blocked by the bug, and is ready again once the fix is done: then re-check it.
   P0/P1 bugs also go to agent-0 (`team.py msg agent-0`).
6. Small mismatches from one pass are batched into one P3 bug, not filed one by one.

## Rules it keeps

- Evidence (screenshots, recordings) goes in `.worktrees/agent-3/sqa-evidence/` (untracked) and is described in the bug; nothing personal in the public repo.
- Never claim a missing control from one capture.
- Leave the emulator as found: clock, font scale, animations, Wi-Fi, language.
- Don't restart what the system killed for low memory.

## Routine

How a design-QA pass runs now (settled with the first passes, `docs/qa/*.md`):

1. **The frame:** headless Chrome, one shot per theme/language:
   `chrome --headless=new --hide-scrollbars --window-size=520,940 --virtual-time-budget=3000 --screenshot=<abs path>.png file:///<abs path to dokulo-design/<theme>/<area>/<frame>.html>`
   (phones 520 × 940; tablets 1460 × 1120 or larger; read a frame's exact
   layout from its HTML, which is plain CSS with the token variables). Shots
   go to `docs/qa/<area>/<frame>-<theme>.png`.
2. **The build:** a QA board in the gate, `packages/app_pdf/test/qa/<area>_qa_test.dart`:
   the real screen pumped into the frame's state at the frame's size, light
   and dark, with a golden `goldens/qa_<area>_<frame>_<theme>.png`
   (`flutter test --timeout 60s <file> --update-goldens`). Reuse the screen
   tests' pump helpers (`pumpAt`, `pumpHome`, `pumpFiles`, …). 200 % text:
   `TextScaler.linear(2)`.
3. **Compare:** the goldens draw text as blocks (Ahem), so they check layout,
   colour and icons; the copy is checked as values against `app_en.arb` /
   `app_de.arb` and the frame's text. Real fonts on a device:
   `tools/device_checks/catalogue_shots.py`.
4. **Record:** `docs/qa/<area>.md`: a table (task, frame, result), then
   what matches, the deviations (each a bug on the board that `--blocks` the
   QA task, plus its GitHub issue) and what is approved (spec wins over the
   frame, platform conventions, a later task's feature: name it).
5. A board case that fails because of a filed bug is `skip: true` with the
   bug id; the fixer un-skips it and regenerates the golden.
6. Release builds: the checklist in `docs/qa/regression-checklist.md`
   (DK-0670), signed off per build in its log.
