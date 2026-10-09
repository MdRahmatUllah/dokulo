import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_icon_button.dart';
import 'dk_text_action.dart';

/// What sits at the left of a [DkTopBar].
enum DkTopBarLeading { none, back, close }

/// One action of a top bar: an icon button with its tooltip.
class DkTopBarAction {
  const DkTopBarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
}

/// The small top bar (UI spec §11.6; DK-0164): 56 tall below the status
/// bar, `color.surface`; back or close on the left; the title in `titleM`,
/// centred on iOS and left-aligned on Android; up to two actions and an
/// overflow on the right. A hairline appears at the bottom once content
/// scrolls under it.
///
/// [DkTopBar.editing] is V2's bar: Cancel, the title centred, Done.
/// [DkLargeTopBar] is the collapsing tab-root bar.
class DkTopBar extends StatefulWidget implements PreferredSizeWidget {
  const DkTopBar({
    super.key,
    this.title,
    this.leading = DkTopBarLeading.back,
    this.onLeading,
    this.actions = const [],
    this.onOverflow,
    this.trailing,
  }) : onCancel = null,
       onDone = null,
       cancelLabel = null,
       doneLabel = null,
       _editing = false;

  /// Editing (V2): Cancel (tertiary) on the left, the title centred, Done
  /// (primary text, bold) on the right. A null [onDone] shows Done
  /// disabled: nothing to save yet.
  const DkTopBar.editing({
    super.key,
    required this.title,
    required VoidCallback this.onCancel,
    required this.onDone,
    this.cancelLabel,
    this.doneLabel,
  }) : leading = DkTopBarLeading.none,
       onLeading = null,
       actions = const [],
       onOverflow = null,
       trailing = null,
       _editing = true;

  final String? title;
  final DkTopBarLeading leading;

  /// Back or close; `Navigator.maybePop` when null.
  final VoidCallback? onLeading;

  /// Two at most; the rest go in the overflow menu.
  final List<DkTopBarAction> actions;

  /// Opens the overflow menu, anchored to the given context (DkMenu).
  final void Function(BuildContext anchor)? onOverflow;

  /// In place of [actions]: a text action ("Select", DkTextAction).
  final Widget? trailing;

  final VoidCallback? onCancel, onDone;
  final bool _editing;

  /// Cancel and Done, when a screen says something more specific.
  final String? cancelLabel, doneLabel;

  static const height = 56.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  State<DkTopBar> createState() => _DkTopBarState();
}

/// The bars hold their text at 130 % at most, as iOS navigation bars do:
/// at 200 % a 56 dp bar can't fit Cancel, a title and Done in German.
// ponytail: a clamp, not a growing bar; grow it (preferredSize from the
// text scale) if a screen ever needs the bar's text at full size.
const _maxTextScale = 1.3;

bool _isIos(BuildContext context) => switch (Theme.of(context).platform) {
  TargetPlatform.iOS || TargetPlatform.macOS => true,
  _ => false,
};

class _DkTopBarState extends State<DkTopBar> with _ScrolledUnder<DkTopBar> {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = MaterialLocalizations.of(context);
    final editing = widget._editing;
    final centred = _isIos(context) || editing;
    final title = widget.title == null
        ? null
        : Semantics(
            header: true,
            child: Text(
              widget.title!,
              style: t.text.titleM.copyWith(color: t.color.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: centred ? TextAlign.center : TextAlign.start,
            ),
          );

    final Widget? leading = editing
        ? DkTextAction(
            label:
                widget.cancelLabel ??
                AppLocalizations.of(context).common_cancel,
            onTap: widget.onCancel!,
          )
        : switch (widget.leading) {
            DkTopBarLeading.none => null,
            DkTopBarLeading.back => DkIconButton(
              icon: DkIcons.back(context),
              tooltip: l10n.backButtonTooltip,
              onPressed: widget.onLeading ?? () => Navigator.maybePop(context),
            ),
            DkTopBarLeading.close => DkIconButton(
              icon: DkIcons.close,
              tooltip: l10n.closeButtonTooltip,
              onPressed: widget.onLeading ?? () => Navigator.maybePop(context),
            ),
          };
    final Widget trailing = editing
        ? DkTextAction(
            label: widget.doneLabel ?? AppLocalizations.of(context).common_done,
            onTap: widget.onDone,
            bold: true,
          )
        : widget.trailing ??
              _Actions(actions: widget.actions, onOverflow: widget.onOverflow);

    // Scaffold gives the bar its height plus the status bar's: pad for it.
    return _BarSurface(
      hairline: scrolledUnder,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: DkTopBar.height,
          child: _Toolbar(
            leading: leading,
            middle: title,
            trailing: trailing,
            centred: centred,
            // Cancel and Done never run into each other: each gets half.
            capSides: editing,
          ),
        ),
      ),
    );
  }
}

