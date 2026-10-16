import 'dart:io';
import 'dart:typed_data';

import 'package:app_pdf/components/dk_promo_cards.dart';
import 'package:app_pdf/l10n/formats.dart';
import 'package:app_pdf/providers/link_providers.dart';
import 'package:app_pdf/providers/mail_providers.dart';
import 'package:app_pdf/providers/signature_providers.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/screens/me/me_screen.dart';
import 'package:app_pdf/screens/settings/files_settings_screen.dart';
import 'package:app_pdf/screens/settings/security_settings_screen.dart';
import 'package:doc_core/doc_core.dart'
    show SavedSignature, SignatureInk, SignatureKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../routes/routes_test.dart' show pumpAt;

/// M1 · Me (DK-0570).
void main() {
  testWidgets('free: the Pro card, the sections, Restore, the footer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpAt(tester, Routes.me);
    expect(find.byType(DkProCard), findsOneWidget);
    for (final text in [
      'Your things',
      'Signatures',
      'Workflows',
      'AI models',
      'Settings',
      'Scanning',
      'Files & storage',
      'Security',
      'Appearance',
      'Language',
      'About',
      'Privacy',
      'Open-source licences',
      'Replay intro',
      'Contact',
      'Rate Dokulo',
      'Restore purchase',
      'Dokulo $appVersion ($appBuild)',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('Pro: the owned row instead of the card', (tester) async {
    await pumpAt(
      tester,
      Routes.me,
      overrides: [isProProvider.overrideWithValue(true)],
    );
    expect(find.byType(DkProCard), findsNothing);
    expect(find.text('Pro – yours for good'), findsOneWidget);
    expect(find.text('Thank you'), findsOneWidget);
  });

  testWidgets('Your things: the signatures count, the models size (DK-1097)', (
    tester,
  ) async {
    await pumpAt(
      tester,
      Routes.me,
      overrides: [
        signaturesProvider.overrideWith(_TwoSignatures.new),
        modelsSizeProvider.overrideWith((ref) async => 1800000000),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(find.text(formatBytes(1800000000, 'en')), findsOneWidget);
  });

  testWidgets('Contact drafts a mail with the version; Rate opens the Play '
      'page (DK-0578)', (tester) async {
    tester.view.physicalSize = const Size(393, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final mails = <Uri>[];
    final links = <Uri>[];
    await pumpAt(
      tester,
      Routes.me,
      overrides: [
        mailComposerProvider.overrideWithValue((u) async {
          mails.add(u);
          return true;
        }),
        linkOpenerProvider.overrideWithValue((u) async {
          links.add(u);
          return true;
        }),
      ],
    );
    await tester.tap(find.text('Contact'));
    await tester.pumpAndSettle();
    expect(mails.single.scheme, 'mailto');
    expect(
      Uri.decodeComponent(mails.single.query),
      contains('Dokulo $appVersion ($appBuild)'),
    );
    await tester.tap(find.text('Rate Dokulo'));
    await tester.pumpAndSettle();
    expect(links.single, playPage);
  });

  testWidgets('a Settings row opens its page', (tester) async {
    tester.view.physicalSize = const Size(393, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpAt(tester, Routes.me);
    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();
    expect(find.byType(SecuritySettingsScreen), findsOneWidget);
  });

  test("the footer's version is pubspec's", () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version: (\S+)\+',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(appVersion, version);
  });
}

class _TwoSignatures extends Signatures {
  @override
  Future<List<(SavedSignature, Uint8List)>> build() async => [
    for (var i = 1; i <= 2; i++)
      (
        (
          id: i,
          kind: SignatureKind.values.first,
          ink: SignatureInk.values.first,
          created: DateTime(2026),
        ),
        Uint8List(0),
      ),
  ];
}
