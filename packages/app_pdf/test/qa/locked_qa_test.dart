import 'dart:io';

import 'package:app_pdf/components/dk_pin_pad.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/patterns/dk_app_lock.dart';
import 'package:app_pdf/patterns/dk_privacy_cover.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/file_providers.dart';
import 'package:app_pdf/providers/files_providers.dart';
import 'package:app_pdf/providers/locked_providers.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/providers/privacy_providers.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/locked_folder_screen_test.dart'
    show LockedSetup, pumpLocked, typePin;

// Visual QA (DK-0755 to DK-0762): the 05-locked-folder frames l1, l2, l3,
// l4, unlock, content, applock and cover, rendered by the real F2, the app
// lock and the privacy cover at 393 × 852. The frames' screenshots are
// in docs/qa/locked/; the findings are in docs/qa/locked.md.
void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    Future<void> shot(WidgetTester tester, String frame) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/qa_locked_${frame}_$theme.png'),
    );

    testWidgets('locked-folder-l1, $theme', (tester) async {
      await pumpLocked(tester, LockedSetup(), tokens: tokens);
      await shot(tester, 'l1');
    });

    testWidgets('locked-folder-l2 (two digits), $theme', (tester) async {
      await pumpLocked(tester, LockedSetup(), tokens: tokens);
      await tester.tap(find.text('Set up'));
      await tester.pumpAndSettle();
      await typePin(tester, '48');
      await shot(tester, 'l2');
    });

    testWidgets('locked-folder-l3 (mismatch), $theme', (tester) async {
      await pumpLocked(tester, LockedSetup(), tokens: tokens);
      await tester.tap(find.text('Set up'));
      await tester.pumpAndSettle();
      await typePin(tester, '482915');
      await typePin(tester, '111111');
      await shot(tester, 'l3');
    });

    testWidgets('locked-folder-l4, $theme', (tester) async {
      await pumpLocked(tester, LockedSetup(), tokens: tokens);
      await tester.tap(find.text('Set up'));
      await tester.pumpAndSettle();
      await typePin(tester, '482915');
      await typePin(tester, '482915');
      await shot(tester, 'l4');
    });

    testWidgets('locked-folder-unlock, $theme', (tester) async {
      final setup = LockedSetup();
      await setup.vault.setPin('482915');
      await pumpLocked(tester, setup, tokens: tokens);
      await shot(tester, 'unlock');
    });

    testWidgets('locked-folder-content (Moved 3 files), $theme', (
      tester,
    ) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('dk_qa_f2_'),
      ))!;
      final db = DokuloDatabase.memory();
      addTearDown(() async {
        await db.close();
        await root.delete(recursive: true);
      });
      final files = FileStore(
        userFolder: Directory('${root.path}/Dokulo'),
        workDirectory: Directory('${root.path}/work'),
      );
      final now = DateTime.now();
      final ids = (await tester.runAsync(() async {
        return [
          for (final (name, size, pages, at) in [
            (
              'Personalausweis – scan.pdf',
              1100000,
              2,
              now.subtract(const Duration(days: 1)),
            ),
            ('Arbeitsvertrag 2026.pdf', 860000, 6, DateTime(now.year, 10, 1)),
            ('Kontoauszug September.pdf', 310000, 3, DateTime(now.year, 9, 30)),
          ])
            await () async {
              final path = '${root.path}/Dokulo/$name';
              File(path)
                ..createSync(recursive: true)
                ..writeAsStringSync('%PDF-1.7\n');
              return db
                  .into(db.files)
                  .insert(
                    FilesCompanion.insert(
                      path: path,
                      name: name,
                      size: size,
                      pages: Value(pages),
                      created: at,
                      modified: at,
                    ),
                  );
            }(),
        ];
      }))!;
      final setup = LockedSetup();
      await setup.vault.setPin('482915');
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = buildRouter(initialLocation: Routes.files);
      addTearDown(router.dispose);
      final container = ProviderContainer(
        overrides: [
          lockedVaultProvider.overrideWithValue(setup.vault),
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
            debugShowCheckedModeBanner: false,
            routerConfig: router,
            theme: dokuloTheme(tokens),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      Future<void> real() async {
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pumpAndSettle();
        }
      }

      await real();
      router.push(Routes.lockedFolder, extra: ids);
      await real();
      // The PIN, its last digit on the real clock: the move reads and
      // writes real files.
      await typePin(tester, '48291');
      await tester.runAsync(() async {
        await tester.tap(
          find.descendant(of: find.byType(DkPinPad), matching: find.text('5')),
        );
        await Future<void>.delayed(const Duration(seconds: 3));
      });
      await real();
      expect(find.text('Moved 3 files to Locked folder'), findsOneWidget);
      await shot(tester, 'content');
    });

    testWidgets('locked-folder-applock, $theme', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final setup = LockedSetup();
      await setup.vault.setPin('482915');
      final container = ProviderContainer(
        overrides: [
          lockedVaultProvider.overrideWithValue(setup.vault),
          biometricKindProvider.overrideWith(
            (ref) async => BiometricKind.faceId,
          ),
          prefsProvider.overrideWith(
            () => Prefs.memory({
              'security.appLock': true,
              'security.lockAfter': 0,
            }),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dokuloTheme(tokens),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => DkAppLock(child: child!),
            home: const Scaffold(body: Text('Kontoauszug September.pdf')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final b = tester.binding;
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        b.handleAppLifecycleStateChanged(s);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('Dokulo is locked'), findsOneWidget);
      await shot(tester, 'applock');
    });

    testWidgets('locked-folder-cover, $theme', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PrivacyChannel.channel, (_) async => null);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(PrivacyChannel.channel, null),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dokuloTheme(tokens),
            builder: (context, child) => DkPrivacyCover(child: child!),
            home: const Scaffold(body: Text('Kontoauszug September.pdf')),
          ),
        ),
      );
      container.read(hidePreviewsProvider.notifier).set(true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await shot(tester, 'cover');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    });
  }
}
