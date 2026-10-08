# Dokulo — read this first

Dokulo is an offline, iLovePDF-style PDF toolkit and scanner for iOS and
Android (Flutter, EN/DE). `main` holds the plan, the design, the team tooling
and the Flutter monorepo: one pub workspace with the five layer packages in
`packages/` (DK-0001; the root `README.md` describes them).

**The team** (six Claude Code agents, one owner): `agent-0` (the lead: the
critical path, assignments, reviews, merges, releases), `agent-1` and
`agent-2` (developers), `agent-3` (SQA), `agent-4` (the website, in
`website/`) and `agent-5` (Marketing & Media). You are one of them.
`developer-agents/README.md` is the full guide; your role is
`developer-agents/agent-N/README.md`. The owner starts each session with
`/agent N`, which runs the start ritual below.

## What this repo is

- `docs/`: the specs. `Developer guide.md` (structure, state, routing, theming, testing, the accessibility checklist, the definition of done), Product and feature list (`Offline PDF Toolkit (iLovePDF-style mobile app).md`), the technology and package plan (stack, licence rules, versions), the frontend & UX plan (screen IDs like H1, F1, V1, S1, A1, M1, X3; the error catalogue), `Overview & foundations.md` (brand voice, fixed EN/DE tool names, tokens), and `dokulo-ui-design-spec.md` (the full UI spec; its §-numbers are referenced from tasks and the design export). **Docs win over code:** when they disagree, fix one of them the same day.
- `dokulo-design/`: a static HTML export of every screen state. Open `dokulo-design/index.html`. `light/`, `dark/` and `deutsch/` mirror the same folder and file names (`<screen>-<state>.html`), so one path shows a screen in each theme and language. Phone frames are 393×852, `-iphone-se` is 375×667, and tablets are in `24-tablet/`.
- `dokulo-task-list.csv`: the plan, 1,031 tasks (DK-NNNN) with description, acceptance criteria, screen IDs, components, design reference and dependencies (`dokulo-task-dependencies.csv` is the edge list). These rows are the spec of every planned task.
- `tools/team.py`: the team board (below). `developer-agents/`: the team's roles.

## Architecture (the Technology & Package Plan; packages in `packages/`)

Five layer packages in one monorepo; dependencies point one way only: `app_pdf → doc_tools → doc_core / doc_vision → ai_core`.

| Package | Role |
|---|---|
| `app_pdf` | Screens, tool grid, viewer, file manager, paywall, Riverpod providers |
| `doc_tools` | One `ToolJob` per feature, progress stream, cancel, undo snapshot, workflow runner; the work on worker isolates |
| `doc_core` | Open/save/render PDFs, page ops, text extraction, image pipeline, OCR text layer (pdfrx/PDFium, our `qpdf_ffi`, Dart `pdf`, opencv_dart) |
| `doc_vision` | Scanner flows, edge detection, OCR engines, layout, document-in-photo detection |
| `ai_core` | Imported from Sogda: model manager, LLM arbiter (llama.cpp), translation, embeddings, retrieval |

The rules every implementation task follows:

- **Threading:** PDFium is single-threaded, so all PDFium calls are serialised on one worker isolate. qpdf, OpenCV and ONNX run on their own isolates. The UI isolate never calls native code.
- **Offline:** no network traffic during any tool run. Optional models are on-demand downloads with hash checks, and the base app stays small.
- **Licences:** permissive only in the app.
  - GPL/AGPL (MuPDF, Ghostscript, …): never.
  - MPL/LGPL: only unmodified and dynamically linked, and no LGPL on iOS.
  - No commercial SDKs.
  - Models need a written licence check.
- **No training:** inference, prompting and RAG only.
- **Versions:** Flutter 3.47+, Dart 3.13+, Riverpod 3 with codegen, go_router, drift with FTS5. EN and DE strings live in ARB files.

## Everything lives in the project directory

| What | Where |
|---|---|
| The code | `main`. You work only in your worktree `.worktrees/agent-N` (gitignored), never in the main checkout |
| The board: tasks, handoffs, locks, plan, worklog | the `team` branch, checked out at `.team/` (gitignored on `main`, created on first use), changed only by `python tools/team.py` |
| Your memory | `.team/agents/agent-N.md` (Now, Next, Memory): `team.py note`, `team.py next` |
| The team's memory | `.team/MEMORY.md`, imported at the bottom of this file: `team.py remember` |
| A task's spec | `python tools/team.py show DK-NNNN` (the CSV row, or `.team/tasks/DK-NNNN.md` for an added task) |

Claude Code's auto-memory is off for this project (`.claude/settings.json`), so every memory goes through `team.py` into `.team/`.

## Start every session like this

