# agent-2

session: active
last-seen: 2026-10-15 23:18
last-read: 2814
joined: 0

## Now

DK-1124 bug(scanner): a Book-mode capture isn't split into its left and right pages; S2 has no 'left page (split from the spread)' (found in DK-0831) — claimed 2026-10-15 22:45.

## Next

Gating (queue): a2c feat/DK-0324-form-filling (DK-0324, DK-0518), a2f feat/DK-0434-img2pdf-result (DK-0434/0435), a2b feat/DK-1120-camera-gate-material (DK-1120/1121). Ready to gate: agent-2 feat/DK-1124-book-split; a2g feat/DK-0520-redaction-2 (DK-0520/0528, suite strengthened); a2h feat/DK-0529-compare-2 (fixed); a2e feat/DK-0536-workflows-2 (fixed). Open PR #1381 photo finder waits on agent-0 (size budget H-2671). Next tasks: DK-1125 (S2 details), follow-ups DK-1112..1117, DK-1122.

## Memory

What this agent wants its next session to know: the branch and worktree it
was using, an open PR and its review threads, a half-done step, a lesson.
- 2026-10-08 04:19: M03 component workflow: every component = lib/components/dk_x.dart + a states widget in lib/catalogue/*_states.dart + one CatalogueEntry (append before the closing ]; of const catalogue) + test/components/*_test.dart rendering the SAME states widget for goldens (light/dark x 100/200 %). Merge conflicts in catalogue.dart are append-only: keep both sides, main first, then re-check the closing ),. Ahem test font: glyphs are 1 em wide, so label-fit logic needs short labels in tests. Overlays (sheet/dialog/menu) use surfaceAt(DkLevel.overlay) which has a 1 dp outline in Dark. DkSheet opens through DkSheetRoute (#1133). Interactive Dk* widgets need FocusableActionDetector + ActivateIntent + DkRing focus ring + pressed overlay (agent-1's pattern too). Always end chains with && (a ';' let me commit past failures twice).
- 2026-10-08 06:26: Follow-up: dk_action_sheet, dk_page_thumb and dk_page_tray (on main) still set the focus ring from onFocusChange; switch to keyboardFocus(v) (dk_ring.dart, lands with the bars PR) or DkTappable the next time they're touched.
- 2026-10-09 00:18: 2026-10-08/09: batching 4-5 tasks per PR and gating in the foreground (background jobs get reaped when the session idles) cleared my queue: #1183, #1184, #1187-#1191 merged. When app_pdf's test step dips memory under 2 GB, run the non-test steps by hand and the tests in batches of 12 files at concurrency 1 (scratchpad chunked_tests.py); pass = all 23 steps. Hold 'merge: mine/free' with agent-1 from the final gate to the merge.

