import 'package:app_pdf/components/dk_banner.dart';
import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/screens/home/home_screen.dart';
import 'package:app_pdf/screens/home/photo_banner.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_screen_test.dart' show pumpHome;

/// H1's photo banner (DK-0252; home-photobanner).
void main() {
  late DokuloDatabase db;
  setUp(() => db = DokuloDatabase.memory());
  tearDown(() => db.close());

  String daysAgo(int d) =>
      DateTime.now().subtract(Duration(days: d)).toIso8601String();
  Map<String, Object?> prefsOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HomeScreen)))
          .read(prefsProvider)
          .value!;

  testWidgets('day one: no banner, the first day is remembered', (
    tester,
  ) async {
    await pumpHome(tester, db);
    await tester.pumpAndSettle();
    expect(find.text('Find documents in your photos?'), findsNothing);
    expect(prefsOf(tester)[firstUseKey], isNotNull);
  });

  testWidgets('day six: still no banner', (tester) async {
    await pumpHome(tester, db, prefs: {firstUseKey: daysAgo(6)});
    await tester.pumpAndSettle();
    expect(find.byType(DkBanner), findsNothing);
  });

  testWidgets('from day seven: the banner; × dismisses it for good', (
    tester,
  ) async {
    await pumpHome(tester, db, prefs: {firstUseKey: daysAgo(8)});
    await tester.pumpAndSettle();
    expect(find.text('Find documents in your photos?'), findsOneWidget);
    expect(find.text('Look now'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(DkBanner),
        matching: find.byIcon(DkIcons.close),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DkBanner), findsNothing);
    expect(prefsOf(tester)[photoBannerKey], 'dismissed');
  });

  testWidgets('Look now opens the photo finder intro; the banner is done', (
    tester,
  ) async {
    await pumpHome(tester, db, prefs: {firstUseKey: daysAgo(8)});
    await tester.pumpAndSettle();
    await tester.tap(find.text('Look now'));
    await tester.pumpAndSettle();
    expect(find.text('Allow photo access'), findsOneWidget);
    expect(prefsOf(tester)[photoBannerKey], 'used');
  });

  testWidgets('already used or dismissed: never again', (tester) async {
    await pumpHome(
      tester,
      db,
      prefs: {firstUseKey: daysAgo(30), photoBannerKey: 'used'},
    );
    await tester.pumpAndSettle();
    expect(find.byType(DkBanner), findsNothing);
  });

  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('golden: home photo banner ($name)', (tester) async {
      await pumpHome(
        tester,
        db,
        tokens: tokens,
        prefs: {firstUseKey: daysAgo(8)},
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(DkBanner),
        matchesGoldenFile('goldens/home_photo_banner_$name.png'),
      );
    });
  }
}
