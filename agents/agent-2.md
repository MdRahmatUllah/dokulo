# agent-2

session: active
last-seen: 2026-10-16 10:39
last-read: 3034
joined: 0

## Now

Nothing claimed.

## Next

Resume (paused by the owner 2026-10-16 ~10:35; all my gate runners stopped). Gate + PR + merge, one at a time: (1) a2q feat/DK-1134-sign-sheet = DK-1134, 1135, 1119, 1123, 1137 (self-reviewed, fixed). (2) a2p feat/DK-1136-photo-finder-qa (reviewed; its gate hung once in app_pdf tests, not reproducible: re-gate, bisect if it hangs again). (3) agent-2 worktree DK-1124/1125 (gate 25/26, doc_vision failed on dartcv keep-list, cleaned: re-gate). (4) a2h DK-0529, a2e DK-0536, a2l DK-0421 stack (DK-0403/0409/0415/0421/0439). (5) a2n feat/DK-1114-edit-fixes = DK-1114, 1116, 1122, 1117, 1115 merged into one batch: review found real bugs to fix first (see note). Then the stacked T2 branches in a2n (DK-0464/0465, 0445, 0469/0481/0487/0511/0493, 0499/0505, 0451/0457/0475/0427, 0535) and DK-1126, DK-1082. DK-1140 waits on agent-0 (H-3033). Launch gates from the Bash tool (powershell Start-Process ... gateq.ps1), never the PowerShell tool (no PATH).

## Memory

What this agent wants its next session to know: the branch and worktree it
was using, an open PR and its review threads, a half-done step, a lesson.
- 2026-10-08 04:19: M03 component workflow: every component = lib/components/dk_x.dart + a states widget in lib/catalogue/*_states.dart + one CatalogueEntry (append before the closing ]; of const catalogue) + test/components/*_test.dart rendering the SAME states widget for goldens (light/dark x 100/200 %). Merge conflicts in catalogue.dart are append-only: keep both sides, main first, then re-check the closing ),. Ahem test font: glyphs are 1 em wide, so label-fit logic needs short labels in tests. Overlays (sheet/dialog/menu) use surfaceAt(DkLevel.overlay) which has a 1 dp outline in Dark. DkSheet opens through DkSheetRoute (#1133). Interactive Dk* widgets need FocusableActionDetector + ActivateIntent + DkRing focus ring + pressed overlay (agent-1's pattern too). Always end chains with && (a ';' let me commit past failures twice).
- 2026-10-08 06:26: Follow-up: dk_action_sheet, dk_page_thumb and dk_page_tray (on main) still set the focus ring from onFocusChange; switch to keyboardFocus(v) (dk_ring.dart, lands with the bars PR) or DkTappable the next time they're touched.
- 2026-10-09 00:18: 2026-10-08/09: batching 4-5 tasks per PR and gating in the foreground (background jobs get reaped when the session idles) cleared my queue: #1183, #1184, #1187-#1191 merged. When app_pdf's test step dips memory under 2 GB, run the non-test steps by hand and the tests in batches of 12 files at concurrency 1 (scratchpad chunked_tests.py); pass = all 23 steps. Hold 'merge: mine/free' with agent-1 from the final gate to the merge.

