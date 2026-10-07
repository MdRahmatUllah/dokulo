import 'package:flutter/material.dart';

/// Dokulo's design tokens (DK-0024; UI spec §4–§9, `Overview & foundations.md`
/// → Design tokens), one instance per theme, after Sogda's `SgTokens`.
/// Widgets read tokens, never raw values:
///
/// ```dart
/// final t = context.tokens;
/// Container(
///   padding: EdgeInsets.all(t.space.l),          // never EdgeInsets.all(16)
///   color: t.color.surface,                      // never Color(0xFFFFFFFF)
///   child: Text(label, style: t.text.labelL),
/// );
/// ```
///
/// The names follow the spec (`color.primary`, `space.m`, `radius.m`,
/// `elevation.raised`, `motion.standard`); the spec's `type.*` styles are
/// `t.text.*`.
@immutable
class DkTokens extends ThemeExtension<DkTokens> {
  const DkTokens({
    required this.brightness,
    required this.color,
    required this.text,
    required this.space,
    required this.radius,
    required this.elevation,
    required this.motion,
  });

  static final light = DkTokens(
    brightness: Brightness.light,
    color: DkColors.light,
    text: DkType.of(DkColors.light.textPrimary),
    space: const DkSpace(),
    radius: const DkRadius(),
    elevation: DkElevation.light,
    motion: const DkMotion(),
  );

  static final dark = DkTokens(
    brightness: Brightness.dark,
    color: DkColors.dark,
    text: DkType.of(DkColors.dark.textPrimary),
    space: const DkSpace(),
    radius: const DkRadius(),
    elevation: DkElevation.dark,
    motion: const DkMotion(),
  );

  final Brightness brightness;
  final DkColors color;

  /// Text styles. (Not `type`: ThemeExtension.type is the key Theme looks it up by.)
  final DkType text;
  final DkSpace space;
  final DkRadius radius;
  final DkElevation elevation;
  final DkMotion motion;

  @override
  DkTokens copyWith({
    Brightness? brightness,
    DkColors? color,
    DkType? text,
    DkSpace? space,
    DkRadius? radius,
    DkElevation? elevation,
    DkMotion? motion,
  }) => DkTokens(
    brightness: brightness ?? this.brightness,
    color: color ?? this.color,
    text: text ?? this.text,
    space: space ?? this.space,
    radius: radius ?? this.radius,
    elevation: elevation ?? this.elevation,
    motion: motion ?? this.motion,
  );

  /// Colours, text styles and shadows blend, so a theme change animates;
  /// the sizes are the same in both themes.
  @override
  DkTokens lerp(covariant DkTokens? other, double t) {
    if (other == null) return this;
    return DkTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      color: color.lerp(other.color, t),
      text: text.lerp(other.text, t),
      space: space,
      radius: radius,
      elevation: elevation.lerp(other.elevation, t),
      motion: motion,
    );
  }
}

/// `context.tokens`: the current theme's tokens.
extension DkTokensContext on BuildContext {
  DkTokens get tokens => Theme.of(this).extension<DkTokens>()!;
}

