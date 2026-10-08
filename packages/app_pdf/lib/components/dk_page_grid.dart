import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../theme/dk_tokens.dart';
import 'dk_page_thumb.dart';
import 'motion/dk_reorder_motion.dart';

/// The pages of a document as a grid (UI spec §11.5; DK-0154): DkPageThumbs,
/// 3 columns on phones, pinch for 2 to 6, a 12 gutter. Virtualised: only the
/// visible rows are built, so 300+ pages scroll smoothly.
///
/// With [onReorder], a long-press (300 ms) lifts a page; while it is dragged
/// a 2 dp primary insertion line with 8 dp end caps shows where it will land,
/// and the grid scrolls when the finger is within 48 dp of an edge (§12.2).
/// Screen readers get "Move left / right / to the start / to the end".
class DkPageGrid extends StatefulWidget {
  const DkPageGrid({
    super.key,
    required this.pageIds,
    required this.pageBuilder,
    this.selected = const {},
    this.onTap,
    this.onLongPress,
    this.onReorder,
    this.initialColumns = 3,
    this.onColumnsChanged,
    this.controller,
  });

  /// One stable id per page, in order.
  final List<Object> pageIds;

  /// The rendered page at [index], or null while it loads.
  final Widget? Function(BuildContext context, int index) pageBuilder;

  /// Indexes of the selected pages (selection mode, §12.1).
  final Set<int> selected;
  final ValueChanged<int>? onTap;

  /// Also called when a drag starts: lifting a page enters selection mode.
  final ValueChanged<int>? onLongPress;

  /// The page at `from` moves to index `to` (its place after the move).
  /// The caller plays the landing haptic (`hapticsProvider.dropped()`) and
  /// any settle animation (§9's 220 ms, `DkSlot`).
  final void Function(int from, int to)? onReorder;
  final int initialColumns;
  final ValueChanged<int>? onColumnsChanged;
  final ScrollController? controller;

  static const minColumns = 2, maxColumns = 6;

  @override
  State<DkPageGrid> createState() => _DkPageGridState();
}

class _DkPageGridState extends State<DkPageGrid> {
  late int _columns = widget.initialColumns;
  ScrollController? _ownController;
  ScrollController get _scroll =>
      widget.controller ?? (_ownController ??= ScrollController());

  // Pinch: the two pointers and the distance the last step started from.
  final _pointers = <int, Offset>{};
  double? _pinchStart;

  // Dragging: the page, where it would land, and the edge auto-scroll.
  int? _dragging, _insertAt;

  /// The finger is past the middle of a row's last page: the line shows at
  /// that row's end, not before the next row's first page (the same slot).
  bool _atRowEnd = false;
  Offset? _finger;
  Timer? _edgeScroll;

  /// The last finger down, and the one carrying the lifted page.
  int? _lastDown, _dragPointer;
  late _Metrics _m;

  @override
  void dispose() {
    _edgeScroll?.cancel();
    _ownController?.dispose();
    super.dispose();
  }

  void _setColumns(int columns) {
    // No more columns than keep a cell 48 dp wide (6 on an SE is 47).
    final fit = ((_m.width - 2 * _m.padding + _m.gutter) / (48 + _m.gutter))
        .floor();
    final most = math.max(
      DkPageGrid.minColumns,
      math.min(DkPageGrid.maxColumns, fit),
    );
    final c = math.min(math.max(columns, DkPageGrid.minColumns), most);
    if (c == _columns) return;
    setState(() => _columns = c);
    widget.onColumnsChanged?.call(c);
  }

