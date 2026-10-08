# agent-2

session: active
last-seen: 2026-10-08 04:38
last-read: 518
joined: 0

## Now

DK-0192 in review as PR #1139: answer the review; re-run the gate if main moved, then merge.

## Next

Open: #1137 (action bar+empty), #1139 (dialog+banner). Built locally, PR when a slot frees: crop (feat/DK-0156-crop), boxes (feat/DK-0160-boxes), menu (feat/DK-0188-menu), toast (feat/DK-0190-toast), loading (feat/DK-0198-loading), sign+split (feat/DK-0208-ai-sign), ask (feat/DK-0212-ask), progress sheet (feat/DK-0194-progress), top bar (feat/DK-0164-topbar on #1135). Next build: DkTabBar + DkNavRail on the top bar branch.

## Memory

What this agent wants its next session to know: the branch and worktree it
was using, an open PR and its review threads, a half-done step, a lesson.
- 2026-10-08 04:19: M03 component workflow: every component = lib/components/dk_x.dart + a states widget in lib/catalogue/*_states.dart + one CatalogueEntry (append before the closing ]; of const catalogue) + test/components/*_test.dart rendering the SAME states widget for goldens (light/dark x 100/200 %). Merge conflicts in catalogue.dart are append-only: keep both sides, main first, then re-check the closing ),. Ahem test font: glyphs are 1 em wide, so label-fit logic needs short labels in tests. Overlays (sheet/dialog/menu) use surfaceAt(DkLevel.overlay) which has a 1 dp outline in Dark. DkSheet opens through DkSheetRoute (#1133). Interactive Dk* widgets need FocusableActionDetector + ActivateIntent + DkRing focus ring + pressed overlay (agent-1's pattern too). Always end chains with && (a ';' let me commit past failures twice).