/// Colours (UI spec §4.1). This batch carries the primary family, surfaces
/// and background, outlines, and text and icons (DK-0025–DK-0028); the status,
/// camera, document, markup and compare families follow (DK-0029–DK-0034).
@immutable
class DkColors {
  const DkColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryPressed,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.focusRing,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.outline,
    required this.outlineStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.iconPrimary,
    required this.iconSecondary,
  });

  // ponytail: the raw values live here and only here; tools/check_tokens.py
  // keeps them out of screens and components.
  static const light = DkColors(
    primary: Color(0xFF2251E6),
    onPrimary: Color(0xFFFFFFFF),
    primaryPressed: Color(0xFF1A41BD),
    primaryContainer: Color(0xFFE6ECFF),
    onPrimaryContainer: Color(0xFF0F2A8A),
    focusRing: Color(0xFF2251E6),
    background: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEEF1F5),
    outline: Color(0xFFD9DEE6),
    outlineStrong: Color(0xFFB8C0CC),
    textPrimary: Color(0xFF14171C),
    textSecondary: Color(0xFF5A6270),
    textDisabled: Color(0xFF9AA1AD),
    iconPrimary: Color(0xFF2E3440),
    iconSecondary: Color(0xFF6B7380),
  );

  static const dark = DkColors(
    primary: Color(0xFF8AA8FF),
    onPrimary: Color(0xFF0B1640),
    primaryPressed: Color(0xFFA4BBFF),
    primaryContainer: Color(0xFF1C2A5C),
    onPrimaryContainer: Color(0xFFDCE4FF),
    focusRing: Color(0xFF8AA8FF),
    background: Color(0xFF0F1115),
    surface: Color(0xFF181B21),
    surfaceRaised: Color(0xFF1F232A),
    surfaceSunken: Color(0xFF12151A),
    outline: Color(0xFF2C313A),
    outlineStrong: Color(0xFF444B57),
    textPrimary: Color(0xFFEEF1F6),
    textSecondary: Color(0xFFA6AEBB),
    textDisabled: Color(0xFF5F6672),
    iconPrimary: Color(0xFFDDE2EA),
    iconSecondary: Color(0xFF9099A6),
  );

  // Primary family (DK-0025).
  final Color primary,
      onPrimary,
      primaryPressed,
      primaryContainer,
      onPrimaryContainer,
      focusRing;
  // Surfaces and background (DK-0026).
  final Color background, surface, surfaceRaised, surfaceSunken;
  // Outlines (DK-0027).
  final Color outline, outlineStrong;
  // Text and icons (DK-0028).
  final Color textPrimary,
      textSecondary,
      textDisabled,
      iconPrimary,
      iconSecondary;

  DkColors lerp(DkColors o, double t) {
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return DkColors(
      primary: c(primary, o.primary),
      onPrimary: c(onPrimary, o.onPrimary),
      primaryPressed: c(primaryPressed, o.primaryPressed),
      primaryContainer: c(primaryContainer, o.primaryContainer),
      onPrimaryContainer: c(onPrimaryContainer, o.onPrimaryContainer),
      focusRing: c(focusRing, o.focusRing),
      background: c(background, o.background),
      surface: c(surface, o.surface),
      surfaceRaised: c(surfaceRaised, o.surfaceRaised),
      surfaceSunken: c(surfaceSunken, o.surfaceSunken),
      outline: c(outline, o.outline),
      outlineStrong: c(outlineStrong, o.outlineStrong),
      textPrimary: c(textPrimary, o.textPrimary),
      textSecondary: c(textSecondary, o.textSecondary),
      textDisabled: c(textDisabled, o.textDisabled),
      iconPrimary: c(iconPrimary, o.iconPrimary),
      iconSecondary: c(iconSecondary, o.iconSecondary),
    );
  }
}

/// Text styles (UI spec §5): system fonts (SF Pro / Roboto), the spec's size,
/// line height, weight and letter spacing, in [DkColors.textPrimary].
/// DK-0036 adds tabular figures and the platform mono font; DK-0037 the text
/// rules.
@immutable
class DkType {
  const DkType({
    required this.display,
    required this.titleL,
    required this.titleM,
    required this.titleS,
    required this.bodyL,
    required this.bodyM,
    required this.labelL,
    required this.labelM,
    required this.caption,
    required this.mono,
    required this.numberXL,
  });

