"""The team board: how parallel agents claim work, record it and report back.

`developer-agents/README.md` is the protocol; this is the only thing that
edits the board. The board is the `team` branch, checked out inside the main
checkout at `.team/` (gitignored on `main`), so the tasks, the memory and the
history all live in the project directory:

    TASKS.md        every task (DK-NNNN), who has it, what blocks it, the
                    shared locks, and the handoffs: assignments, reviews, reports
    STATUS.md       generated from TASKS.md on every change
    PLAN.md         lanes, order, decisions (edited by hand, by the lead)
    MEMORY.md       the project's memory: what every agent should know
    WORKLOG.md      the running record of what each agent is doing
    agents/<id>.md  one agent's memory: now, next, notes for its next session
    tasks/<id>.md   the spec of a task added after the plan (bugs, follow-ups);
                    the planned ones are rows of dokulo-task-list.csv

All agents share the one `.team/` checkout on this machine. Every change runs
under a lock, is committed to `team`, and pushed to origin as a backup.

    python tools/team.py agents             # who is active, who is free
    python tools/team.py join agent-2       # take an identity (in your worktree)
    python tools/team.py status             # handoffs for me, my work, what is ready
    python tools/team.py show DK-0001       # the task's spec and its board state
    python tools/team.py claim DK-0001
    python tools/team.py review DK-0001 --pr 4
    python tools/team.py done DK-0001 --pr 4 -m "what others should know"
"""

from __future__ import annotations

import argparse
import csv
import os
import random
import re
import shutil
import subprocess
import sys
import time
from contextlib import contextmanager
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path

BRANCH = "team"
BOARD_DIR = ".team"
TASK_ID = re.compile(r"^DK-\d{4}$")
AGENT_ID = re.compile(r"^agent-[0-9]$")  # agent-0 is the lead
STATUSES = ("open", "assigned", "in-progress", "review", "done", "needs-decision", "later")
STAMP = "%Y-%m-%d %H:%M"
PLAN_CSV = Path(__file__).resolve().parents[1] / "dokulo-task-list.csv"

# Each agent's lane (PLAN.md): its own ready tasks are listed first.
LANES = {"agent-0": "A", "agent-1": "B", "agent-2": "C", "agent-3": "Q", "agent-4": "W", "agent-5": "M"}
PRI = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}

# An identity nobody has used for this long is free to take over: its last
# session ended without `leave`.
IDLE_AFTER = timedelta(hours=2)
# A team.py command holds the board for a second or two; a lock this old was
# left by a command that was killed.
BOARD_LOCK_STALE_SECONDS = 120
# A device check takes minutes; an agent that died holding the emulator must
# not block it all day.
DEVICE_LOCK_STALE_SECONDS = 45 * 60


class Refused(Exception):
    """The board says no: already claimed, blocked, not yours."""


def now() -> str:
    return datetime.now().strftime(STAMP)


# --- TASKS.md --------------------------------------------------------------------

@dataclass
class Task:
    id: str
    phase: str
    lane: str
    pri: str
    size: str
    title: str
    status: str = "open"
    owner: str = ""
    blocked_by: list[str] = field(default_factory=list)
    pr: str = ""

    def row(self) -> str:
        cells = (self.id, self.phase, self.lane, self.pri, self.size, self.title.replace("|", "/"),
                 self.status, self.owner, " ".join(self.blocked_by), self.pr)
        return "| " + " | ".join(cells) + " |"


@dataclass
class Lock:
    resource: str
    owner: str = ""
    since: str = ""
    why: str = ""

    def row(self) -> str:
        return "| " + " | ".join((self.resource, self.owner, self.since, self.why.replace("|", "/"))) + " |"


