import 'dart:io';

import 'package:ai_core/ai_core.dart' show DeviceCapabilities;
import 'package:app_pdf/crash/crash_log.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/crash_providers.dart';
import 'package:app_pdf/providers/device_providers.dart';
import 'package:app_pdf/providers/mail_providers.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/screens/settings/privacy_settings_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// M3 · Privacy (DK-0576) and its crash reports (DK-0011).
void main() {
  late Directory dir;
  late CrashLog log;
  late ProviderContainer container;
  late List<Uri> mails;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dk_privacy_');
    log = CrashLog(File('${dir.path}/crash_log.jsonl'));
    mails = [];
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pump(
    WidgetTester tester, {
    DkTokens? tokens,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWith(Prefs.memory),
        crashLogProvider.overrideWith((ref) async => log),
        mailComposerProvider.overrideWithValue((mailto) async {
          mails.add(mailto);
          return true;
        }),
        deviceCapabilitiesProvider.overrideWith(
          (ref) async => const DeviceCapabilities(os: 'android'),
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
          home: const PrivacySettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the two lists and the banner, as the frame says', (
    tester,
  ) async {
    await pump(tester);
    for (final text in [
      'What stays on this phone',
      'Your files and scans',
      'What uses the internet',
      'Purchases, through the App Store or Google Play',
      'No analytics, no ads, no account.',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('Keep crash reports: off by default, the row turns it on and '
      'keeps it', (tester) async {
    await pump(tester);
    expect(container.read(crashReportsEnabledProvider), isFalse);
    await tester.tap(find.text('Keep crash reports'));
    await tester.pumpAndSettle();
    expect(container.read(crashReportsEnabledProvider), isTrue);
    expect(container.read(prefsProvider).value?[crashReportsKey], isTrue);
  });

  testWidgets('Send report by email drafts a mail with the log', (
    tester,
  ) async {
    await tester.runAsync(
      () => log.record(
        CrashEntry(at: DateTime.utc(2026), type: 'StateError', frames: []),
      ),
    );
    await pump(tester);
    await tester.ensureVisible(find.text('Send report by email'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Send report by email'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(mails.single.scheme, 'mailto');
    expect(Uri.decodeComponent(mails.single.query), contains('StateError'));
  });

  testWidgets('Delete crash reports empties the log', (tester) async {
    await tester.runAsync(
      () => log.record(
        CrashEntry(at: DateTime.utc(2026), type: 'StateError', frames: []),
      ),
    );
    await pump(tester);
    await tester.ensureVisible(find.text('Delete crash reports'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Delete crash reports'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Crash reports deleted'), findsOneWidget);
    expect(await tester.runAsync(log.entries), isEmpty);
  });

  for (final (name, tokens, locale) in [
    ('light', DkTokens.light, const Locale('en')),
    ('dark', DkTokens.dark, const Locale('en')),
    ('de', DkTokens.light, const Locale('de')),
  ]) {
    testWidgets('golden: privacy ($name)', (tester) async {
      await pump(tester, tokens: tokens, locale: locale);
      await expectLater(
        find.byType(PrivacySettingsScreen),
        matchesGoldenFile('goldens/privacy_$name.png'),
      );
    });
  }
}
