import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/camera_permission.dart';
import 'package:app_pdf/screens/s1_scanner/camera_permission_gate.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePermission implements CameraPermission {
  FakePermission(this.access, {this.answer = CameraAccess.granted});

  CameraAccess access;
  final CameraAccess answer;
  var requests = 0, settings = 0;

  @override
  Future<CameraAccess> status() async => access;

  @override
  Future<CameraAccess> request() async {
    requests++;
    return access = answer;
  }

  @override
  Future<void> openSettings() async => settings++;
}

void main() {
  late FakePermission permission;
  var closed = 0, imported = 0;

  Future<void> pump(
    WidgetTester tester, {
    DkTokens? tokens,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    closed = imported = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cameraPermissionProvider.overrideWithValue(permission)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dokuloTheme(tokens ?? DkTokens.light),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CameraPermissionGate(
              camera: (_) => const Text('CAMERA'),
              onClose: () => closed++,
              onImport: () => imported++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'never asked: the pre-prompt; Continue asks once, then the camera',
    (tester) async {
      permission = FakePermission(CameraAccess.notAsked);
      await pump(tester);
      expect(find.text('Allow camera access'), findsOneWidget);
      expect(
        find.text(
          'Dokulo uses the camera only to scan. Images stay on this phone.',
        ),
        findsOneWidget,
      );
      expect(
        permission.requests,
        0,
        reason: 'no system prompt before Continue',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(permission.requests, 1);
      expect(find.text('CAMERA'), findsOneWidget);
    },
  );

  testWidgets('Not now leaves the scanner without asking', (tester) async {
    permission = FakePermission(CameraAccess.notAsked);
    await pump(tester);
    await tester.tap(find.text('Not now'));
    expect(closed, 1);
    expect(permission.requests, 0);
  });

  testWidgets(
    'a "no": camera access is off; Settings and Import, no second prompt',
    (tester) async {
      permission = FakePermission(
        CameraAccess.notAsked,
        answer: CameraAccess.denied,
      );
      await pump(tester);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Camera access is off'), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      await tester.tap(find.text('Import from photos'));
      await tester.tap(find.byTooltip('Close scanner'));
      expect((permission.settings, imported, closed), (1, 1, 1));
      // Back from Settings, still off: still the denied screen, never a prompt.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Camera access is off'), findsOneWidget);
      expect(permission.requests, 1);
    },
  );

  testWidgets('turned on in Settings: back in the app, the camera opens', (
    tester,
  ) async {
    permission = FakePermission(CameraAccess.denied);
    await pump(tester);
    expect(find.text('Camera access is off'), findsOneWidget);
    permission.access = CameraAccess.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('CAMERA'), findsOneWidget);
    expect(permission.requests, 0);
  });

  testWidgets('granted: straight to the camera', (tester) async {
    permission = FakePermission(CameraAccess.granted);
    await pump(tester);
    expect(find.text('CAMERA'), findsOneWidget);
  });

  for (final (name, tokens, locale) in [
    ('light', DkTokens.light, const Locale('en')),
    ('dark', DkTokens.dark, const Locale('en')),
    ('de', DkTokens.light, const Locale('de')),
  ]) {
    for (final access in [CameraAccess.notAsked, CameraAccess.denied]) {
      testWidgets('golden: ${access.name} $name', (tester) async {
        permission = FakePermission(access);
        await pump(tester, tokens: tokens, locale: locale);
        await expectLater(
          find.byType(CameraPermissionGate),
          matchesGoldenFile('goldens/camera_${access.name}_$name.png'),
        );
      });
    }
  }
}