def _cells(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def _table(lines: list[str], heading: str) -> tuple[int, int]:
    """The line span of the rows of the table under `## heading`."""
    try:
        start = lines.index(f"## {heading}")
    except ValueError as missing:
        raise SystemExit(f"TASKS.md has no '## {heading}' section") from missing
    header = next(i for i in range(start + 1, len(lines)) if lines[i].startswith("|"))
    first = end = header + 2  # past the header and its |---| rule
    while end < len(lines) and lines[end].startswith("|"):
        end += 1
    return first, end


class Board:
    """TASKS.md: the task and lock tables, and the handoffs appended below."""

    def __init__(self, text: str):
        self.text = text
        lines = text.splitlines()
        first, end = _table(lines, "Tasks")
        self.tasks = [Task(c[0], c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8].split(), c[9])
                      for c in (_cells(line) for line in lines[first:end])]
        first, end = _table(lines, "Locks")
        self.locks = [Lock(*_cells(line)[:4]) for line in lines[first:end]]
        self.new_handoffs: list[str] = []

    def task(self, task_id: str) -> Task:
        for task in self.tasks:
            if task.id == task_id:
                return task
        raise Refused(f"{task_id} is not on the board")

    def status_of(self, task_id: str) -> str:
        return next((t.status for t in self.tasks if t.id == task_id), "done")

    def ready(self, task: Task) -> bool:
        return all(self.status_of(n) == "done" for n in task.blocked_by)

    def next_id(self) -> str:
        return f"DK-{max(int(t.id[3:]) for t in self.tasks) + 1:04d}"

    def handoff_ids(self) -> list[int]:
        text = self.text + "".join(self.new_handoffs)
        return [int(n) for n in re.findall(r"^### H-(\d+) ", text, re.M)]

    def handoff(self, sender: str, to: str, kind: str, body: str, task_id: str | None = None) -> int:
        number = max(self.handoff_ids(), default=0) + 1
        tag = f" · {task_id}" if task_id else ""
        self.new_handoffs.append(f"\n### H-{number} · {now()} · {sender} → {to} · {kind}{tag}\n\n{body.strip()}\n")
        return number

    def render(self) -> str:
        lines = self.text.splitlines()
        for heading, rows in (("Tasks", [t.row() for t in self.tasks]), ("Locks", [lk.row() for lk in self.locks])):
            first, end = _table(lines, heading)
            lines[first:end] = rows
        return "\n".join(lines) + "\n" + "".join(self.new_handoffs)

    def ready_tasks(self, agent: str | None = None) -> list[Task]:
        """Ready to claim: open (or assigned to [agent]) and unblocked; the
        agent's own lane first, then phase and priority."""
        lane = LANES.get(agent or "")
        ready = [t for t in self.tasks if self.ready(t) and (t.status == "open" or (t.status == "assigned" and t.owner == agent))]
        return sorted(ready, key=lambda t: (t.owner != agent, t.lane != lane, t.phase, PRI.get(t.pri, 9), t.id))


def handoffs_for(text: str, agent: str, after: int, joined: int = 0) -> list[str]:
    """Handoffs to [agent] or to everyone, newer than [after], not its own.
    A handoff to everyone from before the agent [joined] isn't its."""
    shown = []
    for entry in re.split(r"(?m)^(?=### H-\d+ )", text):
        m = re.match(r"### H-(\d+) · [^·]+ · (\S+) → (\S+) ·", entry)
        if (m and int(m.group(1)) > after and m.group(3) in (agent, "all") and m.group(2) != agent
                and not (m.group(3) == "all" and int(m.group(1)) <= joined)):
            shown.append(entry.strip())
    return shown


# --- agents/<id>.md: one agent's memory --------------------------------------------

AGENT_TEMPLATE = """# {agent}

session: active
last-seen: {stamp}
last-read: 0
joined: {joined}

## Now

Nothing claimed.

## Next

Run `python tools/team.py status` and claim a ready task in your lane.

## Memory

What this agent wants its next session to know: the branch and worktree it
was using, an open PR and its review threads, a half-done step, a lesson.

"""


def agent_path(root: Path, agent: str) -> Path:
    return root / "agents" / f"{agent}.md"


def read_field(text: str, name: str) -> str:
    m = re.search(rf"^{name}: (.*)$", text, re.M)
    return m.group(1).strip() if m else ""


def write_field(root: Path, agent: str, name: str, value: str) -> None:
    path = agent_path(root, agent)
    text = path.read_text(encoding="utf-8")
    text, count = re.subn(rf"^{name}: .*$", f"{name}: {value}", text, count=1, flags=re.M)
    if not count:
        raise SystemExit(f"{path.name} has no '{name}:' line")
    path.write_text(text, encoding="utf-8", newline="\n")


def set_section(root: Path, agent: str, heading: str, body: str, append: bool = False) -> None:
    path = agent_path(root, agent)
    text = path.read_text(encoding="utf-8")
    m = re.compile(rf"(^## {re.escape(heading)}\n\n)(.*?)(?=^## |\Z)", re.M | re.S).search(text)
    if not m:
        raise SystemExit(f"{path.name} has no '## {heading}' section")
    new = (m.group(2).rstrip() + "\n" if append else "") + body.strip() + "\n\n"
    path.write_text(text[: m.start(2)] + new + text[m.end(2):], encoding="utf-8", newline="\n")


def identities(root: Path) -> list[tuple[str, str, str, str]]:
    """(agent, session, last-seen, now) for every agent file."""
    rows = []
    for path in sorted((root / "agents").glob("agent-*.md")):
        text = path.read_text(encoding="utf-8")
        now_line = re.search(r"^## Now\n\n(.*)$", text, re.M)
        rows.append((path.stem, read_field(text, "session"), read_field(text, "last-seen"), now_line.group(1) if now_line else ""))
    return rows


