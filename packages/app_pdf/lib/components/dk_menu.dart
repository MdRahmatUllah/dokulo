import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_action_sheet.dart';

/// Opens a [DkMenu] (UI spec §11.7; DK-0188) under the widget whose
/// [anchor] context is given (an overflow button), aligned to its right
/// edge, or to its left edge when it sits in the left half. With no room
/// below, it opens above. It fades and grows from that corner in
/// `motion.fast`; with Reduce Motion it only fades. A tap outside or back
/// closes it.
Future<void> showDkMenu(
  BuildContext anchor, {
  required List<List<DkAction>> groups,
}) {
  final box = anchor.findRenderObject()! as RenderBox;
  final navigator = Navigator.of(anchor);
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  final motion = anchor.motion(DkMotionKind.fast);
  return navigator.push(
    _MenuRoute(
      anchor: rect,
      groups: groups,
      duration: motion.duration,
      curve: motion.curve,
      grow: !motion.crossFade,
      barrierLabel: MaterialLocalizations.of(anchor).menuDismissLabel,
    ),
  );
}

class _MenuRoute extends PopupRoute<void> {
  _MenuRoute({
    required this.anchor,
    required this.groups,
    required this.duration,
    required this.curve,
    required this.grow,
    required this.barrierLabel,
  });

  final Rect anchor;
  final List<List<DkAction>> groups;
  final Duration duration;
  final Curve curve;
  final bool grow;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => duration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final gap = context.tokens.space.xs;
    final right = anchor.center.dx > screen.width / 2;
    final roomBelow = screen.height - padding.bottom - anchor.bottom - gap;
    final roomAbove = anchor.top - padding.top - gap;
    final below = roomBelow >= math.min(roomAbove, 320);
    // Screen readers say "Menu" when it opens and keep focus inside it, as
    // with Flutter's popup menus.
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: MaterialLocalizations.of(context).popupMenuLabel,
      child: CustomSingleChildLayout(
        delegate: _MenuPosition(anchor, right: right, below: below, gap: gap),
        child: ScaleTransition(
          scale: grow
              ? Tween(
                  begin: 0.9,
                  end: 1.0,
                ).animate(CurvedAnimation(parent: animation, curve: curve))
              : const AlwaysStoppedAnimation(1),
          alignment: Alignment(right ? 1 : -1, below ? -1 : 1),
          child: FadeTransition(
            opacity: animation,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(below ? roomBelow : roomAbove, 120),
              ),
              child: DkMenu(groups: groups),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuPosition extends SingleChildLayoutDelegate {
  _MenuPosition(
    this.anchor, {
    required this.right,
    required this.below,
    required this.gap,
  });

  final Rect anchor;
  final bool right, below;
  final double gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = right ? anchor.right - child.width : anchor.left;
    final y = below ? anchor.bottom + gap : anchor.top - gap - child.height;
    // Keep 8 from the screen's sides.
    return Offset(
      x.clamp(8, math.max(8, size.width - child.width - 8)),
      y.clamp(0, math.max(0, size.height - child.height)),
    );
  }

  @override
  bool shouldRelayout(_MenuPosition old) =>
      old.anchor != anchor || old.right != right || old.below != below;
}

/// The popover (UI spec §11.7): `color.surfaceRaised`, `radius.m`,
/// `elevation.floating`, at least 232 wide, 44 rows (icon 20 + `bodyL`,
/// 16 inset) with dividers between [groups]; a chosen option shows a check.
/// [showDkMenu] opens it; a row closes it, then runs its action.
class DkMenu extends StatelessWidget {
  const DkMenu({super.key, required this.groups, this.closeOnTap = true});

  final List<List<DkAction>> groups;

  /// Off where the menu isn't a route of its own (the catalogue).
  final bool closeOnTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(t.radius.m);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 232, maxWidth: 320),
      child: DecoratedBox(
        decoration: t.surfaceAt(DkLevel.floating, radius: radius),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: t.space.xs),
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, group) in groups.indexed) ...[
                    if (i > 0)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: t.space.xs),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: t.divider.color,
                        ),
                      ),
                    for (final action in group)
                      DkActionRow(
                        action,
                        close: closeOnTap,
                        minHeight: 44,
                        padding: EdgeInsets.symmetric(horizontal: t.space.l),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
