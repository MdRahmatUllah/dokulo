import 'package:app_pdf/catalogue/page_states.dart';
import 'package:app_pdf/components/dk_page_thumb.dart';
import 'package:app_pdf/components/dk_page_tray.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_layout.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget child, {
  DkTokens? tokens,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery.withClampedTextScaling(
    minScaleFactor: textScale,
    maxScaleFactor: textScale,
    child: Scaffold(body: child),
  ),
);

/// A tray of [ids] that applies its own moves, as the editor will.
class _Tray extends StatefulWidget {
  const _Tray(this.ids, {this.onAdd, this.current = 0});
  final List<int> ids;
  final int? current;
  final VoidCallback? onAdd;

  @override
  State<_Tray> createState() => _TrayState();
}

class _TrayState extends State<_Tray> {
  late final ids = [...widget.ids];

  @override
  Widget build(BuildContext context) => DkPageTray(
    pageIds: ids,
    pageBuilder: (_, _) => const CataloguePage(),
    current: widget.current,
    onSelect: (_) {},
    onReorder: (from, to) => setState(() => ids.insert(to, ids.removeAt(from))),
    onAdd: widget.onAdd,
  );
}

/// The page numbers the tray shows, left to right, by page id.
List<int> order(WidgetTester tester) {
  final thumbs = find.byType(DkPageThumb).evaluate().toList()
    ..sort(
      (a, b) => (a.renderObject! as RenderBox)
          .localToGlobal(Offset.zero)
          .dx
          .compareTo(
            (b.renderObject! as RenderBox).localToGlobal(Offset.zero).dx,
          ),
    );
  return [
    for (final e in thumbs)
      ((e.findAncestorWidgetOfExactType<Padding>()!.key! as ValueKey<Object>)
              .value
          as int),
  ];
}

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('every state, $name, ${(scale * 100).round()} %', (
        tester,
      ) async {
        tester.view.physicalSize = Size(460, scale == 1 ? 260 : 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(const PageTrayStates(), tokens: tokens, textScale: scale),
        );
        await expectLater(
          find.byType(PageTrayStates),
          matchesGoldenFile(
            'goldens/page_tray_${name}_${(scale * 100).round()}.png',
          ),
        );
      });
    }
  }

  testWidgets('88 tall in the spec, plus the ring\'s 4 dp; pages 56 × 72, '
      '8 apart', (tester) async {
    await tester.pumpWidget(app(const _Tray([1, 2, 3])));
    final tray = tester.getSize(find.byType(DkPageTray));
    // 72 + 4 + the caption's 16 = 92, + 4 above for the ring.
    expect(tray.height, 96);
    final thumbs = find.byType(DkPageThumb);
    expect(tester.getSize(thumbs.first).width, 56);
    expect(
      tester.getTopLeft(thumbs.at(1)).dx - tester.getTopRight(thumbs.first).dx,
      8,
    );
  });

  testWidgets('long-press and drag reorders the pages', (tester) async {
    await tester.pumpWidget(app(const _Tray([1, 2, 3])));
    expect(order(tester), [1, 2, 3]);
    final first = tester.getCenter(find.byType(DkPageThumb).first);
    final drag = await tester.startGesture(first);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    // Past the third page: 2 × (56 + 8).
    for (var i = 0; i < 7; i++) {
      await drag.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await drag.up();
    await tester.pumpAndSettle();
    expect(order(tester), [2, 3, 1]);
  });

  testWidgets('screen readers: page labels, the current page selected, '
      'move actions, a labelled "+" in EN and DE', (tester) async {
    final handle = tester.ensureSemantics();
    for (final (locale, page, add) in [
      (const Locale('en'), 'Page 1 of 3', 'Add pages'),
      (const Locale('de'), 'Seite 1 von 3', 'Seiten hinzufügen'),
    ]) {
      await tester.pumpWidget(
        app(_Tray(const [1, 2, 3], onAdd: () {}), locale: locale),
      );
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.bySemanticsLabel(page));
      expect(node, isSemantics(isSelected: true));
      expect(
        node.getSemanticsData().customSemanticsActionIds,
        isNotEmpty,
        reason: 'Move right / Move to the end',
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(add)),
        isSemantics(
          label: add,
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
        ),
      );
    }
    handle.dispose();
  });

  testWidgets('the "+" tile: tap, 56 × 72 target, focus ring', (tester) async {
    var adds = 0;
    await tester.pumpWidget(
      app(_Tray(const [1], onAdd: () => adds++, current: null)),
    );
    final plus = find.bySemanticsLabel('Add pages');
    expect(tester.getSize(plus), const Size(56, 72));
    await tester.tap(plus);
    expect(adds, 1);

    final focusRing = Border.fromBorderSide(DkTokens.light.focusRing);
    bool ringed() => tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .any((d) => (d.decoration as BoxDecoration?)?.border == focusRing);
    expect(ringed(), isFalse);
    // Tab past the page to the "+".
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(ringed(), isTrue);
  });
}
