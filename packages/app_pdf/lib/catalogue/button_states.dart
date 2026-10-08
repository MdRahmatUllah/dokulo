import 'package:flutter/material.dart';

import '../components/dk_button.dart';
import '../components/dk_icon.dart';
import '../theme/dk_tokens.dart';

/// DkButton: every variant in every state, then the sizes (UI spec §11.1).
/// The goldens draw this same gallery.
class DkButtonGallery extends StatelessWidget {
  const DkButtonGallery({super.key, this.label = 'Merge 4 files'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    void tap() {}
    Widget row(DkButtonVariant v) {
      final on = v == DkButtonVariant.onCamera;
      return Container(
        // On camera sits on the camera preview: shown on its dark chrome.
        color: on ? t.color.cameraChrome : null,
        padding: EdgeInsets.all(t.space.xs),
        child: Wrap(
          spacing: t.space.s,
          runSpacing: t.space.s,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DkButton(label: label, onPressed: tap, variant: v),
            DkButton(
              label: label,
              onPressed: tap,
              variant: v,
              showPressed: true,
            ),
            DkButton(
              label: label,
              onPressed: tap,
              variant: v,
              showFocused: true,
            ),
            DkButton(label: label, onPressed: null, variant: v),
            DkButton(
              label: label,
              onPressed: tap,
              variant: v,
              loading: true,
              icon: DkIcons.tool('merge'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: t.space.s,
      children: [
        for (final v in DkButtonVariant.values) row(v),
        Wrap(
          spacing: t.space.s,
          runSpacing: t.space.s,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final s in DkButtonSize.values)
              DkButton(
                label: label,
                onPressed: tap,
                size: s,
                icon: DkIcons.tool('merge'),
              ),
          ],
        ),
        DkButton(label: label, onPressed: tap, expand: true),
      ],
    );
  }
}
