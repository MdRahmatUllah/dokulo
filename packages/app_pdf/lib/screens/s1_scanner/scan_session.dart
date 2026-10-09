import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../components/dk_scan_button.dart';
import 'scanner_camera.dart';
import 'scanner_settings.dart';

part 'scan_session.g.dart';

/// A document's corners in a frame, clockwise from top-left, each 0–1 of the
/// frame's width and height (so the screen can draw it at any size).
typedef DetectedQuad = List<Offset>;

/// Finds the document in a preview frame. DK-0337 (OpenCV, both platforms)
/// and DK-0336 (Vision on iOS) provide the real one; until then nothing is
/// found and the user captures by hand.
typedef QuadDetector = Future<DetectedQuad?> Function(GreyFrame frame);

@riverpod
QuadDetector quadDetector(Ref ref) =>
    (_) async => null;

/// One captured page, as S2 reviews it: the photo on disk (so an unsaved
/// scan survives the app being killed), the corners found at capture, the
/// user's own crop (S2's crop mode) and the quarter turns the user rotated
/// it by, and its filter (S2's filter mode).
class ScannedPage {
  const ScannedPage(
    this.id,
    this.path, {
    this.quad,
    this.crop,
    this.turns = 0,
    this.filter,
    this.brightness = 0,
    this.contrast = 0,
  });

  final String id;
  final String path;

  /// Found at capture; null when nothing was.
  final DetectedQuad? quad;

  /// The user's crop, in the same fractions; null: [quad], or the full
  /// photo.
  final DetectedQuad? crop;
  final int turns;

  /// The page's own filter; null: the scanner's default.
  final ScanFilterChoice? filter;

  /// The "Adjust" sliders, -0.5 to 0.5 (0: as the filter leaves it).
  final double brightness, contrast;

  /// The corners the page is cut at.
  DetectedQuad get corners => crop ?? quad ?? fullPage;

  static const DetectedQuad fullPage = [
    Offset.zero,
    Offset(1, 0),
    Offset(1, 1),
    Offset(0, 1),
  ];

  ScannedPage copyWith({
    DetectedQuad? crop,
    int? turns,
    ScanFilterChoice? filter,
    double? brightness,
    double? contrast,
  }) => ScannedPage(
    id,
    path,
    quad: quad,
    crop: crop ?? this.crop,
    turns: turns ?? this.turns,
    filter: filter ?? this.filter,
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
  );

  ScannedPage rotated() => copyWith(turns: (turns + 1) % 4);

  static List<num>? _flat(DetectedQuad? q) => q == null
      ? null
      : [
          for (final o in q) ...[o.dx, o.dy],
        ];

  static DetectedQuad? _quad(Object? json) {
    final q = (json as List?)?.cast<num>();
    return q == null
        ? null
        : [
            for (var i = 0; i + 1 < q.length; i += 2)
              Offset(q[i].toDouble(), q[i + 1].toDouble()),
          ];
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'path': path,
    'turns': turns,
    'quad': ?_flat(quad),
    'crop': ?_flat(crop),
    'filter': ?filter?.name,
    'brightness': brightness,
    'contrast': contrast,
  };

  static ScannedPage fromJson(Map<String, Object?> j) => ScannedPage(
    j['id']! as String,
    j['path']! as String,
    turns: (j['turns'] as int?) ?? 0,
    quad: _quad(j['quad']),
    crop: _quad(j['crop']),
    filter: ScanFilterChoice.values.asNameMap()[j['filter']],
    brightness: (j['brightness'] as num?)?.toDouble() ?? 0,
    contrast: (j['contrast'] as num?)?.toDouble() ?? 0,
  );
}

/// Where the scan in progress is kept: photos and a manifest.
abstract interface class ScanStore {
  /// Stores a photo; returns the path it is read back by.
  Future<String> write(String id, Uint8List jpeg);
  Future<void> delete(String path);
  Future<String?> readManifest();
  Future<void> writeManifest(String json);
  Future<void> clear();
  bool exists(String path);

  /// A photo's size in bytes (the Save sheet's estimates).
  int length(String path);

  /// How a screen shows the photo at [path].
  ImageProvider image(String path);
}

/// The app's store: `<app support>/scan_session/`, the manifest written
/// atomically (a temp file renamed over it).
class FileScanStore implements ScanStore {
  FileScanStore(this._dir);
  final Future<Directory> _dir;

  Future<Directory> get _ready async => (await _dir).create(recursive: true);

  @override
  Future<String> write(String id, Uint8List jpeg) async {
    final file = File('${(await _ready).path}/$id.jpg');
    await file.writeAsBytes(jpeg, flush: true);
    return file.path;
  }

  @override
  Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<String?> readManifest() async {
    final f = File('${(await _ready).path}/session.json');
    return await f.exists() ? f.readAsString() : null;
  }

