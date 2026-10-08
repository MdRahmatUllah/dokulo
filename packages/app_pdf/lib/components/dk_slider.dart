import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';
import 'dk_number_text.dart';

/// A slider with its title and value (DK-0132; UI spec §11.4): a 4 dp
/// `color.outline` track, `color.primary` up to the thumb, a 20 dp white
/// thumb with `elevation.raised`; the value ("30 %") right of the [title].
class DkSlider extends StatelessWidget {
  const DkSlider({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.format,
    this.min = 0,
    this.max = 1,
    this.divisions,
  });

  final String title;
  final double value, min, max;
  final int? divisions;
  final ValueChanged<double>? onChanged;

  /// The value as shown and read: "30 %".
  final String Function(double value) format;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: t.text.titleS)),
            DkNumberText(
              format(value),
              style: t.text.bodyM.copyWith(color: c.textSecondary),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: c.primary,
            inactiveTrackColor: c.outline,
            // White on Light; the export's softer #DDE2EA on Dark (pure white
            // glares on a dark sheet), which is Dark's iconPrimary.
            thumbColor: Theme.of(context).brightness == Brightness.dark
                ? c.iconPrimary
                : c.surface,
            overlayColor: t.state.pressed,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 10,
              // elevation.raised (the shape takes a plain number).
              elevation: 2,
              pressedElevation: 4,
            ),
            trackShape: const RoundedRectSliderTrackShape(),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: format(value),
            semanticFormatterCallback: format,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
