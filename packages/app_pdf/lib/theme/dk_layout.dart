import 'package:flutter/material.dart';

import 'dk_tokens.dart';

/// Borders and dividers (UI spec §6.5; DK-0038).
extension DkBorders on DkTokens {
  /// 1 dp outline; in lists with leading icons, inset [dividerInset] from the
  /// left so it lines up with the text.
  BorderSide get divider => BorderSide(color: color.outline);
  double get dividerInset => space.l;

  /// Inputs: 1 dp at rest, 2 dp primary focused, 2 dp danger on error.
  BorderSide get inputRest => BorderSide(color: color.outlineStrong);
  BorderSide get inputFocused => BorderSide(color: color.primary, width: 2);
  BorderSide get inputError => BorderSide(color: color.danger, width: 2);

  /// The selection ring on cards and thumbnails, drawn 2 dp inside the radius.
  BorderSide get selectionRing => BorderSide(color: color.primary, width: 2);
}

/// How high a surface sits (UI spec §6.4).
enum DkLevel {
  /// On the page: a 1 dp outline, no shadow (thumbnails, list groups).
  flat,

  /// Lifted a little: a soft shadow in Light; `surfaceRaised` and an outline
  /// in Dark (viewer pages, a dragged item).
  raised,

  /// Above the content: a shadow in both themes (menus, the mini job bar,
  /// the magnifier, the markup bar).
  floating,

  /// Sheets and dialogs. [DkSurfaces.surfaceAt] draws the surface only: the
  /// scrim behind it is the sheet's or the dialog's own (`color.scrim`).
  overlay,
}

/// A surface at a [DkLevel] (UI spec §6.4; DK-0038). Light mode lifts with
/// shadows; dark mode with a lighter surface and an outline, because shadows
/// barely show on dark backgrounds.
extension DkSurfaces on DkTokens {
  BoxDecoration surfaceAt(DkLevel level, {BorderRadius? radius}) {
    final dark = brightness == Brightness.dark;
    final outlined = Border.fromBorderSide(BorderSide(color: color.outline));
    return switch (level) {
      DkLevel.flat => BoxDecoration(
        color: color.surface,
        border: outlined,
        borderRadius: radius,
      ),
      DkLevel.raised => BoxDecoration(
        color: dark ? color.surfaceRaised : color.surface,
        border: dark ? outlined : null,
        boxShadow: elevation.raised,
        borderRadius: radius,
      ),
      DkLevel.floating => BoxDecoration(
        color: dark ? color.surfaceRaised : color.surface,
        boxShadow: elevation.floating,
        borderRadius: radius,
      ),
      DkLevel.overlay => BoxDecoration(
        color: dark ? color.surfaceRaised : color.surface,
        boxShadow: elevation.overlay,
        borderRadius: radius,
      ),
    };
  }
}

/// The layout grid of a device class (UI spec §6.2; DK-0038). The breakpoint
/// system (DK-0657) decides the class; this holds its numbers.
class DkGrid {
  const DkGrid._(this.margin, this.columns, this.gutter, {this.rail = 0});

  /// Side margin, columns and gutter in dp; [rail] is the navigation rail's
  /// width on large tablets.
  final double margin, gutter, rail;
  final int columns;

  static const phone = DkGrid._(16, 4, 12);
  static const smallTablet = DkGrid._(24, 8, 16);
  static const largeTablet = DkGrid._(24, 12, 16, rail: 80);

  /// Phone below 600 dp, small tablet below 840, large tablet from 840.
  static DkGrid forWidth(double width) => width < 600
      ? phone
      : width < 840
      ? smallTablet
      : largeTablet;
}
