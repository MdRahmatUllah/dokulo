import 'dart:async';
import 'dart:typed_data';

import 'package:app_pdf/components/dk_camera_top_bar.dart';
import 'package:app_pdf/components/dk_count_badge.dart';
import 'package:app_pdf/components/dk_scan_button.dart';
import 'package:app_pdf/components/dk_shutter_button.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/screens/s1_scanner/s1_screen.dart';
import 'package:app_pdf/screens/s1_scanner/scan_session.dart';
import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/screens/s1_scanner/scanner_camera.dart';
import 'package:app_pdf/screens/s1_scanner/scanner_settings.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A paper-coloured 30 × 40 JPEG: what the fake camera "captures".
final page = Uint8List.fromList(
  img.encodeJpg(
    img.Image(width: 30, height: 40)..clear(img.ColorRgb8(240, 238, 230)),
  ),
);

class FakeCamera implements ScannerCamera {
  final frames$ = StreamController<GreyFrame>.broadcast();
  var opened = false, closed = false, shots = 0;
  DkFlash? flash;

  @override
  Future<void> open() async => opened = true;
  @override
  Widget preview() => Container(
    // A desk with a page on it, for the goldens.
    color: const Color(0xFF3A3631),
    alignment: Alignment.center,
    child: FractionallySizedBox(
      widthFactor: 0.62,
      heightFactor: 0.5,
      child: Container(color: const Color(0xFFF2F0EA)),
    ),
  );
  @override
  double? get aspectRatio => 3 / 4;
  @override
  Stream<GreyFrame> get frames => frames$.stream;
  @override
  Future<void> setFlash(DkFlash f) async => flash = f;
  @override
  Future<Uint8List> capture() async {
    shots++;
    return page;
  }

  @override
  Future<void> close() async => closed = true;

  /// A bright frame (the fake page is lit), taken at [ms] milliseconds.
  void frame([int ms = 0]) => frames$.add(
    GreyFrame(
      Uint8List.fromList(List.filled(256, 200)),
      16,
      16,
      rowStride: 16,
      time: Duration(milliseconds: ms),
    ),
  );
}

/// The page in the fake preview, as a detector would find it.
const found = [
  Offset(0.19, 0.25),
  Offset(0.81, 0.25),
  Offset(0.81, 0.75),
  Offset(0.19, 0.75),
];