  factory DkType.of(Color ink) {
    TextStyle s(double size, double line, FontWeight weight, double spacing) =>
        TextStyle(
          fontSize: size,
          height: line / size,
          fontWeight: weight,
          letterSpacing: spacing,
          color: ink,
        );
    return DkType(
      display: s(28, 34, FontWeight.w700, -0.3),
      titleL: s(22, 28, FontWeight.w700, -0.2),
      titleM: s(18, 24, FontWeight.w600, -0.1),
      titleS: s(16, 22, FontWeight.w600, 0),
      bodyL: s(16, 24, FontWeight.w400, 0),
      bodyM: s(14, 20, FontWeight.w400, 0),
      labelL: s(15, 20, FontWeight.w600, 0),
      labelM: s(13, 18, FontWeight.w600, 0.1),
      caption: s(12, 16, FontWeight.w400, 0.1),
      mono: s(13, 18, FontWeight.w400, 0).copyWith(fontFamily: 'monospace'),
      numberXL: s(32, 38, FontWeight.w700, -0.3),
    );
  }

  final TextStyle display,
      titleL,
      titleM,
      titleS,
      bodyL,
      bodyM,
      labelL,
      labelM,
      caption,
      mono,
      numberXL;

  DkType lerp(DkType o, double t) {
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return DkType(
      display: l(display, o.display),
      titleL: l(titleL, o.titleL),
      titleM: l(titleM, o.titleM),
      titleS: l(titleS, o.titleS),
      bodyL: l(bodyL, o.bodyL),
      bodyM: l(bodyM, o.bodyM),
      labelL: l(labelL, o.labelL),
      labelM: l(labelM, o.labelM),
      caption: l(caption, o.caption),
      mono: l(mono, o.mono),
      numberXL: l(numberXL, o.numberXL),
    );
  }
}

/// Spacing in dp, 4 dp base (UI spec §6.1).
@immutable
class DkSpace {
  const DkSpace();
  final double xxs = 2,
      xs = 4,
      s = 8,
      m = 12,
      l = 16,
      xl = 24,
      xxl = 32,
      xxxl = 48;
}

/// Corner radii in dp (UI spec §6.3).
@immutable
class DkRadius {
  const DkRadius();
  final double xs = 4, s = 8, m = 12, l = 16, sheet = 24, pill = 999;
}

/// Elevation as shadows (UI spec §6.4); in dark mode surfaces lift by colour
/// ([DkColors.surfaceRaised]) instead, so `raised` has no shadow there.
@immutable
class DkElevation {
  const DkElevation({
    required this.raised,
    required this.floating,
    required this.overlay,
  });

  static const light = DkElevation(
    raised: [
      BoxShadow(color: Color(0x1414171C), offset: Offset(0, 2), blurRadius: 8),
    ],
    floating: [
      BoxShadow(color: Color(0x2414171C), offset: Offset(0, 6), blurRadius: 16),
    ],
    overlay: [
      BoxShadow(
        color: Color(0x1F14171C),
        offset: Offset(0, -2),
        blurRadius: 24,
      ),
    ],
  );

  static const dark = DkElevation(
    raised: [],
    floating: [
      BoxShadow(color: Color(0x66000000), offset: Offset(0, 6), blurRadius: 16),
    ],
    overlay: [],
  );

  /// `flat` is a 1 dp [DkColors.outline] border and no shadow.
  final List<BoxShadow> raised, floating, overlay;

  DkElevation lerp(DkElevation o, double t) => DkElevation(
    raised: BoxShadow.lerpList(raised, o.raised, t)!,
    floating: BoxShadow.lerpList(floating, o.floating, t)!,
    overlay: BoxShadow.lerpList(overlay, o.overlay, t)!,
  );
}

/// Motion (UI spec §9). DK-0039 adds reduce-motion handling and haptics.
@immutable
class DkMotion {
  const DkMotion();
  final fast = const Duration(milliseconds: 120);
  final standard = const Duration(milliseconds: 220);
  final emphasis = const Duration(milliseconds: 320);
  final fastCurve = Curves.easeOut;
  final standardCurve = Curves.easeInOutCubic;

  /// "Ease-out with slight overshoot".
  final emphasisCurve = const Cubic(0.34, 1.3, 0.64, 1);
}