def is_idle(session: str, last_seen: str) -> bool:
    if session != "active":
        return True
    try:
        return datetime.now() - datetime.strptime(last_seen, STAMP) > IDLE_AFTER
    except ValueError:
        return True


# --- WORKLOG.md, MEMORY.md, STATUS.md --------------------------------------------------

def append_log(root: Path, agent: str, text: str, task_id: str | None = None) -> None:
    tag = f" {task_id}" if task_id else ""
    with (root / "WORKLOG.md").open("a", encoding="utf-8", newline="\n") as log:
        log.write(f"- {now()} · {agent}{tag} · {text}\n")


def remember(root: Path, agent: str, topic: str, text: str) -> None:
    with (root / "MEMORY.md").open("a", encoding="utf-8", newline="\n") as memory:
        memory.write(f"- **{topic}** ({now()[:10]}, {agent}): {text.strip()}\n")


def render_status(root: Path) -> None:
    board = Board((root / "TASKS.md").read_text(encoding="utf-8"))
    out = [
        "# Project status", "",
        f"Generated by `tools/team.py` from TASKS.md at {now()}. Do not edit: it is rewritten on every board change.", "",
        "## Phases", "",
        "| Phase | Done | In flight | Open | Needs a decision | Later |",
        "|---|---|---|---|---|---|",
    ]
    for phase in sorted({t.phase for t in board.tasks}):
        tasks = [t for t in board.tasks if t.phase == phase]
        count = lambda *s: sum(1 for t in tasks if t.status in s)  # noqa: E731
        out.append(f"| {phase} | {count('done')} of {len(tasks)} | {count('in-progress', 'review')} "
                   f"| {count('open', 'assigned')} | {count('needs-decision')} | {count('later')} |")
    out += ["", "## Agents", "", "| Agent | Lane | Session | Last seen | Now |", "|---|---|---|---|---|"]
    for agent, session, seen, doing in identities(root):
        out.append(f"| {agent} | {LANES.get(agent, '-')} | {'idle' if is_idle(session, seen) else 'active'} | {seen} | {doing} |")
    out += ["", "## In flight", ""]
    flight = [t for t in board.tasks if t.status in ("in-progress", "review", "assigned")]
    out += [f"- {t.id} {t.status} · {t.owner} {t.pr} · {t.title}" for t in flight] or ["- nothing"]
    out += ["", "## Ready to claim (the first ten per lane)", ""]
    ready = board.ready_tasks()
    for lane in sorted({t.lane for t in ready}):
        mine = [t for t in ready if t.lane == lane]
        out.append(f"- **Lane {lane}** ({len(mine)} ready): " + ", ".join(f"{t.id} {t.pri} {t.title}" for t in mine[:10]))
    if not ready:
        out.append("- nothing")
    out += ["", "## Waiting on a decision from the owner", ""]
    out += [f"- {t.id} {t.title}" for t in board.tasks if t.status == "needs-decision"] or ["- nothing"]
    held = [lk for lk in board.locks if lk.owner]
    out += ["", "## Locks held", ""]
    out += [f"- {lk.resource}: {lk.owner} since {lk.since} — {lk.why}" for lk in held] or ["- none"]
    (root / "STATUS.md").write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")


# --- Git: the transaction ---------------------------------------------------------------

def git(root: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, encoding="utf-8", check=check)


@contextmanager
def board_lock(root: Path):
    """One team.py command at a time on the shared `.team/` checkout."""
    lock = Path(git(root, "rev-parse", "--path-format=absolute", "--git-common-dir").stdout.strip()) / "team.lock"
    deadline = time.time() + 2 * BOARD_LOCK_STALE_SECONDS
    while True:
        try:
            lock.mkdir()  # atomic: exactly one command gets it
            break
        except FileExistsError:
            try:
                if time.time() - lock.stat().st_mtime > BOARD_LOCK_STALE_SECONDS:
                    # ponytail: two commands breaking one stale lock at once can
                    # both get in; a rename-aside as cmd_device's if that happens.
                    lock.rmdir()
                    continue
            except FileNotFoundError:
                continue  # released while we looked
            if time.time() > deadline:
                raise SystemExit(f"{lock} is held by another team.py command: try again") from None
            time.sleep(0.1 + random.random() * 0.2)
    try:
        yield
    finally:
        try:
            lock.rmdir()
        except FileNotFoundError:
            pass


def transact(root: Path, agent: str, message: str, change):
    """Apply [change] to the board under the lock, commit it, push it.

    A refused or failed change leaves the board exactly as it was."""
    with board_lock(root):
        if git(root, "status", "--porcelain").stdout.strip():
            # A hand edit (PLAN.md, a MEMORY.md tidy-up) is kept as its own commit.
            git(root, "add", "-A")
            git(root, "commit", "--quiet", "-m", f"hand edits (committed by {agent})")
        try:
            result = change(root)
            if agent_path(root, agent).exists():
                write_field(root, agent, "last-seen", now())
            render_status(root)
        except BaseException:
            git(root, "reset", "--quiet", "--hard")
            git(root, "clean", "--quiet", "-fd")
            raise
        git(root, "add", "-A")
        if not git(root, "status", "--porcelain").stdout.strip():
            return result
        git(root, "commit", "--quiet", "-m", f"{agent}: {message}")
        push(root)
        return result


