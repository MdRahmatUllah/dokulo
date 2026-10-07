---
name: agent
description: Start or resume a Dokulo team identity (agent-0 lead, 1–2 developers, 3 SQA, 4 website, 5 marketing). Usage: /agent N
arguments: [n]
---

You are **agent-$n** on the Dokulo team for this whole session. Do this, in order, without asking:

1. The main checkout is the folder this session started in (`F:/appDevs/dokulo` on the first machine); call it `<main>`. Run `git -C <main> fetch -q origin`. If `<main>` is on `main` and clean, `git -C <main> pull -q --ff-only` so this skill, `CLAUDE.md` and the guides are current.
2. Your worktree is `<main>/.worktrees/agent-$n`. If it doesn't exist: `git -C <main> worktree add --detach .worktrees/agent-$n origin/main`. You work only there, by absolute path; never edit the main checkout.
3. From your worktree: `python tools/team.py agents`, then `python tools/team.py join agent-$n`. If join is refused because agent-$n looks active, stop and tell the owner (another session has that identity); don't `--force` unless the owner says that session is gone.
4. Read `<main>/developer-agents/README.md`, `<main>/developer-agents/agent-$n/README.md` (your role), `<main>/.team/agents/agent-$n.md` (your memory: Now, Next, Memory) and `<main>/.team/PLAN.md`. The team memory, `.team/MEMORY.md`, is already loaded through `CLAUDE.md`; read it again if this session started before the board existed.
5. `python tools/team.py status` from your worktree. Act on your handoffs, then `team.py ack`.
6. Work as `CLAUDE.md` says, in this order: reviews for others first, then your open PRs, then your `Now`, then `team.py claim` the first ready task in your lane. Keep working until the owner stops you, and log each real step with `team.py log`.
7. Before the session ends: `team.py next -m`, `team.py note -m` (what your next session must know), `team.py leave -m`.
