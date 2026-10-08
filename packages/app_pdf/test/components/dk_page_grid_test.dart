import 'package:app_pdf/catalogue/page_states.dart';
import 'package:app_pdf/components/dk_page_grid.dart';
import 'package:app_pdf/components/dk_page_thumb.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {DkTokens? tokens, double textScale = 1}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dokuloTheme(tokens ?? DkTokens.light),
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

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('every state, $name, ${(scale * 100).round()} %', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(393, 560);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(const PageGridStates(), tokens: tokens, textScale: scale),
        );
        await expectLater(
          find.byType(PageGridStates),
          matchesGoldenFile(
            'goldens/page_grid_${name}_${(scale * 100).round()}.png',
          ),
        );
      });
    }
  }

  testWidgets('3 columns on a phone, 12 apart, pages 3 : 4', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const PageGridStates()));
    final thumbs = find.byType(DkPageThumb);
    final first = tester.getRect(thumbs.at(0)),
        second = tester.getRect(thumbs.at(1));
    // (393 − 2 × 16 − 2 × 12) / 3
    expect(first.width, closeTo(112.33, 0.01));
    expect(second.left - first.right, closeTo(12, 0.01));
    expect(tester.getTopLeft(thumbs.at(3)).dx, first.left); // row 2
  });

  testWidgets('pinch out: fewer, bigger pages; pinch in: more (2 to 6)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final columns = <int>[];
    await tester.pumpWidget(
      app(
        DkPageGrid(
          pageIds: List.generate(30, (i) => i),
          pageBuilder: (_, _) => const CataloguePage(),
          onColumnsChanged: columns.add,
        ),
      ),
    );
    Future<void> pinch(double from, double to) async {
      const centre = Offset(196, 400);
      final a = await tester.startGesture(centre - Offset(from / 2, 0));
      final b = await tester.startGesture(centre + Offset(from / 2, 0));
      for (var i = 1; i <= 10; i++) {
        final d = from + (to - from) * i / 10;
        await a.moveTo(centre - Offset(d / 2, 0));
        await b.moveTo(centre + Offset(d / 2, 0));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await tester.pump();
    }

    await pinch(100, 140); // 1.4×: one column fewer
    expect(columns, [2]);
    await pinch(100, 140); // already 2: stays
    expect(columns, [2]);
    await pinch(200, 50); // 0.25×: 3, 4, 5, 6
    expect(columns.last, 6);
    expect(columns, [2, 3, 4, 5, 6]);
  });

  testWidgets('long-press lifts a page; the insertion line shows where it '
      'lands; dropping reorders', (tester) async {
    tester.view.physicalSize = const Size(393, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final moves = <(int, int)>[];
    final lifted = <int>[];
    await tester.pumpWidget(
      app(
        DkPageGrid(
          pageIds: List.generate(9, (i) => i),
          pageBuilder: (_, _) => const CataloguePage(),
          onLongPress: lifted.add,
          onReorder: (from, to) => moves.add((from, to)),
        ),
      ),
    );
    final thumbs = find.byType(DkPageThumb);
    final drag = await tester.startGesture(tester.getCenter(thumbs.at(0)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(lifted, [0], reason: 'lifting enters selection mode');
    // Over the right half of page 3 (the first row's end).
    final target = tester.getRect(thumbs.at(2));
    for (var i = 1; i <= 10; i++) {
      await drag.moveTo(
        Offset.lerp(
          tester.getCenter(thumbs.at(0)),
          target.centerRight - const Offset(10, 0),
          i / 10,
        )!,
      );
      await tester.pump();
    }
    // The whole app: the lifted page is drawn in the overlay.
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/page_grid_dragging.png'),
    );
    await drag.up();
    await tester.pump();
    expect(moves, [(0, 2)]);
  });

  testWidgets('screen readers: move actions reorder without dragging', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final moves = <(int, int)>[];
    await tester.pumpWidget(
      app(
        DkPageGrid(
          pageIds: List.generate(4, (i) => i),
          pageBuilder: (_, _) => const CataloguePage(),
          onReorder: (from, to) => moves.add((from, to)),
        ),
      ),
    );
    final page2 = tester.getSemantics(find.bySemanticsLabel('Page 2 of 4'));
    final owner = page2.owner!;
    int action(String label) =>
        page2.getSemanticsData().customSemanticsActionIds!.firstWhere(
          (id) => CustomSemanticsAction.getAction(id)!.label == label,
        );
    for (final label in [
      'Move to the start',
      'Move left',
      'Move right',
      'Move to the end',
    ]) {
      owner.performAction(
        page2.id,
        SemanticsAction.customAction,
        action(label),
      );
    }
    expect(moves, [(1, 0), (1, 0), (1, 2), (1, 3)]);
    handle.dispose();
  });

  testWidgets(
    '300 pages: only the visible rows are built; the end is reachable',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var built = 0;
      await tester.pumpWidget(
        app(
          DkPageGrid(
            pageIds: List.generate(300, (i) => i),
            pageBuilder: (_, _) {
              built++;
              return const CataloguePage();
            },
          ),
        ),
      );
      expect(built, lessThan(40));
      await tester.fling(find.byType(GridView), const Offset(0, -30000), 8000);
      await tester.pumpAndSettle();
      expect(find.text('300'), findsOneWidget);
      expect(find.byType(DkPageThumb).evaluate().length, lessThan(40));
    },
  );

  // agent-1's repros from the #1132 review.
  testWidgets('dragging back in front of the lifted page still drops', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final moves = <(int, int)>[];
    await tester.pumpWidget(
      app(
        DkPageGrid(
          pageIds: List.generate(9, (i) => i),
          pageBuilder: (_, _) => const CataloguePage(),
          onReorder: (from, to) => moves.add((from, to)),
        ),
      ),
    );
    final thumbs = find.byType(DkPageThumb);
    final five = tester.getCenter(thumbs.at(4));
    final drag = await tester.startGesture(five);
    await tester.pump(const Duration(milliseconds: 400));
    // Into page 5's own left half: the slot is before the lifted page.
    for (var i = 0; i < 4; i++) {
      await drag.moveBy(const Offset(-8, 0));
      await tester.pump();
    }
    // Then to page 1's left half.
    final one = tester.getRect(thumbs.at(0));
    for (var i = 1; i <= 10; i++) {
      await drag.moveTo(
        Offset.lerp(
          five - const Offset(32, 0),
          one.centerLeft + const Offset(10, 0),
          i / 10,
        )!,
      );
      await tester.pump();
    }
    await drag.up();
    await tester.pump();
    expect(moves, [(4, 0)]);
  });

  testWidgets('auto-scroll past the lifted page; release drops and stops '
      'the scrolling', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final moves = <(int, int)>[];
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      app(
        DkPageGrid(
          pageIds: List.generate(300, (i) => i),
          pageBuilder: (_, _) => const CataloguePage(),
          controller: scroll,
          onReorder: (from, to) => moves.add((from, to)),
        ),
      ),
    );
    final drag = await tester.startGesture(
      tester.getCenter(find.byType(DkPageThumb).at(1)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    // Hold at the bottom edge for 2 s: the lifted cell scrolls far away.
    final bottom = tester.getBottomLeft(find.byType(DkPageGrid));
    await drag.moveTo(Offset(196, bottom.dy - 20));
    for (var i = 0; i < 125; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(scroll.offset, greaterThan(500));
    await drag.moveTo(const Offset(196, 400));
    await tester.pump();
    await drag.up();
    await tester.pump();
    expect(moves, hasLength(1));
    expect(moves.single.$1, 1);
    final after = scroll.offset;
    await tester.pump(const Duration(milliseconds: 500));
    expect(scroll.offset, after, reason: 'no scrolling after release');
  });

  testWidgets('on an SE width, at most 5 columns: cells stay 48 dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final columns = <int>[];
    await tester.pumpWidget(
      app(
        DkPageGrid(
          pageIds: List.generate(30, (i) => i),
          pageBuilder: (_, _) => const CataloguePage(),
          onColumnsChanged: columns.add,
        ),
      ),
    );
    const centre = Offset(187, 300);
    final a = await tester.startGesture(centre - const Offset(100, 0));
    final b = await tester.startGesture(centre + const Offset(100, 0));
    for (var i = 1; i <= 10; i++) {
      final d = 200 - 170 * i / 10;
      await a.moveTo(centre - Offset(d / 2, 0));
      await b.moveTo(centre + Offset(d / 2, 0));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pump();
    expect(columns.last, 5);
    expect(
      tester.getSize(find.byType(DkPageThumb).first).width,
      greaterThanOrEqualTo(48),
    );
  });
}