def push(root: Path) -> None:
    """The board is committed locally; origin/team is its backup."""
    if not git(root, "remote", check=False).stdout.strip():
        return
    pushed = git(root, "push", "--quiet", "origin", f"HEAD:refs/heads/{BRANCH}", check=False)
    if pushed.returncode != 0:
        print(f"warning: the board is saved, but not pushed to origin/{BRANCH}: {pushed.stderr.strip()}", file=sys.stderr)


def on_board(change):
    """A board edit as a transaction step: parse TASKS.md, change it, write it."""
    def step(root: Path):
        path = root / "TASKS.md"
        board = Board(path.read_text(encoding="utf-8"))
        result = change(root, board)
        path.write_text(board.render(), encoding="utf-8", newline="\n")
        return result
    return step


def read_board(root: Path) -> tuple[str, Board]:
    with board_lock(root):
        text = (root / "TASKS.md").read_text(encoding="utf-8")
    return text, Board(text)


# --- Commands ------------------------------------------------------------------------------

def cmd_claim(root: Path, agent: str, task_id: str) -> None:
    def change(root, board):
        task = board.task(task_id)
        busy = [t for t in board.tasks if t.owner == agent and t.status == "in-progress" and t.id != task_id]
        if busy:
            raise Refused(f"you already have {busy[0].id} in progress: `review`, `done` or `release` it first")
        if task.status == "assigned" and task.owner != agent:
            raise Refused(f"{task_id} is assigned to {task.owner}")
        if task.status not in ("open", "assigned"):
            raise Refused(f"{task_id} is {task.status}" + (f" ({task.owner})" if task.owner else ""))
        if not board.ready(task):
            raise Refused(f"{task_id} is blocked by " + " ".join(n for n in task.blocked_by if board.status_of(n) != "done"))
        task.status, task.owner = "in-progress", agent
        set_section(root, agent, "Now", f"{task_id} {task.title} — claimed {now()}.")
        append_log(root, agent, f"claimed: {task.title}", task_id)
    transact(root, agent, f"claim {task_id}", on_board(change))
    print(f"claimed {task_id}: `team.py show {task_id}` prints its spec")


def cmd_assign(root: Path, agent: str, task_id: str, to: str, message: str) -> None:
    check_agent(to)
    def change(root, board):
        task = board.task(task_id)
        if task.status not in ("open", "assigned", "later"):
            raise Refused(f"{task_id} is {task.status}; only open work can be assigned")
        task.status, task.owner = "assigned", to
        board.handoff(agent, to, "assign", message or f"Please take {task_id} ({task.title}).", task_id)
        append_log(root, agent, f"assigned to {to}", task_id)
    transact(root, agent, f"assign {task_id} to {to}", on_board(change))
    print(f"assigned {task_id} to {to}")


def cmd_release(root: Path, agent: str, task_id: str, message: str) -> None:
    def change(root, board):
        task = board.task(task_id)
        if task.owner != agent:
            raise Refused(f"{task_id} is not yours ({task.owner or 'nobody'})")
        task.status, task.owner = "open", ""
        board.handoff(agent, "all", "note", f"Released {task_id}: {message}", task_id)
        set_section(root, agent, "Now", "Nothing claimed.")
        append_log(root, agent, f"released: {message}", task_id)
    transact(root, agent, f"release {task_id}", on_board(change))
    print(f"released {task_id}")


def cmd_review(root: Path, agent: str, task_id: str, pr: int, to: str) -> None:
    def change(root, board):
        task = board.task(task_id)
        if task.owner != agent:
            raise Refused(f"{task_id} is not yours ({task.owner or 'nobody'})")
        task.status, task.pr = "review", f"#{pr}"
        board.handoff(agent, to, "review-request",
                      f"PR #{pr} for {task_id} ({task.title}) is up. Review it on GitHub and answer with `team.py msg {agent} --kind review`.", task_id)
        set_section(root, agent, "Now", f"{task_id} in review as PR #{pr}: answer the review; re-run the gate if main moved, then merge.")
        append_log(root, agent, f"PR #{pr} open; review requested from {to}", task_id)
    transact(root, agent, f"review {task_id} (PR #{pr})", on_board(change))
    print(f"{task_id} in review as PR #{pr}")


