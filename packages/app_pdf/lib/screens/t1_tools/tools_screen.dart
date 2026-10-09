import 'package:ai_core/ai_core.dart' show AiEligibility, gemmaNeeds;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_chip.dart';
import '../../components/dk_text_field.dart';
import '../../components/dk_tool_tile.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../patterns/dk_ai_not_eligible.dart';
import '../../providers/device_providers.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';
import '../../tools/tool_catalogue.dart';

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

  /// Null: All.
  ToolCategory? _selected;

  /// While a chip's scroll runs, the scroll doesn't move the selection.
  bool _jumping = false;

  /// Gemma's eligibility on this phone, from the last build.
  AiEligibility? _ai;

  @override
  void dispose() {
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
    final end = _scroll.position.pixels >= _scroll.position.maxScrollExtent;
    if (_scroll.offset > 0) {
      for (final c in _visible) {
        final top = _sectionTop(c);
        if (top != null && top <= line) current = c;
      }
      // The last sections can't reach the chips: at the end, the last one.
      if (end) current = _visible.last;
    }
    if (current != _selected) setState(() => _selected = current);
  }

  Future<void> _jump(ToolCategory? c) async {
    setState(() => _selected = c);
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
    _jumping = false;
  }

  List<ToolCategory> get _visible => [
    for (final c in ToolCategory.values)
      if (c != ToolCategory.ai || _ai != AiEligibility.notArm64) c,
  ];

  void _open(ToolInfo tool) {
    if (tool.category == ToolCategory.ai && _ai == AiEligibility.tooLittleRam) {
      final ram = ref.read(deviceCapabilitiesProvider).value?.totalRam;
      showAiNotEligible(
        context,
        needGb: gemmaNeeds.advertisedGb,
        haveGb: ram == null ? 0 : memoryGb(ram),
      );
      return;
    }
    context.push(Routes.tool(tool.id));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    _ai = ref.watch(gemmaEligibilityProvider).value;
    final visible = _visible;
    return Scaffold(
      backgroundColor: t.color.background,
      body: NotificationListener<ScrollUpdateNotification>(
        onNotification: (_) {
          _follow();
          return false;
        },
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            DkLargeTopBar(title: l.shell_tab_tools),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(t.space.l, 0, t.space.l, 0),
              // ponytail: the field is here; filtering is DK-0257's.
              sliver: SliverToBoxAdapter(
                child: DkSearchField(hint: l.tools_search_hint),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _ChipsBar(
                key: _chipsKey,
                height: 56,
                colour: t.color.background,
                chips: [
                  DkChip(
                    label: l.tools_all,
                    kind: DkChipKind.choice,
                    selected: _selected == null,
                    onSelected: (_) => _jump(null),
                  ),
                  for (final c in visible)
                    DkChip(
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
                key: _sections[c],
                child: Padding(
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
                      Semantics(
                        header: true,
                        child: Text(
                          c.label(l),
                          style: t.text.titleS.copyWith(
                            color: t.color.textPrimary,
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
                sliver: SliverGrid.count(
                  crossAxisCount: 4,
                  mainAxisSpacing: t.space.m,
                  crossAxisSpacing: t.space.m,
                  childAspectRatio: 0.78,
                  children: [
                    for (final tool in ToolCatalogue.inCategory(c))
                      DkToolTile(toolId: tool.id, onTap: () => _open(tool)),
                  ],
                ),
              ),
            ],
            SliverToBoxAdapter(child: SizedBox(height: t.space.xl)),
          ],
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
    return ColoredBox(
      key: key,
      color: colour,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: t.space.l,
          vertical: t.space.s,
        ),
        children: [
          for (final (i, chip) in chips.indexed)
            Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : t.space.s),
              child: chip,
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_ChipsBar old) => true;
}
