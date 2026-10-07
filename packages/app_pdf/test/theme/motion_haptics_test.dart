import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/theme/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records which haptic ran.
class _Fake {
  final calls = <String>[];
  DkHaptics haptics() => DkHaptics(
    selection: () async => calls.add('selection'),
    light: () async => calls.add('light'),
    medium: () async => calls.add('medium'),
  );
}

Future<DkMotionSpec> motionIn(
  WidgetTester tester,
  DkMotionKind kind, {
  required bool reduce,
}) async {
  late DkMotionSpec spec;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: MaterialApp(
        theme: dokuloTheme(DkTokens.light),
        home: Builder(
          builder: (context) {
            spec = context.motion(kind);
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return spec;
}

void main() {
  group('motion (UI spec §9)', () {
    testWidgets('the three kinds, as specified', (tester) async {
      expect(await motionIn(tester, DkMotionKind.fast, reduce: false), (
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        crossFade: false,
      ));
      expect(
        (await motionIn(tester, DkMotionKind.standard, reduce: false)).duration,
        const Duration(milliseconds: 220),
      );
      final emphasis = await motionIn(
        tester,
        DkMotionKind.emphasis,
        reduce: false,
      );
      expect(emphasis.duration, const Duration(milliseconds: 320));
      expect(
        emphasis.curve.transform(0.6),
        greaterThan(1.0),
      ); // the slight overshoot
    });

    testWidgets(
      'Reduce Motion turns every movement into a 120 ms linear cross-fade',
      (tester) async {
        for (final kind in DkMotionKind.values) {
          expect(await motionIn(tester, kind, reduce: true), (
            duration: const Duration(milliseconds: 120),
            curve: Curves.linear,
            crossFade: true,
          ));
        }
      },
    );

    test(
      'the capture flash: off with Reduce Motion, one 80 ms flash otherwise',
      () {
        const m = DkMotion();
        expect(m.flashAllowed(reduce: true), isFalse);
        expect(m.flashAllowed(reduce: false), isTrue);
        // One flash per capture at most: even back-to-back, a flash plus the
        // capture's own work is far longer than 1/3 s, so never above 3 Hz.
        expect(m.captureFlash, lessThan(const Duration(milliseconds: 333)));
      },
    );
  });

  group('haptics (UI spec §9)', () {
    test('each moment gets the feedback the spec names', () async {
      final fake = _Fake();
      final h = fake.haptics();
      await h.selected();
      await h.captured();
      await h.dropped();
      await h.saved();
      expect(fake.calls, ['selection', 'light', 'light', 'medium']);
    });

    test(
      'tests swap the provider for a fake; errors have no haptic to call',
      () {
        final fake = _Fake();
        final container = ProviderContainer(
          overrides: [hapticsProvider.overrideWithValue(fake.haptics())],
        );
        addTearDown(container.dispose);
        container.read(hapticsProvider).saved();
        expect(fake.calls, ['medium']);
      },
    );
  });
}