  void _pointer(PointerEvent e) {
    if (e is PointerDownEvent) _lastDown = e.pointer;
    if (_dragging != null && e.pointer == _dragPointer) {
      // The grid, not the lifted cell, follows the drag: GridView disposes
      // a cell (and its Draggable) once auto-scroll takes it out of view.
      if (e is PointerMoveEvent) _dragUpdate(e.position);
      if (e is PointerUpEvent || e is PointerCancelEvent) _dragEnd();
    }
    if (e is PointerDownEvent || e is PointerMoveEvent) {
      _pointers[e.pointer] = e.localPosition;
    } else {
      _pointers.remove(e.pointer);
    }
    if (_pointers.length != 2) {
      _pinchStart = null;
      return;
    }
    final [a, b] = _pointers.values.toList();
    final distance = (a - b).distance;
    final start = _pinchStart ??= distance;
    // Spread a quarter wider: one column fewer (bigger pages); and back.
    if (distance > start * 1.25) {
      _setColumns(_columns - 1);
      _pinchStart = distance;
    } else if (distance < start * 0.8) {
      _setColumns(_columns + 1);
      _pinchStart = distance;
    }
  }

  /// The slot under [local] (grid coordinates): 0 is before the first page,
  /// `pageIds.length` after the last; and whether it is at a row's end.
  (int, bool) _slotAt(Offset local) {
    final m = _m;
    final x = local.dx - m.padding;
    final y = local.dy + _scroll.offset - m.padding;
    final col = (x / m.pitchX).floor().clamp(0, _columns - 1);
    final inCell = (x - col * m.pitchX) / m.cell.width;
    final row = math.max(0, (y / m.pitchY).floor());
    final right = inCell > 0.5;
    final slot = (row * _columns + col + (right ? 1 : 0)).clamp(
      0,
      widget.pageIds.length,
    );
    return (slot, right && col == _columns - 1);
  }

  void _showSlot(Offset local) {
    final (slot, atRowEnd) = _slotAt(local);
    if (slot != _insertAt || atRowEnd != _atRowEnd) {
      setState(() {
        _insertAt = slot;
        _atRowEnd = atRowEnd;
      });
    }
  }