def pr_merged(pr: int) -> bool:
    out = subprocess.run(["gh", "pr", "view", str(pr), "--json", "state", "--jq", ".state"],
                         capture_output=True, text=True, encoding="utf-8", check=False)
    return out.stdout.strip() == "MERGED"


def cmd_done(root: Path, agent: str, task_id: str, pr: int | None, message: str, merged=pr_merged) -> None:
    if pr and not merged(pr):
        raise Refused(f"PR #{pr} is not merged: merge it first")
    def change(root, board):
        task = board.task(task_id)
        if task.status == "done":
            raise Refused(f"{task_id} is already done")
        if task.pr and not pr and task.status == "review":
            raise Refused(f"{task_id} is in review as {task.pr}: `done {task_id} --pr {task.pr.lstrip('#')}` once it is merged")
        owner = task.owner
        task.status = "done"
        if pr:
            task.pr = f"#{pr}"
        freed = [t for t in board.tasks if t.status in ("open", "assigned") and task_id in t.blocked_by and board.ready(t)]
        report = f"{task_id} ({task.title}) is done" + (f", merged as {task.pr}" if task.pr else "") + "."
        if owner and owner != agent:
            report += f" (Recorded by {agent} for {owner}.)"
        if message:
            report += f" {message}"
        if freed:
            report += " Now ready: " + ", ".join(t.id for t in freed[:30]) + (f" and {len(freed) - 30} more" if len(freed) > 30 else "") + "."
        board.handoff(agent, "all", "report", report, task_id)
        if owner == agent:
            set_section(root, agent, "Now", "Nothing claimed.")
        append_log(root, agent, "done" + (f" ({task.pr})" if task.pr else ""), task_id)
    transact(root, agent, f"done {task_id}", on_board(change))
    print(f"{task_id} done")


def cmd_decision(root: Path, agent: str, task_id: str, message: str) -> None:
    def change(root, board):
        task = board.task(task_id)
        task.status, task.owner = "needs-decision", ""
        board.handoff(agent, "owner", "decision", message, task_id)
        append_log(root, agent, f"needs the owner's decision: {message}", task_id)
    transact(root, agent, f"decision needed on {task_id}", on_board(change))
    print(f"{task_id} waits for the owner's decision")


def cmd_reopen(root: Path, agent: str, task_id: str, message: str) -> None:
    """A decision was made, a claim went stale, or Later became now: open again."""
    def change(root, board):
        task = board.task(task_id)
        task.status, task.owner = "open", ""
        board.handoff(agent, "all", "note", f"{task_id} is open again: {message}", task_id)
        append_log(root, agent, f"reopened: {message}", task_id)
    transact(root, agent, f"reopen {task_id}", on_board(change))
    print(f"{task_id} open")


def cmd_add(root: Path, agent: str, title: str, lane: str, phase: str, pri: str, size: str,
            blocked_by: list[str], blocks: list[str], body: str) -> None:
    """A task the plan didn't have: a bug, a follow-up. Its spec goes to tasks/<id>.md;
    each task in [blocks] waits for it (and an SQA check re-runs once it is done)."""
    for n in blocked_by + blocks:
        check_task(n)
    def change(root, board):
        task_id = board.next_id()
        for n in blocked_by + blocks:
            board.task(n)
        board.tasks.append(Task(task_id, phase, lane, pri, size, title, blocked_by=blocked_by))
        for n in blocks:
            held = board.task(n)
            held.blocked_by.append(task_id)
            if held.status == "in-progress":
                held.status, held.owner = "open", ""
        (root / "tasks").mkdir(exist_ok=True)
        (root / "tasks" / f"{task_id}.md").write_text(f"# {task_id} · {title}\n\nAdded by {agent}, {now()}.\n\n{body.strip()}\n",
                                                       encoding="utf-8", newline="\n")
        note = f"Added {task_id} ({title}) to lane {lane}, {phase} {pri}." + (f" It blocks {' '.join(blocks)}." if blocks else "")
        board.handoff(agent, "all", "note", note, task_id)
        append_log(root, agent, f"added: {title}", task_id)
        return task_id
    print(f"{transact(root, agent, f'add {title}', on_board(change))} added")


def cmd_lock(root: Path, agent: str, resource: str, message: str, release: bool) -> None:
    def change(root, board):
        lock = next((lk for lk in board.locks if lk.resource == resource), None)
        if lock is None:
            raise Refused(f"no lock called {resource!r}; the locks are: {', '.join(lk.resource for lk in board.locks)}")
        if release:
            if lock.owner != agent:
                raise Refused(f"{resource} is held by {lock.owner or 'nobody'}")
            lock.owner = lock.since = lock.why = ""
        else:
            if lock.owner and lock.owner != agent:
                raise Refused(f"{resource} is held by {lock.owner} since {lock.since}: {lock.why}")
            lock.owner, lock.since, lock.why = agent, now(), message
        append_log(root, agent, f"{'unlocked' if release else 'locked'} {resource}" + (f": {message}" if message else ""))
    transact(root, agent, f"{'unlock' if release else 'lock'} {resource}", on_board(change))
    print(f"{resource} {'released' if release else 'held'}")


