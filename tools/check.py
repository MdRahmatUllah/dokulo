"""The local gate (DK-0010): the whole basic check in one command. The owner
decided on 2026-10-07 that there is no CI/CD, so this is what every PR passes
before it is merged.

    python tools/check.py [--apk path/to/app.apk]

Runs every step from the repo root, even after a failure, then prints a summary
and exits 1 if any step failed. A failing step's output is printed in full.
"""

import argparse
import contextlib
import ctypes
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STEP_TIMEOUT = 900  # seconds; a step that hangs fails instead of blocking the gate


def tool(name: str) -> str:
    """flutter and dart are .bat files on Windows; subprocess needs the full path."""
    return shutil.which(name) or name


def packages(root: Path) -> list[Path]:
    return sorted(p.parent for p in (root / "packages").glob("*/pubspec.yaml"))


def is_flutter(package: Path) -> bool:
    return re.search(r"^\s+sdk: flutter\s*$", (package / "pubspec.yaml").read_text(encoding="utf-8"), re.M) is not None


def uses(package: Path, dependency: str) -> bool:
    return re.search(rf"^\s+{dependency}:", (package / "pubspec.yaml").read_text(encoding="utf-8"), re.M) is not None


# Test files `flutter test` runs at once, each in its own flutter_tester. The
# default is one per core (26 on the team's 28-thread machine), and app_pdf's
# 49 files then peak at several GB: the system stopped gate runs for low
# memory (2026-10-08). `dart test` keeps its default: its suites are isolates
# in one process, and staggering them crashes PDFium ("Cannot invoke native
# callback from a different isolate", pdfrx's process-wide callbacks).
# ponytail: a fixed 4; raise it when the machine has the memory to spare.
TEST_CONCURRENCY = "4"


def steps(root: Path, apk: Path | None = None) -> list[tuple[str, list[str], Path]]:
    """(name, command, working directory) for every step of the basic check."""
    py, flutter, dart = sys.executable, tool("flutter"), tool("dart")
    # The bundled OCR models (DK-0398): Flutter needs the asset files, the
    # OCR tests the real models. Fetched once, hash-checked every run.
    out = [
        ("ocr models", [py, "tools/fetch_ocr_models.py"], root),
        # The icon font (DK-0048), declared in app_pdf's pubspec.
        ("icon font", [py, "tools/fetch_icon_font.py"], root),
        # The signature pad's handwriting fonts (DK-0206).
        ("signature fonts", [py, "tools/fetch_signature_fonts.py"], root),
        ("pub get", [flutter, "pub", "get"], root),
    ]
    # app_pdf last: its generators read the other packages' generated types
    # (doc_core's database rows), which must be current first.
    out += [(f"build_runner {p.name}", [dart, "run", "build_runner", "build", "-d"], p)
            for p in sorted(packages(root), key=lambda p: p.name == "app_pdf")
            if uses(p, "build_runner")]
    out += [
        ("analyze", [flutter, "analyze", "--fatal-infos"], root),
        ("format", [dart, "format", "--output=none", "--set-exit-if-changed", "packages"], root),
        ("layers", [py, "tools/check_layers.py"], root),
        ("licences", [py, "tools/licence_scan.py"], root),
        ("l10n", [py, "tools/check_l10n.py"], root),
        ("permissions", [py, "tools/check_permissions.py"], root),
        ("tokens", [py, "tools/check_tokens.py"], root),
        ("copy deck", [py, "tools/check_copy_deck.py"], root),
        ("design German", [py, "tools/check_design_de.py"], root),
        ("privacy manifests", [py, "tools/check_privacy_manifests.py"], root),
    ]
    for p in packages(root):
        if (p / "test").is_dir():
            command = ([flutter, "test", "--timeout", "60s", "--concurrency", TEST_CONCURRENCY]
                       if is_flutter(p) else [dart, "test"])
            out.append((f"test {p.name}", command, p))
    out.append(("tools tests", [py, "-m", "pytest", "tools/tests", "-q"], root))
    out.append(("pdfa (veraPDF)", [py, "tools/check_pdfa.py"], root))
    if apk:
        out.append(("native libs", [py, "tools/native_libs_check.py", str(apk)], root))
        out.append(("apk permissions", [py, "tools/check_permissions.py", str(apk)], root))
        out.append(("size budget", [py, "tools/size_check.py", str(apk)], root))
    return out


