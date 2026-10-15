import 'package:app_pdf/components/dk_promo_cards.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_providers.dart';
import 'package:app_pdf/tools/tool_definition.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_screen_test.dart' show pumpHome;

/// H1's "Continue: job finished" card (DK-0247).
void main() {
  late DokuloDatabase db;
  setUp(() => db = DokuloDatabase.memory());
  tearDown(() => db.close());

  final result = ToolResult(
    toolId: 'compress',
    inputs: [
      FileEntry(
        id: 1,
        path: 'Mietvertrag.pdf',
        name: 'Mietvertrag.pdf',
        size: 8400000,
        pages: 12,
        created: DateTime(2026),
        modified: DateTime(2026),
        hasText: false,
        encrypted: false,
      ),
    ],
    output: const ManyFiles(['a.pdf', 'b.pdf']),
    took: const Duration(seconds: 40),
  );

  Future<ProviderContainer> pump(WidgetTester tester) async {
    await pumpHome(tester, db);
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  testWidgets('none waiting: no card', (tester) async {
    await pump(tester);
    expect(find.byType(DkContinueCard), findsNothing);
  });

  testWidgets('a job done in the background: the card; Open goes to T3', (
    tester,
  ) async {
    final router = await pumpHome(tester, db);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(backgroundResultProvider.notifier).set(result);
    await tester.pumpAndSettle();
    expect(find.text('Compress PDF · Mietvertrag.pdf'), findsOneWidget);
    expect(find.text('2 files'), findsOneWidget);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/tool/compress/result');
    expect(container.read(lastToolResultProvider), same(result));
    expect(container.read(backgroundResultProvider), isNull);
  });

  testWidgets('× dismisses it', (tester) async {
    final container = await pump(tester);
    container.read(backgroundResultProvider.notifier).set(result);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(DkContinueCard), findsNothing);
    expect(container.read(backgroundResultProvider), isNull);
  });

  test('T3 saving it forgets it; another result stays', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final waiting = container.read(backgroundResultProvider.notifier)
      ..set(result);
    waiting.forget(
      ToolResult(
        toolId: 'merge',
        inputs: const [],
        output: const OneFile('x.pdf'),
        took: Duration.zero,
      ),
    );
    expect(container.read(backgroundResultProvider), same(result));
    waiting.forget(result);
    expect(container.read(backgroundResultProvider), isNull);
  });
}
