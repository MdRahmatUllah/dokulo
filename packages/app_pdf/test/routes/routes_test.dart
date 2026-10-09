import 'package:app_pdf/components/dk_scan_button.dart';
import 'package:app_pdf/providers/camera_permission.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_screen.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/components/dk_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The camera is allowed: these tests are about routes, not the permission.
class _Granted implements CameraPermission {
  @override
  Future<CameraAccess> status() async => CameraAccess.granted;
  @override
  Future<CameraAccess> request() async => CameraAccess.granted;
  @override
  Future<void> openSettings() async {}
}

Future<GoRouter> pumpAt(WidgetTester tester, String location) async {
  final router = buildRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    // As in the app; S1's camera gate reads its permission from a provider.
    ProviderScope(
      overrides: [cameraPermissionProvider.overrideWithValue(_Granted())],
      child: MaterialApp.router(
        routerConfig: router,
        theme: dokuloTheme(DkTokens.light), // components read the tokens
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String title(WidgetTester tester) =>
    (tester.widget<AppBar>(find.byType(AppBar).last).title! as Text).data!;

bool tabBarShown(WidgetTester tester) =>
    find.byType(DkTabBar).evaluate().isNotEmpty;

void main() {
  // Every route from a cold start (what a deep link does): the screen, and
  // whether the tab bar shows.
  const coldStarts = {
    Routes.home: ('H1', true),
    Routes.tools: ('T1', true),
    Routes.files: ('F1', true),
    Routes.lockedFolder: ('F2', true),
    Routes.me: ('M1', true),
    Routes.models: ('M2', true),
    '/me/settings/appearance': ('M3 appearance', true),
    Routes.welcome: ('Onboarding', false),
    Routes.scan: ('S1', false),
    Routes.scanReview: ('S2', false),
    '/tool/compress': ('T2 compress', false),
    '/tool/compress/result': ('T3 compress', false),
    '/viewer/f42?mode=edit': ('V2 f42', false),
    '/organize/f42': ('P1 f42', false),
  };
  for (final MapEntry(key: location, value: (screen, tabs))
      in coldStarts.entries) {
    testWidgets('cold start at $location shows $screen', (tester) async {
      await pumpAt(tester, location);
      expect(title(tester), screen);
      expect(tabBarShown(tester), tabs);
    });
  }

  testWidgets('cold start at /viewer/42 shows the V1 viewer, no tab bar', (
    tester,
  ) async {
    // V1 reads the file index: the app's ProviderScope, an empty database.
    final db = DokuloDatabase.memory();
    addTearDown(db.close);
    final router = buildRouter(initialLocation: Routes.viewer('42'));
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          routerConfig: router,
          theme: dokuloTheme(DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump(
      const Duration(milliseconds: 500),
    ); // a spinner never settles
    expect(tester.widget<ViewerScreen>(find.byType(ViewerScreen)).fileId, 42);
    expect(tabBarShown(tester), false);
  });

  test('the path builders match the route table', () {
    expect(Routes.settings('appearance'), '/me/settings/appearance');
    expect(Routes.tool('merge'), '/tool/merge');
    expect(Routes.toolResult('merge'), '/tool/merge/result');
    expect(Routes.viewer('f1'), '/viewer/f1');
    expect(Routes.viewer('f1', edit: true), '/viewer/f1?mode=edit');
    expect(Routes.organize('f1'), '/organize/f1');
  });

  testWidgets('each tab keeps its scroll position and pushed pages', (
    tester,
  ) async {
    final router = await pumpAt(tester, Routes.home);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    final scrolled = tester
        .state<ScrollableState>(find.byType(Scrollable).last)
        .position
        .pixels;
    expect(scrolled, greaterThan(0));

    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    router.push(Routes.lockedFolder);
    await tester.pumpAndSettle();
    expect(title(tester), 'F2');

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(title(tester), 'H1');
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position
          .pixels,
      scrolled,
    );

    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    expect(title(tester), 'F2');
  });

  testWidgets('back from a pushed tool page returns to the tab it came from', (
    tester,
  ) async {
    final router = await pumpAt(tester, Routes.tools);
    router.push(Routes.tool('compress'));
    await tester.pumpAndSettle();
    expect(title(tester), 'T2 compress');
    expect(tabBarShown(tester), isFalse);

    router.pop();
    await tester.pumpAndSettle();
    expect(title(tester), 'T1');
    expect(tester.widget<DkTabBar>(find.byType(DkTabBar)).currentIndex, 1);
  });

  testWidgets('back from a deep-linked full-screen page goes Home', (
    tester,
  ) async {
    await pumpAt(tester, Routes.tool('compress')); // a cold-start deep link
    expect(title(tester), 'T2 compress');
    await tester.binding.handlePopRoute(); // the system back button
    await tester.pumpAndSettle();
    expect(title(tester), 'H1');
    expect(tabBarShown(tester), isTrue);
  });

  testWidgets('the Scan button opens the scanner above the tabs', (
    tester,
  ) async {
    await pumpAt(tester, Routes.files);
    await tester.tap(find.bySemanticsLabel('Scan'));
    await tester.pumpAndSettle();
    expect(title(tester), 'S1');
    expect(tabBarShown(tester), isFalse);
  });

  testWidgets('a long press on Scan picks a mode for the scanner', (
    tester,
  ) async {
    await pumpAt(tester, Routes.home);
    await tester.longPress(find.bySemanticsLabel('Scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ID card'));
    await tester.pumpAndSettle();
    expect(title(tester), 'S1 idCard');
    expect(Routes.scanIn(DkScanMode.book), '/scan?mode=book');
  });
}