def run(plan: list[tuple[str, list[str], Path]]) -> int:
    failed = []
    for name, command, cwd in plan:
        start = time.monotonic()
        try:
            result = subprocess.run(command, cwd=cwd, capture_output=True, text=True,
                                    encoding="utf-8", errors="replace", timeout=STEP_TIMEOUT)
            ok, output = result.returncode == 0, result.stdout + result.stderr
        except (OSError, subprocess.TimeoutExpired) as error:
            ok, output = False, str(error)
        print(f"{'PASS' if ok else 'FAIL'}  {name}  ({time.monotonic() - start:.0f} s)", flush=True)
        if not ok:
            failed.append(name)
            print(output.rstrip() + "\n", flush=True)
    print(f"local gate: {len(plan) - len(failed)}/{len(plan)} passed" + (f"; failed: {', '.join(failed)}" if failed else ""))
    return 1 if failed else 0


def alive(pid: int) -> bool:
    """Whether process [pid] is still running."""
    if sys.platform == "win32":
        kernel = ctypes.windll.kernel32
        handle = kernel.OpenProcess(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
        if not handle:
            return False
        try:
            code = ctypes.c_ulong()
            return bool(kernel.GetExitCodeProcess(handle, ctypes.byref(code))) and code.value == 259  # STILL_ACTIVE
        finally:
            kernel.CloseHandle(handle)
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


@contextlib.contextmanager
def gate_lock(path: Path, poll: float = 20, say=print):
    """One gate at a time on this machine (the owner, 2026-10-15): every
    worktree's gate takes [path] (in the shared .git folder), and waits while
    a running gate holds it. A lock whose gate is gone (killed for low memory,
    say) is taken over. Waiting gates take their turn in the order they came
    (a ticket each in [path].queue), not whoever looks first. A waiting
    gate touches its ticket every poll; a ticket nobody touched for a while
    is dropped too, so a gate killed while waiting can't hold the line
    through its pid, reused by another process (DK-1132)."""
    queue = path.with_name(path.name + ".queue")
    queue.mkdir(exist_ok=True)
    ticket = queue / f"{time.time_ns():020d}-{os.getpid()}"
    ticket.touch()
    try:
        _take(path, queue, ticket, poll, say)
        _unlink(ticket)
        yield
    finally:
        _unlink(ticket)
        _unlink(path)


def _first(queue: Path, stale: float = 180) -> Path | None:
    """The oldest ticket of a gate still waiting: its pid alive and the
    ticket touched within [stale] seconds; other tickets go."""
    for t in sorted(queue.iterdir()):
        try:
            pid = int(t.name.split("-")[1])
            fresh = time.time() - t.stat().st_mtime < stale
        except (IndexError, ValueError, OSError):
            pid, fresh = -1, False
        if pid > 0 and fresh and alive(pid):
            return t
        _unlink(t)
    return None


def _take(path: Path, queue: Path, ticket: Path, poll: float, say) -> None:
    while True:
        ticket.touch()
        first = _first(queue, stale=6 * poll + 60)
        if first is not None and first != ticket:
            say(f"gate lock: waiting in line behind {first.name}", flush=True)
            time.sleep(poll)
            continue
        try:
            fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except PermissionError:
            # Windows: the file is being deleted, or read, right now.
            time.sleep(min(poll, 0.2))
            continue
        except FileExistsError:
            try:
                pid = int(path.read_text(encoding="utf-8").split()[0])
            except (OSError, ValueError, IndexError):
                # Being written this moment, or deleted: look again soon.
                try:
                    if time.time() - path.stat().st_mtime > 10:
                        _unlink(path)
                except OSError:
                    pass
                time.sleep(min(poll, 1))
                continue
            if not alive(pid):
                say(f"gate lock: pid {pid} is gone; taking over", flush=True)
                _unlink(path)
                continue
            say(f"gate lock: waiting for the gate in pid {pid}", flush=True)
            time.sleep(poll)
            continue
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(f"{os.getpid()} {ROOT}\n")
        return


def _unlink(path: Path) -> None:
    """Deletes [path]; on Windows a waiting gate may be reading it this very
    moment, so try again for a few seconds."""
    for _ in range(50):
        try:
            path.unlink(missing_ok=True)
            return
        except PermissionError:
            time.sleep(0.1)
    path.unlink(missing_ok=True)


def lock_path(root: Path) -> Path:
    """The lock file in the git folder every worktree shares."""
    common = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
                            cwd=root, capture_output=True, text=True, check=True).stdout.strip()
    return Path(common) / "dokulo-gate.lock"


def main() -> int:
    # A failing step's output (ß, –, emoji from test names) must print on a
    # Windows console (cp1252) instead of crashing the gate.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--apk", type=Path, help="also check a built APK's native libraries")
    args = parser.parse_args()
    with gate_lock(lock_path(ROOT)):
        return run(steps(ROOT, args.apk))


if __name__ == "__main__":
    sys.exit(main())
