import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/motion/dk_reorder_motion.dart';

export '../components/motion/dk_reorder_motion.dart'
    show DkEdgeScroller, DkReorderStartListener, dkLiftDelay, dkReorderProxy;
import '../theme/dk_tokens.dart';
import '../theme/haptics.dart';

// Drag and drop (UI spec §12.2; DK-0223), once for every screen: files onto
// folders, page reorder, pinned tiles, merge cards, the page tray, workflow
// steps. A long-press of 300 ms lifts the item (×1.04, the floating shadow);
// the others make room; a list or grid scrolls while the finger is within
// 48 dp of its edge; the landing plays the light haptic. A move between
// folders offers Undo (`showDkUndo(context, DkUndo.move, …)`). Screen
// readers move items with actions instead: "Move left / right" in a
// reorderable list, the Move command in a file's menu.

/// An item that a long-press (300 ms) lifts and the finger carries: a file
/// to drop on a folder (§12.2). It plays the selection haptic as it lifts;
/// while it's away its place shows it dimmed. [DkDropTarget] takes it.
class DkDraggable<T extends Object> extends ConsumerWidget {
  const DkDraggable({
    super.key,
    required this.data,
    required this.child,
    this.borderRadius,
    this.onDragStarted,
    this.onDragEnd,
  });

  final T data;
  final Widget child;

  /// The item's shape, so the lifted shadow follows it.
  final BorderRadius? borderRadius;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, box) => LongPressDraggable<T>(
      data: data,
      delay: dkLiftDelay,
      hapticFeedbackOnStart: false, // ours, below
      onDragStarted: () {
        ref.read(hapticsProvider).selected();
        onDragStarted?.call();
      },
      onDragEnd: (_) => onDragEnd?.call(),
      // The lifted copy is as wide as the item, in the overlay.
      feedback: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: box.maxWidth.isFinite ? box.maxWidth : null,
          child: DkLift(lifted: true, borderRadius: borderRadius, child: child),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: context.tokens.state.disabledOpacity,
        child: child,
      ),
      child: child,
    ),
  );
}

/// Where a [DkDraggable] lands (a folder, §12.2): [builder] draws it with
/// whether one hovers over it (DkFolderCard's `dropTarget`); a drop plays
/// the light haptic and calls [onDrop].
class DkDropTarget<T extends Object> extends ConsumerWidget {
  const DkDropTarget({
    super.key,
    required this.onDrop,
    required this.builder,
    this.accepts,
  });

  final ValueChanged<T> onDrop;
  final Widget Function(BuildContext context, bool hovering) builder;

  /// Which items it takes; all by default.
  final bool Function(T data)? accepts;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DragTarget<T>(
    onWillAcceptWithDetails: (d) => accepts?.call(d.data) ?? true,
    onAcceptWithDetails: (d) {
      ref.read(hapticsProvider).dropped();
      onDrop(d.data);
    },
    builder: (context, hovering, _) => builder(context, hovering.isNotEmpty),
  );
}