def cmd_msg(root: Path, agent: str, to: str, kind: str, message: str, task_id: str | None) -> None:
    if to not in ("all", "owner"):
        check_agent(to)
    number = transact(root, agent, f"{kind} to {to}", on_board(lambda root, board: board.handoff(agent, to, kind, message, task_id)))
    print(f"H-{number} sent to {to}")


def cmd_ack(root: Path, agent: str) -> None:
    def change(root):
        latest = max(Board((root / "TASKS.md").read_text(encoding="utf-8")).handoff_ids(), default=0)
        write_field(root, agent, "last-read", str(latest))
        return latest
    print(f"read up to H-{transact(root, agent, 'ack', change)}")


def cmd_join(root: Path, agent: str, force: bool) -> None:
    def change(root):
        path = agent_path(root, agent)
        if not path.exists():
            path.parent.mkdir(exist_ok=True)
            joined = max(Board((root / "TASKS.md").read_text(encoding="utf-8")).handoff_ids(), default=0)
            path.write_text(AGENT_TEMPLATE.format(agent=agent, stamp=now(), joined=joined), encoding="utf-8", newline="\n")
            append_log(root, agent, "joined the team")
            return
        text = path.read_text(encoding="utf-8")
        if not force and not is_idle(read_field(text, "session"), read_field(text, "last-seen")):
            raise Refused(f"{agent} looks active (last seen {read_field(text, 'last-seen')}): take an idle identity, or --force if that session is gone")
        write_field(root, agent, "session", "active")
        append_log(root, agent, "session started")
    transact(root, agent, "join", change)


def cmd_leave(root: Path, agent: str, message: str) -> None:
    def change(root):
        write_field(root, agent, "session", "idle")
        if message:
            set_section(root, agent, "Memory", f"- {now()} (end of session): {message}", append=True)
        append_log(root, agent, "session ended" + (f": {message}" if message else ""))
    transact(root, agent, "leave", change)
    print(f"{agent} is idle; its memory is in {BOARD_DIR}/agents/{agent}.md")


def cmd_status(root: Path, agent: str, show_all: bool, merged=pr_merged) -> None:
    text, board = read_board(root)
    mine = agent_path(root, agent).read_text(encoding="utf-8")
    unread = handoffs_for(text, agent, int(read_field(mine, "last-read") or 0), int(read_field(mine, "joined") or 0))
    print(f"== {agent} (lane {LANES.get(agent, '-')}): {len(unread)} unread handoff(s)" + (" — act on them, then `team.py ack`" if unread else ""))
    for entry in unread:
        print("   " + entry.replace("\n", "\n   "))
    print("== mine")
    for t in board.tasks:
        if t.owner == agent and t.status != "done":
            print(f"   {t.id} {t.status} {t.pr} — {t.title}")
    print("== others in flight")
    for t in board.tasks:
        if t.status in ("in-progress", "review", "assigned") and t.owner != agent:
            print(f"   {t.id} {t.status} {t.owner} {t.pr} — {t.title}")
    ready = board.ready_tasks(agent)
    shown = ready if show_all else ready[:15]
    print(f"== ready to claim: {len(ready)} (yours, your lane, then phase and priority" + ("" if show_all else "; --all for every one") + ")")
    for t in shown:
        print(f"   {t.id} {t.phase} lane {t.lane} {t.pri} {t.size} — {t.title}" + (" [assigned to you]" if t.owner == agent else ""))
    held = [lk for lk in board.locks if lk.owner]
    print("== locks held: " + (", ".join(f"{lk.resource} by {lk.owner} ({lk.why})" for lk in held) or "none"))
    # A merged PR whose `done` was forgotten keeps everything after it blocked.
    for t in board.tasks:
        if t.status == "review" and t.pr and merged(int(t.pr.lstrip("#"))):
            print(f"!! {t.id}'s PR {t.pr} is merged but the task is in review ({t.owner}): `team.py done {t.id} --pr {t.pr.lstrip('#')}` records it")


