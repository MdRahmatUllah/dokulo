# agent-2

session: active
last-seen: 2026-10-08 07:24
last-read: 750
joined: 0

## Now

DK-0181 in review as PR #1154: answer the review; re-run the gate if main moved, then merge.

## Next

Open PRs: #1149 (skeleton/spinner, re-review asked), #1154 (selection/viewer/camera bars). Queued branches, each refreshed against main and the catalogue guard, PR in this order: feat/DK-0174-mini-job-bar; feat/DK-0172-bars-d (tool strip + markup bar: merge main after #1154 lands, then only DK-0176/0177/0202/0203 remain); feat/DK-0156-crop-b; feat/DK-0194-progress-b; feat/DK-0208-sign-b (signature card + split marker); feat/DK-0212-ask-b (stacked on sign-b); feat/DK-0160-boxes-b; feat/DK-0210-chat-diff; feat/DK-0220-detection-group (drop its expandLess/expandMore if #1152 lands first); feat/DK-0206-signature-pad (fonts fetch + disabled Done in DkTopBar.editing; swap TextField for DkTextField after #1153). Only DK-0204/0205 (tool options sheet) is unbuilt: waits on agent-1's DkSlider/DkStepper/DkColorRow (asked in H-698). Scripts in the scratchpad: merge_catalogue.py, merge_arb.py, refresh.sh, ios44.py.

## Memory

What this agent wants its next session to know: the branch and worktree it
was using, an open PR and its review threads, a half-done step, a lesson.
- 2026-10-08 04:19: M03 component workflow: every component = lib/components/dk_x.dart + a states widget in lib/catalogue/*_states.dart + one CatalogueEntry (append before the closing ]; of const catalogue) + test/components/*_test.dart rendering the SAME states widget for goldens (light/dark x 100/200 %). Merge conflicts in catalogue.dart are append-only: keep both sides, main first, then re-check the closing ),. Ahem test font: glyphs are 1 em wide, so label-fit logic needs short labels in tests. Overlays (sheet/dialog/menu) use surfaceAt(DkLevel.overlay) which has a 1 dp outline in Dark. DkSheet opens through DkSheetRoute (#1133). Interactive Dk* widgets need FocusableActionDetector + ActivateIntent + DkRing focus ring + pressed overlay (agent-1's pattern too). Always end chains with && (a ';' let me commit past failures twice).
- 2026-10-08 06:26: Follow-up: dk_action_sheet, dk_page_thumb and dk_page_tray (on main) still set the focus ring from onFocusChange; switch to keyboardFocus(v) (dk_ring.dart, lands with the bars PR) or DkTappable the next time they're touched.

