"""The board's rules: claim only what is ready and free, a refused change leaves
no trace, done frees what waited, add files a task that re-blocks a check."""

import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import team  # noqa: E402

TASKS = """# Tasks

## Tasks

| Task | Ph | Lane | Pri | Size | Title | Status | Owner | Blocked by | PR |
|---|---|---|---|---|---|---|---|---|---|
| DK-0001 | P1 | A | P0 | M | Monorepo | open |  |  |  |
| DK-0002 | P1 | B | P1 | S | Tokens | open |  | DK-0001 |  |
| DK-0003 | P7 | Q | P2 | XS | QA the tokens | open |  | DK-0002 |  |

## Locks

| Resource | Owner | Since | Why |
|---|---|---|---|
| pubspec |  |  |  |

## Handoffs
"""


@pytest.fixture
def board(tmp_path: Path) -> Path:
    subprocess.run(["git", "init", "-q", "-b", "team", str(tmp_path)], check=True)
    for key, value in (("user.name", "t"), ("user.email", "t@example.com")):
        subprocess.run(["git", "-C", str(tmp_path), "config", key, value], check=True)
    (tmp_path / "TASKS.md").write_text(TASKS, encoding="utf-8")
    for agent in ("agent-0", "agent-1", "agent-3"):
        (tmp_path / "agents").mkdir(exist_ok=True)
        (tmp_path / "agents" / f"{agent}.md").write_text(team.AGENT_TEMPLATE.format(agent=agent, stamp=team.now(), joined=0), encoding="utf-8")
    for name in ("WORKLOG.md", "MEMORY.md"):
        (tmp_path / name).write_text(f"# {name}\n", encoding="utf-8")
    subprocess.run(["git", "-C", str(tmp_path), "add", "-A"], check=True)
    subprocess.run(["git", "-C", str(tmp_path), "commit", "-qm", "seed"], check=True)
    return tmp_path


def tasks(root: Path) -> team.Board:
    return team.Board((root / "TASKS.md").read_text(encoding="utf-8"))


def test_claim_blocked_is_refused_and_leaves_no_trace(board: Path):
    with pytest.raises(team.Refused, match="blocked by DK-0001"):
        team.cmd_claim(board, "agent-1", "DK-0002")
    assert team.git(board, "status", "--porcelain").stdout == ""
    assert tasks(board).task("DK-0002").status == "open"


def test_done_frees_the_next_task_and_reports_it(board: Path):
    team.cmd_claim(board, "agent-0", "DK-0001")
    with pytest.raises(team.Refused, match="in progress"):
        team.cmd_claim(board, "agent-0", "DK-0002")
    team.cmd_review(board, "agent-0", "DK-0001", 4, "all")
    with pytest.raises(team.Refused, match="not merged"):
        team.cmd_done(board, "agent-0", "DK-0001", 4, "", merged=lambda pr: False)
    team.cmd_done(board, "agent-0", "DK-0001", 4, "", merged=lambda pr: True)
    assert "Now ready: DK-0002" in (board / "TASKS.md").read_text(encoding="utf-8")
    team.cmd_claim(board, "agent-1", "DK-0002")
    assert tasks(board).task("DK-0002").owner == "agent-1"
    assert "| agent-1 | B |" in (board / "STATUS.md").read_text(encoding="utf-8")


def test_a_bug_blocks_the_check_until_it_is_done(board: Path):
    for agent, task in (("agent-0", "DK-0001"), ("agent-1", "DK-0002")):
        team.cmd_claim(board, agent, task)
        team.cmd_done(board, agent, task, None, "")
    team.cmd_claim(board, "agent-3", "DK-0003")
    team.cmd_add(board, "agent-3", "bug(tokens): wrong teal", "B", "P7", "P1", "S", [], ["DK-0003"], "Expected #0F766E.")
    check = tasks(board).task("DK-0003")
    assert (check.status, check.blocked_by) == ("open", ["DK-0002", "DK-0004"])
    assert "Expected #0F766E." in (board / "tasks" / "DK-0004.md").read_text(encoding="utf-8")
    assert [t.id for t in tasks(board).ready_tasks("agent-1")] == ["DK-0004"]


def test_handoffs_reach_their_reader_once(board: Path):
    team.cmd_msg(board, "agent-0", "agent-1", "note", "hello", None)
    text = (board / "TASKS.md").read_text(encoding="utf-8")
    assert len(team.handoffs_for(text, "agent-1", 0)) == 1
    assert team.handoffs_for(text, "agent-3", 0) == []
    team.cmd_ack(board, "agent-1")
    assert team.read_field((board / "agents" / "agent-1.md").read_text(encoding="utf-8"), "last-read") == "1"
