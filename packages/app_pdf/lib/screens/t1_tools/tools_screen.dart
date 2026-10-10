import 'package:ai_core/ai_core.dart' show AiEligibility, gemmaNeeds;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent, ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_chip.dart';
import '../../components/dk_empty_state.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_illustration.dart';
import '../../components/dk_tappable.dart';
import '../../components/dk_text_action.dart';
import '../../components/dk_text_field.dart';
import '../../components/dk_tool_tile.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../patterns/dk_about_tool.dart';
import '../../patterns/dk_ai_not_eligible.dart';
import '../../providers/device_providers.dart';
import '../../routes/routes.dart';
import '../../theme/dk_layout.dart';
import '../../theme/dk_tokens.dart';
import '../../tools/tool_catalogue.dart';
import '../../tools/tool_search.dart';

/// T1 · Tools (DK-0256; UI spec §15.2): the large top bar, the search field,
/// the category chips (pinned under the bar; a tap scrolls to the section,
/// and the selection follows the scroll), then each section's header with
/// its count and a 4-column grid of tiles. A tile opens T2. On a phone with
/// too little memory an AI tile opens the "not available" sheet instead; on
/// a 32-bit phone the AI section isn't there.
class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  final _scroll = ScrollController();
  final _sections = {for (final c in ToolCategory.values) c: GlobalKey()};
  final _chipsKey = GlobalKey();
  final _chipKeys = {
    for (final c in [null, ...ToolCategory.values]) c: GlobalKey(),
  };

  /// Null: All.
  ToolCategory? _selected;

  /// After a chip's tap the selection stays, even where the section can't
  /// reach the chips (the last ones), until the user scrolls again.
  bool _jumping = false;

  /// Gemma's eligibility on this phone, from the last build.
  AiEligibility? _ai;

  /// The search field (DK-0257); typing replaces the sections with rows.
  final _search = TextEditingController();
  String get _query => _search.text.trim();

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The chips' bottom edge, in global coordinates.
  double _chipsBottom() {
    final box = _chipsKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? 0 : box.localToGlobal(Offset(0, box.size.height)).dy;
  }

  double? _sectionTop(ToolCategory c) {
    final box = _sections[c]!.currentContext?.findRenderObject() as RenderBox?;
    return box?.localToGlobal(Offset.zero).dy;
  }

  /// The last section whose header has reached the chips.
  void _follow() {
    if (_jumping) return;
    final line = _chipsBottom() + 1;
    ToolCategory? current;
    final end = _scroll.position.pixels >= _scroll.position.maxScrollExtent - 1;
    if (_scroll.offset > 0) {
      for (final c in _visible) {
        final top = _sectionTop(c);
        if (top != null && top <= line) current = c;
      }
      // The last sections can't reach the chips: at the end, the last one.
      if (end) current = _visible.last;
    }
    if (current != _selected) _select(current);
  }

  /// Selects [c]'s chip and scrolls the chip row to show it.
  void _select(ToolCategory? c) {
    setState(() => _selected = c);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chip = _chipKeys[c]!.currentContext;
      if (chip == null || !chip.mounted) return;
      // The chip row only: Scrollable.ensureVisible would scroll the page
      // back up to the pinned chips too.
      Scrollable.maybeOf(chip)?.position.ensureVisible(
        chip.findRenderObject()!,
        alignment: 0.5,
        duration: context.motion(DkMotionKind.fast).duration,
      );
    });
  }

  Future<void> _jump(ToolCategory? c) async {
    _select(c);
    final top = c == null ? null : _sectionTop(c);
    final target = c == null
        ? 0.0
        : top == null
        ? null
        : _scroll.offset + top - _chipsBottom();
    if (target == null) return;
    final m = context.motion(DkMotionKind.standard);
    _jumping = true;
    final to = target.clamp(0.0, _scroll.position.maxScrollExtent);
    if (m.crossFade) {
      _scroll.jumpTo(to);
    } else {
      await _scroll.animateTo(to, duration: m.duration, curve: m.curve);
    }
  }

  List<ToolCategory> get _visible => [
    for (final c in ToolCategory.values)
      if (c != ToolCategory.ai || _ai != AiEligibility.notArm64) c,
  ];

  Future<void> _open(ToolInfo tool) async {
    if (tool.category == ToolCategory.ai && _ai == AiEligibility.tooLittleRam) {
      final ram = (await ref.read(deviceCapabilitiesProvider.future)).totalRam;
      if (!mounted) return;
      await showAiNotEligible(
        context,
        needGb: gemmaNeeds.advertisedGb,
        haveGb: ram == null ? 0 : memoryGb(ram),
      );
      return;
    }
    context.push(Routes.tool(tool.id));
  }

  /// The search results (DK-0257, DK-0258): "{n} tools", a row per tool
  /// (its name and description), About for the first; or ILL-07.
  List<Widget> _results(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final found = [
      for (final tool in searchTools(_query, l))
        if (tool.category != ToolCategory.ai || _ai != AiEligibility.notArm64)
          tool,
    ];
    if (found.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: true, // DkEmptyState centres and scrolls itself
          child: DkEmptyState(
            illustration: DkIllustrations.searchNoResults,
            illustrationSize: 80,
            title: l.tools_search_empty_title(_query),
            body: l.tools_search_empty_body,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          t.space.l,
          t.space.l,
          t.space.l,
          t.space.s,
        ),
        sliver: SliverToBoxAdapter(
          child: Text(
            l.tools_count(found.length),
            style: t.text.caption.copyWith(color: t.color.textSecondary),
          ),
        ),
      ),
      SliverList.list(
        children: [
          for (final tool in found)
            DkToolRow(
              toolId: tool.id,
              showDescription: true,
              onTap: () => _open(tool),
            ),
          // A text action, as the frame: the info icon and the words in
          // color.primary, no chevron.
          DkTappable(
            radius: 0,
            onTap: () => showAboutTool(
              context,
              found.first,
              onOpen: () => _open(found.first),
            ),
            builder: (context, pressed) => Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.space.l,
                vertical: t.space.m,
              ),
              child: Row(
                spacing: t.space.m,
                children: [
                  DkIcon(DkIcons.info, color: t.color.primary),
                  Expanded(
                    child: Text(
                      l.tools_about(found.first.name(l)),
                      style: t.text.bodyL.copyWith(color: t.color.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    _ai = ref.watch(gemmaEligibilityProvider).value;
    final visible = _visible;
    // A large tablet (UI spec §30): the categories as a 200 dp sidebar with
    // the title, instead of the large title and the chips (DK-0650).
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final page = NotificationListener<ScrollNotification>(
      // The page's own scroll, not the chip row's.
      onNotification: (n) {
        if (n.depth != 0) return false;
        if (n is UserScrollNotification &&
            n.direction != ScrollDirection.idle) {
          _jumping = false; // the user scrolls: the chips follow again
        }
        if (n is ScrollUpdateNotification) _follow();
        return false;
      },
      child: CustomScrollView(
        controller: _scroll,
        // Every section built, so a chip can find its section's offset.
        // ponytail: fine for ~30 tiles; measure offsets instead if T1
        // ever grows to hundreds.
        scrollCacheExtent: const ScrollCacheExtent.pixels(10000),
        slivers: [
          // Searching, the field moves up in the title's place (the
          // tools-search frame).
          if (_query.isEmpty && !wide)
            DkLargeTopBar(title: l.shell_tab_tools)
          else
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.paddingOf(context).top + t.space.xl,
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(t.space.l, 0, t.space.l, 0),
            sliver: SliverToBoxAdapter(
              // Text columns are 640 at most (tablets, §30).
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Row(
                    spacing: t.space.xs,
                    children: [
                      Expanded(
                        child: DkSearchField(
                          hint: l.tools_search_hint,
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        DkTextAction(
                          label: l.common_cancel,
                          onTap: () {
                            _search.clear();
                            FocusScope.of(context).unfocus();
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            ..._results(context)
          else ...[
            if (!wide)
              SliverPersistentHeader(
                pinned: true,
                delegate: _ChipsBar(
                  key: _chipsKey,
                  height: 56,
                  colour: t.color.background,
                  chips: [
                    DkChip(
                      key: _chipKeys[null],
                      label: l.tools_all,
                      kind: DkChipKind.choice,
                      selected: _selected == null,
                      onSelected: (_) => _jump(null),
                    ),
                    for (final c in visible)
                      DkChip(
                        key: _chipKeys[c],
                        label: c.label(l),
                        kind: DkChipKind.choice,
                        selected: _selected == c,
                        onSelected: (_) => _jump(c),
                      ),
                  ],
                ),
              ),
            for (final c in visible) ...[
              SliverToBoxAdapter(
                child: Padding(
                  key: _sections[c],
                  padding: EdgeInsets.fromLTRB(
                    t.space.l,
                    t.space.l,
                    t.space.l,
                    t.space.s,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    spacing: t.space.s,
                    children: [
                      // The count at the end, as the frames (QA, DK-0728).
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            c.label(l),
                            style: t.text.titleS.copyWith(
                              color: t.color.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        l.tools_count(ToolCatalogue.inCategory(c).length),
                        style: t.text.caption.copyWith(
                          color: t.color.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: t.space.l),
                // 4 across on a phone, 6 or 8 on a tablet (§30).
                sliver: SliverLayoutBuilder(
                  builder: (context, box) => SliverGrid.count(
                    crossAxisCount: toolColumns(box.crossAxisExtent),
                    mainAxisSpacing: t.space.m,
                    crossAxisSpacing: t.space.m,
                    childAspectRatio: toolTileAspect(
                      box.crossAxisExtent,
                      t.space.m,
                    ),
                    children: [
                      for (final tool in ToolCatalogue.inCategory(c))
                        DkToolTile(toolId: tool.id, onTap: () => _open(tool)),
                    ],
                  ),
                ),
              ),
            ],
          ],
          SliverToBoxAdapter(child: SizedBox(height: t.space.xl)),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: t.color.background,
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Sidebar(
                  selected: _selected,
                  categories: visible,
                  onSelect: _jump,
                ),
                VerticalDivider(width: 1, thickness: 1, color: t.color.outline),
                Expanded(child: page),
              ],
            )
          : page,
    );
  }
}

/// T1's sidebar on a large tablet (DK-0650): the title, then All and the
/// categories with their tool counts; the selected one tinted. A tap jumps
/// to its section, as a chip does on a phone.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.categories,
    required this.onSelect,
  });

  final ToolCategory? selected;
  final List<ToolCategory> categories;
  final ValueChanged<ToolCategory?> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    Widget row(ToolCategory? cat, String label, int count) {
      final on = selected == cat;
      return Semantics(
        selected: on,
        child: DkTappable(
          radius: t.radius.m,
          onTap: () => onSelect(cat),
          builder: (context, pressed) => Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: EdgeInsets.symmetric(horizontal: t.space.m),
            decoration: BoxDecoration(
              color: on ? c.primaryContainer : null,
              borderRadius: BorderRadius.circular(t.radius.m),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: t.text.bodyL.copyWith(
                      color: on ? c.onPrimaryContainer : c.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: t.text.caption.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 200,
      child: ColoredBox(
        color: c.surface,
        child: SafeArea(
          right: false,
          bottom: false,
          child: ListView(
            padding: EdgeInsets.all(t.space.s),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  t.space.s,
                  t.space.l,
                  t.space.s,
                  t.space.m,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    l.shell_tab_tools,
                    style: t.text.titleL.copyWith(color: c.textPrimary),
                  ),
                ),
              ),
              row(
                null,
                l.tools_all,
                [for (final cat in categories) ...ToolCatalogue.inCategory(cat)]
                    .length,
              ),
              for (final cat in categories)
                row(cat, cat.label(l), ToolCatalogue.inCategory(cat).length),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipsBar extends SliverPersistentHeaderDelegate {
  _ChipsBar({
    required this.key,
    required this.height,
    required this.colour,
    required this.chips,
  });

  final GlobalKey key;
  final double height;
  final Color colour;
  final List<Widget> chips;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrink, bool overlaps) {
    final t = context.tokens;
    // A hairline once content scrolls under the chips (the tools-chip
    // frame), as the top bars have.
    return DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        color: colour,
        border: overlaps
            ? Border(bottom: BorderSide(color: t.color.outline))
            : null,
      ),
      // A Row, not a lazy list: every chip exists to scroll to.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: t.space.l,
          vertical: t.space.s,
        ),
        child: Row(spacing: t.space.s, children: chips),
      ),
    );
  }

  @override
  bool shouldRebuild(_ChipsBar old) => true;
}
