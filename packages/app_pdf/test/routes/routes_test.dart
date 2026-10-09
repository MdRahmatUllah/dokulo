import 'package:flutter/foundation.dart';
import 'package:app_pdf/components/dk_camera_top_bar.dart';
import 'package:app_pdf/components/dk_scan_button.dart';
import 'package:app_pdf/providers/camera_permission.dart';
import 'package:app_pdf/screens/s1_scanner/s1_screen.dart';
import 'package:app_pdf/screens/s1_scanner/scan_session.dart';
import 'package:app_pdf/screens/s1_scanner/scanner_camera.dart';
import 'package:app_pdf/screens/s1_scanner/scanner_settings.dart';
import 'package:app_pdf/screens/s2_review/s2_screen.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/screens/files/files_screen.dart';
import 'package:app_pdf/screens/home/home_screen.dart';
import 'package:app_pdf/screens/onboarding/onboarding_screen.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_screen.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/components/dk_tab_bar.dart';
import 'package:app_pdf/components/dk_top_bar.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A camera that opens and shows nothing: these tests are about routes.
class _FakeCamera implements ScannerCamera {
  @override
  Future<void> open() async {}
  @override
  Widget preview() => const SizedBox.expand();
  @override
  double? get aspectRatio => 3 / 4;
  @override
  Stream<GreyFrame> get frames => const Stream.empty();
  @override
  Future<void> setFlash(DkFlash flash) async {}
  @override
  Future<Uint8List> capture() async => Uint8List(0);
  @override
  Future<void> close() async {}
}

/// The camera is allowed: these tests are about routes, not the permission.
class _Granted implements CameraPermission {
  @override
  Future<CameraAccess> status() async => CameraAccess.granted;
  @override
  Future<CameraAccess> request() async => CameraAccess.granted;
  @override
  Future<void> openSettings() async {}
}

