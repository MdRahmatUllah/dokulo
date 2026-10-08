import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_box_frame.dart';
import 'dk_icon.dart';
import 'dk_page_thumb.dart';
import 'dk_ring.dart';

/// The page strip of the scan review and the editors (UI spec §11.5;
/// DK-0152): 56 × 72 pages with their numbers, 8 apart, the [current] page
/// ringed, a trailing "+" tile. Long-press a page and drag it to reorder;
/// screen readers get "Move left / right" actions instead.
class DkPageTray extends StatelessWidget {
  const DkPageTray({
    super.key,
    required this.pageIds,
    required this.pageBuilder,
    this.current,
    this.onSelect,
    this.onReorder,
    this.onAdd,
  });

  /// One stable id per page, in order (they key the pages while dragging).
  final List<Object> pageIds;

  /// The rendered page at [index], or null while it loads.
  final Widget? Function(BuildContext context, int index) pageBuilder;
  final int? current;
  final ValueChanged<int>? onSelect;

  /// The page at `from` moves to index `to` (its place after the move).
  /// The caller plays the landing haptic (`hapticsProvider.dropped()`, §9).
  final void Function(int from, int to)? onReorder;

  /// The "+" tile; hidden when null.
  final VoidCallback? onAdd;

  static const _page = Size(56, 72);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // The ring sits 4 dp outside a page: room for it above.
    final top = t.space.xs;
    final height =
        top +
        _page.height +
        t.space.xs +
        MediaQuery.textScalerOf(context)
            .scale(t.text.caption.fontSize! * t.text.caption.height!);
    Widget cell(int i) => Padding(
      key: ValueKey(pageIds[i]),
      padding: EdgeInsets.only(right: t.space.s),
      child: SizedBox(
        width: _page.width,
        child: DkPageThumb(
          pageNumber: i + 1,
          pageCount: pageIds.length,
          page: pageBuilder(context, i),
          current: i == current,
          aspectRatio: _page.width / _page.height,
          onTap: onSelect == null ? null : () => onSelect!(i),
        ),
      ),
    );
    final add = onAdd == null
        ? null
        : Align(
            alignment: Alignment.topLeft,
            child: _AddTile(size: _page, onTap: onAdd!),
          );
    final padding = EdgeInsets.fromLTRB(t.space.l, top, t.space.l, 0);
    return SizedBox(
      height: height,
      child: onReorder == null
          ? ListView(
              scrollDirection: Axis.horizontal,
              padding: padding,
              children: [
                for (var i = 0; i < pageIds.length; i++) cell(i),
                ?add,
              ],
            )
          : ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              padding: padding,
              itemCount: pageIds.length,
              itemBuilder: (context, i) => cell(i),
              footer: add,
              onReorderItem: onReorder!,
              // A lifted page grows 2 % (UI spec §4.4), no Material shadow.
              proxyDecorator: (child, _, animation) => AnimatedBuilder(
                animation: animation,
                builder: (context, child) => Transform.scale(
                  scale: lerpDouble(1, t.state.draggedScale, animation.value),
                  child: child,
                ),
                // The lifted copy is in the overlay: its InkWell needs a
                // Material above it.
                child: Material(type: MaterialType.transparency, child: child),
              ),
            ),
    );
  }
}

/// The trailing "+": a dashed 1 dp `outlineStrong` tile with the add icon.
class _AddTile extends StatefulWidget {
  const _AddTile({required this.size, required this.onTap});
  final Size size;
  final VoidCallback onTap;

  @override
  State<_AddTile> createState() => _AddTileState();
}

class _AddTileState extends State<_AddTile> {
  bool _pressed = false, _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(t.radius.xs);
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).common_add_pages,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (v) => setState(() => _pressed = v),
        onFocusChange: (v) => setState(() => _focused = v),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        child: DkRing(
          side: _focused ? t.focusRing : null,
          radius: t.radius.xs,
          child: CustomPaint(
            painter: DkDashedBorder(t.color.outlineStrong, radius: radius),
            child: Container(
              width: widget.size.width,
              height: widget.size.height,
              decoration: BoxDecoration(
                color: _pressed ? t.state.pressed : null,
                borderRadius: radius,
              ),
              child: DkIcon(DkIcons.add, color: t.color.iconSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
