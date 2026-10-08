// Visual QA of the illustrations (DK-0985, DK-0988..1007): renders every
// DkIllustration at its design frame's size (2×: 400 × 320 or 240 × 240) on
// a transparent background, in Light and Dark, for
// tools/qa_illustrations.py to compare with the design export. It only runs
// with DK_QA_OUT set: `DK_QA_OUT=<dir> flutter test test/qa`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_pdf/components/dk_illustration.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final out = Platform.environment['DK_QA_OUT'];
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final ill in DkIllustrations.values) {
      testWidgets('${ill.file} $name', (tester) async {
        final size = Size(ill.width * 2, ill.height * 2);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dokuloTheme(tokens)
                .copyWith(scaffoldBackgroundColor: Colors.transparent),
            color: Colors.transparent,
            home: RepaintBoundary(
              key: key,
              child: SizedBox.fromSize(
                size: size,
                child: DkIllustration(ill, scale: 2),
              ),
            ),
          ),
        );
        // SVGs decode off the fake clock.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$out/app/${ill.file}-$name.png')
            ..createSync(recursive: true);
          file.writeAsBytesSync(png!.buffer.asUint8List());
        });
      }, skip: out == null);
    }
  }
}
