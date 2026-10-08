"""Drives integration_test/files_visibility_test.dart (DK-1043) on an
emulator: when the test has saved its file, opens the Files app at
Documents/Dokulo and saves a screenshot of it (look for the file there), then
deletes the file as the Files app would; the test then checks the index
drops it.

    python tools/device_checks/files_visibility.py emulator-5556 shot.png

Hold `team.py device` while it runs (docs/qa/device-lab.md)."""
import os
import re
import subprocess
import sys
import time

FLUTTER = os.environ.get("FLUTTER", "flutter.bat" if os.name == "nt" else "flutter")
ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe") if os.name == "nt" else "adb"
# The Files app (DocumentsUI) opened at the folder.
FOLDER = "content://com.android.externalstorage.documents/document/primary%3ADocuments%2FDokulo"


def main(device, screenshot):
    def sh(command):
        # One string: adb shell re-splits its arguments.
        r = subprocess.run([ADB, "-s", device, "shell", command], capture_output=True, text=True, timeout=60)
        return (r.stdout + r.stderr).strip()

    proc = subprocess.Popen(
        [FLUTTER, "test", "integration_test/files_visibility_test.dart", "-d", device, "--flavor", "dev"],
        cwd="packages/app_pdf", stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding="utf-8", errors="replace", shell=os.name == "nt")
    shown = False
    for line in proc.stdout:
        if "DEVICE |" in line or "All tests" in line or "Some tests" in line:
            print(line.rstrip(), flush=True)
        saved = re.search(r"DEVICE \| DK-1043 \| saved \| (\S+)", line)
        if saved:
            path = saved.group(1).replace("/storage/emulated/0", "/sdcard")
            print("HOST | on disk:", sh(f"ls -l '{path}'"), flush=True)
            sh(f"am start -a android.intent.action.VIEW -d {FOLDER} -t vnd.android.document/directory")
            time.sleep(10)  # the Files app loads the folder
            with open(screenshot, "wb") as f:
                f.write(subprocess.run([ADB, "-s", device, "exec-out", "screencap", "-p"],
                                       capture_output=True, timeout=60).stdout)
            shown = os.path.getsize(screenshot) > 0
            print("HOST | the Files app at Documents/Dokulo:", screenshot, flush=True)
            sh("input keyevent KEYCODE_HOME")
            print("HOST | delete outside the app:", sh(f"rm '{path}'") or "ok", flush=True)
    code = proc.wait()
    print("DK-1043", "PASS (check the screenshot)" if code == 0 and shown else "FAIL", flush=True)
    return 0 if code == 0 and shown else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
