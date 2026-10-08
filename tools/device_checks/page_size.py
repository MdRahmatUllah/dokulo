"""Drives integration_test/page_size_test.dart (DK-1048) on a 16 KB-page
emulator: prints the device's page size, and when the test asks, copies
test/fixtures/Invoice INV-2026-014.pdf into the app's folder (run-as works on
the debug build).

    python tools/device_checks/page_size.py emulator-5560

Hold `team.py device` while it runs (docs/qa/device-lab.md)."""
import os
import re
import subprocess
import sys

APP = "app.dokulo.dev"
FIXTURE = "test/fixtures/Invoice INV-2026-014.pdf"
FLUTTER = os.environ.get("FLUTTER", "flutter.bat" if os.name == "nt" else "flutter")
ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe") if os.name == "nt" else "adb"


def main(device):
    def adb(*args, **kw):
        return subprocess.run([ADB, "-s", device, *args], capture_output=True, timeout=120, **kw)

    page = adb("shell", "getconf PAGE_SIZE").stdout.decode().strip()
    print("HOST | page size:", page, flush=True)
    proc = subprocess.Popen(
        [FLUTTER, "test", "integration_test/page_size_test.dart", "-d", device, "--flavor", "dev"],
        cwd="packages/app_pdf", stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding="utf-8", errors="replace", shell=os.name == "nt")
    for line in proc.stdout:
        if "DEVICE |" in line or "All tests" in line or "Some tests" in line:
            print(line.rstrip(), flush=True)
        waiting = re.search(r"DEVICE \| DK-1048 \| waiting \| (\S+)", line)
        if waiting:
            with open(FIXTURE, "rb") as f:
                r = adb("exec-in", "run-as", APP, "sh", "-c", f"cat > '{waiting.group(1)}'", stdin=f)
            print("HOST | copied the invoice:", r.returncode == 0, flush=True)
    code = proc.wait()
    ok = code == 0 and page == "16384"
    print("DK-1048", "PASS" if ok else "FAIL", flush=True)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
