import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';

/// How long a toast stays (UI spec §11.7, §12.4).
abstract final class DkToastDuration {
  /// Every toast: "Moved to Recently deleted · Undo".
  static const regular = Duration(seconds: 4);

  /// Undo after "Replace original": more time to change one's mind.
  static const replaceUndo = Duration(seconds: 10);
}

/// Shows a toast (UI spec §11.7; DK-0190): [message] in `bodyM` on the
/// inverse surface (dark on Light, light on Dark), at most 560 wide and
/// at least 48 tall (a long message wraps at large text), with an
/// optional [action] in `labelL` and `inversePrimary`.
///
/// It is a floating SnackBar (the look comes from `dokuloTheme`), so:
/// - toasts queue: the next one waits for the current one;
/// - they float above the Scaffold's `bottomNavigationBar`. Put the tab bar,
///   DkActionBar and DkMiniJobBar there and a toast never covers them; a
///   bar drawn in the body instead (V1's) passes its height as [above];
/// - with a screen reader on, a toast with an action doesn't time out, so
///   the action stays reachable; otherwise every toast goes after
///   [duration] (Flutter keeps any SnackBar with an action, so `persist` is
///   set here).
///
/// Returns when it is gone; `SnackBarClosedReason.action` means the action
/// ran.
Future<SnackBarClosedReason> showDkToast(
  BuildContext context,
  String message, {
  String? action,
  VoidCallback? onAction,
  Duration duration = DkToastDuration.regular,
  double above = 0,
}) {
  assert((action == null) == (onAction == null), 'an action needs both');
  final t = context.tokens;
  final screen = MediaQuery.sizeOf(context).width;
  final messenger = ScaffoldMessenger.of(context);
  // Phones: the theme's 16 margins; wider screens: 560, centred.
  final wide = screen - 2 * t.space.l > 560;
  return messenger
      .showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          persist: action != null && MediaQuery.accessibleNavigationOf(context),
          width: wide && above == 0 ? 560 : null,
          margin: above == 0
              ? null
              : EdgeInsets.fromLTRB(
                  wide ? (screen - 560) / 2 : t.space.l,
                  0,
                  wide ? (screen - 560) / 2 : t.space.l,
                  above + t.space.l,
                ),
          padding: EdgeInsets.only(
            left: t.space.l,
            right: action == null ? t.space.l : t.space.s,
          ),
          action: action == null
              ? null
              : SnackBarAction(label: action, onPressed: onAction!),
        ),
      )
      .closed;
}
