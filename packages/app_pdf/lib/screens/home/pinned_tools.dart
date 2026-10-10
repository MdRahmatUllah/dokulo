import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_action_sheet.dart';
import '../../components/dk_button.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_menu.dart';
import '../../components/dk_sheet.dart';
import '../../components/dk_tappable.dart';
import '../../components/dk_text_field.dart';
import '../../components/dk_tool_tile.dart';
import '../../l10n/app_localizations.dart';
import '../../patterns/dk_about_tool.dart';
import '../../patterns/dk_undo.dart';
import '../../providers/database_providers.dart';
import '../../providers/files_providers.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';
import '../../tools/tool_catalogue.dart';

/// Home's "Your tools" (DK-0244, DK-0248, DK-0249; UI spec §15.1), as
/// slivers: the header with Edit, the pinned tiles 4 across. A tap opens
/// T2; a long-press, the menu (Unpin with Undo, About this tool). In edit
/// mode each tile has a minus badge, a long-press drags it to a new place,
/// and while fewer than 8 are pinned an "Add tool" tile opens the add sheet.
class PinnedToolsSection extends ConsumerStatefulWidget {
  const PinnedToolsSection({super.key});

  /// Home holds 2 rows of 4.
  static const max = 8;

  @override
  ConsumerState<PinnedToolsSection> createState() => _PinnedState();
}

class _PinnedState extends ConsumerState<PinnedToolsSection> {
  var _editing = false;

  List<String> get _pinned =>
      ref.read(pinnedToolsProvider).value ?? defaultPinnedTools;

  Future<void> _save(List<String> ids) =>
      savePinnedTools(ref.read(appDatabaseProvider), ids);

  Future<void> _unpin(String id) async {
    final l = AppLocalizations.of(context);
    final before = _pinned;
    await _save([
      for (final p in before)
        if (p != id) p,
    ]);
    if (!mounted) return;
    await showDkUndo(
      context,
      DkUndo.move,
      l.home_unpinned(ToolCatalogue.of(id).name(l)),
      onUndo: () => _save(before), // the exact position again
    );
  }

