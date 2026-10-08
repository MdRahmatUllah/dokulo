import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_button.dart';
import 'dk_icon.dart';
import 'motion/dk_transition_motion.dart';

/// Asks before something that can't be undone (UI spec §11.7, §12.4;
/// DK-0186): delete forever, empty trash, apply redaction, replace the
/// original, discard a scan or edits, cancel a long job, remove a saved
/// signature. Everything else gets an Undo toast instead.
///
/// True when [action] was chosen; false on Cancel, back, Esc or a tap
/// outside. It opens in DkDialogRoute: a 220 ms fade and grow, or a 120 ms
/// fade with Reduce Motion.
Future<bool> showDkConfirm(
  BuildContext context, {
  required String title,
  required String action,
  String? body,
  String? cancel,
  bool destructive = false,
  IconData? icon,
}) async {
  final chosen = await Navigator.of(context).push<bool>(
    DkDialogRoute.of(
      context,
      builder: (context) => DkConfirmDialog(
        title: title,
        body: body,
        action: action,
        cancel: cancel,
        destructive: destructive,
        icon: icon,
        onCancel: () => Navigator.pop(context, false),
        onAction: () => Navigator.pop(context, true),
      ),
    ),
  );
  return chosen ?? false;
}

/// The dialog (UI spec §11.7): min(320, screen − 48) wide, `radius.l`, 24
/// padding; an optional 40 icon circle (danger colours when [destructive]);
/// the title in `titleM`, the body in `bodyM`; Cancel (tertiary) and the
/// action on the right, stacked full-width when the labels don't fit side by
/// side.
class DkConfirmDialog extends StatelessWidget {
  const DkConfirmDialog({
    super.key,
    required this.title,
    required this.action,
    required this.onCancel,
    required this.onAction,
    this.body,
    this.cancel,
    this.destructive = false,
    this.icon,
  });

  final String title;
  final String? body;

  /// Verb + object: "Delete for good", never "OK".
  final String action;

  /// The way out when Cancel doesn't say it ("Keep editing"); Cancel if null.
  final String? cancel;
  final bool destructive;
  final IconData? icon;
  final VoidCallback onCancel, onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final cancel = this.cancel ?? AppLocalizations.of(context).common_cancel;
    final width = math.min(320.0, MediaQuery.sizeOf(context).width - 48);
    final inner = width - 2 * t.space.xl;
    // A regular DkButton is its label plus 2 × 20, and at least 96 wide.
    final scaler = MediaQuery.textScalerOf(context);
    double buttonWidth(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: t.text.labelL),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = math.max(96.0, painter.width + 40);
      painter.dispose();
      return w;
    }

    final sideBySide =
        buttonWidth(cancel) + t.space.s + buttonWidth(action) <= inner;
    final cancelButton = DkButton(
      label: cancel,
      onPressed: onCancel,
      variant: DkButtonVariant.tertiary,
      expand: !sideBySide,
    );
    final actionButton = DkButton(
      label: action,
      onPressed: onAction,
      variant: destructive
          ? DkButtonVariant.destructive
          : DkButtonVariant.primary,
      expand: !sideBySide,
    );

    final head = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: t.space.s,
      children: [
        if (icon != null) ...[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: destructive ? c.dangerContainer : c.primaryContainer,
            ),
            child: DkIcon(
              icon!,
              size: DkIconSize.m,
              color: destructive ? c.danger : c.onPrimaryContainer,
            ),
          ),
          // 16 under the circle in all (the export's `.dic` margin).
          const SizedBox.shrink(),
        ],
        Text(title, style: t.text.titleM.copyWith(color: c.textPrimary)),
        if (body != null)
          Text(body!, style: t.text.bodyM.copyWith(color: c.textSecondary)),
      ],
    );
    final screen = MediaQuery.sizeOf(context);
    return Center(
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: title,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: width,
            // Never taller than the screen: at 200 % text on a small phone
            // the title and body scroll, the buttons stay.
            constraints: BoxConstraints(maxHeight: screen.height - 48),
            padding: EdgeInsets.all(t.space.xl),
            decoration: t.surfaceAt(
              DkLevel.overlay,
              radius: BorderRadius.circular(t.radius.l),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(child: SingleChildScrollView(child: head)),
                SizedBox(height: t.space.l),
                if (sideBySide)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    spacing: t.space.s,
                    children: [cancelButton, actionButton],
                  )
                else ...[
                  // Stacked: the action on top, Cancel under it.
                  SizedBox(width: double.infinity, child: actionButton),
                  SizedBox(height: t.space.s),
                  SizedBox(width: double.infinity, child: cancelButton),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