/// The bar's row: [NavigationToolbar] inside a `space.xs` inset, with the
/// title 16 from the edge when there is nothing on the left. Holds the
/// text at [_maxTextScale].
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.leading,
    required this.middle,
    required this.trailing,
    required this.centred,
    this.capSides = false,
  });

  final Widget? leading, middle;
  final Widget trailing;
  final bool centred, capSides;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final spacing = centred ? t.space.l : t.space.xs;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: t.space.xs),
        child: LayoutBuilder(
          builder: (context, box) {
            Widget side(Widget child) => capSides
                ? ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth / 2),
                    child: child,
                  )
                : child;
            return NavigationToolbar(
              // Nothing on the left: a left-aligned title still starts 16
              // in; a centred one needs no spacer.
              leading: leading != null
                  ? side(leading!)
                  : centred
                  ? null
                  : SizedBox(width: t.space.l - t.space.xs - spacing),
              middle: middle,
              trailing: side(trailing),
              centerMiddle: centred,
              middleSpacing: spacing,
            );
          },
        ),
      ),
    );
  }
}

/// Up to two actions and the overflow, at the right of a bar.
class _Actions extends StatelessWidget {
  const _Actions({required this.actions, required this.onOverflow});

  final List<DkTopBarAction> actions;
  final void Function(BuildContext anchor)? onOverflow;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final a in actions)
        DkIconButton(icon: a.icon, tooltip: a.tooltip, onPressed: a.onPressed),
      if (onOverflow != null)
        Builder(
          builder: (anchor) => DkIconButton(
            icon: DkIcons.overflow(context),
            tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
            onPressed: () => onOverflow!(anchor),
          ),
        ),
    ],
  );
}

/// The collapsing top bar of a tab root (UI spec §11.6, large; DK-0164): a
/// pinned sliver, 112 tall when expanded with the title in `titleL` at the
/// bottom left, collapsing into the small bar (56, `titleM`; centred on
/// iOS) as the content scrolls. The actions stay at the top right. Use it
/// as the first sliver of a CustomScrollView.
class DkLargeTopBar extends StatelessWidget {
  const DkLargeTopBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.onOverflow,
  });

  final String title;
  final List<DkTopBarAction> actions;
  final void Function(BuildContext anchor)? onOverflow;

  static const expanded = 112.0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _LargeBar(
        title: title,
        actions: actions,
        onOverflow: onOverflow,
        top: top,
        tokens: context.tokens,
      ),
    );
  }
}

class _LargeBar extends SliverPersistentHeaderDelegate {
  _LargeBar({
    required this.title,
    required this.actions,
    required this.onOverflow,
    required this.top,
    required this.tokens,
  });

  final String title;
  final List<DkTopBarAction> actions;
  final void Function(BuildContext anchor)? onOverflow;
  final double top;
  final DkTokens tokens;

  @override
  double get maxExtent => top + DkLargeTopBar.expanded;

  @override
  double get minExtent => top + DkTopBar.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final t = context.tokens;
    final range = maxExtent - minExtent;
    // 0 expanded … 1 collapsed.
    final k = (shrinkOffset / range).clamp(0.0, 1.0);
    return _BarSurface(
      hairline: k >= 1,
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: _maxTextScale,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The big title, bottom left, fading out as the bar collapses.
              Positioned(
                left: t.space.l,
                right: t.space.l,
                bottom: t.space.s,
                child: Opacity(
                  opacity: 1 - k,
                  child: ExcludeSemantics(
                    excluding: k > 0.5,
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: t.text.titleL.copyWith(
                          color: t.color.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
              // The 56 bar: the small title fading in, between the edge and
              // the actions.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: DkTopBar.height,
                child: _Toolbar(
                  leading: null,
                  middle: Opacity(
                    opacity: k,
                    child: ExcludeSemantics(
                      excluding: k <= 0.5,
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: t.text.titleM.copyWith(
                            color: t.color.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  trailing: _Actions(actions: actions, onOverflow: onOverflow),
                  centred: _isIos(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_LargeBar old) =>
      old.title != title ||
      old.actions != actions ||
      old.onOverflow != onOverflow ||
      old.top != top ||
      old.tokens != tokens;
}

/// The bar's `surface`, with a 1 dp `outline` hairline at the bottom when
/// content is under it.
class _BarSurface extends StatelessWidget {
  const _BarSurface({required this.hairline, required this.child});
  final bool hairline;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.color.surface,
        border: Border(
          bottom: BorderSide(
            color: hairline ? t.color.outline : t.color.surface,
          ),
        ),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// Like AppBar: listens to the Scaffold's scroll notifications and knows
/// when content has scrolled under the bar.
mixin _ScrolledUnder<W extends StatefulWidget> on State<W> {
  ScrollNotificationObserverState? _observer;
  bool scrolledUnder = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observer?.removeListener(_onScroll);
    _observer = ScrollNotificationObserver.maybeOf(context);
    _observer?.addListener(_onScroll);
  }

  @override
  void dispose() {
    _observer?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll(ScrollNotification n) {
    if (n is! ScrollUpdateNotification || n.depth != 0) return;
    if (n.metrics.axis != Axis.vertical) return;
    final under = n.metrics.extentBefore > 0;
    if (under != scrolledUnder) setState(() => scrolledUnder = under);
  }
}
