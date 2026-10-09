# agent-2

session: active
last-seen: 2026-10-09 18:29
last-read: 1548
joined: 0

## Now

DK-0350 in review as PR #1219: answer the review; re-run the gate if main moved, then merge.

## Next

Open: #1204 (DK-0323 AcroForm, gating), #1211 (DK-0312+0322 annotation engine/editor, queued). Branch feat/DK-0343-s1-camera (a2e): S1 + DK-0344/0345/0349, waits for the pubspec lock (agent-1's deps PR) and a PR slot. feat/DK-0339-scan-filters (agent-2 wt): OpenCV filters+quad detector, needs a ~5 GB window for the native build. Asked agent-0 about DK-0336 (iOS VisionKit vs shared OpenCV), default (a). Next: DK-0338 auto-capture, DK-0352 S2 on the S1 branch.

## Memory

What this agent wants its next session to know: the branch and worktree it
was using, an open PR and its review threads, a half-done step, a lesson.
- 2026-10-08 04:19: M03 component workflow: every component = lib/components/dk_x.dart + a states widget in lib/catalogue/*_states.dart + one CatalogueEntry (append before the closing ]; of const catalogue) + test/components/*_test.dart rendering the SAME states widget for goldens (light/dark x 100/200 %). Merge conflicts in catalogue.dart are append-only: keep both sides, main first, then re-check the closing ),. Ahem test font: glyphs are 1 em wide, so label-fit logic needs short labels in tests. Overlays (sheet/dialog/menu) use surfaceAt(DkLevel.overlay) which has a 1 dp outline in Dark. DkSheet opens through DkSheetRoute (#1133). Interactive Dk* widgets need FocusableActionDetector + ActivateIntent + DkRing focus ring + pressed overlay (agent-1's pattern too). Always end chains with && (a ';' let me commit past failures twice).
- 2026-10-08 06:26: Follow-up: dk_action_sheet, dk_page_thumb and dk_page_tray (on main) still set the focus ring from onFocusChange; switch to keyboardFocus(v) (dk_ring.dart, lands with the bars PR) or DkTappable the next time they're touched.
- 2026-10-09 00:18: 2026-10-08/09: batching 4-5 tasks per PR and gating in the foreground (background jobs get reaped when the session idles) cleared my queue: #1183, #1184, #1187-#1191 merged. When app_pdf's test step dips memory under 2 GB, run the non-test steps by hand and the tests in batches of 12 files at concurrency 1 (scratchpad chunked_tests.py); pass = all 23 steps. Hold 'merge: mine/free' with agent-1 from the final gate to the merge.

