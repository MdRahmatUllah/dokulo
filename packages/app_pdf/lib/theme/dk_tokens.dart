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
    required this.markup,
    required this.compare,
    required this.state,
    required this.text,
    required this.space,
    required this.radius,
    required this.elevation,
    required this.motion,
  });

  static final light = DkTokens(
    brightness: Brightness.light,
    color: DkColors.light,
    markup: const DkMarkup(),
    compare: DkCompare.light,
    state: DkStates.of(DkColors.light),
    text: DkType.of(DkColors.light.textPrimary),
    space: const DkSpace(),
    radius: const DkRadius(),
    elevation: DkElevation.light,
    motion: const DkMotion(),
  );

  static final dark = DkTokens(
    brightness: Brightness.dark,
    color: DkColors.dark,
    markup: const DkMarkup(),
    compare: DkCompare.dark,
    state: DkStates.of(DkColors.dark),
    text: DkType.of(DkColors.dark.textPrimary),
    space: const DkSpace(),
    radius: const DkRadius(),
    elevation: DkElevation.dark,
    motion: const DkMotion(),
  );

  final Brightness brightness;
  final DkColors color;
  final DkMarkup markup;
  final DkCompare compare;
  final DkStates state;

  /// Text styles. (Not `type`: ThemeExtension.type is the key Theme looks it up by.)
  final DkType text;
  final DkSpace space;
  final DkRadius radius;
  final DkElevation elevation;
  final DkMotion motion;

  /// Page thumbnails stay white with a 1 dp `color.outline`; in Dark they are
  /// dimmed to 92 % so they don't glare (UI spec §29.4; DK-0047). Wrap the
  /// thumbnail's image in `ColorFiltered(colorFilter: t.thumbnailFilter)`.
  /// The viewer shows pages unfiltered (only its night mode inverts them).
  ColorFilter get thumbnailFilter {
    final b = brightness == Brightness.dark ? 0.92 : 1.0;
    return ColorFilter.matrix([
      b, 0, 0, 0, 0, //
      0, b, 0, 0, 0, //
      0, 0, b, 0, 0, //
      0, 0, 0, 1, 0, //
    ]);
  }

  @override
  DkTokens copyWith({
    Brightness? brightness,
    DkColors? color,
    DkMarkup? markup,
    DkCompare? compare,
    DkStates? state,
    DkType? text,
    DkSpace? space,
    DkRadius? radius,
    DkElevation? elevation,
    DkMotion? motion,
  }) => DkTokens(
    brightness: brightness ?? this.brightness,
    color: color ?? this.color,
    markup: markup ?? this.markup,
    compare: compare ?? this.compare,
    state: state ?? this.state,
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
      markup: markup,
      compare: compare.lerp(other.compare, t),
      state: state.lerp(other.state, t),
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

/// Colours (UI spec §4.1): every token has a Light and a Dark value; the
/// markup and compare colours are their own groups ([DkMarkup], [DkCompare]).
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
    required this.pro,
    required this.proContainer,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.scrim,
    required this.cameraChrome,
    required this.onCamera,
    required this.quadFill,
    required this.quadStroke,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.inversePrimary,
    required this.pageWhite,
    required this.redactBox,
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
    outlineStrong: Color(0xFF828C9B),
    textPrimary: Color(0xFF14171C),
    textSecondary: Color(0xFF5A6270),
    textDisabled: Color(0xFF9AA1AD),
    iconPrimary: Color(0xFF2E3440),
    iconSecondary: Color(0xFF6B7380),
    pro: Color(0xFF8A5A0B),
    proContainer: Color(0xFFFFF4DD),
    success: Color(0xFF117A4B),
    successContainer: Color(0xFFE3F5EC),
    warning: Color(0xFFB54708),
    warningContainer: Color(0xFFFFF1E0),
    danger: Color(0xFFC8281E),
    onDanger: Color(0xFFFFFFFF),
    dangerContainer: Color(0xFFFDECEA),
    scrim: Color(0x6614171C),
    cameraChrome: Color(0x99000000),
    onCamera: Color(0xFFFFFFFF),
    quadFill: Color(0x332251E6),
    quadStroke: Color(0xFF2251E6),
    inverseSurface: Color(0xFF14171C),
    onInverseSurface: Color(0xFFFFFFFF),
    inversePrimary: Color(0xFF8AA8FF),
    pageWhite: Color(0xFFFFFFFF),
    redactBox: Color(0xFF000000),
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
    outlineStrong: Color(0xFF666E7B),
    textPrimary: Color(0xFFEEF1F6),
    textSecondary: Color(0xFFA6AEBB),
    textDisabled: Color(0xFF5F6672),
    iconPrimary: Color(0xFFDDE2EA),
    iconSecondary: Color(0xFF9099A6),
    pro: Color(0xFFF2C266),
    proContainer: Color(0xFF3A2C10),
    success: Color(0xFF5DD39E),
    successContainer: Color(0xFF12301F),
    warning: Color(0xFFFDB022),
    warningContainer: Color(0xFF3A2410),
    danger: Color(0xFFFF7A70),
    onDanger: Color(0xFF14171C),
    dangerContainer: Color(0xFF3A1614),
    scrim: Color(0x8C000000),
    cameraChrome: Color(0x99000000),
    onCamera: Color(0xFFFFFFFF),
    quadFill: Color(0x338AA8FF),
    quadStroke: Color(0xFF8AA8FF),
    inverseSurface: Color(0xFFEEF1F6),
    onInverseSurface: Color(0xFF14171C),
    inversePrimary: Color(0xFF2251E6),
    pageWhite: Color(0xFFFFFFFF),
    redactBox: Color(0xFF000000),
  );

  // Primary family (DK-0025).
  /// Primary buttons, active tab, links, selection rings, progress.
  final Color primary;

  /// Text and icons on [primary].
  final Color onPrimary;

  /// Pressed state of [primary].
  final Color primaryPressed;

  /// Selected chips, tile icon backgrounds, info banners, page chips.
  final Color primaryContainer;

  /// Text and icons on [primaryContainer].
  final Color onPrimaryContainer;

  /// The 2 dp keyboard/switch-access focus ring, 2 dp offset.
  final Color focusRing;

  // Surfaces and background (DK-0026).
  /// Screen background.
  final Color background;

  /// Cards, sheets, bars, dialogs.
  final Color surface;

  /// Sheets and menus above [surface] (dark mode needs the lift).
  final Color surfaceRaised;

  /// The PDF canvas behind pages, input fields, the search field.
  final Color surfaceSunken;

  // Outlines (DK-0027).
  /// Card borders, dividers, thumbnail outlines.
  final Color outline;

  /// Input borders at rest, the segmented control's border (3:1 on surfaces, WCAG 1.4.11).
  final Color outlineStrong;

  // Text and icons (DK-0028).
  /// Headings and body text.
  final Color textPrimary;

  /// Meta text, help text, captions.
  final Color textSecondary;

  /// Disabled labels.
  final Color textDisabled;

  /// Default icons.
  final Color iconPrimary;

  /// Secondary icons, chevrons.
  final Color iconSecondary;

  // Status (DK-0029).
  /// Pro badge text and icon.
  final Color pro;

  /// Pro badge background, the Pro card's tint.
  final Color proContainer;

  /// Success ticks and icons, size-saved numbers.
  final Color success;

  /// The success result card's tint.
  final Color successContainer;

  /// Partial success, low memory, storage warnings.
  final Color warning;

  /// Warning banners.
  final Color warningContainer;

  /// Delete, destructive buttons, error text.
  final Color danger;

  /// Text and icons on a [danger] fill (the Destructive button). Dark in
  /// Dark, like [onPrimary]: white on the light red would be 2.5:1.
  final Color onDanger;

  /// Error banners, the destructive confirm's icon background.
  final Color dangerContainer;

  // Overlay and camera (DK-0030).
  /// Behind sheets and dialogs (#14171C at 40 % / #000000 at 55 %).
  final Color scrim;

  /// Scanner bars over the camera image (#000000 at 60 %, both themes).
  final Color cameraChrome;

  /// Text and icons over the camera image.
  final Color onCamera;

  /// The detected document area in the camera ([quadStroke] at 20 %).
  final Color quadFill;

  /// The detected document edge, 2 dp.
  final Color quadStroke;

  // Inverse, for toasts (DK-0035; from the design export, added to UI spec §4.1).
  /// The toast's background.
  final Color inverseSurface;

  /// Text and icons on [inverseSurface].
  final Color onInverseSurface;

  /// The toast's action ("Undo") on [inverseSurface].
  final Color inversePrimary;

  // Document (DK-0031).
  /// PDF page background: pages stay white in dark mode unless the viewer's night mode is on.
  final Color pageWhite;

  /// Redaction boxes: always pure black, in every theme.
  final Color redactBox;

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
      pro: c(pro, o.pro),
      proContainer: c(proContainer, o.proContainer),
      success: c(success, o.success),
      successContainer: c(successContainer, o.successContainer),
      warning: c(warning, o.warning),
      warningContainer: c(warningContainer, o.warningContainer),
      danger: c(danger, o.danger),
      onDanger: c(onDanger, o.onDanger),
      dangerContainer: c(dangerContainer, o.dangerContainer),
      scrim: c(scrim, o.scrim),
      cameraChrome: c(cameraChrome, o.cameraChrome),
      onCamera: c(onCamera, o.onCamera),
      quadFill: c(quadFill, o.quadFill),
      quadStroke: c(quadStroke, o.quadStroke),
      inverseSurface: c(inverseSurface, o.inverseSurface),
      onInverseSurface: c(onInverseSurface, o.onInverseSurface),
      inversePrimary: c(inversePrimary, o.inversePrimary),
      pageWhite: c(pageWhite, o.pageWhite),
      redactBox: c(redactBox, o.redactBox),
    );
  }
}

