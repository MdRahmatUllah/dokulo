import 'package:flutter/material.dart';

import '../components/dk_segmented.dart';
import '../components/dk_switch.dart';
import '../theme/dk_tokens.dart';

const _modes = [(0, 'By ranges'), (1, 'Every N pages'), (2, 'Each page')];

/// DkSwitch on, off and disabled; DkSegmented with three and two segments,
/// enabled and disabled.
class DkSwitchSegmentedGallery extends StatelessWidget {
  const DkSwitchSegmentedGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    void any(Object? _) {}
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: t.space.m,
      children: [
        Row(
          spacing: t.space.m,
          children: [
            DkSwitch(value: true, onChanged: any),
            DkSwitch(value: false, onChanged: any),
            const DkSwitch(value: true, onChanged: null),
          ],
        ),
        DkSegmented<int>(segments: _modes, selected: 1, onChanged: any),
        DkSegmented<int>(
          segments: _modes.sublist(0, 2),
          selected: 0,
          onChanged: null,
        ),
      ],
    );
  }
}