  @override
  Future<void> writeManifest(String json) async {
    final dir = await _ready;
    final tmp = File('${dir.path}/session.json.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename('${dir.path}/session.json');
  }

  @override
  Future<void> clear() async {
    final dir = await _dir;
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  @override
  bool exists(String path) => File(path).existsSync();

  @override
  int length(String path) => File(path).lengthSync();

  @override
  ImageProvider image(String path) => FileImage(File(path));
}

/// A store in memory (widget tests: no real file I/O).
class MemoryScanStore implements ScanStore {
  final files = <String, Uint8List>{};
  String? manifest;

  @override
  Future<String> write(String id, Uint8List jpeg) async {
    files['mem/$id.jpg'] = jpeg;
    return 'mem/$id.jpg';
  }

  @override
  Future<void> delete(String path) async => files.remove(path);
  @override
  Future<String?> readManifest() async => manifest;
  @override
  Future<void> writeManifest(String json) async => manifest = json;
  @override
  Future<void> clear() async {
    files.clear();
    manifest = null;
  }

  @override
  bool exists(String path) => files.containsKey(path);

  @override
  int length(String path) => files[path]!.length;
  @override
  ImageProvider image(String path) => MemoryImage(files[path]!);
}

@Riverpod(keepAlive: true)
ScanStore scanStore(Ref ref) => FileScanStore(
  getApplicationSupportDirectory().then(
    (d) => Directory('${d.path}/scan_session'),
  ),
);

/// The pages of the scan in progress, shared by S1 and S2 (DK-0343,
/// DK-0352). Every change is written to the store's manifest beside the
/// photos, so [restore] brings an unsaved scan back after the app was
/// killed (and Home's continue card can offer it).
@Riverpod(keepAlive: true)
class ScanSession extends _$ScanSession {
  var _next = 0;

  @override
  List<ScannedPage> build() => const [];

  ScanStore get _store => ref.read(scanStoreProvider);

  /// Loads the scan left in the store, if this session is empty.
  Future<void> restore() async {
    if (state.isNotEmpty) return;
    final json = await _store.readManifest();
    if (json == null) return;
    try {
      final list = (jsonDecode(json) as List).cast<Map<String, Object?>>();
      final pages = [
        for (final j in list)
          if (_store.exists(j['path']! as String)) ScannedPage.fromJson(j),
      ];
      _next = pages.length;
      state = pages;
    } on FormatException {
      // A manifest cut off mid-write: start over rather than fail.
    }
  }

  Future<void> _save() =>
      _store.writeManifest(jsonEncode([for (final p in state) p.toJson()]));

  Future<String> _write(Uint8List jpeg) =>
      _store.write('${DateTime.now().microsecondsSinceEpoch}-${_next++}', jpeg);

  /// Adds a captured page at the end.
  Future<void> add(Uint8List jpeg, {DetectedQuad? quad}) async {
    final path = await _write(jpeg);
    state = [
      ...state,
      ScannedPage(path.split(RegExp(r'[\/]')).last, path, quad: quad),
    ];
    await _save();
  }

  /// Retake: the page at [index] becomes the new photo.
  Future<void> replace(int index, Uint8List jpeg, {DetectedQuad? quad}) async {
    final old = state[index];
    final path = await _write(jpeg);
    state = [...state]..[index] = ScannedPage(old.id, path, quad: quad);
    await _save();
    await _store.delete(old.path);
  }

  Future<void> rotate(int index) async {
    state = [...state]..[index] = state[index].rotated();
    await _save();
  }

  /// Crop mode's Apply.
  Future<void> setCrop(int index, DetectedQuad crop) async {
    state = [...state]..[index] = state[index].copyWith(crop: crop);
    await _save();
  }

  /// A page's own changes (the filter mode's).
  Future<void> update(int index, ScannedPage page) async {
    state = [...state]..[index] = page;
    await _save();
  }

  /// "Apply to all pages": every page gets what is given. Returns the pages
  /// as they were, for Undo ([restoreAll]).
  Future<List<ScannedPage>> applyToAll({
    DetectedQuad? crop,
    int? turns,
    ScanFilterChoice? filter,
    double? brightness,
    double? contrast,
  }) async {
    final before = state;
    state = [
      for (final p in state)
        p.copyWith(
          crop: crop,
          turns: turns,
          filter: filter,
          brightness: brightness,
          contrast: contrast,
        ),
    ];
    await _save();
    return before;
  }

  /// Undo of [applyToAll].
  Future<void> restoreAll(List<ScannedPage> pages) async {
    state = pages;
    await _save();
  }

  Future<void> move(int from, int to) async {
    final pages = [...state];
    pages.insert(to, pages.removeAt(from));
    state = pages;
    await _save();
  }

  /// Removes the page at [index]; returns it, so an Undo can [insert] it.
  Future<ScannedPage> remove(int index) async {
    final page = state[index];
    state = [...state]..removeAt(index);
    await _save();
    return page;
  }

  Future<void> insert(int index, ScannedPage page) async {
    state = [...state]..insert(index, page);
    await _save();
  }

  /// Discards the scan: the pages, their photos and the manifest.
  Future<void> clear() async {
    state = const [];
    await _store.clear();
  }
}

/// Picks photos to add to a scan (DK-0351): the system photo picker, which
/// needs no library permission (PHPicker on iOS 14+, the photo picker on
/// Android 13+). JPG, PNG, HEIC and WebP. Empty when the user cancels.
typedef ScanImportPicker = Future<List<Uint8List>> Function();

@riverpod
ScanImportPicker scanImportPicker(Ref ref) =>
    () async => [
      for (final f in await FilePicker.pickFiles(type: FileType.image))
        await f.readAsBytes(),
    ];

/// The scanner's mode (the mode switcher; the Scan button's long press).
@riverpod
class ScanModeState extends _$ScanModeState {
  @override
  DkScanMode build() => DkScanMode.document;

  void set(DkScanMode mode) => state = mode;
}
