"""The local gate runs every step, keeps going after a failure and fails the
whole run; it picks flutter test or dart test per package."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check  # noqa: E402


def test_run_reports_every_step(tmp_path: Path, capsys) -> None:
    ok = [sys.executable, "-c", "pass"]
    bad = [sys.executable, "-c", "print('broken'); raise SystemExit(3)"]
    assert check.run([("one", ok, tmp_path), ("two", bad, tmp_path), ("three", ok, tmp_path)]) == 1
    out = capsys.readouterr().out
    assert "PASS  one" in out and "FAIL  two" in out and "PASS  three" in out and "broken" in out
    assert "2/3 passed; failed: two" in out
    assert check.run([("one", ok, tmp_path)]) == 0


def test_steps_pick_the_right_test_runner(tmp_path: Path) -> None:
    for name, pubspec in (("app", "dependencies:\n  flutter:\n    sdk: flutter\ndev_dependencies:\n  build_runner: ^2.0.0\n"),
                          ("core", "dependencies:\n  ai:\n    path: ../ai\n"),
                          ("empty", "name: empty\n")):
        (tmp_path / "packages" / name).mkdir(parents=True)
        (tmp_path / "packages" / name / "pubspec.yaml").write_text(pubspec, encoding="utf-8")
    (tmp_path / "packages" / "app" / "test").mkdir()
    (tmp_path / "packages" / "core" / "test").mkdir()

    plan = {name: command for name, command, _ in check.steps(tmp_path, apk=Path("x.apk"))}
    assert list(plan)[:4] == ["ocr models", "icon font", "signature fonts", "pub get"]
    assert "build_runner app" in plan and "build_runner core" not in plan
    assert plan["test app"][1:] == ["test", "--timeout", "60s", "--concurrency", "4"] and "flutter" in plan["test app"][0]
    assert plan["test core"][1:] == ["test"] and "dart" in plan["test core"][0]
    assert "test empty" not in plan
    assert plan["native libs"][-1] == "x.apk" and plan["size budget"][-1] == "x.apk"


def test_app_pdf_generates_last(tmp_path: Path) -> None:
    for name in ("app_pdf", "doc_core", "zeta"):
        (tmp_path / "packages" / name).mkdir(parents=True)
        (tmp_path / "packages" / name / "pubspec.yaml").write_text(
            "dev_dependencies:\n  build_runner: ^2.0.0\n", encoding="utf-8")
    plan = [name for name, _, _ in check.steps(tmp_path, apk=None) if name.startswith("build_runner")]
    assert plan == ["build_runner doc_core", "build_runner zeta", "build_runner app_pdf"]


def test_gate_lock_waits_for_a_live_gate_and_takes_over_a_dead_one(tmp_path: Path) -> None:
    import subprocess
    import threading

    lock = tmp_path / "gate.lock"
    said = []
    # A live holder: this very process. The second gate waits until it lets go.
    with check.gate_lock(lock, poll=0.05):
        assert lock.read_text(encoding="utf-8").split()[0] == str(__import__("os").getpid())
        entered = threading.Event()

        def second():
            with check.gate_lock(lock, poll=0.05, say=lambda *a, **k: said.append(a[0])):
                entered.set()

        t = threading.Thread(target=second)
        t.start()
        assert not entered.wait(0.3)
        assert any("waiting" in s for s in said)
    t.join(5)
    assert entered.is_set() and not lock.exists()

    # A dead holder: a process that has ended.
    gone = subprocess.run([sys.executable, "-c", "import os; print(os.getpid())"],
                          capture_output=True, text=True).stdout.strip()
    lock.write_text(f"{gone} somewhere\n", encoding="utf-8")
    said.clear()
    with check.gate_lock(lock, poll=0.05, say=lambda *a, **k: said.append(a[0])):
        assert "taking over" in said[0]
    assert not lock.exists()



def test_gate_lock_takes_turns_in_order(tmp_path: Path) -> None:
    import os
    import threading

    lock = tmp_path / "gate.lock"
    queue = tmp_path / "gate.lock.queue"
    queue.mkdir()
    # An older ticket of a gate still running (this process): a newer gate
    # waits behind it even though the lock is free.
    older = queue / f"{1:020d}-{os.getpid()}"
    older.touch()
    entered = threading.Event()

    def newer():
        with check.gate_lock(lock, poll=0.05, say=lambda *a, **k: None):
            entered.set()

    t = threading.Thread(target=newer)
    t.start()
    assert not entered.wait(0.3)
    older.unlink()
    t.join(5)
    assert entered.is_set()
    assert not lock.exists() and list(queue.iterdir()) == []
