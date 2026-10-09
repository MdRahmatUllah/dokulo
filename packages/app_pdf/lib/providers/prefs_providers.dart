import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'prefs_providers.g.dart';

/// Small per-user choices that outlive a restart (F1's list or grid and its
/// sort, DK-0260/DK-0261): a JSON file in app support. If it can't be read,
/// the defaults apply; a failed write keeps the choice for this session.
/// Tests override it with [Prefs.memory].
@Riverpod(keepAlive: true)
class Prefs extends _$Prefs {
  @override
  Future<Map<String, Object?>> build() async {
    try {
      final file = await _file();
      if (!await file.exists()) return {};
      return (jsonDecode(await file.readAsString()) as Map).cast();
    } on Exception {
      return {};
    }
  }

  Future<File> _file() async => File(
    '${(await getApplicationSupportDirectory()).path}'
    '${Platform.pathSeparator}prefs.json',
  );

  Future<void> set(String key, Object? value) async {
    final next = {...state.value ?? const {}, key: value};
    state = AsyncData(next);
    try {
      await (await _file()).writeAsString(jsonEncode(next), flush: true);
    } on Exception {
      // ponytail: kept for this session; the next set writes it again
    }
  }

  /// For tests: no file system.
  static Prefs memory([Map<String, Object?> values = const {}]) =>
      _MemoryPrefs(values);
}

class _MemoryPrefs extends Prefs {
  _MemoryPrefs(this._values);
  final Map<String, Object?> _values;

  @override
  Future<Map<String, Object?>> build() async => {..._values};

  @override
  Future<void> set(String key, Object? value) async =>
      state = AsyncData({...state.value ?? const {}, key: value});
}