/// Markup colours (UI spec §4.2; DK-0032): stored inside the PDF, so the same
/// in both themes. Their user-facing names are ARB strings (`markup_yellow`
/// … `markup_ink`: Yellow / Gelb, …).
@immutable
class DkMarkup {
  const DkMarkup();

  /// Highlighter: Yellow / Gelb.
  final yellow = const Color(0xFFFFE066);

  /// Highlighter: Green / Grün.
  final green = const Color(0xFFA8E6A1);

  /// Highlighter: Blue / Blau.
  final blue = const Color(0xFFA7D3FF);

  /// Highlighter: Pink / Pink.
  final pink = const Color(0xFFFFB3D1);

  /// Pen: Red / Rot.
  final red = const Color(0xFFE5484D);

  /// Pen: Black / Schwarz.
  final black = const Color(0xFF111111);

  /// Signature: Blue ink / Blaue Tinte.
  final ink = const Color(0xFF1A2B6D);
}

/// One Compare PDFs highlight: its background and its text colour. The label
/// ("Added" / "Hinzugefügt", …) and the icon are always shown with it, so
/// colour is never the only cue.
typedef DkHighlight = ({Color background, Color text});

/// Compare colours (UI spec §4.3; DK-0033).
@immutable
class DkCompare {
  const DkCompare({
    required this.added,
    required this.removed,
    required this.changed,
  });

