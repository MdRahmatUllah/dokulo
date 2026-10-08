import 'package:flutter/material.dart';

import '../components/dk_icon.dart';
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
    Widget large({required bool collapsed}) => SizedBox(
      height: 180,
      child: CustomScrollView(
        controller: ScrollController(initialScrollOffset: collapsed ? 80 : 0),
        slivers: [
          const DkLargeTopBar(
            title: 'Files',
            actions: actions,
            onOverflow: _anchor,
          ),
          SliverList.list(
            children: [
              for (var i = 0; i < 12; i++)
                ListTile(title: Text('Row ${i + 1}')),
            ],
          ),
        ],
      ),
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
          large(collapsed: false),
          large(collapsed: true),
        ],
      ),
    );
  }
}
