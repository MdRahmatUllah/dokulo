import 'package:flutter/widgets.dart';

import 'dk_tokens.dart';

/// A folder's colour tag (UI spec §11.2, DkFolderCard). The same in both
/// themes, as the spec gives one value each; no tag draws the folder in
/// `color.iconSecondary`.
enum DkFolderTag {
  blue(Color(0xFF2251E6)),
  green(Color(0xFF13804F)),
  orange(Color(0xFFB54708)),
  red(Color(0xFFC8281E)),
  purple(Color(0xFF6E4AD8)),
  grey(Color(0xFF6B7380));

  const DkFolderTag(this.colour);
  final Color colour;

  /// The folder icon's colour for [tag] (null: untagged).
  static Color of(DkFolderTag? tag, DkTokens t) =>
      tag?.colour ?? t.color.iconSecondary;
}