def cmd_show(root: Path, task_id: str) -> None:
    _, board = read_board(root)
    task = board.task(task_id)
    print(f"{task.id} · {task.title}\n{task.phase} · lane {task.lane} · {task.pri} · {task.size} · {task.status}"
          + (f" · {task.owner}" if task.owner else "") + (f" · PR {task.pr}" if task.pr else ""))
    if task.blocked_by:
        print("blocked by: " + ", ".join(f"{n} ({board.status_of(n)})" for n in task.blocked_by))
    added = root / "tasks" / f"{task_id}.md"
    if added.exists():
        print("\n" + added.read_text(encoding="utf-8"))
        return
    with PLAN_CSV.open(encoding="utf-8-sig", newline="") as plan:
        row = next((r for r in csv.DictReader(plan) if r["Task ID"] == task_id), None)
    if row is None:
        print(f"(no spec: {task_id} is neither in {PLAN_CSV.name} nor in {BOARD_DIR}/tasks/)")
        return
    for key in ("Epic", "Feature", "Sub-feature / capability", "Task type", "Platform", "Tier", "Description",
                "Acceptance criteria", "Screen IDs", "Components", "Design reference (dokulo-design.zip)",
                "Reference documents", "Blocks (task IDs)"):
        if row.get(key, "").strip():
            print(f"\n## {key}\n{row[key].strip()}")


def cmd_agents(root: Path) -> None:
    with board_lock(root):
        rows = identities(root)
    for agent, session, seen, doing in rows:
        print(f"{agent} (lane {LANES.get(agent, '-')})  {'idle' if is_idle(session, seen) else 'ACTIVE'}  last seen {seen}  now: {doing}")


def cmd_device(root: Path, agent: str, release: bool, refresh: bool = False) -> None:
    """The developers' emulator is one device on one machine: a local lock."""
    lock = Path(git(root, "rev-parse", "--path-format=absolute", "--git-common-dir").stdout.strip()) / "device.lock"
    owner_file = lock / "owner"
    holder = lambda: owner_file.read_text(encoding="utf-8").strip() if owner_file.exists() else "?"  # noqa: E731
    if refresh:
        if not owner_file.exists() or holder().split()[0] != agent:
            raise Refused("you don't hold the device")
        os.utime(lock)
        print("device lock refreshed")
        return
    if release:
        if owner_file.exists() and holder().split()[0] != agent:
            raise Refused(f"the device is held by {holder()}, not you")
        shutil.rmtree(lock, ignore_errors=True)
        print("device released")
        return
    for _ in range(3):
        try:
            lock.mkdir()  # atomic: exactly one agent gets it
            break
        except FileExistsError:
            try:
                age = time.time() - lock.stat().st_mtime
                who = holder()
            except FileNotFoundError:
                continue  # released while we looked: try again
            if age < DEVICE_LOCK_STALE_SECONDS:
                raise Refused(f"the device is in use by {who} ({int(age // 60)} min): do other work and try again") from None
            print(f"breaking a stale device lock ({who}, {int(age // 60)} min)")
            # Renamed aside in one step, so of two agents breaking it only one wins.
            aside = lock.with_name(f"{lock.name}.stale-{os.getpid()}-{time.time_ns()}")
            try:
                os.replace(lock, aside)
            except OSError:
                continue
            shutil.rmtree(aside, ignore_errors=True)
    else:
        raise Refused("the device lock is changing hands: try again")
    owner_file.write_text(f"{agent} {now()}\n", encoding="utf-8")
    print("device held: `team.py device --release` the moment the check is over")


# --- Where things are ------------------------------------------------------------------------

def check_agent(agent: str) -> str:
    if not AGENT_ID.match(agent):
        raise SystemExit(f"agent ids are agent-0 … agent-9, not {agent!r}")
    return agent


def check_task(task_id: str) -> str:
    if not TASK_ID.match(task_id):
        raise SystemExit(f"task ids look like DK-0001, not {task_id!r}")
    return task_id


def _git_out(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True, encoding="utf-8", check=True).stdout.strip()


def board_root() -> Path:
    """`<main checkout>/.team`, the same from every worktree; checked out on first use."""
    if os.environ.get("DK_BOARD"):
        return Path(os.environ["DK_BOARD"])
    main = Path(_git_out("rev-parse", "--path-format=absolute", "--git-common-dir")).parent
    root = main / BOARD_DIR
    if not (root / "TASKS.md").exists():
        git(main, "fetch", "--quiet", "origin", f"{BRANCH}:{BRANCH}", check=False)
        added = git(main, "worktree", "add", "--quiet", str(root), BRANCH, check=False)
        if added.returncode != 0:
            raise SystemExit(f"cannot check out the board at {root}: {added.stderr.strip()}")
    return root


def my_agent() -> str:
    marker = Path(_git_out("rev-parse", "--show-toplevel")) / ".dk-agent"
    if not marker.exists():
        raise SystemExit("this worktree has no agent: run `python tools/team.py agents`, then `join agent-N` in your worktree")
    return check_agent(marker.read_text(encoding="utf-8").strip())


