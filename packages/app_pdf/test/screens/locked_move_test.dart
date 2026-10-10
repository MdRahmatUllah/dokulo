import 'dart:convert';
import 'dart:io';

import 'package:app_pdf/components/dk_pin_pad.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/file_providers.dart';
import 'package:app_pdf/providers/files_providers.dart';
import 'package:app_pdf/providers/locked_providers.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'locked_folder_screen_test.dart' show LockedSetup, typePin;

/// Flow 6 (DK-0289): a file from Files into the locked folder, the setup
/// first, with the vault and the files on a real disk.
void main() {
  late Directory root;
  late DokuloDatabase db;
  late FileStore files;
  const pdf = '%PDF-1.7 Kontoauszug IBAN DE89';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dk_f2_');
    db = DokuloDatabase.memory();
    files = FileStore(
      userFolder: Directory('${root.path}/Dokulo'),
      workDirectory: Directory('${root.path}/work'),
    );
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<void> real(WidgetTester tester, [int ms = 50]) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(Duration(milliseconds: ms)),
      );
      await tester.pumpAndSettle();
    }
  }

  /// The PIN again, its last digit on the real clock: the move that
  /// follows reads and writes real files.
  Future<void> confirmPinReal(WidgetTester tester, String pin) async {
    await typePin(tester, pin.substring(0, pin.length - 1));
    await tester.runAsync(() async {
      await tester.tap(
        find.descendant(
          of: find.byType(DkPinPad),
          matching: find.text(pin[pin.length - 1]),
        ),
      );
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await real(tester);
  }

  Future<(GoRouter, ProviderContainer)> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = buildRouter(initialLocation: Routes.files);
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [
        lockedVaultProvider.overrideWithValue(LockedSetup().vault),
        biometricKindProvider.overrideWith((ref) async => null),
        appDatabaseProvider.overrideWithValue(db),
        prefsProvider.overrideWith(Prefs.memory),
        fileStoreProvider.overrideWith((ref) async => files),
        thumbnailCacheProvider.overrideWith(
          (ref) async => ThumbnailCache(Directory('${root.path}/thumbs')),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: dokuloTheme(DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await real(tester);
    return (router, container);
  }

  testWidgets('move in: set up, sealed, listed; Undo puts it back', (
    tester,
  ) async {
    final path = '${root.path}/Dokulo/Kontoauszug.pdf';
    late int id;
    await tester.runAsync(() async {
      File(path)
        ..createSync(recursive: true)
        ..writeAsStringSync(pdf);
      id = await db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              path: path,
              name: 'Kontoauszug.pdf',
              size: pdf.length,
              pages: const Value(3),
              created: DateTime(2026, 10, 1),
              modified: DateTime(2026, 10, 1),
            ),
          );
    });
    final (router, _) = await pump(tester);
    router.push(Routes.lockedFolder, extra: [id]);
    await real(tester);
    // Not set up yet: the setup runs first (flow 6).
    await tester.tap(find.text('Set up'));
    await tester.pumpAndSettle();
    await typePin(tester, '482915');
    await confirmPinReal(tester, '482915');

    expect(find.text('Moved 1 file to Locked folder'), findsOneWidget);
    expect(find.text('Kontoauszug.pdf'), findsOneWidget);
    expect(find.text('1 file'), findsOneWidget);
    expect(File(path).existsSync(), isFalse, reason: 'the plain copy goes');
    final rows = await tester.runAsync(() => db.select(db.files).get());
    expect(rows, isEmpty);
    final vault = Directory('${root.path}/work/locked');
    final raw = [
      for (final f in vault.listSync(recursive: true))
        if (f is File) latin1.decode(f.readAsBytesSync()),
    ].join();
    expect(raw, isNot(contains('IBAN')));
    expect(raw, isNot(contains('Kontoauszug')));

    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await real(tester);
    expect(File(path).readAsStringSync(), pdf);
    expect(find.text('Kontoauszug.pdf'), findsNothing);
  });

  testWidgets('locking deletes the decrypted copies', (tester) async {
    final path = '${root.path}/Dokulo/a.pdf';
    late int id;
    await tester.runAsync(() async {
      File(path)
        ..createSync(recursive: true)
        ..writeAsStringSync(pdf);
      id = await db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              path: path,
              name: 'a.pdf',
              size: pdf.length,
              created: DateTime(2026, 10, 1),
              modified: DateTime(2026, 10, 1),
            ),
          );
    });
    final (router, container) = await pump(tester);
    router.push(Routes.lockedFolder, extra: [id]);
    await real(tester);
    await tester.tap(find.text('Set up'));
    await tester.pumpAndSettle();
    await typePin(tester, '482915');
    await confirmPinReal(tester, '482915');
    final store = await tester.runAsync(
      () => container.read(lockedStoreProvider.future),
    );
    final cipher = container.read(lockedSessionProvider)!;
    final open = await tester.runAsync(() async {
      final entry = (await store!.list(cipher)).single;
      return store.open(entry.id, cipher);
    });
    expect(open!.existsSync(), isTrue);
    await tester.tap(find.byTooltip('Lock now'));
    await real(tester);
    expect(open.existsSync(), isFalse);
    expect(store!.openDirectory.existsSync(), isFalse);
  });
}
