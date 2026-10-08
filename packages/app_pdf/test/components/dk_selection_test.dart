import 'package:app_pdf/components/dk_bottom_bars.dart';
import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/components/dk_selection.dart';
import 'package:app_pdf/components/dk_tappable.dart';
import 'package:app_pdf/components/dk_top_bar.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/theme/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final ticks = <String>[];
final opened = <String>[];
const files = ['Lease.pdf', 'Invoice.pdf', 'ID scan.pdf'];

/// A Files-like screen: rows that take part in selection mode.
Widget screen(DkSelection<String> selection, {ValueNotifier<bool>? shell}) {
  final page = DkSelectionScaffold<String>(
    selection: selection,
    all: () => files,
    appBar: const DkTopBar(title: 'Files', leading: DkTopBarLeading.none),
    actions: (selected) => [
      DkBarAction(icon: DkIcons.delete, label: 'Delete', onPressed: () {}),
    ],
    body: ListView(
      children: [
        for (final f in files)
          DkSelectable<String>(
            selection: selection,
            item: f,
            onOpen: () => opened.add(f),
            builder: (context, s) => DkTappable(
              onTap: s.onTap,
              onLongPress: s.onLongPress,
              radius: 0,
              builder: (context, pressed) => SizedBox(
                height: 72,
                child: Row(
                  children: [
                    if (s.selecting)
                      Icon(s.selected ? Icons.check_circle : Icons.circle),
                    Text(f),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
  return ProviderScope(
    overrides: [
      hapticsProvider.overrideWithValue(
        DkHaptics(selection: () async => ticks.add('tick')),
      ),
    ],
    child: MaterialApp(
      theme: dokuloTheme(DkTokens.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: shell == null
          ? page
          : DkShellChrome(tabBarHidden: shell, child: page),
    ),
  );
}

void main() {
  setUp(() {
    ticks.clear();
    opened.clear();
  });

  testWidgets('a long press starts it: "1 selected", Cancel, Select all, the '
      'selection bar; a tick', (tester) async {
    final selection = DkSelection<String>();
    addTearDown(selection.dispose);
    await tester.pumpWidget(screen(selection));
    expect(find.byType(DkSelectionBar), findsNothing);
    await tester.longPress(find.text('Lease.pdf'));
    await tester.pump();
    expect(find.text('1 selected'), findsOne);
    expect(find.text('Cancel'), findsOne);
    expect(find.text('Select all'), findsOne);
    expect(find.byType(DkSelectionBar), findsOne);
    expect(ticks, ['tick']);
  });

  testWidgets('taps toggle while selecting, each with a tick; Select all; '
      'Cancel ends it; a tap opens again', (tester) async {
    final selection = DkSelection<String>();
    addTearDown(selection.dispose);
    await tester.pumpWidget(screen(selection));
    await tester.longPress(find.text('Lease.pdf'));
    await tester.pump();
    await tester.tap(find.text('Invoice.pdf'));
    await tester.pump();
    expect(find.text('2 selected'), findsOne);
    await tester.tap(find.text('Lease.pdf'));
    await tester.pump();
    expect(selection.selected, {'Invoice.pdf'});
    expect(ticks, hasLength(3));
    expect(opened, isEmpty);
    await tester.tap(find.text('Select all'));
    await tester.pump();
    expect(find.text('3 selected'), findsOne);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(selection.active, isFalse);
    expect(find.byType(DkSelectionBar), findsNothing);
    await tester.tap(find.text('Lease.pdf'));
    expect(opened, ['Lease.pdf']);
  });

  testWidgets('back ends selection mode before it leaves the screen', (
    tester,
  ) async {
    final selection = DkSelection<String>();
    addTearDown(selection.dispose);
    await tester.pumpWidget(screen(selection));
    await tester.longPress(find.text('Lease.pdf'));
    await tester.pump();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pump();
    expect(selection.active, isFalse);
    expect(find.text('Files'), findsOne);
  });

  testWidgets("the shell's tab bar steps aside while selecting", (
    tester,
  ) async {
    final selection = DkSelection<String>();
    final hidden = ValueNotifier(false);
    addTearDown(selection.dispose);
    addTearDown(hidden.dispose);
    await tester.pumpWidget(screen(selection, shell: hidden));
    await tester.longPress(find.text('Lease.pdf'));
    await tester.pump();
    expect(hidden.value, isTrue);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(hidden.value, isFalse);
  });

  testWidgets('screen readers: a Select action instead of the long press; '
      'the selected state while selecting', (tester) async {
    final handle = tester.ensureSemantics();
    final selection = DkSelection<String>();
    addTearDown(selection.dispose);
    await tester.pumpWidget(screen(selection));
    final node = tester.getSemantics(find.text('Invoice.pdf'));
    final select = node
        .getSemanticsData()
        .customSemanticsActionIds!
        .map(CustomSemanticsAction.getAction)
        .firstWhere((a) => a!.label == 'Select')!;
    tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
      node.id,
      SemanticsAction.customAction,
      CustomSemanticsAction.getIdentifier(select),
    );
    await tester.pump();
    expect(selection.selected, {'Invoice.pdf'});
    expect(
      tester.getSemantics(find.text('Invoice.pdf')),
      isSemantics(hasSelectedState: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('Lease.pdf')),
      isSemantics(hasSelectedState: true, isSelected: false),
    );
    handle.dispose();
  });
}
