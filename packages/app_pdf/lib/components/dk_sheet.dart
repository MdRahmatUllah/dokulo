import 'package:flutter/material.dart';

import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'motion/dk_transition_motion.dart';

/// How tall a sheet opens (UI spec §11.7): its content's height, half the
/// screen, or 92 % of it.
enum DkSheetDetent { small, medium, large }

/// Opens a [DkSheet] (DK-0182). On a phone it is a bottom sheet at
/// [detent] in `DkSheetRoute` (§9: it slides up in `motion.standard` while
/// the scrim is in by `motion.fast`; Reduce Motion fades it in place). A
/// swipe down on its handle and title closes it; medium and large also
/// close when dragged to their bottom, and snap between 50 % and 92 %. On a
/// tablet (600 dp and wider) it is a centred dialog, at most 560 wide, that
/// fades and grows in `motion.standard`.
///
/// [confirmDismiss] (unsaved content): every way of closing it (the swipe,
/// back, the scrim, the ×) asks first and closes only on true. The sheet's
/// own buttons close it with `Navigator.pop(context, result)` as usual.
Future<T?> showDkSheet<T>(
  BuildContext context, {
  required Widget body,
  String? title,
  bool showClose = false,
  String? closeLabel,
  Widget? actions,
  DkSheetDetent detent = DkSheetDetent.small,
  Future<bool> Function()? confirmDismiss,
}) {
  final t = context.tokens;
  final motion = context.motion(DkMotionKind.standard);

  // Every way of closing goes through maybePop, so PopScope can ask.
  Widget guarded(BuildContext context, Widget child) {
    if (confirmDismiss == null) return child;
    return PopScope<T>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmDismiss()) navigator.pop();
      },
      child: child,
    );
  }

  DkSheet sheet(
    BuildContext context, {
    ScrollController? controller,
    bool inDialog = false,
  }) => DkSheet(
    title: title,
    body: body,
    actions: actions,
    scrollController: controller,
    closeLabel: closeLabel,
    inDialog: inDialog,
    onClose: showClose ? () => Navigator.maybePop(context) : null,
    onSwipeDown: inDialog ? null : () => Navigator.maybePop(context),
  );

  if (DkGrid.forWidth(MediaQuery.sizeOf(context).width) != DkGrid.phone) {
    // The same fade and grow as DkConfirmDialog (DkDialogRoute keeps the
    // 120 ms fade under Reduce Motion).
    return Navigator.of(context).push<T>(
      DkDialogRoute<T>.of(
        context,
        builder: (context) => guarded(
          context,
          SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(t.space.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Material(
                    type: MaterialType.transparency,
                    child: sheet(context, inDialog: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  return Navigator.of(context).push(
    DkSheetRoute<T>.of(
      context,
      builder: (context) => guarded(
        context,
        SafeArea(
          bottom: false,
          child: Padding(
            // The keyboard pushes the content and the action area up.
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: switch (detent) {
                DkSheetDetent.small => sheet(context),
                DkSheetDetent.medium || DkSheetDetent.large => () {
                  final min = confirmDismiss == null
                      ? 0.25
                      : (detent == DkSheetDetent.medium ? 0.5 : 0.92);
                  return NotificationListener<DraggableScrollableNotification>(
                    // Dragged down to its bottom: close (or ask).
                    onNotification: (n) {
                      if (confirmDismiss == null &&
                          n.extent <= n.minExtent + 0.001) {
                        Navigator.maybePop(context);
                      }
                      return false;
                    },
                    child: DraggableScrollableSheet(
                      expand: false,
                      initialChildSize: detent == DkSheetDetent.medium
                          ? 0.5
                          : 0.92,
                      minChildSize: min,
                      maxChildSize: 0.92,
                      // Snap sizes must lie strictly between min and max:
                      // with a confirmation a large sheet can't move at all.
                      snap: min < 0.92,
                      snapSizes: [if (min < 0.5) 0.5],
                      // §9: detent changes take `motion.standard`.
                      snapAnimationDuration: motion.duration,
                      builder: (context, controller) =>
                          sheet(context, controller: controller),
                    ),
                  );
                }(),
              },
            ),
          ),
        ),
      ),
    ),
  );
}

/// The sheet itself (UI spec §11.7): `color.surfaceRaised` with a 24 top
/// radius (`elevation.overlay`), the 36 × 4 grab handle 8 below the top, the
/// title in `titleM` 16 below it with an optional ×, the content with 16
/// padding, and [actions] fixed at the bottom while the content scrolls.
/// [showDkSheet] opens it; the catalogue and tests show it as it is.
class DkSheet extends StatelessWidget {
  const DkSheet({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.onClose,
    this.closeLabel,
    this.scrollController,
    this.onSwipeDown,
    this.inDialog = false,
  });

  final Widget body;
  final String? title;

  /// The sticky action area (a primary button, maybe a secondary).
  final Widget? actions;

  /// The ×; hidden when null.
  final VoidCallback? onClose;

  /// The ×'s screen-reader label; the platform's "Close" when null.
  final String? closeLabel;

  /// From a DraggableScrollableSheet (medium, large), so dragging the
  /// content moves the sheet.
  final ScrollController? scrollController;

  /// A downward swipe on the handle area, when the sheet handles it itself.
  final VoidCallback? onSwipeDown;

  /// A tablet dialog: all corners rounded, no grab handle.
  final bool inDialog;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = Radius.circular(t.radius.sheet);
    final top = <Widget>[
      if (!inDialog)
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: t.space.s),
            decoration: BoxDecoration(
              color: t.color.outlineStrong,
              borderRadius: BorderRadius.circular(t.radius.pill),
            ),
          ),
        ),
      if (title != null || onClose != null)
        Padding(
          padding: EdgeInsets.fromLTRB(
            t.space.l,
            inDialog ? t.space.l : t.space.s,
            onClose == null ? t.space.l : t.space.xs,
            0,
          ),
          child: Row(
            children: [
              if (title == null)
                const Spacer()
              else
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title!,
                      style: t.text.titleM.copyWith(color: t.color.textPrimary),
                    ),
                  ),
                ),
              if (onClose != null)
                IconButton(
                  onPressed: onClose,
                  tooltip:
                      closeLabel ??
                      MaterialLocalizations.of(context).closeButtonTooltip,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  icon: DkIcon(DkIcons.close, color: t.color.iconSecondary),
                ),
            ],
          ),
        ),
    ];
    return DecoratedBox(
      decoration: t.surfaceAt(
        DkLevel.overlay,
        radius: inDialog
            ? BorderRadius.all(radius)
            : BorderRadius.vertical(top: radius),
      ),
      child: SafeArea(
        top: false,
        // At a detent (a scroll controller) the sheet fills its height;
        // small, it is as tall as its content.
        child: Column(
          mainAxisSize: scrollController == null
              ? MainAxisSize.min
              : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (onSwipeDown == null)
              ...top
            else
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) > 300) onSwipeDown!();
                },
                child: Column(children: top),
              ),
            Flexible(
              fit: scrollController == null ? FlexFit.loose : FlexFit.tight,
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.all(t.space.l),
                child: body,
              ),
            ),
            if (actions != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  t.space.l,
                  0,
                  t.space.l,
                  t.space.l,
                ),
                child: actions,
              ),
          ],
        ),
      ),
    );
  }
}
