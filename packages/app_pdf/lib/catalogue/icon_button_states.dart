import 'package:flutter/material.dart';

import '../components/dk_icon.dart';
import '../components/dk_icon_button.dart';
import '../theme/dk_tokens.dart';

const _pin = 'Pin';

/// DkIconButton: each variant default, pressed, selected and disabled.
class DkIconButtonGallery extends StatelessWidget {
  const DkIconButtonGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    void tap() {}
    Widget row(DkIconButtonVariant v) => Container(
      color: v == DkIconButtonVariant.onCamera ? t.color.cameraChrome : null,
      child: Row(
        children: [
          DkIconButton(
            icon: DkIcons.pin,
            tooltip: _pin,
            onPressed: tap,
            variant: v,
          ),
          DkIconButton(
            icon: DkIcons.pin,
            tooltip: _pin,
            onPressed: tap,
            variant: v,
            showPressed: true,
          ),
          DkIconButton(
            icon: DkIcons.pin,
            tooltip: _pin,
            onPressed: tap,
            variant: v,
            selected: true,
          ),
          DkIconButton(
            icon: DkIcons.pin,
            tooltip: _pin,
            onPressed: null,
            variant: v,
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final v in DkIconButtonVariant.values) row(v)],
    );
  }
}
