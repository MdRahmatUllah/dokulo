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
    assert "build_runner app" in plan and "build_runner core" not in plan
    assert plan["test app"][1:] == ["test", "--timeout", "60s"] and "flutter" in plan["test app"][0]
    assert plan["test core"][1:] == ["test"] and "dart" in plan["test core"][0]
    assert "test empty" not in plan
    assert plan["native libs"][-1] == "x.apk"
