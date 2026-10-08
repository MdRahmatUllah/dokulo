import 'package:app_pdf/catalogue/overlay_states.dart';
import 'package:app_pdf/components/dk_toast.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget child, {
  DkTokens? tokens,
  double textScale = 1,
  bool screenReader = false,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      accessibleNavigation: screenReader,
      textScaler: TextScaler.linear(textScale),
    ),
    child: child!,
  ),
  home: child,
);

/// A screen with a tab bar and a mini job bar under the content, as the
/// shell will have them, and a button that shows a toast.
Widget screen({String? action, Duration? duration}) => Scaffold(
  body: Builder(
    builder: (context) => Center(
      child: TextButton(
        onPressed: () => showDkToast(
          context,
          'Moved to Recently deleted',
          action: action,
          onAction: action == null ? null : () {},
          duration: duration ?? DkToastDuration.regular,
        ),
        child: const Text('show'),
      ),
    ),
  ),
  bottomNavigationBar: const Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(key: Key('mini'), height: 48), // DkMiniJobBar
      SizedBox(height: 64), // DkTabBar
    ],
  ),
);

void phone(WidgetTester tester, [Size size = const Size(393, 852)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('a toast with an action, $name, ${(scale * 100).round()} %', (
        tester,
      ) async {
        phone(tester, const Size(393, 340));
        await tester.pumpWidget(
          app(
            const Scaffold(body: ToastStates()),
            tokens: tokens,
            textScale: scale,
          ),
        );
        await tester.tap(find.text('With an action'));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(ToastStates),
          matchesGoldenFile(
            'goldens/toast_${name}_${(scale * 100).round()}.png',
          ),
        );
      });
    }
  }

  testWidgets('48 tall, inverse colours, the action in inversePrimary; above '
      'the mini job bar', (tester) async {
    phone(tester);
    await tester.pumpWidget(app(screen(action: 'Undo')));
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
    final toast = find.byType(SnackBar);
    final material = tester.widget<Material>(
      find.descendant(of: toast, matching: find.byType(Material)).first,
    );
    expect(material.color, DkTokens.light.color.inverseSurface);
    // The bar's own 48, less nothing: one line of bodyM plus 2 × 14.
    final surface = tester.getRect(
      find.descendant(of: toast, matching: find.byType(Material)).first,
    );
    expect(surface.height, 48);
    expect(
      surface.bottom,
      lessThanOrEqualTo(tester.getRect(find.byKey(const Key('mini'))).top),
    );
    final action = tester.widget<Text>(find.text('Undo'));
    final style = DefaultTextStyle.of(tester.element(find.text('Undo'))).style
        .merge(action.style);
    expect(style.color, DkTokens.light.color.inversePrimary);
  });

  testWidgets('it goes after 4 s; toasts queue', (tester) async {
    phone(tester);
    await tester.pumpWidget(app(screen()));
    await tester.tap(find.text('show'));
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget, reason: 'one at a time');
    await tester.pump(DkToastDuration.regular);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget, reason: 'the second now');
    await tester.pump(DkToastDuration.regular);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('with a screen reader, a toast with an action stays', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(app(screen(action: 'Undo'), screenReader: true));
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('wider than 592: 560 wide, centred', (tester) async {
    phone(tester, const Size(1024, 768));
    await tester.pumpWidget(app(screen()));
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
    final rect = tester.getRect(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(rect.width, 560);
    expect(rect.center.dx, closeTo(512, 1));
  });
}
