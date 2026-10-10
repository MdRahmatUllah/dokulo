import 'dart:convert';

import 'package:app_pdf/components/dk_pin_pad.dart';
import 'package:app_pdf/components/dk_switch.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/patterns/dk_app_lock.dart';
import 'package:app_pdf/providers/locked_providers.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/providers/privacy_providers.dart';
import 'package:app_pdf/providers/security_providers.dart';
import 'package:app_pdf/screens/settings/security_settings_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'locked_folder_screen_test.dart' show LockedSetup, typePin;

/// Settings → Security (DK-0573), Change PIN (DK-0292), the app lock
/// (DK-0290).
void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    LockedSetup setup,
    Widget home, {
    Map<String, Object?> prefs = const {},
    BiometricKind? kind = BiometricKind.faceId,
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        lockedVaultProvider.overrideWithValue(setup.vault),
        biometricKindProvider.overrideWith((ref) async => kind),
        prefsProvider.overrideWith(() => Prefs.memory(prefs)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dokuloTheme(DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  DkSwitch switchFor(WidgetTester tester, String title) =>
      tester.widget<DkSwitch>(
        find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == 'DkSettingsRow',
            ),
          ),
          matching: find.byType(DkSwitch),
        ),
      );

  testWidgets('defaults: App lock off, 1 min, Hide previews on', (
    tester,
  ) async {
    final setup = LockedSetup();
    await setup.vault.setPin('482915');
    final c = await pump(tester, setup, const SecuritySettingsScreen());
    expect(switchFor(tester, 'App lock').value, isFalse);
    expect(find.text('1 min'), findsOneWidget);
    expect(switchFor(tester, 'Hide previews in app switcher').value, isTrue);
    expect(c.read(privacyCoverProvider), isTrue);
    expect(find.text('Unlock with Face ID'), findsOneWidget);
    expect(
      find.text('Ask for Face ID or PIN when opening Dokulo'),
      findsOneWidget,
    );
  });

  testWidgets('without a PIN, App lock and Change PIN wait for one', (
    tester,
  ) async {
    await pump(tester, LockedSetup(), const SecuritySettingsScreen());
    expect(switchFor(tester, 'App lock').onChanged, isNull);
    expect(find.text('Set a locked folder PIN first.'), findsNWidgets(2));
  });

  testWidgets('changes apply at once and are kept', (tester) async {
    final setup = LockedSetup();
    await setup.vault.setPin('482915');
    final c = await pump(tester, setup, const SecuritySettingsScreen());
    switchFor(tester, 'App lock').onChanged!(true);
    switchFor(tester, 'Hide previews in app switcher').onChanged!(false);
    await tester.pumpAndSettle();
    expect(c.read(securitySettingsProvider).appLock, isTrue);
    expect(c.read(privacyCoverProvider), isFalse);
    await tester.tap(find.text('Lock after'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 min'));
    await tester.pumpAndSettle();
    expect(c.read(securitySettingsProvider).lockAfter, 300);
    expect(c.read(prefsProvider).value!['security.lockAfter'], 300);
  });

  testWidgets('Change PIN: the old PIN stops working, the key stays', (
    tester,
  ) async {
    final setup = LockedSetup();
    await setup.vault.setPin('482915');
    final before = await setup.vault.unlockWithPin('482915') as PinUnlocked;
    final sealed = await before.cipher.seal(utf8.encode('Kontoauszug'));
    await pump(tester, setup, const ChangePinScreen());
    expect(find.text('Enter your current PIN'), findsOneWidget);
    await typePin(tester, '000000');
    expect(find.text('Wrong PIN.'), findsOneWidget);
    await typePin(tester, '482915');
    expect(find.text('Create a 6-digit PIN'), findsOneWidget);
    await typePin(tester, '135790');
    expect(find.text('Enter the PIN again'), findsOneWidget);
    await typePin(tester, '135790');
    expect(await setup.vault.unlockWithPin('482915'), isA<PinWrong>());
    final after = await setup.vault.unlockWithPin('135790') as PinUnlocked;
    // Files sealed before the change still open.
    expect(utf8.decode(await after.cipher.open(sealed)), 'Kontoauszug');
  });

  group('the app lock', () {
    var clock = DateTime(2026, 10, 10, 9);
    DateTime now() => clock;

    Future<void> background(WidgetTester tester, Duration away) async {
      final b = tester.binding;
      b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      b.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clock = clock.add(away);
      b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    Widget app() => DkAppLock(now: now, child: const Text('Home'));

    testWidgets('on: back after Lock after, the lock screen; the PIN opens', (
      tester,
    ) async {
      final setup = LockedSetup();
      await setup.vault.setPin('482915');
      await pump(
        tester,
        setup,
        app(),
        prefs: {'security.appLock': true},
        kind: null,
      );
      await background(tester, const Duration(seconds: 30));
      expect(find.text('Dokulo is locked'), findsNothing, reason: '< 1 min');
      await background(tester, const Duration(minutes: 2));
      expect(find.text('Dokulo is locked'), findsOneWidget);
      expect(find.byType(DkPinPad), findsOneWidget);
      await typePin(tester, '482915');
      expect(find.text('Dokulo is locked'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('Immediately: locked as soon as it leaves', (tester) async {
      final setup = LockedSetup();
      await setup.vault.setPin('482915');
      await pump(
        tester,
        setup,
        app(),
        prefs: {'security.appLock': true, 'security.lockAfter': 0},
        kind: null,
      );
      // A moment away is enough: the lock is set on leaving (no frame is
      // drawn while hidden), so the first frame back is the lock.
      await background(tester, Duration.zero);
      expect(find.text('Dokulo is locked'), findsOneWidget);
    });

    testWidgets('off: never locks', (tester) async {
      final setup = LockedSetup();
      await setup.vault.setPin('482915');
      await pump(tester, setup, app(), kind: null);
      await background(tester, const Duration(hours: 1));
      expect(find.text('Dokulo is locked'), findsNothing);
    });

    testWidgets('biometrics failing leave the PIN pad', (tester) async {
      final setup = LockedSetup();
      await setup.vault.setPin('482915');
      await setup.vault.enableBiometrics('test'); // on, while it works
      setup.biometricOk = false; // then the finger fails
      await pump(tester, setup, app(), prefs: {'security.appLock': true});
      await background(tester, const Duration(minutes: 5));
      expect(setup.prompts, 2, reason: 'asked at once on the lock');
      expect(find.byType(DkPinPad), findsOneWidget);
    });
  });
}