  void _dragUpdate(Offset global) {
    final box = context.findRenderObject()! as RenderBox;
    final local = box.globalToLocal(global);
    _finger = local;
    _showSlot(local);
    // Within 48 dp of an edge: keep scrolling while the finger stays there.
    const edge = 48.0;
    final dy = local.dy < edge
        ? -6.0
        : local.dy > box.size.height - edge
        ? 6.0
        : 0.0;
    if (dy == 0) {
      _edgeScroll?.cancel();
      _edgeScroll = null;
    } else {
      _edgeScroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
        final p = _scroll.position;
        final next = (p.pixels + dy).clamp(
          p.minScrollExtent,
          p.maxScrollExtent,
        );
        if (next == p.pixels) return;
        _scroll.jumpTo(next);
        _showSlot(_finger!);
      });
    }
  }

  void _dragEnd() {
    _edgeScroll?.cancel();
    _edgeScroll = null;
    final from = _dragging, slot = _insertAt;
    _dragPointer = null;
    setState(() => _dragging = _insertAt = null);
    if (from == null || slot == null) return;
    final to = slot > from ? slot - 1 : slot;
    if (to != from) widget.onReorder!(from, to);
  }

  void _move(int from, int to) {
    if (to != from) widget.onReorder!(from, to);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        _m = _Metrics(
          width: constraints.maxWidth,
          columns: _columns,
          padding: t.space.l,
          gutter: t.space.m,
          captionHeight:
              t.space.xs +
              MediaQuery.textScalerOf(context)
                  .scale(t.text.caption.fontSize! * t.text.caption.height!),
        );
        return Listener(
          onPointerDown: _pointer,
          onPointerMove: _pointer,
          onPointerUp: _pointer,
          onPointerCancel: _pointer,
          child: GridView.builder(
            controller: _scroll,
            padding: EdgeInsets.all(_m.padding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
              crossAxisSpacing: _m.gutter,
              mainAxisSpacing: _m.gutter,
              childAspectRatio: _m.cell.aspectRatio,
            ),
            itemCount: widget.pageIds.length,
            itemBuilder: (context, i) => _cell(context, i),
          ),
        );
      },
    );
  }

  Widget _cell(BuildContext context, int i) {
    final t = context.tokens;
    final count = widget.pageIds.length;
    final page = widget.pageBuilder(context, i);
    Widget thumb({bool interactive = true, bool lifted = false}) => DkPageThumb(
      pageNumber: i + 1,
      pageCount: count,
      page: page,
      lifted: lifted,
      selected: widget.selected.contains(i),
      onTap: interactive && widget.onTap != null
          ? () => widget.onTap!(i)
          : null,
      onLongPress: interactive && widget.onReorder == null
          ? (widget.onLongPress == null ? null : () => widget.onLongPress!(i))
          : null,
    );

    Widget cell = thumb();
    if (widget.onReorder != null) {
      final l10n = WidgetsLocalizations.of(context);
      cell = Semantics(
        container: true,
        customSemanticsActions: {
          if (i > 0) ...{
            CustomSemanticsAction(label: l10n.reorderItemToStart): () =>
                _move(i, 0),
            CustomSemanticsAction(label: l10n.reorderItemLeft): () =>
                _move(i, i - 1),
          },
          if (i < count - 1) ...{
            CustomSemanticsAction(label: l10n.reorderItemRight): () =>
                _move(i, i + 1),
            CustomSemanticsAction(label: l10n.reorderItemToEnd): () =>
                _move(i, count - 1),
          },
        },
        child: LongPressDraggable<int>(
          data: i,
          delay: const Duration(milliseconds: 300),
          onDragStarted: () {
            _dragPointer = _lastDown;
            setState(() => _dragging = i);
            widget.onLongPress?.call(i);
          },
          // The lifted page floats just above the finger, so neither the
          // finger nor the page hides the insertion line under it.
          dragAnchorStrategy: (_, _, _) =>
              Offset(_m.cell.width / 2, _m.cell.height + t.space.s),
          // The lifted page grows 2 % and takes `raised` (UI spec §4.4).
          feedback: Material(
            type: MaterialType.transparency,
            child: Transform.scale(
              scale: t.state.draggedScale,
              child: SizedBox(
                width: _m.cell.width,
                child: thumb(interactive: false, lifted: true),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: t.state.disabledOpacity,
            child: thumb(interactive: false),
          ),
          child: cell,
        ),
      );
      // The insertion line: before this page, or after it when it is the
      // last page or the finger is at its row's end.
      final at = _insertAt;
      final before = at == i && !_atRowEnd;
      final after = at == i + 1 && (i == count - 1 || _atRowEnd);
      final line = _dragging != null && (before || after);
      // Always a Stack, the line or not: swapping the cell's root widget
      // would dispose the Draggable in the middle of its drag.
      {
        cell = Stack(
          clipBehavior: Clip.none,
          children: [
            cell,
            // The I-beam (#1128), centred in the gutter.
            if (line)
              Positioned(
                top: 0,
                left: before ? -_m.gutter / 2 - DkInsertionLine.cap / 2 : null,
                right: after ? -_m.gutter / 2 - DkInsertionLine.cap / 2 : null,
                child: IgnorePointer(
                  child: DkInsertionLine(
                    length: _m.cell.width / _Metrics.pageAspect,
                  ),
                ),
              ),
          ],
        );
      }
    }
    return cell;
  }
}

/// The grid's cell sizes for a width and a column count.
class _Metrics {
  _Metrics({
    required this.width,
    required this.columns,
    required this.padding,
    required this.gutter,
    required this.captionHeight,
  });

  /// Pages are shown 3 : 4 (a page's own shape is fitted inside).
  static const pageAspect = 3 / 4;

  final double width, padding, gutter, captionHeight;
  final int columns;

  late final Size cell = () {
    final w = (width - 2 * padding - (columns - 1) * gutter) / columns;
    return Size(w, w / pageAspect + captionHeight);
  }();
  double get pitchX => cell.width + gutter;
  double get pitchY => cell.height + gutter;
}
