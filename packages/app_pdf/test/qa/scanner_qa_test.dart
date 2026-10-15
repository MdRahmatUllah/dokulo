import 'dart:typed_data';

import 'package:app_pdf/components/dk_scan_button.dart';
import 'package:app_pdf/components/dk_shutter_button.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/camera_permission.dart';
import 'package:app_pdf/screens/s1_scanner/camera_permission_gate.dart';
import 'package:app_pdf/screens/s1_scanner/s1_screen.dart';
import 'package:app_pdf/screens/s1_scanner/scan_session.dart';
import 'package:app_pdf/screens/s1_scanner/scanner_camera.dart';
import 'package:app_pdf/screens/s1_scanner/scanner_settings.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/s1_screen_test.dart' show FakeCamera, found;

// Visual QA (DK-0806, DK-0807, DK-0808, DK-0810, DK-0811, DK-0813, DK-0816,
// DK-0817, DK-0818, DK-0819, DK-0820): the 10-scanner camera frames prompt,
// denied, nodoc, countdown, flash, idback, retake, far, dark, cutoff and
// quad-iphone-se, rendered by the real S1 (and its permission gate) in
// light, dark and German. Frames in docs/qa/scanner/, findings in
// docs/qa/scanner.md. Some states already have goldens in
// test/screens/goldens/s1_*.png (flash menu light/dark, idback light/de,
// quad SE light): the board adds the rest.

class _Permission implements CameraPermission {
  _Permission(this.access);
  final CameraAccess access;
  @override
  Future<CameraAccess> status() async => access;
  @override
  Future<CameraAccess> request() async => access;
  @override
  Future<void> openSettings() async {}
}

/// A frame of one grey level, at [ms].
GreyFrame _grey(int level, int ms) => GreyFrame(
  Uint8List.fromList(List.filled(256, level)),
  16,
  16,
  rowStride: 16,
  time: Duration(milliseconds: ms),
);

/// The page far away: a small quad in the middle.
const _small = [
  Offset(0.42, 0.44),
  Offset(0.58, 0.44),
  Offset(0.58, 0.56),
  Offset(0.42, 0.56),
];

/// The page cut off at the top and left.
const _cut = [
  Offset(0.0, 0.0),
  Offset(0.8, 0.02),
  Offset(0.82, 0.7),
  Offset(0.01, 0.72),
];

void main() {
  late FakeCamera camera;
  late ProviderContainer container;

  for (final (theme, tokens, locale) in [
    ('light', DkTokens.light, const Locale('en')),
    ('dark', DkTokens.dark, const Locale('en')),
    ('deutsch', DkTokens.light, const Locale('de')),
  ]) {
    Future<void> pump(
      WidgetTester tester, {
      CameraAccess access = CameraAccess.granted,
      List<Offset>? quad,
      String? prefsJson,
      int? retake,
      Size size = const Size(393, 852),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      camera = FakeCamera();
      container = ProviderContainer(
        overrides: [
          cameraPermissionProvider.overrideWithValue(_Permission(access)),
          scannerCameraProvider.overrideWith((ref) => camera),
          quadDetectorProvider.overrideWith(
            (ref) =>
                (_) async => quad,
          ),
          scanStoreProvider.overrideWithValue(MemoryScanStore()),
          scannerPrefsStoreProvider.overrideWithValue(
            MemoryPrefsStore()..json = prefsJson,
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
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CameraPermissionGate(
              camera: (_) => S1Screen(
                onClose: () {},
                onImport: () {},
                onReview: () {},
                onSettings: () {},
                retake: retake,
                onRetaken: () {},
              ),
              onClose: () {},
              onImport: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> frames(WidgetTester tester, List<GreyFrame> list) async {
      for (final f in list) {
        camera.frames$.add(f);
        await tester.pumpAndSettle();
      }
    }

    Future<void> shot(WidgetTester tester, String frame) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/qa_scanner_${frame}_$theme.png'),
    );

    testWidgets('scanner-camera-prompt, $theme', (tester) async {
      await pump(tester, access: CameraAccess.notAsked);
      await shot(tester, 'prompt');
    });

    testWidgets('scanner-camera-denied, $theme', (tester) async {
      await pump(tester, access: CameraAccess.denied);
      await shot(tester, 'denied');
    });

    testWidgets('scanner-camera-nodoc, $theme', (tester) async {
      await pump(tester);
      await frames(tester, [_grey(200, 0), _grey(200, 100)]);
      await shot(tester, 'nodoc');
    });

    testWidgets('scanner-camera-countdown, $theme', (tester) async {
      await pump(tester, quad: found, prefsJson: '{"autoCapture": true}');
      await frames(tester, [_grey(200, 0), _grey(200, 100), _grey(200, 300)]);
      await shot(tester, 'countdown');
    });

    testWidgets('scanner-camera-flash, $theme', (tester) async {
      await pump(tester, quad: found);
      final off = lookupAppLocalizations(locale).camera_flash_off;
      await tester.longPressAt(tester.getCenter(find.text(off).first));
      await tester.pumpAndSettle();
      await shot(tester, 'flash');
    });

    testWidgets('scanner-camera-idback, $theme', (tester) async {
      await pump(tester, quad: found);
      container.read(scanModeStateProvider.notifier).set(DkScanMode.idCard);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DkShutterButton));
      await tester.pumpAndSettle();
      await shot(tester, 'idback');
    });

    testWidgets('scanner-camera-retake (page 3), $theme', (tester) async {
      await pump(tester, quad: found, retake: 2);
      await frames(tester, [_grey(200, 0), _grey(200, 100)]);
      await shot(tester, 'retake');
    });

    testWidgets('scanner-camera-far, $theme', (tester) async {
      await pump(tester, quad: _small);
      await frames(tester, [_grey(200, 0), _grey(200, 100)]);
      await shot(tester, 'far');
    });

    testWidgets('scanner-camera-dark, $theme', (tester) async {
      await pump(tester, quad: found);
      await frames(tester, [_grey(12, 0), _grey(12, 100), _grey(12, 300)]);
      await shot(tester, 'dark');
    });

    testWidgets('scanner-camera-cutoff, $theme', (tester) async {
      await pump(tester, quad: _cut);
      await frames(tester, [_grey(200, 0), _grey(200, 100)]);
      await shot(tester, 'cutoff');
    });

    testWidgets('scanner-camera-quad-iphone-se, $theme', (tester) async {
      await pump(tester, quad: found, size: const Size(375, 667));
      await frames(tester, [_grey(200, 0), _grey(200, 100)]);
      await shot(tester, 'quad_se');
    });
  }
}
