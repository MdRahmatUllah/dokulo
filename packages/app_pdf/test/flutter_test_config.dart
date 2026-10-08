import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file in app_pdf. Tests don't load package fonts on
/// their own: load the icon font (DK-0048), so component goldens show the
/// glyphs. Text stays in the test font (Ahem), which renders the same on
/// every machine.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final font = FontLoader('MaterialSymbolsRounded')
    ..addFont(rootBundle.load('assets/fonts/MaterialSymbolsRounded.ttf'));
  await font.load();
  await testMain();
}
