import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'scanner_settings.g.dart';

/// The scanner's remembered choices (DK-0338; Settings → Scanning). Auto-crop
/// and auto-capture are separate (the top complaint about other scanners):
/// auto-crop is on and auto-capture off on first use; then the user's last
/// choice. DK-0361's defaults (filter, page size, name) join them here.
/// The filter a new page gets (S2's filter strip; doc_vision's ScanFilter).
enum ScanFilterChoice {
  original,
  autoColour,
  greyscale,
  blackWhite,
  removeShadows,
}

/// The page size a scan is saved at.
enum ScanPageSize { auto, a4, letter }

/// The language text recognition expects (doc_vision's OcrLanguage).
enum ScanOcrLanguage { auto, english, german }

/// The file name a scan gets, with `{date}`, `{time}` and `{number}`.
const defaultNamePattern = 'Scan {date} {time}';

class ScannerPrefs {
  const ScannerPrefs({
    this.autoCapture = false,
    this.autoCrop = true,
    this.filter = ScanFilterChoice.autoColour,
    this.pageSize = ScanPageSize.auto,
    this.folder,
    this.namePattern = defaultNamePattern,
    this.ocrLanguage = ScanOcrLanguage.auto,
  });

  final bool autoCapture, autoCrop;

  /// Settings → Scanning → File name (DK-0361).
  final String namePattern;
  final ScanOcrLanguage ocrLanguage;
  final ScanFilterChoice filter;
  final ScanPageSize pageSize;

  /// The Save sheet's last folder, relative to the user folder (null: its
  /// top).
  final String? folder;

  ScannerPrefs copyWith({
    bool? autoCapture,
    bool? autoCrop,
    ScanFilterChoice? filter,
    ScanPageSize? pageSize,
    String? Function()? folder,
    String? namePattern,
    ScanOcrLanguage? ocrLanguage,
  }) => ScannerPrefs(
    autoCapture: autoCapture ?? this.autoCapture,
    autoCrop: autoCrop ?? this.autoCrop,
    filter: filter ?? this.filter,
    pageSize: pageSize ?? this.pageSize,
    folder: folder == null ? this.folder : folder(),
    namePattern: namePattern ?? this.namePattern,
    ocrLanguage: ocrLanguage ?? this.ocrLanguage,
  );

  Map<String, Object?> toJson() => {
    'autoCapture': autoCapture,
    'autoCrop': autoCrop,
    'filter': filter.name,
    'pageSize': pageSize.name,
    'folder': ?folder,
    'namePattern': namePattern,
    'ocrLanguage': ocrLanguage.name,
  };

  static ScannerPrefs fromJson(Map<String, Object?> j) => ScannerPrefs(
    autoCapture: j['autoCapture'] as bool? ?? false,
    autoCrop: j['autoCrop'] as bool? ?? true,
    filter:
        ScanFilterChoice.values.asNameMap()[j['filter']] ??
        ScanFilterChoice.autoColour,
    pageSize:
        ScanPageSize.values.asNameMap()[j['pageSize']] ?? ScanPageSize.auto,
    folder: j['folder'] as String?,
    namePattern: j['namePattern'] as String? ?? defaultNamePattern,
    ocrLanguage:
        ScanOcrLanguage.values.asNameMap()[j['ocrLanguage']] ??
        ScanOcrLanguage.auto,
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

  Future<void> setFilter(ScanFilterChoice f) => _set(state.copyWith(filter: f));

  Future<void> setPageSize(ScanPageSize s) => _set(state.copyWith(pageSize: s));

  Future<void> setFolder(String? f) => _set(state.copyWith(folder: () => f));

  Future<void> setNamePattern(String p) => _set(
    state.copyWith(namePattern: p.trim().isEmpty ? defaultNamePattern : p),
  );

  Future<void> setOcrLanguage(ScanOcrLanguage l) =>
      _set(state.copyWith(ocrLanguage: l));
}
