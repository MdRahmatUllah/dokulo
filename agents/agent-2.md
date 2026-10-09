# agent-2

session: active
last-seen: 2026-10-09 21:55
last-read: 1738
joined: 0

## Now

DK-0520 Black out: detectors (IBAN mod-97, German Steuer-ID check digit, email, phone, DOB, US SSN, UK NI) + AI name/address suggestions — claimed 2026-10-09 21:39.

## Next

1) #1217 (DK-0339/0337/0340/0341): APK + gate --apk running (apk_gate.sh); then merge main, merge, done, close issues. 2) #1219 (S1 camera, 7 tasks): gate --apk, merge. 3) Open PRs from a2f stack: DK-0369 (40e05d38); DK-0353-0356 (bc8a2ba3, b85df6a9, 644c3330); DK-0357/0358 + DK-0359 sheet (103c4fc8, a11e1ba3) - save-sheet tests not run yet. 4) DK-0362 scorer (a2g, f23f0468, stacked on 0339): test in agent-2 after #1217. 5) DK-0359 export pipeline (warp+filter+JPEG in doc_vision, images PDF in doc_core) after both PRs merge. DK-0353..0359 claim when DK-0352/0339 are done.

## Memory

What this agent wants its next session to know: the branch and worktree it
was using, an open PR and its review threads, a half-done step, a lesson.
- 2026-10-08 04:19: M03 component workflow: every component = lib/components/dk_x.dart + a states widget in lib/catalogue/*_states.dart + one CatalogueEntry (append before the closing ]; of const catalogue) + test/components/*_test.dart rendering the SAME states widget for goldens (light/dark x 100/200 %). Merge conflicts in catalogue.dart are append-only: keep both sides, main first, then re-check the closing ),. Ahem test font: glyphs are 1 em wide, so label-fit logic needs short labels in tests. Overlays (sheet/dialog/menu) use surfaceAt(DkLevel.overlay) which has a 1 dp outline in Dark. DkSheet opens through DkSheetRoute (#1133). Interactive Dk* widgets need FocusableActionDetector + ActivateIntent + DkRing focus ring + pressed overlay (agent-1's pattern too). Always end chains with && (a ';' let me commit past failures twice).
- 2026-10-08 06:26: Follow-up: dk_action_sheet, dk_page_thumb and dk_page_tray (on main) still set the focus ring from onFocusChange; switch to keyboardFocus(v) (dk_ring.dart, lands with the bars PR) or DkTappable the next time they're touched.
- 2026-10-09 00:18: 2026-10-08/09: batching 4-5 tasks per PR and gating in the foreground (background jobs get reaped when the session idles) cleared my queue: #1183, #1184, #1187-#1191 merged. When app_pdf's test step dips memory under 2 GB, run the non-test steps by hand and the tests in batches of 12 files at concurrency 1 (scratchpad chunked_tests.py); pass = all 23 steps. Hold 'merge: mine/free' with agent-1 from the final gate to the merge.

