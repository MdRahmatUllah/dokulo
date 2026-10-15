import 'dart:io';
import 'dart:typed_data';

import 'package:app_pdf/screens/s1_scanner/scan_session.dart';
import 'package:app_pdf/screens/s1_scanner/scanner_camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('frame turns: Android takes the device turn off the sensor turn; '
      'iOS frames come upright', () {
    expect(frameTurns(90, DeviceOrientation.portraitUp, ios: false), 1);
    expect(frameTurns(90, DeviceOrientation.landscapeLeft, ios: false), 0);
    expect(frameTurns(90, DeviceOrientation.landscapeRight, ios: false), 2);
    expect(frameTurns(270, DeviceOrientation.portraitUp, ios: false), 3);
    expect(frameTurns(90, DeviceOrientation.portraitUp, ios: true), 0);
  });

  test('a quad from a landscape sensor turns upright, top-left first', () {
    // A page in the sensor frame's left half, as a phone held upright sees
    // it in the preview's top half.
    const sensor = [
      Offset(0.1, 0.2),
      Offset(0.5, 0.2),
      Offset(0.5, 0.8),
      Offset(0.1, 0.8),
    ];
    expect(uprightQuad(sensor, 0), sensor);
    final up = uprightQuad(sensor, 1);
    for (final (a, b) in [
      (up[0], const Offset(0.2, 0.1)),
      (up[1], const Offset(0.8, 0.1)),
      (up[2], const Offset(0.8, 0.5)),
      (up[3], const Offset(0.2, 0.5)),
    ]) {
      expect((a - b).distance, lessThan(1e-9));
    }
    final back = uprightQuad(up, 3);
    for (var i = 0; i < 4; i++) {
      expect((back[i] - sensor[i]).distance, lessThan(1e-9));
    }
  });

  late Directory dir;
  ProviderContainer session() {
    final c = ProviderContainer(
      overrides: [
        scanStoreProvider.overrideWithValue(FileScanStore(Future.value(dir))),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async => dir = await Directory.systemTemp.createTemp('dk_scan_'));
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Uint8List shot(int v) => Uint8List.fromList([v, v, v]);

  test(
    'every change is on disk; a new session restores it (after a kill)',
    () async {
      final a = session();
      final s = a.read(scanSessionProvider.notifier);
      await s.add(
        shot(1),
        quad: const [
          Offset(0.1, 0.1),
          Offset(0.9, 0.1),
          Offset(0.9, 0.9),
          Offset(0.1, 0.9),
        ],
      );
      await s.add(shot(2));
      await s.add(shot(3));
      await s.rotate(0);
      await s.move(2, 0);
      final before = a.read(scanSessionProvider);
      expect(
        [for (final p in before) File(p.path).readAsBytesSync().first],
        [3, 1, 2],
      );

      final b = session();
      await b.read(scanSessionProvider.notifier).restore();
      final after = b.read(scanSessionProvider);
      expect([for (final p in after) p.id], [for (final p in before) p.id]);
      expect(after[1].turns, 1);
      expect(after[1].quad, before[1].quad);
    },
  );

  test(
    'remove and insert (Undo); replace (Retake) drops the old photo',
    () async {
      final c = session();
      final s = c.read(scanSessionProvider.notifier);
      await s.add(shot(1));
      await s.add(shot(2));
      final gone = await s.remove(0);
      expect(c.read(scanSessionProvider), hasLength(1));
      await s.insert(0, gone);
      expect(c.read(scanSessionProvider).first.id, gone.id);
      final oldPath = c.read(scanSessionProvider)[1].path;
      await s.replace(1, shot(9));
      expect(
        File(c.read(scanSessionProvider)[1].path).readAsBytesSync().first,
        9,
      );
      expect(File(oldPath).existsSync(), isFalse);
    },
  );

  test(
    'clear removes the photos and the manifest; restore finds nothing',
    () async {
      final c = session();
      final s = c.read(scanSessionProvider.notifier);
      await s.add(shot(1));
      await s.clear();
      expect(c.read(scanSessionProvider), isEmpty);
      final d = session();
      await d.read(scanSessionProvider.notifier).restore();
      expect(d.read(scanSessionProvider), isEmpty);
    },
  );

  test(
    'a cut-off manifest or a missing photo does not break restore',
    () async {
      final c = session();
      final s = c.read(scanSessionProvider.notifier);
      await s.add(shot(1));
      await s.add(shot(2));
      File(c.read(scanSessionProvider).first.path).deleteSync();
      final d = session();
      await d.read(scanSessionProvider.notifier).restore();
      expect(
        d.read(scanSessionProvider),
        hasLength(1),
        reason: 'the page whose photo went is dropped',
      );
      File('${dir.path}/session.json').writeAsStringSync('[{"id": "x", "pa');
      final e = session();
      await e.read(scanSessionProvider.notifier).restore();
      expect(e.read(scanSessionProvider), isEmpty);
    },
  );
}