void main() {
  late FakeCamera camera;
  late MemoryPrefsStore prefs;
  Future<void> capture(WidgetTester tester) async {
    await tester.tap(find.byType(DkShutterButton));
    await tester.pumpAndSettle();
  }

  late ProviderContainer container;
  var closed = 0, imported = 0, reviewed = 0;

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(393, 852),
    DkTokens? tokens,
    Locale locale = const Locale('en'),
    DetectedQuad? quad,
    String? prefsJson,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    camera = FakeCamera();
    prefs = MemoryPrefsStore()..json = prefsJson;
    closed = imported = reviewed = 0;
    container = ProviderContainer(
      overrides: [
        scannerCameraProvider.overrideWith((ref) => camera),
        quadDetectorProvider.overrideWith(
          (ref) =>
              (_) async => quad,
        ),
        scanStoreProvider.overrideWithValue(MemoryScanStore()),
        scannerPrefsStoreProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dokuloTheme(tokens ?? DkTokens.light),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: S1Screen(
            onClose: () => closed++,
            onImport: () => imported++,
            onReview: () => reviewed++,
            onSettings: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens the camera; without a document: "Point at a document"', (
    tester,
  ) async {
    await pump(tester);
    expect(camera.opened, isTrue);
    camera.frame();
    await tester.pumpAndSettle();
    expect(find.text('Point at a document'), findsOneWidget);
  });

  testWidgets('a document in view: "Ready"', (tester) async {
    await pump(tester, quad: found);
    // Two frames with the same quad: it held steady.
    camera.frame();
    await tester.pumpAndSettle();
    camera.frame();
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('capture adds a page: the stack shows it and its count; to S2', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    expect(find.byType(DkCountBadge), findsNothing);
    await capture(tester);
    await capture(tester);
    expect(camera.shots, 2);
    expect(container.read(scanSessionProvider), hasLength(2));
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Review 2 pages'));
    expect(reviewed, 1);
    semantics.dispose();
  });

  testWidgets('modes, flash, grid, close and import', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    await tester.tap(find.text('Book'));
    await tester.pump();
    expect(container.read(scanModeStateProvider), DkScanMode.book);
    await tester.tap(find.bySemanticsLabel(RegExp('^Flash')));
    await tester.pump();
    expect(camera.flash, DkFlash.on);
    await tester.tap(find.bySemanticsLabel('Close scanner'));
    await tester.tap(find.bySemanticsLabel('Import from photos'));
    expect((closed, imported), (1, 1));
    semantics.dispose();
  });

  testWidgets('a long press on flash opens the menu; a pick sets it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    await tester.longPress(find.bySemanticsLabel(RegExp('^Flash')));
    await tester.pumpAndSettle();
    expect(find.text('On'), findsOneWidget);
    await tester.tap(find.text('Auto').last);
    await tester.pumpAndSettle();
    expect(camera.flash, DkFlash.auto);
    expect(find.bySemanticsLabel('Flash options'), findsNothing);
    semantics.dispose();
  });

  testWidgets(
    'capture: "Page 1 captured" for screen readers; Reduce Motion: no flash',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pump(tester);
      await tester.tap(find.byType(DkShutterButton));
      await tester.pump();
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains('Page 1 captured'),
      );
      expect(container.read(scanSessionProvider), hasLength(1));
    },
  );

  group('auto-capture (DK-0338)', () {
    Future<void> frames(WidgetTester tester, List<int> times) async {
      for (final t in times) {
        camera.frame(t);
        await tester.pumpAndSettle();
      }
    }

    testWidgets('steady for 0.5 s: "Capturing…", the arc, then the shot', (
      tester,
    ) async {
      await pump(tester, quad: found, prefsJson: '{"autoCapture": true}');
      await frames(tester, [0, 100, 300]);
      expect(find.text('Capturing…'), findsOneWidget);
      final arc = tester
          .widget<DkShutterButton>(find.byType(DkShutterButton))
          .countdown;
      expect(arc, closeTo(0.4, 0.01));
      expect(camera.shots, 0);
      await frames(tester, [600]);
      expect(camera.shots, 1);
    });

    testWidgets('off by default: a steady page is only "Ready"', (
      tester,
    ) async {
      await pump(tester, quad: found);
      await frames(tester, [0, 100, 900]);
      expect(find.text('Ready'), findsOneWidget);
      expect(camera.shots, 0);
    });

    testWidgets('Batch forces it on with a lock; the toggle is remembered', (
      tester,
    ) async {
      await pump(tester, quad: found);
      await tester.tap(find.text('Auto'));
      await tester.pumpAndSettle();
      expect(prefs.json, contains('"autoCapture":true'));
      await tester.tap(find.text('Auto'));
      await tester.pumpAndSettle();
      expect(prefs.json, contains('"autoCapture":false'));
      await tester.ensureVisible(find.text('Batch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batch'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate((w) => w is DkIcon && w.icon == DkIcons.lock),
        findsOneWidget,
      );
      await frames(tester, [0, 100, 700]);
      expect(camera.shots, 1, reason: 'Batch captures by itself');
    });
  });

  testWidgets('closing the screen closes the camera', (tester) async {
    await pump(tester);
    await tester.pumpWidget(const SizedBox());
    expect(camera.closed, isTrue);
  });

  for (final (name, size, tokens, locale) in [
    ('quad_light', const Size(393, 852), DkTokens.light, const Locale('en')),
    ('quad_dark', const Size(393, 852), DkTokens.dark, const Locale('en')),
    ('quad_de', const Size(393, 852), DkTokens.light, const Locale('de')),
    (
      'quad_iphone_se',
      const Size(375, 667),
      DkTokens.light,
      const Locale('en'),
    ),
    (
      'quad_landscape',
      const Size(852, 393),
      DkTokens.light,
      const Locale('en'),
    ),
  ]) {
    testWidgets('golden: $name', (tester) async {
      await pump(
        tester,
        size: size,
        tokens: tokens,
        locale: locale,
        quad: found,
      );
      // Two frames with the same quad: steady, "Ready".
      camera.frame();
      await tester.pumpAndSettle();
      camera.frame();
      await capture(tester);
      // The stack's thumbnail: decode it for real.
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(S1Screen),
        matchesGoldenFile('goldens/s1_$name.png'),
      );
    });
  }

  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('golden: flash menu ($name)', (tester) async {
      await pump(tester, tokens: tokens, quad: found);
      // The flash button sits second from the left in the top bar.
      await tester.longPressAt(tester.getCenter(find.text('Off').first));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(S1Screen),
        matchesGoldenFile('goldens/s1_flash_menu_$name.png'),
      );
    });
  }
}
