import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';
import 'dk_number_text.dart';
import 'motion/dk_capture_motion.dart';

/// The count badge (DK-0114; UI spec §11.3): a pill at least 18 dp tall and
/// wide, `color.primary` with the number in `type.labelM`, on the scanner's
/// page tray and on tab icons. A new [count] pops it ([DkPop]: ×1.35 and
/// back, or a cross-fade with Reduce Motion).
///
/// The text is `color.onPrimary` as in the export: the spec's "white" would
/// be 2.3:1 on Dark's light primary.
class DkCountBadge extends StatelessWidget {
  const DkCountBadge(this.count, {super.key, this.semanticsLabel});

  final int count;

  /// What a screen reader says ("3 pages"); the number alone without it.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DkPop(
      value: count,
      child: Container(
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: t.color.primary,
          borderRadius: BorderRadius.circular(t.radius.pill),
        ),
        // Centred, but only as big as the number (and the minimums).
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: DkNumberText(
            '$count',
            style: t.text.labelM.copyWith(color: t.color.onPrimary, height: 1),
            semanticsLabel: semanticsLabel,
          ),
        ),
      ),
    );
  }
}