1. `python tools/team.py agents`: who is active. Take an idle identity.
2. Your worktree is `.worktrees/agent-N`. If it is missing, create it with `git worktree add --detach .worktrees/agent-N origin/main`. Run team.py from the worktree: `python tools/team.py join agent-N`.
3. Read `.team/agents/agent-N.md` and `.team/PLAN.md`. The team memory is below.
4. `python tools/team.py status`: act on your handoffs, then `team.py ack`.
5. Reviews come first, then your open PRs, then your `Now`, then `team.py claim` the first ready task in your lane.

While you work, run `team.py log -m "..."` at each real step and `team.py next -m` when your plan changes. To end a session: `team.py next`, `team.py note`, then `team.py leave -m "..."`.

## One task, start to finish

1. `team.py claim DK-NNNN`.
2. In your worktree: `git fetch -q origin && git switch -c feat/DK-NNNN-<slug> origin/main`.
3. Read the task with `team.py show DK-NNNN`, plus the docs and the artboards it names.
4. Implement it. Add tests, and goldens for a screen or component.
5. Run the basic check, then commit and push.
6. Open the PR. Its first line is `**Agent-N**`, and its body names every task id.
7. `team.py review DK-NNNN --pr P`.
8. Another agent reviews. Fix everything in one push, until the review approves.
9. `git merge origin/main` into the branch, and re-run the check.
10. `gh pr merge P --squash --subject "<title> (#P)"`, then `git push origin --delete <branch>`.
11. `team.py done DK-NNNN --pr P -m "what others should know"`, then the next task.

Board commands not used above: `assign`, `release`, `decision` (to the owner), `reopen`, `add` (a bug or a follow-up, with `--blocks` to re-block a check), `msg`, `ack`, `lock`/`unlock`, `device` (the emulator lock), `log`, `next`, `note`, `remember`. Run `python tools/team.py <cmd> -h` for their options.

## The basic check

It is the only check a PR gets: **there is no CI/CD** (the owner, 2026-10-07; DK-0010). One command runs all of it from the repo root, before you push and again before you merge if `origin/main` moved:

```bash
python tools/check.py                    # add --apk <built.apk> when a native dependency or its config changed
```

It takes about 2–3 minutes (build_runner and analyze are most of it). It runs every step even after a failure, prints `PASS`/`FAIL` per step with the failing output, and exits 1 if anything failed. The steps:

```bash
python tools/fetch_ocr_models.py                                 # the bundled PP-OCRv5 models, hash-checked (fetched once)
python tools/fetch_icon_font.py                                  # Material Symbols Rounded, hash-checked (fetched once)
flutter pub get                                                  # one pub workspace: resolves every package, regenerates l10n
(cd packages/<p> && dart run build_runner build -d)              # each package that uses build_runner (*.g.dart are not committed)
flutter analyze --fatal-infos                                    # the whole workspace
dart format --output=none --set-exit-if-changed packages
python tools/check_layers.py                                     # dependencies point one way only; no FFI in app_pdf
python tools/licence_scan.py                                     # every pubspec.lock against the licence register
python tools/check_l10n.py                                       # EN/DE keys match, no hard-coded strings in app_pdf
python tools/check_permissions.py [built apk]                    # only the Android permissions DK-0016 lists
python tools/check_tokens.py                                     # no raw colours in screens/components: DkTokens only
python tools/check_privacy_manifests.py                          # the iOS privacy manifest, and one per native iOS plugin
(cd packages/<p> && flutter test --timeout 60s --concurrency 4 | dart test)  # every package with tests; 4 flutter_testers at once (memory)
python -m pytest tools/tests -q
python tools/check_pdfa.py                                       # PDF/A writer output validates in veraPDF (install: docs/compliance/pdfa.md)
python tools/native_libs_check.py <built apk>                    # only with --apk: no FFmpeg/excluded OpenCV, 16 KB-aligned .so (Play)
python tools/size_check.py <built apk>                           # only with --apk: per-ABI size budget, no bundled models but OCR
```

doc_vision's OCR tests run the real models through Python onnxruntime (`pip install onnxruntime numpy`); without it they are skipped, not failed.

While you iterate, run a single step by hand; the gate is for the end. When a new suite lands (golden PDFs, redaction security), add it as a step in `tools/check.py` in the same PR.

A package that adds a Flutter plugin becomes a Flutter package; the gate then runs `flutter test` there instead of `dart test`.

`website/` has its own check: `npm run typecheck && npm run lint && npm run build`.

`tools/tests/test_team.py` builds a throwaway `team` repo in `tmp_path` and calls the `cmd_*` functions directly. `cmd_done` and `cmd_status` take a `merged=` callable, so the tests never call `gh`.

## Non-negotiables

The owner's rules are in the memory below. In short:

- commits use the owner's git identity;
- every PR body starts with `**Agent-N**`;
- an approving review comes before every merge;
- ids come from tools, never from memory;
- decisions go to the owner;
- the repo is public;
- never `taskkill /IM flutter_tester.exe`;
- use only Dokulo's emulators: `5562` is shared under `team.py device`, and `5564` is agent-3's.

## Team memory

@.team/MEMORY.md