  static const light = DkCompare(
    added: (background: Color(0xFFD9F2E2), text: Color(0xFF117A4B)),
    removed: (background: Color(0xFFFDECEA), text: Color(0xFFC8281E)),
    changed: (background: Color(0xFFFFF1E0), text: Color(0xFFB54708)),
  );

  static const dark = DkCompare(
    added: (background: Color(0xFF12301F), text: Color(0xFF5DD39E)),
    removed: (background: Color(0xFF3A1614), text: Color(0xFFFF7A70)),
    changed: (background: Color(0xFF3A2410), text: Color(0xFFFDB022)),
  );

  /// Added text, with a plus icon.
  final DkHighlight added;

  /// Removed text, struck through, with a minus icon.
  final DkHighlight removed;

  /// Changed text, with a dot icon.
  final DkHighlight changed;

  DkCompare lerp(DkCompare o, double t) {
    DkHighlight h(DkHighlight a, DkHighlight b) => (
      background: Color.lerp(a.background, b.background, t)!,
      text: Color.lerp(a.text, b.text, t)!,
    );
    return DkCompare(
      added: h(added, o.added),
      removed: h(removed, o.removed),
      changed: h(changed, o.changed),
    );
  }
}

/// Interaction states on any surface (UI spec §4.4; DK-0034).
@immutable
class DkStates {
  const DkStates({
    required this.hover,
    required this.pressed,
    required this.selected,
  });