def main(argv: list[str] | None = None) -> int:
    # The board is UTF-8 (→, ·, umlauts), and a Windows console is cp1252.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(prog="team.py", description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("agents")
    p = sub.add_parser("join"); p.add_argument("agent"); p.add_argument("--force", action="store_true")
    p = sub.add_parser("leave"); p.add_argument("-m", default="")
    p = sub.add_parser("status"); p.add_argument("--all", action="store_true")
    p = sub.add_parser("show"); p.add_argument("task", type=check_task)
    p = sub.add_parser("claim"); p.add_argument("task", type=check_task)
    p = sub.add_parser("assign"); p.add_argument("task", type=check_task); p.add_argument("to"); p.add_argument("-m", default="")
    p = sub.add_parser("release"); p.add_argument("task", type=check_task); p.add_argument("-m", required=True)
    p = sub.add_parser("review"); p.add_argument("task", type=check_task); p.add_argument("--pr", type=int, required=True); p.add_argument("--to", default="all")
    p = sub.add_parser("done"); p.add_argument("task", type=check_task); p.add_argument("--pr", type=int); p.add_argument("-m", default="")
    p = sub.add_parser("decision"); p.add_argument("task", type=check_task); p.add_argument("-m", required=True)
    p = sub.add_parser("reopen"); p.add_argument("task", type=check_task); p.add_argument("-m", required=True)
    p = sub.add_parser("add"); p.add_argument("title"); p.add_argument("--lane", required=True)
    p.add_argument("--phase", required=True); p.add_argument("--pri", default="P2"); p.add_argument("--size", default="S")
    p.add_argument("--blocked-by", nargs="*", default=[]); p.add_argument("--blocks", nargs="*", default=[])
    p.add_argument("-m", required=True, help="the spec: steps, expected, actual, evidence, acceptance criteria")
    p = sub.add_parser("log"); p.add_argument("-m", required=True); p.add_argument("--task", type=check_task)
    p = sub.add_parser("next"); p.add_argument("-m", required=True)
    p = sub.add_parser("note"); p.add_argument("-m", required=True)
    p = sub.add_parser("remember"); p.add_argument("topic"); p.add_argument("-m", required=True)
    p = sub.add_parser("msg"); p.add_argument("to"); p.add_argument("-m", required=True); p.add_argument("--task", type=check_task)
    p.add_argument("--kind", default="note", choices=("note", "question", "answer", "report", "heads-up", "review"))
    sub.add_parser("ack")
    p = sub.add_parser("lock"); p.add_argument("resource"); p.add_argument("-m", required=True)
    p = sub.add_parser("unlock"); p.add_argument("resource")
    p = sub.add_parser("device"); p.add_argument("--release", action="store_true"); p.add_argument("--refresh", action="store_true")
    args = parser.parse_args(argv)

    try:
        root = board_root()
        if args.cmd == "agents":
            cmd_agents(root)
            return 0
        if args.cmd == "show":
            cmd_show(root, args.task)
            return 0
        if args.cmd == "join":
            agent = check_agent(args.agent)
            cmd_join(root, agent, args.force)
            (Path(_git_out("rev-parse", "--show-toplevel")) / ".dk-agent").write_text(agent + "\n", encoding="utf-8")
            print(f"you are {agent}: read {root / 'agents' / (agent + '.md')} — your memory — then `team.py status`")
            return 0
        agent = my_agent()
        match args.cmd:
            case "leave": cmd_leave(root, agent, args.m)
            case "status": cmd_status(root, agent, args.all)
            case "claim": cmd_claim(root, agent, args.task)
            case "assign": cmd_assign(root, agent, args.task, args.to, args.m)
            case "release": cmd_release(root, agent, args.task, args.m)
            case "review": cmd_review(root, agent, args.task, args.pr, args.to)
            case "done": cmd_done(root, agent, args.task, args.pr, args.m)
            case "decision": cmd_decision(root, agent, args.task, args.m)
            case "reopen": cmd_reopen(root, agent, args.task, args.m)
            case "add": cmd_add(root, agent, args.title, args.lane, args.phase, args.pri, args.size, args.blocked_by, args.blocks, args.m)
            case "log": transact(root, agent, "log", lambda r: append_log(r, agent, args.m, args.task)); print("logged")
            case "next": transact(root, agent, "next", lambda r: set_section(r, agent, "Next", args.m)); print("next updated")
            case "note": transact(root, agent, "note", lambda r: set_section(r, agent, "Memory", f"- {now()}: {args.m}", append=True)); print("noted in your memory")
            case "remember": transact(root, agent, f"remember {args.topic}", lambda r: remember(r, agent, args.topic, args.m)); print("added to MEMORY.md")
            case "msg": cmd_msg(root, agent, args.to, args.kind, args.m, args.task)
            case "ack": cmd_ack(root, agent)
            case "lock": cmd_lock(root, agent, args.resource, args.m, release=False)
            case "unlock": cmd_lock(root, agent, args.resource, "", release=True)
            case "device": cmd_device(root, agent, args.release, args.refresh)
    except Refused as refused:
        print(f"refused: {refused}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
