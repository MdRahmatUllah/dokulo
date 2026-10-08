import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/motion/dk_reorder_motion.dart';
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

/// How long a press lifts an item (§12.2), not the platform's 500 ms.
const dkLiftDelay = Duration(milliseconds: 300);

/// Keeps a scrollable moving while a dragging finger is within [edge] of
/// its leading or trailing side (§12.2). Feed it every drag update; stop it
/// when the drag ends.
class DkEdgeScroller {
  DkEdgeScroller(this.controller, {this.axis = Axis.vertical, this.onScroll});

  final ScrollController controller;
  final Axis axis;

  /// After every step: the finger stayed still but what's under it moved.
  final VoidCallback? onScroll;

  static const edge = 48.0;

  /// Pixels per frame.
  static const step = 6.0;

  Timer? _timer;

  bool get scrolling => _timer != null;

  /// [local] is the finger in the scrollable's own box, of [size].
  void update(Offset local, Size size) {
    final at = axis == Axis.vertical ? local.dy : local.dx;
    final length = axis == Axis.vertical ? size.height : size.width;
    final delta = at < edge
        ? -step
        : at > length - edge
        ? step
        : 0.0;
    if (delta == 0) return stop();
    _timer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!controller.hasClients) return;
      final p = controller.position;
      final next = (p.pixels + delta).clamp(
        p.minScrollExtent,
        p.maxScrollExtent,
      );
      if (next == p.pixels) return;
      controller.jumpTo(next);
      onScroll?.call();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

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

/// For a `ReorderableListView` (merge cards, workflow steps, the page tray)
/// with `buildDefaultDragHandles: false`: wrap each item so a 300 ms press
/// lifts it (§12.2) instead of the platform's 500 ms.
class DkReorderStartListener extends ReorderableDragStartListener {
  const DkReorderStartListener({
    super.key,
    required super.child,
    required super.index,
    super.enabled,
  });

  @override
  MultiDragGestureRecognizer createRecognizer() =>
      DelayedMultiDragGestureRecognizer(delay: dkLiftDelay, debugOwner: this);
}

/// A `ReorderableListView.proxyDecorator`: the lifted item grows to 1.04
/// with the floating shadow (DkLift), on a Material for its ink.
Widget dkReorderProxy(Widget child, int index, Animation<double> animation) =>
    Material(
      type: MaterialType.transparency,
      child: DkLift(lifted: true, child: child),
    );