  void _menu(BuildContext anchor, String id) {
    final l = AppLocalizations.of(anchor);
    showDkMenu(
      anchor,
      groups: [
        [
          DkAction(
            icon: DkIcons.pin,
            label: l.home_unpin,
            onTap: () => _unpin(id),
          ),
          DkAction(
            icon: DkIcons.info,
            label: l.home_about_tool,
            onTap: () => showAboutTool(
              context,
              ToolCatalogue.of(id),
              onOpen: () => context.push(Routes.tool(id)),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _move(String id, int to) async {
    final ids = [..._pinned]..remove(id);
    ids.insert(to.clamp(0, ids.length), id);
    await _save(ids);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final large = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final pinned = (ref.watch(pinnedToolsProvider).value ?? defaultPinnedTools)
        .take(PinnedToolsSection.max)
        .toList();
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            t.space.l,
            t.space.xl,
            t.space.s,
            t.space.s,
          ),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l.home_your_tools,
                      style: t.text.titleS.copyWith(color: t.color.textPrimary),
                    ),
                  ),
                ),
                DkButton(
                  label: _editing ? l.common_done : l.home_edit,
                  variant: DkButtonVariant.tertiary,
                  size: DkButtonSize.compact,
                  onPressed: () => setState(() => _editing = !_editing),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: t.space.l),
          // At large text (200 %) 2 across, taller, so names wrap whole
          // (DK-0254); on tablets 6, or 8 from 840 dp (UI spec §30).
          sliver: SliverLayoutBuilder(
            builder: (context, box) => SliverGrid.count(
              crossAxisCount: _columns(box.crossAxisExtent, large: large),
              mainAxisSpacing: t.space.m,
              crossAxisSpacing: t.space.m,
              // A phone's tile is 0.78 wide to tall; on a tablet, the same
              // 108 dp of height in a wider column.
              childAspectRatio: large
                  ? 1.0
                  : _columns(box.crossAxisExtent, large: false) == 4
                  ? 0.78
                  : _tileWidth(box.crossAxisExtent, t.space.m) / 108,
              children: [
                for (final (i, id) in pinned.indexed)
                  if (_editing)
                    _EditTile(
                      id: id,
                      onRemove: () => _unpin(id),
                      onDrop: (dragged) => _move(dragged, i),
                    )
                  else
                    Builder(
                      builder: (anchor) => DkToolTile(
                        toolId: id,
                        onTap: () => context.push(Routes.tool(id)),
                        onLongPress: () => _menu(anchor, id),
                      ),
                    ),
                if (_editing && pinned.length < PinnedToolsSection.max)
                  _AddTile(
                    onTap: () => showAddTool(context, pinned, (id) {
                      _save([...pinned, id]);
                    }),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A tile in edit mode: the minus badge; a long-press drags it, and a tile
/// dropped on it takes its place.
class _EditTile extends StatelessWidget {
  const _EditTile({
    required this.id,
    required this.onRemove,
    required this.onDrop,
  });

  final String id;
  final VoidCallback onRemove;
  final ValueChanged<String> onDrop;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final tile = DkToolTile(toolId: id, onTap: () {});
    return LayoutBuilder(
      builder: (context, box) => DragTarget<String>(
        onWillAcceptWithDetails: (d) => d.data != id,
        onAcceptWithDetails: (d) => onDrop(d.data),
        builder: (context, hovering, _) => LongPressDraggable<String>(
          data: id,
          // The tile follows the finger at its own size; its place stays,
          // faded.
          feedback: SizedBox(
            width: box.maxWidth,
            height: box.maxHeight,
            child: Material(type: MaterialType.transparency, child: tile),
          ),
          childWhenDragging: Opacity(opacity: 0.4, child: tile),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: tile),
              // On the icon square's top-left corner (48 dp, centred; the
              // home-edit frame), its 44 dp target around it.
              Positioned(
                top: -18,
                left: box.maxWidth / 2 - 24 - 22,
                child: Semantics(
                  button: true,
                  label: l.home_unpin_named(ToolCatalogue.of(id).name(l)),
                  excludeSemantics: true,
                  onTap: onRemove,
                  child: DkTappable(
                    onTap: onRemove,
                    radius: 24,
                    builder: (context, pressed) => SizedBox.square(
                      dimension: 44,
                      child: Align(
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: t.color.danger,
                          ),
                          child: DkIcon(
                            DkIcons.remove,
                            size: DkIconSize.s,
                            color: t.color.onDanger,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Add tool": a dashed outline with the add icon, in the next free slot.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l.home_add_tool,
      excludeSemantics: true,
      onTap: onTap,
      child: DkTappable(
        onTap: onTap,
        radius: t.radius.m,
        builder: (context, pressed) => Column(
          spacing: t.space.xs,
          children: [
            CustomPaint(
              painter: _Dashed(t.color.outlineStrong, t.radius.m),
              child: SizedBox.square(
                dimension: 48,
                child: DkIcon(DkIcons.add, color: t.color.primary),
              ),
            ),
            Text(
              l.home_add_tool,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: t.text.labelM.copyWith(color: t.color.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dashed extends CustomPainter {
  const _Dashed(this.colour, this.radius);

  final Color colour;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Dashed old) => old.colour != colour;
}

/// "Add a tool" (DK-0249): the tools not pinned yet (Scan is the centre
/// button), filterable; a tap pins one at the end.
Future<void> showAddTool(
  BuildContext context,
  List<String> pinned,
  ValueChanged<String> onAdd,
) {
  final l = AppLocalizations.of(context);
  return showDkSheet<void>(
    context,
    title: l.home_add_tool_title,
    showClose: true,
    detent: DkSheetDetent.large,
    body: _AddToolList(pinned: pinned, onAdd: onAdd),
  );
}

class _AddToolList extends StatefulWidget {
  const _AddToolList({required this.pinned, required this.onAdd});

  final List<String> pinned;
  final ValueChanged<String> onAdd;

  @override
  State<_AddToolList> createState() => _AddToolListState();
}

class _AddToolListState extends State<_AddToolList> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final q = _query.trim().toLowerCase();
    final tools = [
      for (final tool in ToolCatalogue.all)
        if (tool.category != null && !widget.pinned.contains(tool.id))
          if (q.isEmpty ||
              tool.name(l).toLowerCase().contains(q) ||
              tool.description(l).toLowerCase().contains(q))
            tool,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: t.space.s,
      children: [
        DkSearchField(
          hint: l.tools_search_hint,
          onChanged: (v) => setState(() => _query = v),
        ),
        for (final tool in tools)
          DkToolRow(
            toolId: tool.id,
            showDescription: true,
            trailingIcon: DkIcons.addCircle,
            onTap: () {
              Navigator.pop(context);
              widget.onAdd(tool.id);
            },
          ),
      ],
    );
  }
}

/// 4 tiles across on a phone, 6 from 600 dp, 8 from 840 (UI spec §30); 2 at
/// large text (DK-0254).
int _columns(double width, {required bool large}) => large
    ? 2
    : width >= 840
    ? 8
    : width >= 600
    ? 6
    : 4;

double _tileWidth(double width, double gap) {
  final n = _columns(width, large: false);
  return (width - (n - 1) * gap) / n;
}
