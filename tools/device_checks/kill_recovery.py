"""Drives integration_test/kill_recovery_test.dart (DK-1047) on an emulator:
three launches; in the first two the app is force-stopped once Compress has
started, and before the third the second job's input is deleted.

    python tools/device_checks/kill_recovery.py emulator-5556

Hold `team.py device` while it runs (docs/qa/device-lab.md)."""
import os
import re
import subprocess
import sys
import time

APP = "app.dokulo.dev"
FLUTTER = os.environ.get("FLUTTER", "flutter.bat" if os.name == "nt" else "flutter")
ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe") if os.name == "nt" else "adb"


def adb(device, *args):
    return subprocess.run([ADB, "-s", device, *args], capture_output=True, text=True, timeout=60).stdout.strip()


def launch(device, on_started=None):
    """One run of the test; on_started(path) runs when the job has started."""
    proc = subprocess.Popen(
        [FLUTTER, "test", "integration_test/kill_recovery_test.dart", "-d", device, "--flavor", "dev"],
        cwd="packages/app_pdf", stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding="utf-8", errors="replace", shell=os.name == "nt")
    for line in proc.stdout:
        if "DEVICE |" in line or "All tests" in line or "Some tests" in line:
            print(line.rstrip(), flush=True)
        started = re.search(r"DEVICE \| DK-1047 \| started \| (\S+)", line)
        if started and on_started:
            on_started(started.group(1))
    return proc.wait()


def main(device):
    def kill(_):
        time.sleep(2)  # well inside the job: a dozen pages take several seconds
        adb(device, "shell", "am", "force-stop", APP)
        print("HOST | force-stopped", APP, flush=True)

    def kill_and_delete(path):
        kill(path)
        adb(device, "shell", "rm", path.replace("/storage/emulated/0", "/sdcard"))
        print("HOST | deleted", path, flush=True)

    launch(device, kill)
    launch(device, kill_and_delete)
    code = launch(device)
    print("DK-1047", "PASS" if code == 0 else "FAIL", flush=True)
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
