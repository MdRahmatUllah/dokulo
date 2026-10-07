"""PDF/A check (DK-0395): the PDF/A writer's output on the sample documents
must validate as PDF/A-2b in veraPDF.

    python tools/check_pdfa.py

Runs doc_core's pdfa_writer_test with PDFA_OUT set (it writes one PDF/A file
per sample document there), then veraPDF over the folder. veraPDF is a test
tool (GPL/MPL, Java), never shipped: install it once per machine, see
docs/compliance/pdfa.md. VERAPDF overrides where it is looked for.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def verapdf() -> Path | None:
    if os.environ.get("VERAPDF"):
        return Path(os.environ["VERAPDF"])
    home = Path(os.environ.get("LOCALAPPDATA", Path.home() / ".local" / "share")) / "dokulo-tools" / "verapdf"
    for name in ("verapdf.bat", "verapdf"):
        if (home / name).is_file():
            return home / name
    found = shutil.which("verapdf")
    return Path(found) if found else None


def failures(report: str) -> list[str]:
    """'<file>: <clause>-<test>' for every failed rule; '<file>: not checked' when veraPDF couldn't parse it."""
    out = []
    for job in report.split("<job>")[1:]:
        name = re.search(r"<item [^>]*>\s*<name>([^<]*)</name>", job)
        file = Path(name.group(1)).name if name else "?"
        if not re.search(r'isCompliant="true"', job):
            rules = re.findall(r'<rule [^>]*clause="([^"]*)"[^>]*testNumber="(\d+)"[^>]*status="failed"', job)
            out += [f"{file}: PDF/A-2b clause {c} test {t}" for c, t in rules] or [f"{file}: not checked"]
    return out


def main() -> int:
    tool = verapdf()
    if tool is None:
        print("check_pdfa: veraPDF not found; install it as docs/compliance/pdfa.md says (or set VERAPDF)")
        return 1
    flutter_dart = shutil.which("dart") or "dart"
    with tempfile.TemporaryDirectory(prefix="dk_pdfa_") as out:
        made = subprocess.run([flutter_dart, "test", "test/pdf/pdfa_writer_test.dart"], cwd=ROOT / "packages" / "doc_core",
                              env={**os.environ, "PDFA_OUT": out}, capture_output=True, text=True)
        if made.returncode != 0:
            print(made.stdout[-3000:] + made.stderr[-2000:])
            print("check_pdfa: the PDF/A writer's tests failed")
            return 1
        files = sorted(Path(out).glob("*.pdf"))
        command = [str(tool), "--flavour", "2b", "--format", "xml", out]
        if os.name == "nt" and tool.suffix == ".bat":
            command = ["cmd", "/c", *command]
        report = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
        problems = failures(report)
        if len(re.findall(r"<job>", report)) != len(files):
            problems.append(f"veraPDF checked {len(re.findall(r'<job>', report))} of {len(files)} files")
    for p in problems:
        print(p)
    print(f"pdfa check: {len(files)} files, " + (f"{len(problems)} problem(s)" if problems else "all PDF/A-2b"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
