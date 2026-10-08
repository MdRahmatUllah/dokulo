import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
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

  /// Where its target sits on the 120 × 160 page.
  Alignment get alignment => switch (this) {
    topLeft => const Alignment(-1, -1),
    topCentre => const Alignment(0, -1),
    topRight => const Alignment(1, -1),
    centre => Alignment.center,
    bottomLeft => const Alignment(-1, 1),
    bottomCentre => const Alignment(0, 1),
    bottomRight => const Alignment(1, 1),
  };
}

/// A page diagram to choose a position (DK-0140; UI spec §11.4): 120 × 160 on
/// `color.pageWhite` with its outline, six 28 dp targets (top and bottom ×
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
    return Container(
      width: 120,
      height: 160,
      padding: EdgeInsets.all(t.space.xs),
      decoration: BoxDecoration(
        color: c.pageWhite,
        borderRadius: BorderRadius.circular(t.radius.xs),
        border: Border.all(color: c.outline),
      ),
      child: Stack(
        children: [
          for (final p in targets)
            Align(
              alignment: p.alignment,
              child: Semantics(
                button: true,
                inMutuallyExclusiveGroup: true,
                selected: p == selected,
                label: p.label(l),
                excludeSemantics: true,
                onTap: onChanged == null ? null : () => onChanged!(p),
                child: DkTappable(
                  onTap: onChanged == null ? null : () => onChanged!(p),
                  radius: 18,
                  builder: (context, pressed) => SizedBox.square(
                    // 36 to touch: six fit on the small page.
                    dimension: 36,
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p == selected ? c.primary : c.pageWhite,
                          border: Border.all(
                            color: p == selected ? c.primary : c.outlineStrong,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
