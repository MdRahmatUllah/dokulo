import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'scanner_settings.g.dart';

/// The scanner's remembered choices (DK-0338; Settings → Scanning). Auto-crop
/// and auto-capture are separate (the top complaint about other scanners):
/// auto-crop is on and auto-capture off on first use; then the user's last
/// choice. DK-0361's defaults (filter, page size, name) join them here.
class ScannerPrefs {
  const ScannerPrefs({this.autoCapture = false, this.autoCrop = true});

  final bool autoCapture, autoCrop;

  ScannerPrefs copyWith({bool? autoCapture, bool? autoCrop}) => ScannerPrefs(
    autoCapture: autoCapture ?? this.autoCapture,
    autoCrop: autoCrop ?? this.autoCrop,
  );

  Map<String, Object?> toJson() => {
    'autoCapture': autoCapture,
    'autoCrop': autoCrop,
  };

  static ScannerPrefs fromJson(Map<String, Object?> j) => ScannerPrefs(
    autoCapture: j['autoCapture'] as bool? ?? false,
    autoCrop: j['autoCrop'] as bool? ?? true,
  );
}

/// Where the choices are kept: a small JSON file, or memory in tests.
abstract interface class PrefsStore {
  Future<String?> read();
  Future<void> write(String json);
}

class FilePrefsStore implements PrefsStore {
  FilePrefsStore(this._file);
  final Future<File> _file;

  @override
  Future<String?> read() async {
    final f = await _file;
    return await f.exists() ? f.readAsString() : null;
  }

  @override
  Future<void> write(String json) async {
    final f = await _file;
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(f.path);
  }
}

class MemoryPrefsStore implements PrefsStore {
  String? json;
  @override
  Future<String?> read() async => json;
  @override
  Future<void> write(String value) async => json = value;
}

@Riverpod(keepAlive: true)
PrefsStore scannerPrefsStore(Ref ref) => FilePrefsStore(
  getApplicationSupportDirectory().then(
    (d) => File('${d.path}/scanner_settings.json'),
  ),
);

@Riverpod(keepAlive: true)
class ScannerSettings extends _$ScannerSettings {
  var _loaded = false;

  @override
  ScannerPrefs build() => const ScannerPrefs();

  /// Reads the stored choices once (S1 calls it on open).
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final json = await ref.read(scannerPrefsStoreProvider).read();
    if (json == null) return;
    try {
      state = ScannerPrefs.fromJson(
        (jsonDecode(json) as Map).cast<String, Object?>(),
      );
    } on FormatException {
      // A cut-off file: the defaults.
    }
  }

  Future<void> _set(ScannerPrefs prefs) async {
    state = prefs;
    await ref.read(scannerPrefsStoreProvider).write(jsonEncode(prefs.toJson()));
  }

  Future<void> setAutoCapture(bool on) => _set(state.copyWith(autoCapture: on));

  Future<void> setAutoCrop(bool on) => _set(state.copyWith(autoCrop: on));
}
