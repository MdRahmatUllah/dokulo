import 'package:flutter/material.dart';

import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';

/// The loupe for placing crop corners and signatures (UI spec §11.5;
/// DK-0158): a 96 circle with a 2 dp white border and `elevation.floating`,
/// showing the content under the finger at 4×, with a 1 dp primary
/// crosshair. It sits 80 above the finger, and below it near the top edge.
///
/// A [Positioned]: put it in the [Stack] that holds the magnified content,
/// with [finger] in that stack's coordinates. Decorative for screen readers:
/// the handle being dragged announces itself.
class DkMagnifier extends StatelessWidget {
  const DkMagnifier({super.key, required this.finger});

  final Offset finger;

  static const diameter = 96.0, zoom = 4.0, distance = 80.0;

  /// Whether it shows below the finger: there's no room above.
  static bool flipped(Offset finger) => finger.dy - distance - diameter / 2 < 0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final below = flipped(finger);
    final centre = finger.translate(0, below ? distance : -distance);
    return Positioned(
      left: centre.dx - diameter / 2,
      top: centre.dy - diameter / 2,
      child: ExcludeSemantics(
        child: RawMagnifier(
          size: const Size.square(diameter),
          magnificationScale: zoom,
          // The floating shadow is offset: keep it off the lens.
          clipBehavior: Clip.antiAlias,
          // The point to magnify: the finger, from the loupe's centre.
          focalPointOffset: finger - centre,
          decoration: MagnifierDecoration(
            shape: CircleBorder(
              side: BorderSide(color: t.color.onCamera, width: 2),
            ),
            shadows: t.surfaceAt(DkLevel.floating).boxShadow,
          ),
          child: CustomPaint(painter: _Crosshair(t.color.primary)),
        ),
      ),
    );
  }
}

/// A 1 dp cross through the loupe's centre, a third of its width.
class _Crosshair extends CustomPainter {
  const _Crosshair(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final arm = size.width / 6;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas
      ..drawLine(c.translate(-arm, 0), c.translate(arm, 0), paint)
      ..drawLine(c.translate(0, -arm), c.translate(0, arm), paint);
  }

  @override
  bool shouldRepaint(_Crosshair old) => old.color != color;
}
