import 'package:flutter/material.dart';

import '../../components/dk_button.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_icon_button.dart';
import '../../components/dk_page_pill.dart';
import '../../components/dk_text_rules.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dk_tokens.dart';
import 'viewer_chrome.dart';

/// V1 on a tablet (UI spec §17.4, `24-tablet/tablet-viewer-landscape` and
/// `-portrait`; DK-0310): no bottom bar and nothing hides. A 64 dp top bar
/// carries back, the thumbnail sidebar's toggle, the file name (a tap
/// renames), search, then the phone's bottom-bar actions inline (Edit · Sign
/// · AI · Tools as labelled buttons, Share) and the overflow; under it the
/// [sidebar] (open from the start in landscape) beside the pages.
///
/// ponytail: the AI pane (400 dp, right) comes with A1 (M13); AI opens
/// Summarize as on a phone until then.
class ViewerTabletChrome extends StatefulWidget {
  const ViewerTabletChrome({
    super.key,
    required this.name,
    required this.page,
    required this.pageCount,
    required this.actions,
    required this.canvas,
    required this.sidebar,
    this.onSidebarToggled,
  });

  final String name;

  /// 1-based; null until the document is laid out.
  final int? page;
  final int pageCount;
  final ViewerActions actions;
  final Widget canvas;

  /// The thumbnails, down the left.
  final Widget sidebar;

  /// After the sidebar shows or hides: the pages reflow, and the viewer
  /// keeps its page.
  final VoidCallback? onSidebarToggled;

  static const barHeight = 64.0;

  @override
  State<ViewerTabletChrome> createState() => _ViewerTabletChromeState();
}

class _ViewerTabletChromeState extends State<ViewerTabletChrome> {
  bool? _sidebar;

  void _toggle() {
    setState(() => _sidebar = !_sidebar!);
    widget.onSidebarToggled?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final a = widget.actions;
    final size = MediaQuery.sizeOf(context);
    final sidebar = _sidebar ??= size.width > size.height;
    Widget labelled(
      IconData icon,
      String label,
      VoidCallback? onTap, {
      bool tonal = false,
    }) => DkButton(
      label: label,
      icon: icon,
      size: DkButtonSize.compact,
      variant: tonal ? DkButtonVariant.tonal : DkButtonVariant.tertiary,
      onPressed: onTap,
    );
    final bar = Container(
      height: ViewerTabletChrome.barHeight,
      padding: EdgeInsets.symmetric(horizontal: t.space.m),
      decoration: BoxDecoration(
        color: t.color.surface.withValues(alpha: 0.94),
        border: Border(bottom: BorderSide(color: t.color.outline)),
      ),
      child: Row(
        spacing: t.space.xs,
        children: [
          DkIconButton(
            icon: DkIcons.back(context),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          DkIconButton(
            icon: DkIcons.sidebar,
            tooltip: l.viewer_thumbnails,
            selected: sidebar,
            onPressed: _toggle,
          ),
          Expanded(
            child: Semantics(
              button: a.onRename != null,
              label: widget.name,
              excludeSemantics: true,
              onTap: a.onRename,
              child: GestureDetector(
                onTap: a.onRename,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DkMiddleEllipsisText(
                    widget.name,
                    style: t.text.titleM.copyWith(color: t.color.textPrimary),
                  ),
                ),
              ),
            ),
          ),
          if (a.onSearch != null)
            DkIconButton(
              icon: DkIcons.search,
              tooltip: l.viewer_search,
              onPressed: a.onSearch,
            ),
          labelled(DkIcons.pen, l.viewer_edit, a.onEdit),
          labelled(DkIcons.tool('sign'), l.viewer_sign, a.onSign),
          labelled(DkIcons.tool('summarize'), l.viewer_ai, a.onAi, tonal: true),
          labelled(DkIcons.toolsTab, l.viewer_tools, a.onTools),
          DkIconButton(
            icon: DkIcons.share(context),
            tooltip: l.common_share,
            onPressed: a.onShare,
          ),
          if (a.onOverflow case final overflow?)
            Builder(
              builder: (anchor) => DkIconButton(
                icon: DkIcons.overflow(context),
                tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                onPressed: () => overflow(anchor),
              ),
            ),
        ],
      ),
    );
    return Column(
      children: [
        SafeArea(bottom: false, child: bar),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sidebar) widget.sidebar,
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: widget.canvas),
                    if (widget.page case final page?)
                      PositionedDirectional(
                        end: t.space.l,
                        bottom:
                            t.space.l + MediaQuery.paddingOf(context).bottom,
                        child: DkPagePill(page: page, count: widget.pageCount),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
