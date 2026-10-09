import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'database.steps.dart';

part 'database.g.dart';

/// Dokulo's database (DK-0005); the schema is `schema.drift`.
@DriftDatabase(include: {'schema.drift'})
class DokuloDatabase extends _$DokuloDatabase {
  DokuloDatabase(super.e);

  /// Opens `dokulo.db` in the app's support directory (never the
  /// user-visible folder), on a background isolate, so no query runs on the
  /// UI isolate. The app passes path_provider's `getApplicationSupportDirectory`.
  DokuloDatabase.open(Future<Directory> Function() supportDirectory)
    : this(
        LazyDatabase(
          () async =>
              NativeDatabase.createInBackground(file(await supportDirectory())),
        ),
      );

  /// In memory, for tests. Streams close as soon as their last listener
  /// goes: widget tests then end with no drift timer pending.
  DokuloDatabase.memory()
    : this(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );

  /// Where the database lives inside the app's support directory.
  static File file(Directory supportDirectory) =>
      File('${supportDirectory.path}${Platform.pathSeparator}dokulo.db');

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: stepByStep(
      from1To2: (m, schema) async => m.createTable(schema.jobs), // DK-0008
      from2To3: (m, schema) async =>
          m.addColumn(schema.files, schema.files.indexedAt), // DK-0270
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
