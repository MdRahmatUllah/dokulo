import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';
import 'dk_radio_row.dart';
import 'dk_tappable.dart';

/// One choice of 2–4 (DK-0130; UI spec §11.4): a 36 dp `color.surfaceSunken`
/// track (`radius.s`) in a 48 dp tap target; the selected segment is
/// `color.surface` with `elevation.raised`; labels in `type.labelM`. With
/// [radioAtLargeText] (the Split mode switch), it becomes a list of
/// [DkRadioRow]s at 160 % text and above, where four labels can't fit.
class DkSegmented<T> extends StatelessWidget {
  const DkSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.radioAtLargeText = false,
  }) : assert(segments.length >= 2 && segments.length <= 4);

  /// The values and their labels, in order.
  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T>? onChanged;
  final bool radioAtLargeText;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    if (radioAtLargeText && MediaQuery.textScalerOf(context).scale(1) >= 1.6) {
      return RadioGroup<T>(
        groupValue: selected,
        onChanged: (v) {
          if (v != null) onChanged?.call(v);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, label) in segments)
              DkRadioRow<T>(value: value, label: label),
          ],
        ),
      );
    }
    final m = context.motion(DkMotionKind.fast);
    // The track is 36; each segment's target is 48 tall (Android's minimum;
    // iOS asks 44): a 6 dp band above and below the track also picks it.
    const band = 6.0;
    return Opacity(
      opacity: onChanged == null ? t.state.disabledOpacity : 1,
      child: Stack(
        children: [
          Positioned.fill(
            top: band,
            bottom: band,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surfaceSunken,
                borderRadius: BorderRadius.circular(t.radius.s),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.xxs),
            child: Row(
              children: [
                for (final (value, label) in segments)
                  Expanded(
                    child: Semantics(
                      button: true,
                      inMutuallyExclusiveGroup: true,
                      selected: value == selected,
                      enabled: onChanged != null,
                      onTap: onChanged == null ? null : () => onChanged!(value),
                      excludeSemantics: true,
                      label: label,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onChanged == null
                            ? null
                            : () => onChanged!(value),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: band + t.space.xxs,
                          ),
                          child: DkTappable(
                            onTap: onChanged == null
                                ? null
                                : () => onChanged!(value),
                            radius: t.radius.s - t.space.xxs,
                            builder: (context, pressed) => AnimatedContainer(
                              duration: m.duration,
                              curve: m.curve,
                              constraints: const BoxConstraints(minHeight: 32),
                              padding: EdgeInsets.symmetric(
                                horizontal: t.space.s,
                              ),
                              decoration: BoxDecoration(
                                color: value == selected
                                    ? c.surface
                                    : (pressed ? t.state.pressed : null),
                                borderRadius: BorderRadius.circular(
                                  t.radius.s - t.space.xxs,
                                ),
                                boxShadow: value == selected
                                    ? t.elevation.raised
                                    : null,
                              ),
                              // Centred without filling a tall parent.
                              child: Center(
                                heightFactor: 1,
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: t.text.labelM.copyWith(
                                    color: value == selected
                                        ? c.textPrimary
                                        : c.textSecondary,
                                  ),
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
          ),
        ],
      ),
    );
  }
}
