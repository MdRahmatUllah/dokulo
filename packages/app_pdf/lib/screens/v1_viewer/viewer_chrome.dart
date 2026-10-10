import 'dart:async';

import 'package:flutter/material.dart';

import '../../components/dk_bottom_bars.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_text_rules.dart';
import '../../components/dk_page_pill.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dk_tokens.dart';

/// What the viewer's chrome does; null leaves a button out (or disabled).
class ViewerActions {
  const ViewerActions({
    this.onRename,
    this.onSearch,
    this.onOverflow,
    this.onEdit,
    this.onSign,
    this.onAi,
    this.onTools,
    this.onShare,
  });

  final VoidCallback? onRename, onSearch, onEdit, onSign, onAi, onTools;
  final VoidCallback? onShare;
  final void Function(BuildContext anchor)? onOverflow;
}

/// V1's chrome (DK-0294; UI spec §17.1, design `06-viewer/viewer-default`,
/// `viewer-hidden`) around [canvas]:
///
/// - the top bar, translucent with the page blurred behind: back, the file
///   name (cut in the middle; a tap renames), search and overflow;
/// - DkPagePill 16 from the bottom-right, above the bottom bar;
/// - DkViewerBar: Edit · Sign · AI · Tools · Share.
///
/// The bars hide 3 s after a scroll starts and on a single tap, and come
/// back on a tap; the page pill stays. With a screen reader on they never
/// hide. [canvas] gets the tap and scroll callbacks to call.
class ViewerChrome extends StatefulWidget {
  const ViewerChrome({
    super.key,
    required this.name,
    required this.page,
    required this.pageCount,
    required this.actions,
    required this.canvas,
    this.strip,
  });

  /// Above the bottom bar, hidden with it: the thumbnail strip (Pages in
  /// the overflow menu, DK-0295).
  final Widget? strip;

  final String name;

  /// 1-based; null until the document is laid out.
  final int? page;
  final int pageCount;
  final ViewerActions actions;
  final Widget Function(VoidCallback onTap, VoidCallback onScrollStart) canvas;

  static const hideAfter = Duration(seconds: 3);

  @override
  State<ViewerChrome> createState() => _ViewerChromeState();
}

class _ViewerChromeState extends State<ViewerChrome> {
  var _visible = true;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  bool get _screenReader => MediaQuery.accessibleNavigationOf(context);

  void _tap() {
    _hide?.cancel();
    setState(() => _visible = _screenReader || !_visible);
  }

  void _scrolled() {
    if (_screenReader || !_visible) return;
    _hide?.cancel();
    _hide = Timer(ViewerChrome.hideAfter, () {
      if (mounted && !_screenReader) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final a = widget.actions;
    final visible = _visible || _screenReader;
    final top = DkTopBar(
      translucent: true,
      actions: [
        if (a.onSearch != null)
          DkTopBarAction(
            icon: DkIcons.search,
            tooltip: l.viewer_search,
            onPressed: a.onSearch,
          ),
      ],
      onOverflow: a.onOverflow,
    );
    final bar = DkViewerBar(
      visible: visible,
      actions: [
        DkBarAction(
          icon: DkIcons.pen,
          label: l.viewer_edit,
          onPressed: a.onEdit,
        ),
        DkBarAction(
          icon: DkIcons.tool('sign'),
          label: l.viewer_sign,
          onPressed: a.onSign,
        ),
        DkBarAction(
          icon: DkIcons.tool('summarize'),
          label: l.viewer_ai,
          onPressed: a.onAi,
        ),
        DkBarAction(
          icon: DkIcons.toolsTab,
          label: l.viewer_tools,
          onPressed: a.onTools,
        ),
        DkBarAction(
          icon: DkIcons.share(context),
          label: l.common_share,
          onPressed: a.onShare,
        ),
      ],
    );
    return Stack(
      children: [
        Positioned.fill(child: widget.canvas(_tap, _scrolled)),
        // The top bar slides up and away; the file name on it renames.
        AnimatedPositioned(
          duration: context.motion(DkMotionKind.standard).duration,
          left: 0,
          right: 0,
          top: visible
              ? 0
              : -(DkTopBar.height + MediaQuery.paddingOf(context).top),
          child: ExcludeSemantics(
            excluding: !visible,
            child: Stack(
              children: [
                top,
                Positioned.fill(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 56 + 4),
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
                              style: t.text.titleM.copyWith(
                                color: t.color.textPrimary,
                              ),
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
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.page case final page?)
                Padding(
                  padding: EdgeInsets.all(t.space.l),
                  child: DkPagePill(page: page, count: widget.pageCount),
                ),
              if (widget.strip case final strip? when visible) strip,
              bar,
            ],
          ),
        ),
      ],
    );
  }
}
