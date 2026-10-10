import 'dart:io';

import 'package:app_pdf/components/dk_signature_card.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/providers/signature_providers.dart';
import 'package:app_pdf/screens/sign/signatures_sheet.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_providers.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

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

Future<void> settleIo(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  late DokuloDatabase db;
  late Directory dir;
  late SignatureStore store;
  late ProviderContainer container;
  (SavedSignature, Uint8List)? picked;

  setUp(() async {
    db = DokuloDatabase.memory();
    dir = await Directory.systemTemp.createTemp('sign_sheet_');
    store = SignatureStore(db, dir, LockedCipher(List.filled(32, 5)));
    picked = null;
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<void> open(
    WidgetTester tester, {
    DkTokens? tokens,
    Locale locale = const Locale('en'),
    Future<(Uint8List, Color)?> Function(BuildContext)? pad,
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        signatureStoreProvider.overrideWith((ref) async => store),
        prefsProvider.overrideWith(Prefs.memory),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(signaturesProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dokuloTheme(tokens ?? DkTokens.light),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => picked = await showSignaturesSheet(
                    context,
                    openPad: pad ?? (_) async => null,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> seed(WidgetTester tester) => tester.runAsync(
    () => store.add(SignatureKind.signature, png(), ink: SignatureInk.blue),
  );

  testWidgets('empty: "No signatures yet" and Add signature', (tester) async {
    await open(tester);
    expect(find.text('Your signatures'), findsOneWidget);
    expect(find.text('No signatures yet'), findsOneWidget);
  });

  testWidgets('adding from the empty sheet stores it; tapping it picks it', (
    tester,
  ) async {
    await open(tester, pad: (_) async => (png(), const DkMarkup().ink));
    await tester.tap(find.text('Add signature'));
    await settleIo(tester);
    expect(find.text('No signatures yet'), findsNothing);
    await tester.tap(find.byType(DkSignatureCard));
    await tester.pumpAndSettle();
    expect(picked?.$1.ink, SignatureInk.blue);
  });

  testWidgets("the switches are kept in the app's prefs", (tester) async {
    await open(tester);
    await tester.ensureVisible(find.text('Add date next to signature'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add date next to signature'));
    await tester.pumpAndSettle();
    final prefs = container.read(prefsProvider).value!;
    expect(prefs[signAddDateKey], isTrue);
    expect(prefs[signInitialsKey], isNull);
  });

  testWidgets('the pad opens in landscape and gives the phone back', (
    tester,
  ) async {
    final calls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          calls.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: dokuloTheme(DkTokens.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => openSignaturePad(context),
            child: const Text('pad'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('pad'));
    await tester.pumpAndSettle();
    expect(calls, [
      ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight'],
    ]);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls.last, isEmpty);
  });

  Future<(Uint8List, Color)?> Function() padWithPhoto(
    WidgetTester tester,
    Future<Uint8List> Function(String) fromPhoto,
  ) {
    (Uint8List, Color)? result;
    return () async {
      // The pad turns the phone to landscape and back.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            devicePickerProvider.overrideWithValue(
              (input, {required photos}) async => ['signature.jpg'],
            ),
          ],
          child: MaterialApp(
            theme: dokuloTheme(DkTokens.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async => result = await openSignaturePad(
                    context,
                    fromPhoto: fromPhoto,
                  ),
                  child: const Text('pad'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('pad'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();
      return result;
    };
  }

  testWidgets('Image tab (DK-1084): a chosen photo becomes the signature, '
      'black ink', (tester) async {
    final png = Uint8List.fromList([137, 80, 78, 71]);
    final picked = <String>[];
    final result = await padWithPhoto(tester, (path) async {
      picked.add(path);
      return png;
    })();
    expect(picked, ['signature.jpg']);
    expect(result?.$1, png);
    expect(result?.$2, const DkMarkup().black);
  });

  testWidgets('Image tab: a photo without ink says so and stays open', (
    tester,
  ) async {
    await padWithPhoto(
      tester,
      (path) async => throw const FormatException('no ink'),
    )();
    expect(find.text('No signature found in this photo.'), findsOneWidget);
    expect(find.text('Choose photo'), findsOneWidget);
  });

  for (final (name, tokens, locale) in [
    ('light', DkTokens.light, const Locale('en')),
    ('dark', DkTokens.dark, const Locale('en')),
    ('de', DkTokens.light, const Locale('de')),
  ]) {
    testWidgets('golden: signatures sheet ($name)', (tester) async {
      await seed(tester);
      await open(tester, tokens: tokens, locale: locale);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/signatures_sheet_$name.png'),
      );
    });
  }
}
