import 'package:flutter/material.dart';

import '../components/motion/dk_transition_motion.dart';
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
    // Pushed pages (UI spec §13.4; DK-0237).
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: DkPageTransitionsBuilder(),
        TargetPlatform.iOS: DkPageTransitionsBuilder(),
      },
    ),
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
    // Stock Material buttons (a SnackBar's action, dialog buttons) take
    // `labelL`, like DkButton.
    textTheme: TextTheme(labelLarge: tokens.text.labelL),
    // Stock text buttons (a toast's action) show the 2 dp focus ring when
    // the keyboard focuses them, like every Dk control.
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        side: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.focused)
              ? BorderSide(color: c.focusRing, width: 2)
              : null,
        ),
      ),
    ),
    // DkToast (DK-0190): a floating SnackBar in the inverse colours.
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.inverseSurface,
      contentTextStyle: tokens.text.bodyM.copyWith(color: c.onInverseSurface),
      actionTextColor: c.inversePrimary,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: tokens.space.l,
        vertical: tokens.space.s,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius.m),
      ),
    ),
    extensions: [tokens],
  );
}
