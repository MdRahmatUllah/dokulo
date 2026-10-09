import 'package:flutter/material.dart';

import '../components/dk_toast.dart';
import '../l10n/app_localizations.dart';

/// What the app does at once and offers to take back (UI spec §12.6;
/// DK-0226): no dialog first, a toast with Undo after.
enum DkUndo {
  /// Files moved to Recently deleted.
  deleteToTrash,

  /// Files moved to another folder.
  move,

  /// A page deleted in a scan's review.
  pageDelete,

  /// An Organize operation (delete, rotate, move pages).
  organize,

  /// The original replaced by the result: 10 s instead of 4.
  replaceOriginal,

  /// A tool unpinned from Home.
  unpinTool,

  /// A scan's "Apply to all pages" (S2).
  applyToAll;

  Duration get duration => this == replaceOriginal
      ? DkToastDuration.replaceUndo
      : DkToastDuration.regular;
}

/// Shows [message] with Undo for [kind]'s time (`toast_moved_trash`,
/// `toast_moved`, … from the copy deck). [onUndo] restores the exact state
/// before (order, folder, pages); it runs at most once, when the user taps
/// Undo. Completes with whether they did.
Future<bool> showDkUndo(
  BuildContext context,
  DkUndo kind,
  String message, {
  required VoidCallback onUndo,
}) async {
  final reason = await showDkToast(
    context,
    message,
    action: AppLocalizations.of(context).common_undo,
    onAction: onUndo,
    duration: kind.duration,
  );
  return reason == SnackBarClosedReason.action;
}
