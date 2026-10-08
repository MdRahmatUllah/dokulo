import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_box_frame.dart';
import 'dk_tappable.dart';

/// Where on the page (page numbers, watermark): DkPositionPicker's targets.
enum DkPagePosition {
  topLeft,
  topCentre,
  topRight,
  centre,
  bottomLeft,
  bottomCentre,
  bottomRight;

  String label(AppLocalizations l) => switch (this) {
    topLeft => l.position_top_left,
    topCentre => l.position_top_centre,
    topRight => l.position_top_right,
    centre => l.position_centre,
    bottomLeft => l.position_bottom_left,
    bottomCentre => l.position_bottom_centre,
    bottomRight => l.position_bottom_right,
  };

  /// Its column (left, centre, right) and row (top, centre, bottom).
  (int, int) get cell => switch (this) {
    topLeft => (0, 0),
    topCentre => (1, 0),
    topRight => (2, 0),
    centre => (1, 1),
    bottomLeft => (0, 2),
    bottomCentre => (1, 2),
    bottomRight => (2, 2),
  };
}

/// A page diagram to choose a position (DK-0140; UI spec §11.4): 120 × 160 on
/// `color.pageWhite` with its outline (in a 144 wide box: the 48 dp targets
/// reach past its sides), six 28 dp circles (top and bottom ×
/// left, centre, right), the selected one filled `color.primary`; [withCentre]
/// adds the centre (watermark). Each target is announced ("Bottom centre").
class DkPositionPicker extends StatelessWidget {
  const DkPositionPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.withCentre = false,
  });

  final DkPagePosition selected;
  final ValueChanged<DkPagePosition>? onChanged;
  final bool withCentre;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final targets = [
      for (final p in DkPagePosition.values)
        if (p != DkPagePosition.centre || withCentre) p,
    ];
    // Three columns of 48 dp targets don't fit on a 120 dp page: the
    // targets reach 12 dp past its sides, so the picker is 144 wide. The
    // circles stay where the page puts them (4 dp in, 38 dp apart), each
    // kept inside its own target.
    const target = 48.0, ring = 36.0, side = 12.0;
    return SizedBox(
      width: 120 + 2 * side,
      height: 160,
      child: Stack(
        children: [
          Positioned(
            left: side,
            width: 120,
            top: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.pageWhite,
                borderRadius: BorderRadius.circular(t.radius.xs),
                border: Border.all(color: c.outline),
              ),
            ),
          ),
          for (final p in targets)
            Positioned(
              left: p.cell.$1 * target,
              top: [0.0, 56.0, 112.0][p.cell.$2],
              width: target,
              height: target,
              child: Semantics(
                button: true,
                inMutuallyExclusiveGroup: true,
                selected: p == selected,
                label: p.label(l),
                excludeSemantics: true,
                onTap: onChanged == null ? null : () => onChanged!(p),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onChanged == null ? null : () => onChanged!(p),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        // Where the page puts the circle, kept inside its own
                        // target (the outer columns move 4 dp inwards).
                        left:
                            (side +
                                    t.space.xs +
                                    p.cell.$1 * 38 -
                                    p.cell.$1 * target)
                                .clamp(0, target - ring),
                        top: [
                          t.space.xs,
                          80 - ring / 2 - 56,
                          160 - t.space.xs - ring - 112,
                        ][p.cell.$2],
                        width: ring,
                        height: ring,
                        child: DkTappable(
                          onTap: onChanged == null ? null : () => onChanged!(p),
                          radius: ring / 2,
                          builder: (context, pressed) {
                            // The watermark-only centre is dashed until it's
                            // chosen, as in the design export.
                            final dashed =
                                p == DkPagePosition.centre && p != selected;
                            return Center(
                              child: CustomPaint(
                                foregroundPainter: dashed
                                    ? DkDashedBorder(
                                        c.outlineStrong,
                                        radius: BorderRadius.circular(14),
                                        width: 2,
                                      )
                                    : null,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: p == selected
                                        ? c.primary
                                        : pressed
                                        ? Color.alphaBlend(
                                            t.state.pressed,
                                            c.pageWhite,
                                          )
                                        : c.pageWhite,
                                    border: dashed
                                        ? null
                                        : Border.all(
                                            color: p == selected
                                                ? c.primary
                                                : c.outlineStrong,
                                            width: 2,
                                          ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
