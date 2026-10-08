import 'package:flutter/material.dart';

import '../components/dk_icon.dart';
import '../components/dk_scan_button.dart';
import '../components/dk_tab_bar.dart';
import '../components/dk_top_bar.dart';
import '../theme/dk_tokens.dart';

void _none() {}
void _anchor(BuildContext _) {}

/// DkTopBar (DK-0164): small with back, two actions and the overflow, on
/// Android (title left) and iOS (title centred); with close; editing; then
/// the large bar expanded and collapsed.
class TopBarStates extends StatelessWidget {
  const TopBarStates({super.key});

  static const actions = [
    DkTopBarAction(icon: DkIcons.search, tooltip: 'Search', onPressed: _none),
    DkTopBarAction(icon: DkIcons.sort, tooltip: 'Sort', onPressed: _none),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget platform(TargetPlatform p, Widget child) => Theme(
      data: Theme.of(context).copyWith(platform: p),
      child: child,
    );
    return ColoredBox(
      color: t.color.background,
      child: Column(
        spacing: t.space.m,
        children: [
          platform(
            TargetPlatform.android,
            const DkTopBar(
              title: 'Mietvertrag.pdf',
              actions: actions,
              onOverflow: _anchor,
            ),
          ),
          platform(
            TargetPlatform.iOS,
            const DkTopBar(
              title: 'Mietvertrag.pdf',
              actions: actions,
              onOverflow: _anchor,
            ),
          ),
          const DkTopBar(title: 'Settings', leading: DkTopBarLeading.close),
          const DkTopBar.editing(
            title: 'Editing',
            onCancel: _none,
            onDone: _none,
          ),
          const _LargeBarDemo(collapsed: false),
          const _LargeBarDemo(collapsed: true),
        ],
      ),
    );
  }
}

/// DkTabBar (DK-0166) with the raised Scan button, Files selected; then
/// DkNavRail (DK-0168) for tablets, Home selected.
class TabBarStates extends StatelessWidget {
  const TabBarStates({super.key});

  static const items = [
    DkTabItem(icon: DkIcons.home, label: 'Home'),
    DkTabItem(icon: DkIcons.toolsTab, label: 'Tools'),
    DkTabItem(icon: DkIcons.files, label: 'Files'),
    DkTabItem(icon: DkIcons.me, label: 'Me'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      spacing: t.space.l,
      children: [
        SizedBox(
          height: 200,
          child: Scaffold(
            floatingActionButton: DkScanButton(
              showLabel: false,
              onPressed: _none,
              onMode: (_) {},
            ),
            floatingActionButtonLocation: DkTabBar.scanLocation,
            bottomNavigationBar: DkTabBar(
              items: items,
              currentIndex: 2,
              onSelect: (_) {},
            ),
          ),
        ),
        SizedBox(
          height: 420,
          child: Row(
            children: [
              DkNavRail(
                items: items,
                currentIndex: 0,
                onSelect: (_) {},
                onScan: _none,
              ),
              Expanded(child: ColoredBox(color: t.color.background)),
            ],
          ),
        ),
      ],
    );
  }
}

/// The large bar over a list, scrolled so it shows [collapsed] or expanded.
class _LargeBarDemo extends StatefulWidget {
  const _LargeBarDemo({required this.collapsed});
  final bool collapsed;

  @override
  State<_LargeBarDemo> createState() => _LargeBarDemoState();
}

class _LargeBarDemoState extends State<_LargeBarDemo> {
  late final _scroll = ScrollController(
    initialScrollOffset: widget.collapsed ? 80 : 0,
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 180,
    child: CustomScrollView(
      controller: _scroll,
      slivers: [
        const DkLargeTopBar(
          title: 'Files',
          actions: TopBarStates.actions,
          onOverflow: _anchor,
        ),
        SliverList.list(
          children: [
            for (var i = 0; i < 12; i++) ListTile(title: Text('Row ${i + 1}')),
          ],
        ),
      ],
    ),
  );
}
