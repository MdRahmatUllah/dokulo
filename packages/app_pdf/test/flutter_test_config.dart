import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file in app_pdf. Tests don't load package fonts on
/// their own: load the icon font (DK-0048), so component goldens show the
/// glyphs, and the signature fonts. Other text stays in the test font
/// (Ahem), which renders the same on every machine.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final font = FontLoader('MaterialSymbolsRounded')
    ..addFont(rootBundle.load('assets/fonts/MaterialSymbolsRounded.ttf'));
  await font.load();
  // The signature pad's handwriting styles (DK-0206), so its goldens show
  // them; they render the same everywhere, like Ahem.
  for (final family in ['Caveat', 'DancingScript', 'HomemadeApple']) {
    await (FontLoader(
      family,
    )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
  }
  await testMain();
}
