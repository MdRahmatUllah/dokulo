import 'dart:convert';
import 'dart:typed_data';

import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/components/dk_promo_cards.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/screens/home/continue_card.dart';
import 'package:app_pdf/screens/s1_scanner/scan_session.dart';
import 'package:app_pdf/screens/s2_review/s2_screen.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'home_screen_test.dart' show pumpHome;

/// H1's "Continue: unsaved scan" (DK-0246; home-contscan).
void main() {
  late DokuloDatabase db;
  setUp(() => db = DokuloDatabase.memory());
  tearDown(() => db.close());

  /// A scan of [n] pages left on disk by a killed app, begun at [at].
  MemoryScanStore leftScan(int n, DateTime at) {
    final store = MemoryScanStore();
    final pages = [
      for (var i = 0; i < n; i++)
        {
          'id': '${at.microsecondsSinceEpoch}-$i.jpg',
          'path': 'p$i',
          'turns': 0,
        },
    ];
    for (final p in pages) {
      store.files[p['path']! as String] = _page;
    }
    store.manifest = jsonEncode(pages);
    return store;
  }

  testWidgets('an unsaved scan after a restart: the card, Continue opens S2', (
    tester,
  ) async {
    final at = DateTime.now().subtract(const Duration(minutes: 5));
    await pumpHome(tester, db, scanStore: leftScan(6, at));
    await tester.pumpAndSettle();
    expect(find.text('Scan of 6 pages not saved'), findsOneWidget);
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(started(en, at, 'en', DateTime.now())), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(S2Screen), findsOneWidget);
  });

  testWidgets('× hides the card; the scan stays', (tester) async {
    final store = leftScan(2, DateTime.now());
    await pumpHome(tester, db, scanStore: store);
    await tester.pumpAndSettle();
    expect(find.text('Scan of 2 pages not saved'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(DkContinueCard),
        matching: find.byIcon(DkIcons.close),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Scan of 2 pages not saved'), findsNothing);
    expect(store.manifest, isNotNull);
  });

  testWidgets('no scan, no card', (tester) async {
    await pumpHome(tester, db);
    await tester.pumpAndSettle();
    expect(find.textContaining('not saved'), findsNothing);
  });

  test('"Started today 14:32", yesterday, or the date', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final de = await AppLocalizations.delegate.load(const Locale('de'));
    final now = DateTime(2026, 10, 15, 18);
    expect(
      started(en, DateTime(2026, 10, 15, 14, 32), 'en', now),
      'Started today 14:32',
    );
    expect(
      started(de, DateTime(2026, 10, 15, 14, 32), 'de', now),
      'Heute 14:32 begonnen',
    );
    expect(
      started(en, DateTime(2026, 10, 14, 9, 5), 'en', now),
      'Started yesterday 09:05',
    );
    expect(started(en, DateTime(2026, 10, 7), 'en', now), 'Started 7 Oct 2026');
    expect(
      scanStarted(const ScannedPage('1760536320000000-0.jpg', 'p')),
      DateTime.fromMicrosecondsSinceEpoch(1760536320000000),
    );
    expect(scanStarted(const ScannedPage('odd', 'p')), isNull);
  });
}

/// A paper-coloured 30 × 40 JPEG: S2 decodes the pages it opens.
final _page = Uint8List.fromList(
  img.encodeJpg(
    img.Image(width: 30, height: 40)..clear(img.ColorRgb8(240, 238, 230)),
  ),
);
