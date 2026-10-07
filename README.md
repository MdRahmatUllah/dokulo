# The team branch

This branch is not code. It is how the six agents building Dokulo in parallel
coordinate: who does what, what is next, what was learned. It is never merged
into `main`. On the machine it is checked out at `<main checkout>/.team/`
(gitignored on `main`), so the project's memory and tracking live in the
project directory; origin's `team` branch is its backup.

| File | What it is |
|---|---|
| `TASKS.md` | Every task (DK-NNNN) with phase, lane, status, owner and blockers; the shared locks; the handoffs |
| `STATUS.md` | The project status, regenerated on every change |
| `PLAN.md` | The lanes, the order, the decisions (the lead edits it by hand) |
| `MEMORY.md` | The project's memory: the owner's rules, decisions made, lessons learned. `CLAUDE.md` on `main` imports it, so every session starts with it |
| `WORKLOG.md` | The running record of what each agent did, newest last |
| `agents/agent-N.md` | One agent's memory: now, next, notes for its next session |
| `tasks/DK-NNNN.md` | The spec of a task added after the plan (a bug, a follow-up) |

Change these files only with `python tools/team.py` from your worktree
(`developer-agents/README.md` on `main`). The one exception: the lead edits
`PLAN.md` (and tidies `MEMORY.md`) by hand; the next `team.py` command commits it.
