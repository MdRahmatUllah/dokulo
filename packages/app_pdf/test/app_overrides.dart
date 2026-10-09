import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// What a test needs to show the real Home or Files (DK-0242, DK-0260): an
/// empty file index and no prefs file. Call it inside the test: the index
/// closes with the test.
List<Override> homeOverrides() {
  final db = DokuloDatabase.memory();
  addTearDown(db.close);
  return [
    appDatabaseProvider.overrideWithValue(db),
    prefsProvider.overrideWith(Prefs.memory),
  ];
}
