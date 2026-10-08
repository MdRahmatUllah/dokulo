import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/patterns/dk_drag.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/theme/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> felt;

  Widget app(Widget child) => ProviderScope(
    overrides: [
      hapticsProvider.overrideWithValue(
        DkHaptics(
          selection: () async => felt.add('selected'),
          light: () async => felt.add('light'),
          medium: () async => felt.add('medium'),
        ),
      ),
    ],
    child: MaterialApp(
      theme: dokuloTheme(DkTokens.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  setUp(() => felt = []);

  testWidgets('DkEdgeScroller: scrolls within 48 dp of an edge, then stops', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      app(
        ListView(
          controller: controller,
          children: [for (var i = 0; i < 50; i++) SizedBox(height: 60)],
        ),
      ),
    );
    final scroller = DkEdgeScroller(controller);
    const size = Size(800, 600);
    scroller.update(const Offset(100, 300), size); // the middle
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.offset, 0);
    scroller.update(const Offset(100, 600 - 20), size); // near the bottom
    await tester.pump(const Duration(milliseconds: 160));
    final down = controller.offset;
    expect(down, greaterThan(0));
    scroller.update(const Offset(100, 300), size); // back to the middle
    await tester.pump(const Duration(milliseconds: 160));
    expect(controller.offset, down);
    scroller.update(const Offset(100, 10), size); // near the top
    await tester.pump(const Duration(milliseconds: 160));
    expect(controller.offset, lessThan(down));
    scroller.stop();
  });

  testWidgets('a 300 ms press lifts a file; dropped on a folder, it moves', (
    tester,
  ) async {
    final moved = <String>[];
    final hovering = <bool>[];
    await tester.pumpWidget(
      app(
        Column(
          children: [
            const DkDraggable<String>(
              data: 'scan.pdf',
              child: SizedBox(height: 64, child: Text('scan.pdf')),
            ),
            const SizedBox(height: 200),
            DkDropTarget<String>(
              onDrop: moved.add,
              builder: (context, over) {
                hovering.add(over);
                return const SizedBox(height: 64, child: Text('Taxes'));
              },
            ),
          ],
        ),
      ),
    );
    // 250 ms is not yet a lift.
    var g = await tester.startGesture(tester.getCenter(find.text('scan.pdf')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(felt, isEmpty);
    await g.up();
    await tester.pump();
    // 300 ms is.
    g = await tester.startGesture(tester.getCenter(find.text('scan.pdf')));
    await tester.pump(dkLiftDelay);
    expect(felt, ['selected']);
    await g.moveTo(tester.getCenter(find.text('Taxes')));
    await tester.pump();
    expect(hovering.last, isTrue);
    await g.up();
    await tester.pump();
    expect(moved, ['scan.pdf']);
    expect(felt, ['selected', 'light']);
  });

  testWidgets('a reorderable list lifts after 300 ms and reorders', (
    tester,
  ) async {
    final items = ['A', 'B', 'C'];
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, set) => ReorderableListView.builder(
            buildDefaultDragHandles: false,
            proxyDecorator: dkReorderProxy,
            itemCount: items.length,
            onReorderItem: (from, to) =>
                set(() => items.insert(to, items.removeAt(from))),
            itemBuilder: (context, i) => DkReorderStartListener(
              key: ValueKey(items[i]),
              index: i,
              child: SizedBox(height: 60, child: Text(items[i])),
            ),
          ),
        ),
      ),
    );
    final g = await tester.startGesture(tester.getCenter(find.text('A')));
    await tester.pump(dkLiftDelay);
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(0, 15));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(items, ['B', 'C', 'A']);
  });
}
