# agent-2

session: active
last-seen: 2026-10-09 23:20
last-read: 1738
joined: 0

## Now

DK-1077 T3: Share (share_plus) and the split Save with its menu — claimed 2026-10-09 22:20.

## Next

Blocked on the owner's OK to rerun the #1217 --apk gate (stopped by the system for low memory ~20:55). Then: #1217 merge -> #1219 (--apk) merge -> open the stacked PRs: DK-0369; DK-0353-0356; DK-0357/0358/0359(sheet)/0361/0351; DK-0346-0348; DK-0362+0363-0368; DK-0359 export (feat/DK-0359-scan-export); DK-0325-0327 (feat/DK-0325-signature-store, db-schema held). Done off-goal (M12) while waiting: DK-0520, DK-0528, DK-0529 (+visual on OpenCV branch), DK-0463 - asked agent-0 (H-1744) about the PR cap. DK-0321 needs agent-0's DK-0300 (viewer text selection).

## Memory

What this agent wants its next session to know: the branch and worktree it
was using, an open PR and its review threads, a half-done step, a lesson.
- 2026-10-08 04:19: M03 component workflow: every component = lib/components/dk_x.dart + a states widget in lib/catalogue/*_states.dart + one CatalogueEntry (append before the closing ]; of const catalogue) + test/components/*_test.dart rendering the SAME states widget for goldens (light/dark x 100/200 %). Merge conflicts in catalogue.dart are append-only: keep both sides, main first, then re-check the closing ),. Ahem test font: glyphs are 1 em wide, so label-fit logic needs short labels in tests. Overlays (sheet/dialog/menu) use surfaceAt(DkLevel.overlay) which has a 1 dp outline in Dark. DkSheet opens through DkSheetRoute (#1133). Interactive Dk* widgets need FocusableActionDetector + ActivateIntent + DkRing focus ring + pressed overlay (agent-1's pattern too). Always end chains with && (a ';' let me commit past failures twice).
- 2026-10-08 06:26: Follow-up: dk_action_sheet, dk_page_thumb and dk_page_tray (on main) still set the focus ring from onFocusChange; switch to keyboardFocus(v) (dk_ring.dart, lands with the bars PR) or DkTappable the next time they're touched.
- 2026-10-09 00:18: 2026-10-08/09: batching 4-5 tasks per PR and gating in the foreground (background jobs get reaped when the session idles) cleared my queue: #1183, #1184, #1187-#1191 merged. When app_pdf's test step dips memory under 2 GB, run the non-test steps by hand and the tests in batches of 12 files at concurrency 1 (scratchpad chunked_tests.py); pass = all 23 steps. Hold 'merge: mine/free' with agent-1 from the final gate to the merge.

