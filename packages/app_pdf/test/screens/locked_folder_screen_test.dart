import 'package:app_pdf/components/dk_pin_pad.dart';
import 'package:app_pdf/components/dk_tab_bar.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/locked_providers.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Setup {
  final store = MemorySecretStore();
  var biometricOk = true;
  var prompts = 0;
  late final vault = LockedVault(
    store,
    pinIterations: 1000,
    biometrics: (_) async {
      prompts++;
      return biometricOk;
    },
  );
}

Future<ProviderContainer> pumpLocked(
  WidgetTester tester,
  _Setup setup, {
  BiometricKind? kind = BiometricKind.faceId,
  DkTokens? tokens,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = buildRouter(initialLocation: Routes.lockedFolder);
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      lockedVaultProvider.overrideWithValue(setup.vault),
      biometricKindProvider.overrideWith((ref) async => kind),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: dokuloTheme(tokens ?? DkTokens.light),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> typePin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(
      find.descendant(of: find.byType(DkPinPad), matching: find.text(digit)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('F2 is full screen: no tab bar', (tester) async {
    await pumpLocked(tester, _Setup());
    expect(find.byType(DkTabBar), findsNothing);
  });

  testWidgets('first time: L1 → L2 → L3 → L4 → the folder, open', (
    tester,
  ) async {
    final setup = _Setup();
    final container = await pumpLocked(tester, setup);
    expect(find.text('Keep files private'), findsOneWidget);
    expect(find.textContaining('need Face ID or your PIN'), findsOneWidget);
    await tester.tap(find.text('Set up'));
    await tester.pumpAndSettle();
    expect(find.text('Create a 6-digit PIN'), findsOneWidget);
    await typePin(tester, '482915');
    expect(find.text('Enter the PIN again'), findsOneWidget);
    await typePin(tester, '482915');
    expect(find.text('Use Face ID?'), findsOneWidget);
    await tester.tap(find.text('Use Face ID'));
    await tester.pumpAndSettle();
    expect(find.text('Locked folder'), findsOneWidget);
    expect(find.byTooltip('Lock now'), findsOneWidget);
    expect(await setup.vault.hasPin, isTrue);
    expect(await setup.vault.biometricsEnabled, isTrue);
    expect(container.read(lockedSessionProvider), isNotNull);
    expect(
      setup.store.values.values.join(),
      isNot(contains('482915')),
      reason: 'the PIN is stored only hashed',
    );
  });

  testWidgets('L3 mismatch: back to L2, cleared, with the message', (
    tester,
  ) async {
    final setup = _Setup();
    await pumpLocked(tester, setup);
    await tester.tap(find.text('Set up'));
    await tester.pumpAndSettle();
    await typePin(tester, '482915');
    await typePin(tester, '111111');
    expect(find.text('Create a 6-digit PIN'), findsOneWidget);
    expect(find.text("PINs don't match. Try again."), findsOneWidget);
    expect(await setup.vault.hasPin, isFalse);
  });

  testWidgets('without biometrics: no L4, and the PIN-only copy', (
    tester,
  ) async {
    final setup = _Setup();
    await pumpLocked(tester, setup, kind: null);
    expect(find.textContaining('need your PIN to open'), findsOneWidget);
    await tester.tap(find.text('Set up'));
    await tester.pumpAndSettle();
    await typePin(tester, '482915');
    await typePin(tester, '482915');
    expect(find.byTooltip('Lock now'), findsOneWidget);
  });

  testWidgets('Android wording: fingerprint', (tester) async {
    final setup = _Setup();
    await setup.vault.setPin('482915');
    await pumpLocked(tester, setup, kind: BiometricKind.fingerprint);
    expect(find.bySemanticsLabel('Use fingerprint'), findsOneWidget);
  });

  testWidgets('unlock: a wrong PIN says so; the right one opens', (
    tester,
  ) async {
    final setup = _Setup();
    await setup.vault.setPin('482915');
    await pumpLocked(tester, setup);
    expect(setup.prompts, 0, reason: 'biometrics were never turned on');
    expect(find.text('Locked folder'), findsOneWidget);
    await typePin(tester, '000000');
    expect(find.text('Wrong PIN.'), findsOneWidget);
    await typePin(tester, '482915');
    expect(find.byTooltip('Lock now'), findsOneWidget);
  });

  testWidgets('the biometric prompt opens it on arrival when turned on', (
    tester,
  ) async {
    final setup = _Setup();
    await setup.vault.setPin('482915');
    await setup.vault.enableBiometrics('test');
    setup.prompts = 0;
    final container = await pumpLocked(tester, setup);
    expect(setup.prompts, 1);
    expect(find.byTooltip('Lock now'), findsOneWidget);
    expect(container.read(lockedSessionProvider), isNotNull);
  });

  testWidgets('a cancelled prompt leaves the PIN pad', (tester) async {
    final setup = _Setup();
    await setup.vault.setPin('482915');
    await setup.vault.enableBiometrics('test');
    setup.biometricOk = false;
    await pumpLocked(tester, setup);
    expect(find.byType(DkPinPad), findsOneWidget);
  });

  testWidgets('Lock now locks; leaving locks too', (tester) async {
    final setup = _Setup();
    await setup.vault.setPin('482915');
    final container = await pumpLocked(tester, setup);
    await typePin(tester, '482915');
    await tester.tap(find.byTooltip('Lock now'));
    await tester.pumpAndSettle();
    expect(container.read(lockedSessionProvider), isNull);
    expect(find.byType(DkPinPad), findsOneWidget);

    await typePin(tester, '482915');
    expect(container.read(lockedSessionProvider), isNotNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(container.read(lockedSessionProvider), isNull);
  });

  testWidgets('after 5 wrong PINs it asks to wait', (tester) async {
    final setup = _Setup();
    await setup.vault.setPin('482915');
    await pumpLocked(tester, setup);
    for (var i = 0; i < 5; i++) {
      await typePin(tester, '000000');
    }
    expect(find.textContaining('Too many tries.'), findsOneWidget);
    await typePin(tester, '482915');
    expect(find.byTooltip('Lock now'), findsNothing, reason: 'throttled');
  });

  group('goldens', () {
    for (final (name, tokens, locale) in [
      ('light', DkTokens.light, const Locale('en')),
      ('dark', DkTokens.dark, const Locale('en')),
      ('de', DkTokens.light, const Locale('de')),
    ]) {
      testWidgets('L1, L2 and L4 ($name)', (tester) async {
        final setup = _Setup();
        await pumpLocked(tester, setup, tokens: tokens, locale: locale);
        final screen = find.byType(MaterialApp);
        await expectLater(
          screen,
          matchesGoldenFile('goldens/locked_l1_$name.png'),
        );
        await tester.tap(
          find.text(locale.languageCode == 'de' ? 'Einrichten' : 'Set up'),
        );
        await tester.pumpAndSettle();
        await expectLater(
          screen,
          matchesGoldenFile('goldens/locked_l2_$name.png'),
        );
        await typePin(tester, '482915');
        await typePin(tester, '482915');
        await expectLater(
          screen,
          matchesGoldenFile('goldens/locked_l4_$name.png'),
        );
      });
    }
  });
}
