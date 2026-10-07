import 'package:app_pdf/components/motion/dk_transition_motion.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const ms = Duration(milliseconds: 1);

/// The platform's Reduce Motion, above the navigator as on a device.
Widget reduceMotion(BuildContext context, Widget? app, bool reduce) =>
    MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
      child: app!,
    );

void main() {
  group('Sheet (DK-0044)', () {
    const sheetKey = ValueKey('sheet');

    Future<void> open(WidgetTester tester, {bool reduce = false}) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: dokuloTheme(DkTokens.light),
          builder: (context, app) => reduceMotion(context, app, reduce),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDkSheet<void>(
                  context,
                  builder: (_) =>
                      const SizedBox(key: sheetKey, width: 400, height: 300),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
    }

    double top(WidgetTester tester) => tester.getRect(find.byKey(sheetKey)).top;
    Color scrim(WidgetTester tester) =>
        tester.widget<ModalBarrier>(find.byType(ModalBarrier).last).color!;

    testWidgets('slides up in 220 ms; the scrim is in at 120 ms', (
      tester,
    ) async {
      await open(tester);
      expect(top(tester), 800, reason: 'starts below the screen');
      await tester.pump(ms * 120);
      expect(top(tester), inExclusiveRange(500, 800));
      expect(scrim(tester), DkTokens.light.color.scrim);
      await tester.pump(ms * 100); // 220 ms
      expect(top(tester), 500);

      // A tap on the scrim closes it.
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();
      expect(find.byKey(sheetKey), findsNothing);
    });

    testWidgets('Reduce Motion: it fades in where it ends, 120 ms', (
      tester,
    ) async {
      await open(tester, reduce: true);
      await tester.pump(ms * 60);
      expect(top(tester), 500);
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byKey(sheetKey),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, closeTo(0.5, 0.1));
      await tester.pump(ms * 60);
      expect(fade.opacity.value, 1);
    });

    testWidgets('detent changes take 220 ms; a jump with Reduce Motion', (
      tester,
    ) async {
      for (final reduce in [false, true]) {
        final sheet = DraggableScrollableController();
        await tester.pumpWidget(
          MaterialApp(
            theme: dokuloTheme(DkTokens.light),
            builder: (context, app) => reduceMotion(context, app, reduce),
            home: Scaffold(
              body: DraggableScrollableSheet(
                controller: sheet,
                initialChildSize: 0.5,
                minChildSize: 0.25,
                builder: (_, scroll) =>
                    ListView(controller: scroll, children: const []),
              ),
            ),
          ),
        );
        animateDkSheetTo(
          tester.element(find.byType(ListView)),
          sheet,
          0.9,
        ).ignore();
        await tester.pump();
        if (reduce) {
          expect(sheet.size, 0.9);
        } else {
          await tester.pump(ms * 110);
          expect(sheet.size, inExclusiveRange(0.5, 0.9));
          await tester.pump(ms * 110);
          expect(sheet.size, closeTo(0.9, 0.001));
        }
        await tester.pumpWidget(const SizedBox());
        sheet.dispose();
      }
    });
  });

  group('Mini job bar (DK-0045)', () {
    Widget job(bool collapsed, {bool reduce = false}) => MaterialApp(
      theme: dokuloTheme(DkTokens.light),
      builder: (context, app) => reduceMotion(context, app, reduce),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: DkJobMorph(
            collapsed: collapsed,
            sheet: const SizedBox(key: ValueKey('sheet'), height: 280),
            bar: const SizedBox(key: ValueKey('bar'), height: 56),
          ),
        ),
      ),
    );
    double height(WidgetTester tester) =>
        tester.getSize(find.byType(DkJobMorph)).height;

    testWidgets('the sheet shrinks into the bar in 220 ms', (tester) async {
      await tester.pumpWidget(job(false));
      expect(height(tester), 280);
      await tester.pumpWidget(job(true));
      await tester.pump(ms * 110);
      expect(height(tester), inExclusiveRange(56, 280));
      await tester.pump(ms * 110);
      expect(height(tester), 56);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sheet')), findsNothing);
    });

    testWidgets('Reduce Motion: the bar takes its size at once and fades in', (
      tester,
    ) async {
      await tester.pumpWidget(job(false, reduce: true));
      await tester.pumpWidget(job(true, reduce: true));
      await tester.pump();
      expect(height(tester), 56);
      await tester.pump(ms * 60);
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('bar')),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, closeTo(0.5, 0.1));
      await tester.pumpAndSettle();
    });
  });

  group('Viewer open (DK-0046)', () {
    const thumb = Rect.fromLTWH(16, 100, 60, 80);
    const page = ValueKey('page');

    Future<GoRouter> app(WidgetTester tester, {bool reduce = false}) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Stack(
                children: [
                  Positioned.fromRect(
                    rect: thumb,
                    child: const DkHero(
                      tag: 'file-1',
                      child: ColoredBox(color: Color(0xFFFFFFFF)),
                    ),
                  ),
                ],
              ),
            ),
            routes: [
              GoRoute(
                path: 'viewer',
                pageBuilder: (context, s) => dkViewerPage(
                  context,
                  key: s.pageKey,
                  child: const Scaffold(
                    body: Center(
                      child: DkHero(
                        tag: 'file-1',
                        child: ColoredBox(
                          key: page,
                          color: Color(0xFFFFFFFF),
                          child: SizedBox(width: 360, height: 480),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: dokuloTheme(DkTokens.light),
          builder: (context, app) => reduceMotion(context, app, reduce),
          routerConfig: router,
        ),
      );
      return router;
    }

    testWidgets('the thumbnail expands into the first page in 220 ms', (
      tester,
    ) async {
      final router = await app(tester);
      router.push('/viewer');
      await tester.pump();
      await tester.pump();
      await tester.pump(ms * 110);
      final mid = tester.getRect(find.byKey(page));
      expect(mid.width, inExclusiveRange(60, 360));
      expect(mid.top, inExclusiveRange(100, 160));
      await tester.pump(ms * 110);
      await tester.pump();
      expect(
        tester.getRect(find.byKey(page)),
        const Rect.fromLTWH(20, 160, 360, 480),
      );
    });

    testWidgets('Reduce Motion: no flight; the viewer fades in, 120 ms', (
      tester,
    ) async {
      final router = await app(tester, reduce: true);
      router.push('/viewer');
      await tester.pump();
      await tester.pump();
      await tester.pump(ms * 60);
      expect(
        tester.getRect(find.byKey(page)),
        const Rect.fromLTWH(20, 160, 360, 480),
        reason: 'the page is in its place from the start',
      );
      await tester.pump(ms * 70);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