Future<GoRouter> pumpAt(
  WidgetTester tester,
  String location, {
  bool reduceMotion = false,
  List<Override> overrides = const [],
  DokuloDatabase? database,
}) async {
  final router = buildRouter(initialLocation: location);
  addTearDown(router.dispose);
  // Home and F1 read the file index and their view: an empty database
  // unless the test gives one, no prefs file.
  final db = database ?? DokuloDatabase.memory();
  if (database == null) addTearDown(db.close);
  await tester.pumpWidget(
    // As in the app; S1's camera gate reads its permission from a provider.
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        prefsProvider.overrideWith(Prefs.memory),
        cameraPermissionProvider.overrideWithValue(_Granted()),
        scannerCameraProvider.overrideWith((ref) => _FakeCamera()),
        scanStoreProvider.overrideWithValue(MemoryScanStore()),
        scannerPrefsStoreProvider.overrideWithValue(MemoryPrefsStore()),
        ...overrides,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: dokuloTheme(DkTokens.light), // components read the tokens
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// The title of the screen on top: a placeholder's AppBar, or a real
/// screen's DkTopBar (T2).
String title(WidgetTester tester) {
  final bar = find.byType(DkTopBar);
  if (bar.evaluate().isNotEmpty) {
    return tester.widget<DkTopBar>(bar.last).title!;
  }
  return (tester.widget<AppBar>(find.byType(AppBar).last).title! as Text).data!;
}

bool tabBarShown(WidgetTester tester) =>
    find.byType(DkTabBar).evaluate().isNotEmpty;

void main() {
  // Every route from a cold start (what a deep link does): the screen, and
  // whether the tab bar shows.
  const coldStarts = {
    Routes.tools: ('T1', true),
    Routes.me: ('M1', true),
    Routes.models: ('M2', true),
    '/me/settings/appearance': ('M3 appearance', true),
    '/tool/compress': ('Compress PDF', false),
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

  testWidgets('cold start at /home shows H1 with the tab bar', (tester) async {
    await pumpAt(tester, Routes.home);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tabBarShown(tester), isTrue);
  });

  testWidgets('cold start at /files shows F1 with the tab bar', (tester) async {
    await pumpAt(tester, Routes.files);
    expect(find.byType(FilesScreen), findsOneWidget);
    expect(tabBarShown(tester), isTrue);
  });

  testWidgets('cold start at /welcome shows onboarding, no tab bar', (
    tester,
  ) async {
    final router = buildRouter(initialLocation: Routes.welcome);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          theme: dokuloTheme(DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(tabBarShown(tester), isFalse);
  });

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
    final router = await pumpAt(tester, Routes.tools);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    final scrolled = tester
        .state<ScrollableState>(find.byType(Scrollable).last)
        .position
        .pixels;
    expect(scrolled, greaterThan(0));

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    router.push(Routes.models);
    await tester.pumpAndSettle();
    expect(title(tester), 'M2');

    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    expect(title(tester), 'T1');
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position
          .pixels,
      scrolled,
    );

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    expect(title(tester), 'M2');
  });

  testWidgets('back from a pushed tool page returns to the tab it came from', (
    tester,
  ) async {
    final router = await pumpAt(tester, Routes.tools);
    router.push(Routes.tool('compress'));
    await tester.pumpAndSettle();
    expect(title(tester), 'Compress PDF');
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
    expect(title(tester), 'Compress PDF');
    await tester.binding.handlePopRoute(); // the system back button
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tabBarShown(tester), isTrue);
  });

  testWidgets('cold start at /scan/review shows S2, no tab bar', (
    tester,
  ) async {
    await pumpAt(tester, Routes.scanReview);
    expect(find.byType(S2Screen), findsOneWidget);
    expect(tabBarShown(tester), isFalse);
  });

  testWidgets('cold start at /scan shows S1, no tab bar', (tester) async {
    await pumpAt(tester, Routes.scan);
    expect(find.byType(S1Screen), findsOneWidget);
    expect(tabBarShown(tester), isFalse);
  });

  testWidgets('the Scan button opens the scanner above the tabs', (
    tester,
  ) async {
    await pumpAt(tester, Routes.files);
    await tester.tap(find.bySemanticsLabel('Scan'));
    await tester.pumpAndSettle();
    expect(find.byType(S1Screen), findsOneWidget);
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
    expect(
      ProviderScope.containerOf(tester.element(find.byType(S1Screen)))
          .read(scanModeStateProvider),
      DkScanMode.idCard,
    );
    expect(Routes.scanIn(DkScanMode.book), '/scan?mode=book');
  });

  testWidgets('Import photos in the Scan popover goes to S2 and its picker '
      '(DK-0230)', (tester) async {
    await pumpAt(tester, Routes.home);
    await tester.longPress(find.bySemanticsLabel('Scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import photos'));
    await tester.pumpAndSettle();
    expect(title(tester), 'S2 photos');
    expect(tabBarShown(tester), isFalse);
  });

  testWidgets('from 840 dp the rail replaces the tab bar, live on resize, '
      'and the tabs keep their stacks (DK-0232)', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    final router = await pumpAt(tester, Routes.me);
    router.push(Routes.models);
    await tester.pumpAndSettle();
    expect(tabBarShown(tester), isTrue);

    tester.view.physicalSize = const Size(1280, 800); // rotated tablet
    await tester.pumpAndSettle();
    expect(find.byType(DkNavRail), findsOneWidget);
    expect(tabBarShown(tester), isFalse);
    expect(title(tester), 'M2', reason: 'the Me stack survives');

    tester.view.physicalSize = const Size(700, 1000); // medium: tab bar
    await tester.pumpAndSettle();
    expect(find.byType(DkNavRail), findsNothing);
    expect(tabBarShown(tester), isTrue);
    expect(title(tester), 'M2');
  });

  group('transitions (UI spec §13.4; DK-0229, DK-0237)', () {
    testWidgets('tabs cross-fade in 120 ms, then the old tab goes offstage', (
      tester,
    ) async {
      await pumpAt(tester, Routes.home);
      await tester.tap(find.text('Files'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        find.byType(HomeScreen),
        findsOneWidget,
        reason: 'still fading out',
      );
      expect(find.byType(FilesScreen), findsOneWidget, reason: 'fading in');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(
        find.byType(HomeScreen),
        findsNothing,
        reason: 'offstage after 120 ms',
      );
      expect(find.byType(FilesScreen), findsOneWidget);
    });

    testWidgets('the scanner slides up in 220 ms; with Reduce Motion it '
        'fades in place', (tester) async {
      Future<double> midway({required bool reduce}) async {
        await pumpAt(tester, Routes.home, reduceMotion: reduce);
        await tester.tap(find.bySemanticsLabel('Scan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        final mid = tester.getTopLeft(find.byType(S1Screen)).dy;
        await tester.pumpAndSettle();
        return mid - tester.getTopLeft(find.byType(S1Screen)).dy;
      }

      expect(await midway(reduce: false), greaterThan(100), reason: 'sliding');
      expect(await midway(reduce: true), 0, reason: 'no movement');
    });

    testWidgets('a pushed page comes in along the x axis (Android shared '
        'axis), by at most 7.5 % of the width', (tester) async {
      final router = await pumpAt(tester, Routes.me);
      router.push(Routes.models);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final mid = tester.getTopLeft(find.text('M2')).dx;
      await tester.pumpAndSettle();
      final end = tester.getTopLeft(find.text('M2')).dx;
      // At most 7.5 % of the width (about 30 dp on a phone).
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(mid - end, inExclusiveRange(0, width * 0.075 + 0.01));
    });

    testWidgets('on iOS a pushed page slides in from the right edge', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final router = await pumpAt(tester, Routes.me);
      router.push(Routes.models);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final mid = tester.getTopLeft(find.text('M2')).dx;
      await tester.pumpAndSettle();
      expect(mid - tester.getTopLeft(find.text('M2')).dx, greaterThan(30));
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a full-screen page (T2) is pushed with the transition too', (
      tester,
    ) async {
      final router = await pumpAt(tester, Routes.home);
      router.push(Routes.tool('compress'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final mid = tester.getTopLeft(find.byType(ToolOptionsScreen)).dx;
      await tester.pumpAndSettle();
      final end = tester.getTopLeft(find.byType(ToolOptionsScreen)).dx;
      // At most 7.5 % of the width (about 30 dp on a phone).
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(mid - end, inExclusiveRange(0, width * 0.075 + 0.01));
    });
  });
}
