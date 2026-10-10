# Locked folder: security checks (DK-0291)

What protects the locked folder, and how each part is checked. Automated
checks run in the gate; the manual ones need a phone and are done before
each release (and recorded in the release's QA notes).

## Automated

| Check | Where |
|---|---|
| A sealed file shows neither its content nor its name (raw bytes are ciphertext; names live only in the sealed manifest) | `doc_core/test/files/locked_store_test.dart` |
| The folder's key is nowhere in the vault's files | `locked_store_test.dart` |
| The wrong key opens nothing | `locked_crypto_test.dart`, `locked_store_test.dart` |
| A failing move leaves the original untouched; the plain copy goes only after the sealed copy reads back | `locked_store_test.dart` |
| Locking deletes every decrypted copy (viewing decrypts to `<work>/locked/open` only) | `locked_store_test.dart`, `app_pdf/test/screens/locked_move_test.dart` |
| A moved file's thumbnails leave the plain cache (`ThumbnailCache.forget`) | `locked_move_test.dart` (the move), `thumbnail_cache` keys |
| The PIN is stored only as a PBKDF2 hash; the key only in the secret store (Keychain / Keystore) | `app_pdf/test/screens/locked_security_test.dart`, `locked_folder_screen_test.dart` |
| PIN brute force: 5 free tries, then 30 s, doubling up to 1 h; even the right PIN waits while throttled | `locked_security_test.dart`, `locked_crypto_test.dart` (PinThrottle) |
| While the folder is open the app switcher shows the privacy cover; locking or leaving drops it | `locked_security_test.dart` |
| Leaving the folder, Lock now and a minute in the background lock it | `locked_folder_screen_test.dart` |

## Manual (on a phone)

1. **App switcher.** Open the locked folder, go to the app switcher: the card shows the Dokulo cover, not the files (iOS); the card is blank and a screenshot is refused (Android, FLAG_SECURE). Lock it: the card shows the app again.
2. **Screenshots** (Android): inside the folder and its viewer, a screenshot is blocked; outside it works.
3. **Background lock.** Open the folder, leave the app for more than a minute, come back: the unlock screen shows.
4. **Biometrics change.** Add a new fingerprint or face in the OS settings: the folder still opens with the PIN; biometrics ask again (the OS invalidates the old binding).
5. **Files app / file manager.** In iOS Files and an Android file manager, the Dokulo folder shows no locked file and no decrypted copy, before and after viewing one.
6. **Backup.** The vault lives in the app sandbox (`<app support>/work/locked`). Check it is excluded from iCloud/Google backup together with the rest of `work/`; the key never leaves the phone's Keychain/Keystore.
7. **Uninstall and reinstall.**
   - **Android:** uninstalling removes the sandbox and the Keystore key; after reinstalling the folder is new and empty.
   - **iOS:** the sandbox goes, but a Keychain item can survive a reinstall. The sealed files are gone with the sandbox, so nothing can be recovered either way, as the L1 intro warns ("If you forget the PIN and biometrics stop working, these files can't be recovered"). A leftover key opens nothing.

Record each manual run (phone, OS version, date, result) in the release's QA
notes; a real-device run is owed for the M06 follow-ups (no phone is
connected yet; the emulator covers 1–3 and 5).
