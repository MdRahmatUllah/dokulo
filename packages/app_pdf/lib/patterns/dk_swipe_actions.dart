import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../components/dk_icon.dart';
import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';

/// Swipe actions on a Files row (DK-0224; UI spec §12.3): swiping the row
/// left reveals Share (`color.primary`) and Delete (`color.danger`), each
/// 80 wide with its icon over its label. Let go past half an action and the
/// row stays open; less and it closes; swipe most of the way across and it
/// deletes ([onDelete]; the screen then shows "Moved to Recently deleted ·
/// Undo"). It snaps in `motion.fast`, at once with Reduce Motion.
///
/// Swiping is a gesture only: screen readers get Share and Delete as
/// actions. [builder] builds the row and puts them on the row's own
/// semantics node (DkFileCard's `semanticsActions`, with selection mode's
/// Select if it has one), so they are on the node screen readers focus.
// ponytail: left-to-right only, as EN and DE are; mirror the drag for RTL.
class DkSwipeActions extends StatefulWidget {
  const DkSwipeActions({
    super.key,
    required this.builder,
    required this.onShare,
    required this.onDelete,
  });

  final Widget Function(
    BuildContext context,
    Map<CustomSemanticsAction, VoidCallback> actions,
  )
  builder;
  final VoidCallback onShare, onDelete;

  /// Each action's width; open, the row moves by both.
  static const actionWidth = 80.0;

  @override
  State<DkSwipeActions> createState() => _DkSwipeActionsState();
}

class _DkSwipeActionsState extends State<DkSwipeActions>
    with SingleTickerProviderStateMixin {
  /// How far the row has moved left, in dp (0 … the row's width).
  late final _offset = AnimationController.unbounded(vsync: this);
  var _width = 0.0;

  static const _open = 2 * DkSwipeActions.actionWidth;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _settle(double to) {
    final m = context.motion(DkMotionKind.fast);
    if (m.crossFade) {
      _offset.value = to;
    } else {
      _offset.animateTo(to, duration: m.duration, curve: m.curve);
    }
  }

  void _drag(DragUpdateDetails d) =>
      _offset.value = (_offset.value - d.delta.dx).clamp(0.0, _width);

  void _release(DragEndDetails d) {
    final moved = _offset.value;
    if (moved > _width * 0.6) {
      // A full swipe: it deletes.
      _settle(0);
      widget.onDelete();
    } else {
      _settle(moved > DkSwipeActions.actionWidth / 2 ? _open : 0);
    }
  }

  void _run(VoidCallback action) {
    _settle(0);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    Widget action(
      IconData icon,
      String label,
      Color fill,
      Color ink,
      VoidCallback onTap,
    ) => SizedBox(
      width: DkSwipeActions.actionWidth,
      child: Material(
        color: fill,
        child: InkWell(
          onTap: () => _run(onTap),
          overlayColor: WidgetStatePropertyAll(t.state.pressed),
          splashFactory: NoSplash.splashFactory,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: t.space.xxs,
            children: [
              DkIcon(icon, color: ink),
              Text(label, style: t.text.caption.copyWith(color: ink)),
            ],
          ),
        ),
      ),
    );
    final actions = {
      CustomSemanticsAction(label: l.common_share): widget.onShare,
      CustomSemanticsAction(label: l.common_delete): widget.onDelete,
    };
    return LayoutBuilder(
      builder: (context, box) {
        _width = box.maxWidth;
        return GestureDetector(
          // From where the finger went down: the row's own tap and long
          // press hold the drag back for the slop, which mustn't be lost.
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragUpdate: _drag,
          onHorizontalDragEnd: _release,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _offset,
              builder: (context, row) => Stack(
                children: [
                  // The actions, behind the row; screen readers use the
                  // row's actions instead.
                  if (_offset.value > 0)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 0,
                      child: ExcludeSemantics(
                        child: Row(
                          children: [
                            action(
                              DkIcons.share(context),
                              l.common_share,
                              c.primary,
                              c.onPrimary,
                              widget.onShare,
                            ),
                            action(
                              DkIcons.delete,
                              l.common_delete,
                              c.danger,
                              c.onDanger,
                              widget.onDelete,
                            ),
                          ],
                        ),
                      ),
                    ),
                  Transform.translate(
                    offset: Offset(-_offset.value, 0),
                    child: row,
                  ),
                ],
              ),
              // The row covers the actions: give it the page's colour.
              child: ColoredBox(
                color: c.background,
                child: widget.builder(context, actions),
              ),
            ),
          ),
        );
      },
    );
  }
}
