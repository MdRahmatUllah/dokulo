import 'dart:async';
import 'dart:typed_data';

import 'package:app_pdf/components/dk_camera_top_bar.dart';
import 'package:app_pdf/components/dk_count_badge.dart';
import 'package:app_pdf/components/dk_scan_button.dart';
import 'package:app_pdf/components/dk_shutter_button.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/screens/s1_scanner/s1_screen.dart';
import 'package:app_pdf/screens/s1_scanner/scan_session.dart';
import 'package:app_pdf/screens/s1_scanner/scanner_camera.dart';
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

  void frame() => frames$.add(
    GreyFrame(Uint8List(4), 2, 2, rowStride: 2, time: Duration.zero),
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
  late ProviderContainer container;
  var closed = 0, imported = 0, reviewed = 0;

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(393, 852),
    DkTokens? tokens,
    Locale locale = const Locale('en'),
    DetectedQuad? quad,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    camera = FakeCamera();
    closed = imported = reviewed = 0;
    container = ProviderContainer(
      overrides: [
        scannerCameraProvider.overrideWith((ref) => camera),
        quadDetectorProvider.overrideWith(
          (ref) =>
              (_) async => quad,
        ),
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
    await tester.tap(find.byType(DkShutterButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DkShutterButton));
    await tester.pumpAndSettle();
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
      camera.frame();
      await tester.tap(find.byType(DkShutterButton));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(S1Screen),
        matchesGoldenFile('goldens/s1_$name.png'),
      );
    });
  }
}