  factory DkStates.of(DkColors c) => DkStates(
    hover: c.textPrimary.withValues(alpha: 0.04),
    pressed: c.textPrimary.withValues(alpha: 0.08),
    selected: c.primaryContainer,
  );

  /// Overlay while a pointer hovers (tablets): [DkColors.textPrimary] at 4 %.
  final Color hover;

  /// Overlay while pressed: [DkColors.textPrimary] at 8 %.
  final Color pressed;

  /// The fill of a selected list row: [DkColors.primaryContainer].
  final Color selected;

  /// A dragged item scales up 2 % and takes `elevation.floating`.
  final double draggedScale = 1.02;

  /// A disabled element is drawn at 40 % opacity as a whole.
  final double disabledOpacity = 0.4;

  DkStates lerp(DkStates o, double t) => DkStates(
    hover: Color.lerp(hover, o.hover, t)!,
    pressed: Color.lerp(pressed, o.pressed, t)!,
    selected: Color.lerp(selected, o.selected, t)!,
  );
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
      // The platform's mono: Android's "monospace"; iOS has no font by that
      // name, so it falls back to Menlo (SF Mono isn't open to apps).
      mono: s(13, 18, FontWeight.w400, 0).copyWith(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Menlo', 'Courier New'],
      ),
      // Result numbers ("1.9 MB") don't jiggle as they change (DK-0036).
      numberXL: s(
        32,
        38,
        FontWeight.w700,
        -0.3,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
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

/// The three kinds of movement (UI spec §9).
enum DkMotionKind {
  /// Press states, chip toggles, switch thumbs.
  fast,

  /// Sheets, pushes, tile reorder, expand/collapse.
  standard,

  /// Success tick, Scan button press, capture thumbnail fly-in.
  emphasis,
}

/// A motion's timing: how long and how it eases. [crossFade] is true when
/// Reduce Motion is on: the widget then fades instead of moving, scaling or
/// sliding.
typedef DkMotionSpec = ({Duration duration, Curve curve, bool crossFade});

/// Motion (UI spec §9; DK-0039). Widgets ask [of] (or `context.motion(kind)`),
/// never the raw durations, so Reduce Motion replaces every movement.
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

  /// With Reduce Motion on, every movement becomes this cross-fade.
  final reduced = const Duration(milliseconds: 120);
  final reducedCurve = Curves.linear;

  /// The scanner's capture flash (white, 80 ms, once per capture). At most
  /// one flash per capture, and captures are seconds apart, so it never
  /// flashes above 3 Hz; with Reduce Motion it is off ([flashAllowed]).
  final captureFlash = const Duration(milliseconds: 80);

  /// The timing for [kind], or the cross-fade when [reduce] is on.
  DkMotionSpec of(DkMotionKind kind, {required bool reduce}) {
    if (reduce) {
      return (duration: reduced, curve: reducedCurve, crossFade: true);
    }
    return switch (kind) {
      DkMotionKind.fast => (duration: fast, curve: fastCurve, crossFade: false),
      DkMotionKind.standard => (
        duration: standard,
        curve: standardCurve,
        crossFade: false,
      ),
      DkMotionKind.emphasis => (
        duration: emphasis,
        curve: emphasisCurve,
        crossFade: false,
      ),
    };
  }

  /// Flashes (the capture flash) are off with Reduce Motion.
  bool flashAllowed({required bool reduce}) => !reduce;
}

/// `context.reduceMotion` and `context.motion(kind)`: Reduce Motion is the
/// platform's setting (iOS Reduce Motion, Android "Remove animations"), which
/// Flutter reports as [MediaQueryData.disableAnimations].
extension DkMotionContext on BuildContext {
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  DkMotionSpec motion(DkMotionKind kind) =>
      tokens.motion.of(kind, reduce: reduceMotion);
}
