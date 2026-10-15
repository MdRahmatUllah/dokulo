import 'dart:typed_data';

import 'package:app_pdf/screens/s1_scanner/scan_hints.dart';
import 'package:flutter_test/flutter_test.dart';

const page = [
  Offset(0.2, 0.2),
  Offset(0.8, 0.2),
  Offset(0.8, 0.8),
  Offset(0.2, 0.8),
];
const small = [
  Offset(0.4, 0.4),
  Offset(0.6, 0.4),
  Offset(0.6, 0.6),
  Offset(0.4, 0.6),
];
const cut = [
  Offset(0.0, 0.2),
  Offset(0.8, 0.2),
  Offset(0.8, 0.8),
  Offset(0.0, 0.8),
];

void main() {
  test('each condition, in priority order', () {
    ScanHint h(
      List<Offset>? q, {
      double b = 0.6,
      bool steady = true,
      bool capturing = false,
    }) =>
        scanHint(quad: q, brightness: b, steady: steady, capturing: capturing);
    expect(h(null, b: 0.05, steady: false), ScanHint.pointAt);
    expect(h(small, steady: false), ScanHint.moveCloser);
    expect(h(page, steady: false, b: 0.05), ScanHint.holdSteady);
    expect(h(page, b: 0.05), ScanHint.moreLight);
    expect(h(cut), ScanHint.fitPage);
    expect(h(page), ScanHint.ready);
    expect(h(page, capturing: true), ScanHint.capturing);
  });

  test('area, brightness and steadiness', () {
    expect(quadArea(page), closeTo(0.36, 1e-9));
    expect(brightnessOf(Uint8List.fromList(List.filled(640, 255))), 1);
    expect(brightnessOf(Uint8List(0)), 0);
    expect(quadSteady(page, page), isTrue);
    expect(
      quadSteady(page, [for (final p in page) p + const Offset(0.05, 0)]),
      isFalse,
    );
    expect(quadSteady(null, page), isFalse);
  });

  test('announcements: on change only, at most every 2 s', () {
    final said = <String>[];
    final a = HintAnnouncer(said.add);
    Duration s(int v) => Duration(seconds: v);
    a.update(ScanHint.pointAt, 'point', s(0));
    a.update(ScanHint.pointAt, 'point', s(5));
    a.update(ScanHint.ready, 'ready', s(6));
    a.update(ScanHint.holdSteady, 'steady', s(7)); // too soon
    a.update(ScanHint.holdSteady, 'steady', s(9));
    expect(said, ['point', 'ready', 'steady']);
  });
}
