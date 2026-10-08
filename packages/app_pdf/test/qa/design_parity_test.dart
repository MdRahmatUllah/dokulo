// Visual QA of the foundations and motion (DK-0982, DK-0986): DkTokens
// against the design export's own CSS (dokulo-design/light/00-design-system/
// foundations.html, motion.html), so the two can't drift apart unnoticed:
// colours in Light and Dark, the type scale, durations and curves. A
// deliberate change is listed in [approved] with its reason.
import 'dart:io';
import 'dart:math' as math;

import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

String _page(String name) =>
    File('../../dokulo-design/light/00-design-system/$name').readAsStringSync();

final _css = _page('foundations.html');

/// The export's colour variable → the token.
final _colours = <String, Color Function(DkColors)>{
  'p': (c) => c.primary,
  'op': (c) => c.onPrimary,
  'pp': (c) => c.primaryPressed,
  'pc': (c) => c.primaryContainer,
  'opc': (c) => c.onPrimaryContainer,
  'bg': (c) => c.background,
  'sf': (c) => c.surface,
  'sfr': (c) => c.surfaceRaised,
  'sk': (c) => c.surfaceSunken,
  'ol': (c) => c.outline,
  'ols': (c) => c.outlineStrong,
  't1': (c) => c.textPrimary,
  't2': (c) => c.textSecondary,
  't3': (c) => c.textDisabled,
  'ic': (c) => c.iconPrimary,
  'ic2': (c) => c.iconSecondary,
  'pro': (c) => c.pro,
  'proc': (c) => c.proContainer,
  'ok': (c) => c.success,
  'okc': (c) => c.successContainer,
  'wr': (c) => c.warning,
  'wrc': (c) => c.warningContainer,
  'dg': (c) => c.danger,
  'dgc': (c) => c.dangerContainer,
  'inva': (c) => c.inversePrimary,
  'invb': (c) => c.inverseSurface,
  'invf': (c) => c.onInverseSurface,
};

/// Where the app deliberately differs from the export: `theme.var` → why.
const approved = {
  'light.ok': 'WCAG: #117A4B reaches 4.5:1 on its container (PR #1116)',
  'light.ols': 'WCAG 1.4.11: input boundaries need 3:1 (PR #1116)',
  'dark.ols': 'WCAG 1.4.11: input boundaries need 3:1 (PR #1116)',
  // Overview & foundations names Flutter's curves. Docs win. The export's
  // CSS has other cubic-beziers: --e-out (0, 0, .2, 1) decelerates harder
  // than CSS's own ease-out (0, 0, .58, 1), up to 0.20 in value; --e-std is
  // within 0.025.
  'motion.e-out': 'Curves.easeOut (0, 0, .58, 1), as the docs name it',
  'motion.e-std': 'Curves.easeInOutCubic (.645, .045, .355, 1), as the docs',
};

Map<String, int> _block(String selector) {
  final start = _css.indexOf('$selector{');
  expect(start, isNot(-1), reason: 'no "$selector" block in the export');
  final body = _css.substring(start, _css.indexOf('}', start));
  return {
    for (final m in RegExp(r'--([a-z0-9]+):#([0-9A-Fa-f]{6})').allMatches(body))
      m[1]!: 0xFF000000 | int.parse(m[2]!, radix: 16),
  };
}

void main() {
  for (final (theme, selector, colours) in [
    ('light', '.ph,.dkb', DkColors.light),
    ('dark', '.ph.dark,.dkb.dark,.tab-root.dark', DkColors.dark),
  ]) {
    test('colours match the export: $theme', () {
      final export = _block(selector);
      final off = <String>[];
      for (final MapEntry(key: name, value: token) in _colours.entries) {
        final want = export[name];
        expect(want, isNotNull, reason: '--$name missing in the export');
        final have = token(colours).toARGB32();
        final approvedChange = approved.containsKey('$theme.$name');
        if ((have == want) == approvedChange) {
          off.add(
            '--$name: export #${want!.toRadixString(16)}, '
            'app #${have.toRadixString(16)}'
            '${approvedChange ? ' (listed as approved but equal)' : ''}',
          );
        }
      }
      expect(off, isEmpty);
    });
  }

  test('type scale matches the export', () {
    final type = DkType.of(const Color(0xFF000000));
    final styles = {
      't-d': type.display,
      't-l': type.titleL,
      't-m': type.titleM,
      't-s': type.titleS,
      'b-l': type.bodyL,
      'b-m': type.bodyM,
      'l-l': type.labelL,
      'l-m': type.labelM,
      'cap': type.caption,
    };
    for (final MapEntry(key: cls, value: style) in styles.entries) {
      final m = RegExp(
        '\\.$cls\\{font:(\\d+) (\\d+)px/(\\d+)px[^;}]*(?:;letter-spacing:(-?[\\d.]+)px)?',
      ).firstMatch(_css);
      expect(m, isNotNull, reason: '.$cls missing in the export');
      expect(style.fontWeight!.value, int.parse(m![1]!), reason: cls);
      expect(style.fontSize, double.parse(m[2]!), reason: cls);
      expect(
        style.fontSize! * style.height!,
        closeTo(double.parse(m[3]!), 1e-9),
        reason: cls,
      );
      expect(style.letterSpacing, double.parse(m[4] ?? '0'), reason: cls);
    }
  });

  test('motion matches the export', () {
    final css = _page('motion.html');
    const m = DkMotion();
    // The legend: "120 ms · ease-out · press states …".
    for (final (ms, what, have) in [
      (120, 'ease-out ·', m.fast),
      (220, 'ease-in-out cubic', m.standard),
      (320, 'ease-out, slight overshoot', m.emphasis),
      (120, '', m.reduced),
    ]) {
      expect(
        css,
        contains(
          what.isEmpty ? '$ms ms cross-fade · linear' : '$ms ms · $what',
        ),
      );
      expect(have, Duration(milliseconds: ms), reason: what);
    }
    expect(m.reducedCurve, Curves.linear);
    expect(css, contains('80 ms → page shrinks'));
    expect(m.captureFlash, const Duration(milliseconds: 80));
    // The curves: --e-emph is the app's exactly; the other two are approved.
    Cubic bezier(String name) {
      final v = RegExp(
        '--$name:cubic-bezier'
        r'\(([^)]*)\)',
      ).firstMatch(css)![1]!.split(',').map(double.parse).toList();
      return Cubic(v[0], v[1], v[2], v[3]);
    }

    // The largest difference in value over the curve.
    double gap(Curve a, Cubic b) => [
      for (var x = 0.0; x <= 1; x += 0.05)
        (a.transform(x) - b.transform(x)).abs(),
    ].reduce(math.max);

    expect(gap(m.emphasisCurve, bezier('e-emph')), lessThan(1e-6));
    // The approvals cover the named curves and nothing further.
    expect(approved, contains('motion.e-out'));
    expect(gap(m.fastCurve, bezier('e-out')), inInclusiveRange(1e-6, 0.21));
    expect(approved, contains('motion.e-std'));
    expect(gap(m.standardCurve, bezier('e-std')), inInclusiveRange(1e-6, 0.03));
  });
}
