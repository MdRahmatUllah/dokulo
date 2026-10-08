import 'package:app_pdf/catalogue/chat_states.dart';
import 'package:app_pdf/components/dk_chat_bubble.dart';
import 'package:app_pdf/components/dk_diff_row.dart';
import 'package:app_pdf/components/dk_page_chip.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget home, {
  DkTokens? tokens,
  Locale locale = const Locale('en'),
  double textScale = 1,
  bool reduceMotion = false,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: reduceMotion,
      textScaler: TextScaler.linear(textScale),
    ),
    child: child!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: home)),
);

void main() {
  for (final (what, gallery) in [
    ('chat', const ChatStates()),
    ('diff', const DiffStates()),
  ]) {
    for (final (name, tokens) in [
      ('light', DkTokens.light),
      ('dark', DkTokens.dark),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$what, $name, ${(scale * 100).round()} %', (tester) async {
          tester.view.physicalSize = Size(393, scale == 1 ? 520 : 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            app(gallery, tokens: tokens, textScale: scale, reduceMotion: true),
          );
          await expectLater(
            find.byWidget(gallery),
            matchesGoldenFile(
              'goldens/${what}_${name}_${(scale * 100).round()}.png',
            ),
          );
        });
      }
    }
  }

  testWidgets('the user on the right, the AI on the left, at most 85 %', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const ChatStates()));
    final bubbles = find.byType(DkChatBubble);
    Rect box(int i) => tester.getRect(
      find
          .descendant(of: bubbles.at(i), matching: find.byType(Container))
          .first,
    );
    expect(box(0).right, closeTo(400 - 16, 0.5));
    expect(box(1).left, closeTo(16, 0.5));
    expect(box(1).width, lessThanOrEqualTo((400 - 32) * 0.85 + 0.5));
  });

  testWidgets('**bold** is drawn bold without the stars; page chips jump', (
    tester,
  ) async {
    final pages = <int>[];
    await tester.pumpWidget(
      app(
        DkChatBubble(
          role: DkChatRole.ai,
          text: 'It ends on **31 December**.',
          pages: const [3],
          onPage: pages.add,
        ),
      ),
    );
    final rich = tester.widget<RichText>(
      find
          .descendant(
            of: find.byType(DkChatBubble),
            matching: find.byType(RichText),
          )
          .first,
    );
    expect(rich.text.toPlainText(), 'It ends on 31 December.');
    final bold = <String>[];
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.style?.fontWeight == FontWeight.w700) {
        bold.add(span.text!);
      }
      return true;
    });
    expect(bold, ['31 December']);
    await tester.tap(find.byType(DkPageChip));
    expect(pages, [3]);
  });

  testWidgets('the caret blinks while streaming; still with Reduce Motion', (
    tester,
  ) async {
    double caret() => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byType(DkChatBubble),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    const bubble = DkChatBubble(
      role: DkChatRole.ai,
      text: 'Thinking',
      streaming: true,
    );
    await tester.pumpWidget(app(bubble));
    expect(caret(), 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(caret(), 0);
    await tester.pumpWidget(app(bubble, reduceMotion: true));
    await tester.pump(const Duration(seconds: 2));
    expect(caret(), 1);
  });

  testWidgets('diff rows: the tag in EN and DE, removed struck through, a '
      'tap jumps', (tester) async {
    for (final (locale, tag) in [
      (const Locale('en'), 'Removed'),
      (const Locale('de'), 'Entfernt'),
    ]) {
      var jumps = 0;
      await tester.pumpWidget(
        app(
          DkDiffRow(
            change: DkChange.removed,
            excerpt: 'A parking space.',
            page: 3,
            onTap: () => jumps++,
          ),
          locale: locale,
        ),
      );
      expect(find.text(tag), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('A parking space.')).style!.decoration,
        TextDecoration.lineThrough,
      );
      await tester.tap(find.text('A parking space.'));
      expect(jumps, 1);
      expect(
        tester.getSize(find.byType(DkDiffRow)).height,
        greaterThanOrEqualTo(56),
      );
    }
  });
}
