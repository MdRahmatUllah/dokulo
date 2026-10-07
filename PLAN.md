# The plan

Where Dokulo is going and in what order. TASKS.md is the live state; this is
the route. The lead changes it when reality changes, and says so in a handoff
(`team.py msg all --kind heads-up`).

## The team and the lanes

Six agents, each in its own worktree (`<main checkout>/.worktrees/agent-N`),
all on one machine, all acting as the owner's GitHub account.

| Agent | Role | Lane | Work streams (from `dokulo-task-list.csv`) | Tasks · dev-days |
|---|---|---|---|---|
| agent-0 | **The lead** and a developer: the critical path, assignments, reviews, merges, releases | A | Platform & architecture, PDF engine & native, AI, Compliance & legal, Product & decisions, Design | 119 · 280 |
| agent-1 | Developer | B | Design system & components, Home/Files & security, Me/Pro & system surfaces, Localisation & content, Tablet & layout, accessibility | 351 · 456 |
| agent-2 | Developer | C | Tools & tool shell, Scanner, Viewer & editor | 224 · 383 |
| agent-3 | **SQA**, the one and only: the design-QA tasks per frame, device checks, bugs | Q | every task of type QA | 306 · 167 |
| agent-4 | **The website**, in `website/` of this repo | W | DK-1032…DK-1038 (added: the plan had no website) | 7 |
| agent-5 | **Marketing & Media**: research, copy, store assets, launch plan; never publishes | M | Store & launch, DK-1013, DK-1039…DK-1040 | 17 · 23 |
| — | Later (post-launch backlog): status `later`, nobody's until the owner says | L | Post-launch backlog | 16 · 80 |

**Lanes are defaults, not fences.** When your lane has nothing ready, take
the oldest-phase ready task from the fullest developer lane (B, then C, then
A) and tell the lead with `team.py msg agent-0`. The lead rebalances with
`team.py assign`.

**Batching.** 455 tasks are XS (half a day). Take 2–5 related tasks in one PR
(a tool's options UI, result card, errors and tests; a component and its
goldens): claim the first, `assign` the others to yourself, list every id in
the PR body, and `done` each after the merge.

## The phases

| Phase | Tasks | What it is |
|---|---|---|
| Ph1 Foundations | 173 | the monorepo, toolchain, state, routing, database, isolates, tokens, components, icons, the shell |
| Ph2 Scanner | 46 | S1, S2, the save flow, the photo finder |
| Ph3 Core tools | 243 | the tool shell and the PDF tools |
| Ph4 Edit & security | 80 | the edit mode, signatures, forms, the locked folder |
| Ph5 OCR & automation | 35 | OCR, the text layer, workflows |
| Ph6 Intelligence | 70 | the AI features and their models |
| Ph7 Launch | 377 | design QA per frame, accessibility, store, release |
| Ph8 Post-launch | 16 | `later` |

The phases are an order of value, not gates: a task is ready when its
blockers are done, whatever its phase. `team.py status` lists the earliest
phases first.

## The start

1. **DK-0001 (agent-0) comes first:** the monorepo with the five layer packages.
   Every code task waits for it. Then the critical path: DK-0007 (isolates),
   DK-0010 (CI: see the owner's question below), DK-0390…DK-0394,
   DK-0520, DK-0524, DK-0648, DK-0665, DK-0671, DK-0695…DK-0697.
2. **Until DK-0001 merges,** agent-1 and agent-2 take the compliance tasks
   (research into `docs/compliance/`, one PR each or batched): agent-1 has DK-0672, DK-0678,
   DK-0680, DK-0681; agent-2 has DK-0674…DK-0677, DK-0683.
3. **agent-3** sets up the device lab (DK-0668) and its design-QA routine; the
   QA tasks become ready as the screens they check merge.
4. **agent-4** scaffolds the website (DK-1033); **agent-5** writes the marketing
   plan and the store research (DK-1039, DK-1040).

## Waiting on the owner

- The product decisions DK-0698…DK-0708 and the website's DK-1032 (status
  `needs-decision`). The lead asks the owner, records the answer in the task
  (`team.py done <id> -m "the owner, <date>: …"`), and in MEMORY.md.
- **CI (DK-0010):** on DeutschPlan the owner turned GitHub CI off, and the
  local gate is the only check. DK-0010 asks for CI. The lead asks the owner
  before any workflow is enabled; until then the basic check in `CLAUDE.md` is the gate.

## Design and specs

- The source of truth for the interface: `docs/dokulo-ui-design-spec.md` and
  `docs/Overview & foundations.md` (the guide wins over code: fix one of them
  the same day). The product and the stack: the three `docs/Offline PDF Toolkit…` files.
- The artboards: `dokulo-design/{light,dark,deutsch}/<section>/<screen>-<state>.html`
  (open `dokulo-design/index.html`). A task's "Design reference" column names them.
