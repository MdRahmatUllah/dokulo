"""Screenshots catalogue entries on a device for visual QA (DK-09xx): runs
integration_test/catalogue_shots_test.dart and saves one PNG per entry and
theme into OUT, to compare with the frames in dokulo-design/.

    python tools/device_checks/catalogue_shots.py emulator-5556 OUT "DkPinPad,DkDropdown"

Hold `team.py device` while it runs (docs/qa/device-lab.md)."""
import os
import re
import subprocess
import sys
import time
from pathlib import Path

FLUTTER = os.environ.get("FLUTTER", "flutter.bat" if os.name == "nt" else "flutter")
ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe") if os.name == "nt" else "adb"


def main(device, out, entries=""):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    proc = subprocess.Popen(
        [FLUTTER, "test", "integration_test/catalogue_shots_test.dart", "-d", device,
         "--flavor", "dev", f"--dart-define=QA_ENTRIES={entries}"],
        cwd="packages/app_pdf", stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding="utf-8", errors="replace", shell=os.name == "nt")
    shots = 0
    for line in proc.stdout:
        shown = re.search(r"DEVICE \| QA \| (.+?) \| (light|dark)", line)
        if shown:
            time.sleep(1)  # let the frame settle
            name = re.sub(r"[^A-Za-z0-9]+", "-", shown.group(1)).strip("-")
            png = subprocess.run([ADB, "-s", device, "exec-out", "screencap", "-p"],
                                 capture_output=True, timeout=60).stdout
            (out / f"{name}-{shown.group(2)}.png").write_bytes(png)
            shots += 1
        elif "All tests" in line or "Some tests" in line:
            print(line.rstrip(), flush=True)
    code = proc.wait()
    print(f"{shots} screenshots in {out}", flush=True)
    return code


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:4]))
