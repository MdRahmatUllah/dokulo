import 'package:flutter/material.dart';

import '../components/dk_slider.dart';
import '../components/dk_stepper.dart';
import '../theme/dk_tokens.dart';

/// DkSlider with its value; DkStepper mid-range and at its only value (both
/// buttons off).
class DkSliderStepperGallery extends StatelessWidget {
  const DkSliderStepperGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    void any(Object? _) {}
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: t.space.m,
      children: [
        DkSlider(
          title: 'Opacity',
          value: 0.3,
          onChanged: any,
          format: (v) => '${(v * 100).round()} %',
        ),
        const DkSlider(
          title: 'Opacity',
          value: 0.6,
          onChanged: null,
          format: _percent,
        ),
        Row(
          spacing: t.space.m,
          children: [
            DkStepper(value: 2, min: 1, onChanged: any, label: 'Every N pages'),
            DkStepper(
              value: 1,
              min: 1,
              max: 1,
              onChanged: any,
              label: 'Every N pages',
            ),
          ],
        ),
      ],
    );
  }
}

String _percent(double v) => '${(v * 100).round()} %';
