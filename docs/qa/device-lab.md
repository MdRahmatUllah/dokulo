# The device lab (DK-0668)

What Dokulo is checked on, and how a device check records its scope. The
targets come from the Technology plan ("Testing and device targets").

## Now: the shared emulator (the owner, 2026-10-08)

Device checks run on **`emulator-5554`** now and are marked done with that
scope; the real-phone parts become follow-up tasks for when phones are
connected (DK-1066).

| Device | OS | ABI | RAM | Screen | Page size | Use |
| --- | --- | --- | --- | --- | --- | --- |
| `emulator-5554`, AVD `flutter_emulator` (`sdk_gphone64_x86_64`) | Android 16 (API 36), patch 2025-04-05 | x86_64; arm64-v8a apps run through translation | 2 GB | 1080 × 1920, 420 dpi | 4 KB | Every Android device check, x86_64 scope. Close to the low-end target in memory |

- Hold it with `python tools/team.py device` while you install or drive it,
  release it right after; always name it: `adb -s emulator-5554`
  (`$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe` in Git Bash).
- After an install, check `dumpsys package app.dokulo.dev | grep lastUpdateTime`.
- DeutschPlan's `emulator-5556` and `-5558` are not ours.
- The planned AVDs `dk-dev` (5562) and `dk-sqa` (5564) aren't created: one
  emulator is what this machine's memory allows next to both teams' builds.
  Create them only when the owner says memory is free.
- Not covered by the emulator: arm64 speed, iOS, 16 KB pages (DK-1048 needs a
  16 KB system image), real cameras.

## Later: the real devices (DK-1066)

| Target | Why | Status |
| --- | --- | --- |
| Low-end Android, 3 GB RAM, arm64 | memory floor; AI eligibility off | not connected |
| Mid Android, 6–8 GB RAM, arm64 | the performance targets (OCR page < 1.5 s, compress 50 pages < 20 s, merge 200 pages < 3 s) | not connected |
| Older iPhone (iPhone 11), iOS 16+ | Vision OCR, the slowest supported iPhone | not connected (needs the Mac, DK-1046) |
| Recent iPhone | Vision OCR, Gemma speed | not connected (needs the Mac, DK-1046) |
| Tablets (one Android, one iPad) | the tablet layouts (`24-tablet/`) | not connected |

armeabi-v7a phones get the tools but no AI (Technology plan).

## How a device check records its result

In its `team.py done` message (and the PR, if it changes code): the device,
OS and ABI, the build (`dev` debug or `prod` release), what passed, the
numbers measured, and what the emulator couldn't cover, as a follow-up task
under DK-1066 when it needs a real phone.
