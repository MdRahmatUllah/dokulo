import 'dart:io';

import 'package:app_pdf/components/dk_promo_cards.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/screens/me/me_screen.dart';
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

  testWidgets('a Settings row opens its page', (tester) async {
    tester.view.physicalSize = const Size(393, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpAt(tester, Routes.me);
    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();
    // M3 is a placeholder until its pages land (DK-0573, ...).
    expect(find.text('M3 security'), findsOneWidget);
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
