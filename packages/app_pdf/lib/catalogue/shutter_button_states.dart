import 'package:flutter/material.dart';

import '../components/dk_shutter_button.dart';
import '../theme/dk_tokens.dart';

/// DkShutterButton on the camera chrome: default, pressed, the countdown at
/// 60 %, focused and disabled (no permission).
class DkShutterButtonGallery extends StatelessWidget {
  const DkShutterButtonGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    void tap() {}
    return Container(
      color: t.color.cameraChrome,
      padding: EdgeInsets.all(t.space.m),
      child: Wrap(
        spacing: t.space.l,
        runSpacing: t.space.l,
        children: [
          DkShutterButton(onPressed: tap),
          DkShutterButton(onPressed: tap, showPressed: true),
          DkShutterButton(onPressed: tap, countdown: 0.6),
          DkShutterButton(onPressed: tap, showFocused: true),
          const DkShutterButton(onPressed: null),
        ],
      ),
    );
  }
}
