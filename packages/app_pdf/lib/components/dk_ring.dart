import 'package:flutter/widgets.dart';

import '../theme/dk_tokens.dart';

/// A ring 2 dp outside [child]'s rounded rectangle (`outline-offset: 2px` in
/// the design export): the selection ring (`DkBorders.selectionRing`) or the
/// keyboard focus ring (`DkBorders.focusRing`). Draws nothing when [side] is
/// null; the child's layout never changes.
class DkRing extends StatelessWidget {
  const DkRing({
    super.key,
    required this.side,
    required this.radius,
    required this.child,
  });

  final BorderSide? side;

  /// The child's corner radius; the ring's follows it.
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ring = side;
    if (ring == null) return child;
    final out = context.tokens.space.xxs + ring.width;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          left: -out,
          top: -out,
          right: -out,
          bottom: -out,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.fromBorderSide(ring),
                borderRadius: BorderRadius.circular(radius + out),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
