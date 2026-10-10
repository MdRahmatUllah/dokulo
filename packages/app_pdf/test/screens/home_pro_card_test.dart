import 'package:app_pdf/components/dk_file_card.dart';
import 'package:app_pdf/components/dk_promo_cards.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/screens/home/home_screen.dart';
import 'package:app_pdf/screens/me/me_screen.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_screen_test.dart' show addFile, pumpHome;

/// H1's Pro card (DK-0251).
void main() {
  group('showProCard: the frequency cap', () {
    final now = DateTime(2026, 10, 10);
    bool show({
      bool pro = false,
      int recents = 6,
      int dismissals = 0,
      DateTime? dismissedAt,
    }) => showProCard(
      pro: pro,
      recents: recents,
      dismissals: dismissals,
      dismissedAt: dismissedAt,
      now: now,
    );

    test('free, 5 recent files or more, never dismissed: shown', () {
      expect(show(), isTrue);
      expect(show(recents: 5), isTrue);
      expect(show(recents: 4), isFalse, reason: 'no 5th row to follow');
    });
    test('never to Pro users', () => expect(show(pro: true), isFalse));
    test('a dismissal hides it for 30 days: at most once a month', () {
      DateTime ago(int days) => now.subtract(Duration(days: days));
      expect(show(dismissals: 1, dismissedAt: ago(29)), isFalse);
      expect(show(dismissals: 1, dismissedAt: ago(30)), isTrue);
    });
    test('the second dismissal is for good', () {
      expect(
        show(
          dismissals: 2,
          dismissedAt: now.subtract(const Duration(days: 400)),
        ),
        isFalse,
      );
    });
  });

  late DokuloDatabase db;
  setUp(() => db = DokuloDatabase.memory());
  tearDown(() => db.close());

  Future<void> seven(WidgetTester tester) => tester.runAsync(() async {
    for (var i = 0; i < 7; i++) {
      await addFile(db, 'f$i.pdf', opened: DateTime(2026, 10, 1, i));
    }
  });

  testWidgets('after the 5th recent row; × hides it and counts', (
    tester,
  ) async {
    await seven(tester);
    await pumpHome(tester, db);
    await tester.scrollUntilVisible(find.byType(DkProCard), 200);
    // Five rows above it, the other two below.
    final cardTop = tester.getTopLeft(find.byType(DkProCard)).dy;
    final rows = tester.widgetList<DkFileCard>(find.byType(DkFileCard));
    final above = [
      for (final r in rows)
        if (tester.getTopLeft(find.byWidget(r)).dy < cardTop) r,
    ];
    expect(above, hasLength(5));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    // Clear of the tab bar.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(
      find.descendant(
        of: find.byType(DkProCard),
        matching: find.bySemanticsLabel('Close'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(DkProCard), findsNothing);
    expect(container.read(prefsProvider).value![proCardDismissals], 1);
  });

  testWidgets('never for Pro users', (tester) async {
    await seven(tester);
    await pumpHome(
      tester,
      db,
      overrides: [isProProvider.overrideWithValue(true)],
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DkFileCard), findsWidgets);
    expect(find.byType(DkProCard), findsNothing);
  });
}
