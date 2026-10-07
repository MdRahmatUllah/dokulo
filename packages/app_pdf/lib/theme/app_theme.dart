import 'package:flutter/material.dart';

import 'dk_tokens.dart';

/// The MaterialApp theme for [tokens]: the tokens as its extension (widgets
/// read `context.tokens`) and the screen background. Mapping the tokens onto
/// Material's ColorScheme comes with theme switching (DK-0047).
ThemeData dokuloTheme(DkTokens tokens) => ThemeData(
  brightness: tokens.brightness,
  scaffoldBackgroundColor: tokens.color.background,
  extensions: [tokens],
);
