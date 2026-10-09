"""The local gate (DK-0010): the whole basic check in one command. The owner
decided on 2026-10-07 that there is no CI/CD, so this is what every PR passes
before it is merged.

    python tools/check.py [--apk path/to/app.apk]

Runs every step from the repo root, even after a failure, then prints a summary
and exits 1 if any step failed. A failing step's output is printed in full.
"""

import argparse
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
TEST_CONCURRENCY = "1"


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
    out += [(f"build_runner {p.name}", [dart, "run", "build_runner", "build", "-d"], p)
            for p in packages(root) if uses(p, "build_runner")]
    out += [
        ("analyze", [flutter, "analyze", "--fatal-infos"], root),
        ("format", [dart, "format", "--output=none", "--set-exit-if-changed", "packages"], root),
        ("layers", [py, "tools/check_layers.py"], root),
        ("licences", [py, "tools/licence_scan.py"], root),
        ("l10n", [py, "tools/check_l10n.py"], root),
        ("permissions", [py, "tools/check_permissions.py"], root),
        ("tokens", [py, "tools/check_tokens.py"], root),
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


def main() -> int:
    # A failing step's output (ß, –, emoji from test names) must print on a
    # Windows console (cp1252) instead of crashing the gate.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--apk", type=Path, help="also check a built APK's native libraries")
    args = parser.parse_args()
    return run(steps(ROOT, args.apk))


if __name__ == "__main__":
    sys.exit(main())
