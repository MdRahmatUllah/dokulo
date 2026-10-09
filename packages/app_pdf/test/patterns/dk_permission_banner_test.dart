import 'package:app_pdf/catalogue/global_banners_gallery.dart';
import 'package:app_pdf/components/dk_banner.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/patterns/dk_permission_banner.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: dokuloTheme(DkTokens.light),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('every denied permission says what doesn\'t work and opens '
        'settings, never a prompt (DK-0621, ${platform.name})', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      for (final p in DkPermission.values) {
        var opened = 0;
        await tester.pumpWidget(
          app(
            DkPermissionBanner(permission: p, onOpenSettings: () => opened++),
          ),
        );
        final banner = tester.widget<DkBanner>(find.byType(DkBanner));
        expect(banner.variant, DkBannerVariant.warning, reason: '$p');
        expect(banner.text, contains(' off'), reason: '$p');
        await tester.tap(find.text('Open settings'));
        expect(opened, 1, reason: '$p');
      }
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('the camera banner reads as the global states board, EN and DE', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        DkPermissionBanner(
          permission: DkPermission.camera,
          onOpenSettings: () {},
        ),
      ),
    );
    expect(
      find.text("Camera access is off, so scanning doesn't work."),
      findsOneWidget,
    );
    await tester.pumpWidget(
      app(
        DkPermissionBanner(
          permission: DkPermission.camera,
          onOpenSettings: () {},
        ),
        locale: const Locale('de'),
      ),
    );
    expect(
      find.text('Kamerazugriff ist aus, daher funktioniert das Scannen nicht.'),
      findsOneWidget,
    );
    expect(find.text('Einstellungen öffnen'), findsOneWidget);
  });

  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final lang in ['en', 'de']) {
      testWidgets('golden: global_banners_${theme}_$lang (DK-0622)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(393, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dokuloTheme(tokens),
            locale: Locale(lang),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: GlobalBannersGallery(),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/global_banners_${theme}_$lang.png'),
        );
      });
    }
  }

  testWidgets('each banner variant has its board message (DK-0622)', (
    tester,
  ) async {
    await tester.pumpWidget(app(const GlobalBannersGallery()));
    final variants = tester
        .widgetList<DkBanner>(find.byType(DkBanner))
        .map((b) => b.variant);
    expect(variants, DkBannerVariant.values);
    expect(find.text('3 scans have no searchable text yet.'), findsOneWidget);
    expect(
      find.text("Purchase didn't complete. You weren't charged."),
      findsOneWidget,
    );
    expect(find.text('Free try · Pro unlocks unlimited use'), findsOneWidget);
  });
}
