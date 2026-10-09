import 'dart:io';
import 'dart:typed_data';

import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/signature_providers.dart';
import 'package:app_pdf/screens/m1_me/signatures_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A small signature: dark ink strokes on transparent.
Uint8List png() {
  final im = img.Image(width: 120, height: 48, numChannels: 4);
  img.drawLine(
    im,
    x1: 8,
    y1: 36,
    x2: 112,
    y2: 12,
    color: img.ColorRgba8(26, 43, 109, 255),
    thickness: 4,
  );
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  late DokuloDatabase db;
  late Directory dir;
  late SignatureStore store;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    DkTokens tokens = DkTokens.light,
    Locale locale = const Locale('en'),
    Future<(Uint8List, Color)?> Function(BuildContext)? add,
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [signatureStoreProvider.overrideWith((ref) async => store)],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(signaturesProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dokuloTheme(tokens),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SignaturesScreen(addSignature: add ?? (_) async => null),
        ),
      ),
    );
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await tester.pumpAndSettle();
  }

  setUp(() async {
    db = DokuloDatabase.memory();
    dir = await Directory.systemTemp.createTemp('signatures_');
    store = SignatureStore(db, dir, LockedCipher(List.filled(32, 3)));
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    await store.add(
      SignatureKind.signature,
      png(),
      ink: SignatureInk.blue,
      now: DateTime(2026, 10, 2),
    );
    await store.add(SignatureKind.initials, png(), now: DateTime(2026, 10, 2));
  });

  testWidgets('lists signatures and initials with ink and date', (
    tester,
  ) async {
    await seed(tester);
    await pump(tester);
    expect(find.text('Blue ink · added 2 Oct 2026'), findsOneWidget);
    expect(find.text('Black · added 2 Oct 2026'), findsOneWidget);
    expect(find.text('Add signature'), findsOneWidget);
    expect(find.text('Add initials'), findsOneWidget);
  });

  testWidgets('Add signature saves what the pad drew, sealed', (tester) async {
    await pump(tester, add: (_) async => (png(), const DkMarkup().ink));
    await tester.tap(find.text('Add signature'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    final list = await tester.runAsync(store.list);
    expect(
      [for (final s in list!) (s.kind, s.ink)],
      [(SignatureKind.signature, SignatureInk.blue)],
    );
  });

  testWidgets('a long press asks, and Remove deletes it', (tester) async {
    await seed(tester);
    await pump(tester);
    await tester.longPress(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(find.text('Remove this signature?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(await tester.runAsync(store.list), hasLength(1));
  });

  for (final (name, tokens, locale) in [
    ('light', DkTokens.light, const Locale('en')),
    ('dark', DkTokens.dark, const Locale('en')),
    ('de', DkTokens.light, const Locale('de')),
  ]) {
    testWidgets('golden: signatures ($name)', (tester) async {
      await seed(tester);
      await pump(tester, tokens: tokens, locale: locale);
      await expectLater(
        find.byType(SignaturesScreen),
        matchesGoldenFile('goldens/signatures_$name.png'),
      );
    });
  }
}
