import 'package:flutter/material.dart';

import 'dk_tokens.dart';

/// The MaterialApp theme for [tokens] (DK-0047): the tokens as its extension
/// (widgets read `context.tokens`), and Material's ColorScheme mapped from
/// them, so a stock Material widget (a dialog, a date picker, the text
/// selection handles) draws in Dokulo's colours in both themes.
ThemeData dokuloTheme(DkTokens tokens) {
  final c = tokens.color;
  return ThemeData(
    brightness: tokens.brightness,
    scaffoldBackgroundColor: c.background,
    colorScheme: ColorScheme(
      brightness: tokens.brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.primary,
      onSecondary: c.onPrimary,
      tertiary: c.pro,
      onTertiary: c.surface,
      tertiaryContainer: c.proContainer,
      onTertiaryContainer: c.pro,
      error: c.danger,
      onError: c.onDanger,
      errorContainer: c.dangerContainer,
      onErrorContainer: c.danger,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.surfaceSunken,
      surfaceContainerLow: c.background,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfaceRaised,
      outline: c.outlineStrong,
      outlineVariant: c.outline,
      scrim: c.scrim,
      shadow: Colors.black,
      inverseSurface: c.inverseSurface,
      onInverseSurface: c.onInverseSurface,
      inversePrimary: c.inversePrimary,
      surfaceTint:
          Colors.transparent, // Dark lifts with surfaceRaised, not tint
    ),
    extensions: [tokens],
  );
}
