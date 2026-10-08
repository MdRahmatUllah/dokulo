import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/dk_tokens.dart';

/// The illustrations (UI spec §8; DK-0050–DK-0069), with their size in dp.
/// The assets come from the design export (`tools/extract_illustrations.py`).
enum DkIllustrations {
  /// ILL-01: phone in airplane mode with a document (Onboarding 1).
  onboarding1('ill-01-onboarding-1', 200, 160),

  /// ILL-02: clean page with a one-time price tag (Onboarding 2).
  onboarding2('ill-02-onboarding-2', 200, 160),

  /// ILL-03: camera, folder and toolbox (Onboarding 3).
  onboarding3('ill-03-onboarding-3', 200, 160),

  /// ILL-04: two pages in a scan frame (Home empty).
  homeEmpty('ill-04-home-empty', 120, 120),

  /// ILL-05: open folder with a page sliding in (Files empty).
  filesEmpty('ill-05-files-empty', 120, 120),

  /// ILL-06: an empty folder outline (Folder empty).
  folderEmpty('ill-06-folder-empty', 120, 120),

  /// ILL-07: a magnifier over a blank page (Search, no results).
  searchNoResults('ill-07-search-no-results', 120, 120),

  /// ILL-08: an empty bin with a check (Trash empty).
  trashEmpty('ill-08-trash-empty', 120, 120),

  /// ILL-09: a folder with a lock and a fingerprint (Locked folder intro).
  lockedFolderIntro('ill-09-locked-folder-intro', 120, 120),

  /// ILL-10: a camera with a slash and a page (Camera permission denied; the
  /// scanner shows it inverted on black).
  cameraDenied('ill-10-camera-denied', 120, 120);

  const DkIllustrations(this.file, this.width, this.height);
  final String file;
  final double width, height;

  String get asset => 'assets/illustrations/$file.svg';
}

/// An illustration in the active theme's colours: one SVG asset (drawn in
/// the light palette) whose colours are swapped for the current tokens while
/// it is parsed, so Light and Dark need no second file.
///
/// Decorative by default: the text beside it says the same, so screen
/// readers skip it. Give [semanticLabel] where it carries meaning on its own.
class DkIllustration extends StatelessWidget {
  const DkIllustration(
    this.illustration, {
    super.key,
    this.scale = 1,
    this.semanticLabel,
  });

  final DkIllustrations illustration;

  /// 1 = the spec's size (200 × 160 or 120 × 120 dp).
  final double scale;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    illustration.asset,
    width: illustration.width * scale,
    height: illustration.height * scale,
    colorMapper: DkIllustrationColors(context.tokens.color),
    semanticsLabel: semanticLabel,
    excludeFromSemantics: semanticLabel == null,
  );
}

/// The light palette's colours in the assets → the active tokens. The
/// paywall's amber (#8A5A0B, #FFF4DD) is the same in both themes, as in the
/// design export, so it isn't mapped.
@immutable
class DkIllustrationColors extends ColorMapper {
  const DkIllustrationColors(this.colors);
  final DkColors colors;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    final mapped = switch (color.toARGB32() & 0xFFFFFF) {
      0x2251E6 => colors.primary,
      0x2E3440 => colors.iconPrimary,
      0xE6ECFF => colors.primaryContainer,
      0xFFFFFF => colors.surface,
      _ => null,
    };
    return mapped == null ? color : mapped.withValues(alpha: color.a);
  }

  // The SVG cache keys on the mapper: equal tokens, equal pictures.
  @override
  bool operator ==(Object other) =>
      other is DkIllustrationColors && other.colors == colors;

  @override
  int get hashCode => colors.hashCode;
}
