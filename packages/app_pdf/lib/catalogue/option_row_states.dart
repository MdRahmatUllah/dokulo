import 'package:flutter/material.dart';

import '../components/dk_checkbox_row.dart';
import '../components/dk_option_row.dart';
import '../components/dk_position_picker.dart';
import '../components/dk_segmented.dart';
import '../components/dk_switch.dart';
import '../theme/dk_tokens.dart';

/// DkOptionRow with a switch to the right and a control below; More options
/// open; DkPositionPicker with six targets and with the centre.
class DkOptionRowGallery extends StatelessWidget {
  const DkOptionRowGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    void any(Object? _) {}
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DkOptionRow(
          title: 'Keep bookmarks',
          help: 'Bookmarks from every file stay in the merged PDF.',
          control: DkSwitch(value: true, onChanged: any),
        ),
        DkOptionRow(
          title: 'Format',
          controlBelow: true,
          last: true,
          control: DkSegmented<int>(
            segments: const [(0, '1'), (1, '1 of N')],
            selected: 0,
            onChanged: any,
          ),
        ),
        DkMoreOptions(
          initiallyOpen: true,
          children: [
            DkCheckboxRow(label: 'Start at 2', value: false, onChanged: any),
          ],
        ),
        SizedBox(height: t.space.m),
        Row(
          spacing: t.space.l,
          children: [
            DkPositionPicker(
              selected: DkPagePosition.bottomCentre,
              onChanged: any,
            ),
            DkPositionPicker(
              selected: DkPagePosition.centre,
              withCentre: true,
              onChanged: any,
            ),
          ],
        ),
      ],
    );
  }
}
