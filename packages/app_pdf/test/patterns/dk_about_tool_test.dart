import 'package:app_pdf/components/dk_pro_badge.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/patterns/dk_about_tool.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/tools/tool_catalogue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ToolInfo tool(String id) => ToolCatalogue.all.firstWhere((t) => t.id == id);

/// A screen with one button that runs [run] with its context.
Widget app(
  Widget Function(BuildContext) child, {
  DkTokens? tokens,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Builder(builder: child)),
);

void main() {
  test('every tool has its About text in EN and DE', () async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l = await AppLocalizations.delegate.load(locale);
      for (final t in ToolCatalogue.all) {
        expect(t.need(l), isNotEmpty, reason: '${t.id} need ($locale)');
        expect(t.get(l), isNotEmpty, reason: '${t.id} get ($locale)');
      }
    }
  });

  group('goldens', () {
    for (final (name, id, tokens, locale) in [
      ('compress_light', 'compress', DkTokens.light, const Locale('en')),
      ('compress_dark', 'compress', DkTokens.dark, const Locale('en')),
      ('web_de', 'web', DkTokens.light, const Locale('de')),
      ('ocr_light', 'ocr', DkTokens.light, const Locale('en')),
    ]) {
      testWidgets(name, (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            (context) => Padding(
              padding: const EdgeInsets.all(16),
              child: DkAboutTool(tool(id)),
            ),
            tokens: tokens,
            locale: locale,
          ),
        );
        await expectLater(
          find.byType(DkAboutTool),
          matchesGoldenFile('goldens/about_tool_$name.png'),
        );
      });
    }
  });

  testWidgets('a free tool says Free and works offline', (tester) async {
    await tester.pumpWidget(app((_) => DkAboutTool(tool('compress'))));
    expect(find.text('Compress PDF'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.byType(DkProBadge), findsNothing);
    expect(find.text('One or more PDFs'), findsOneWidget);
    expect(
      find.text('A smaller copy. Your original stays unchanged.'),
      findsOneWidget,
    );
    expect(find.text('Works offline'), findsOneWidget);
  });

  testWidgets('a Pro tool shows the Pro badge', (tester) async {
    await tester.pumpWidget(app((_) => DkAboutTool(tool('ocr'))));
    expect(find.byType(DkProBadge), findsOneWidget);
    expect(find.text('Free'), findsNothing);
  });

  testWidgets('Web page to PDF says it loads the page', (tester) async {
    await tester.pumpWidget(app((_) => DkAboutTool(tool('web'))));
    expect(find.text('Needs the internet'), findsOneWidget);
    expect(find.text('Works offline'), findsNothing);
  });

  testWidgets('each fact is one node for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app((_) => DkAboutTool(tool('compress'))));
    expect(
      find.bySemanticsLabel('What you need\nOne or more PDFs'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('the sheet: Open runs the tool, × closes', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      app(
        (context) => TextButton(
          onPressed: () =>
              showAboutTool(context, tool('compress'), onOpen: () => opened++),
          child: const Text('go'),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Compress PDF'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.byType(DkAboutTool), findsNothing);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(DkAboutTool), findsNothing);
  });

  testWidgets('from T2 (no onOpen) there is no Open button', (tester) async {
    await tester.pumpWidget(
      app(
        (context) => TextButton(
          onPressed: () => showAboutTool(context, tool('merge')),
          child: const Text('go'),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Open '), findsNothing);
  });
}
