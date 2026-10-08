import 'package:flutter/widgets.dart';

import '../components/dk_confirm_dialog.dart';
import '../components/dk_icon.dart';
import '../l10n/app_localizations.dart';

/// The only things the app asks before doing (UI spec §12.4; DK-0225):
/// they can't be undone. Everything else does it at once and offers Undo
/// (`showDkUndo`, §12.6).
enum DkConfirmation {
  /// Delete files from Recently deleted for good.
  deleteForever,

  /// Empty Recently deleted.
  emptyTrash,

  /// Apply a redaction: the blacked-out content leaves the file.
  applyRedaction,

  /// Write the result over the original (it stays in Versions for 30 days).
  replaceOriginal,

  /// Delete the last page of a scan, and with it the scan.
  discardScan,

  /// Leave edit mode with changes.
  discardEdits,

  /// Cancel a job that has run for more than 30 s.
  cancelJob,

  /// Remove a saved signature.
  removeSignature,
}

/// Asks [kind]'s question; true when the user goes ahead. [count] is the
/// number of files for [DkConfirmation.deleteForever] and
/// [DkConfirmation.emptyTrash]; [title] lets a tool name its own job
/// ("Stop compressing?") for [DkConfirmation.cancelJob].
Future<bool> confirmDk(
  BuildContext context,
  DkConfirmation kind, {
  int count = 1,
  String? title,
}) {
  final l = AppLocalizations.of(context);
  final (heading, body, action, cancel, destructive) = switch (kind) {
    DkConfirmation.deleteForever || DkConfirmation.emptyTrash => (
      l.confirm_delete_forever_title(count),
      l.confirm_cant_undo,
      l.common_delete_forever,
      null,
      true,
    ),
    DkConfirmation.applyRedaction => (
      l.confirm_redact_title,
      l.confirm_redact_body,
      l.confirm_redact_action,
      null,
      true,
    ),
    DkConfirmation.replaceOriginal => (
      l.confirm_replace_title,
      l.confirm_replace_body,
      l.confirm_replace_action,
      null,
      false,
    ),
    DkConfirmation.discardScan => (
      l.confirm_discard_scan_title,
      l.confirm_discard_scan_body,
      l.common_discard,
      l.common_keep,
      true,
    ),
    DkConfirmation.discardEdits => (
      l.confirm_discard_edits_title,
      l.confirm_discard_edits_body,
      l.common_discard,
      l.common_keep_editing,
      true,
    ),
    DkConfirmation.cancelJob => (
      l.confirm_stop_job_title,
      l.confirm_stop_job_body,
      l.common_stop,
      l.common_keep_going,
      false,
    ),
    DkConfirmation.removeSignature => (
      l.confirm_remove_signature_title,
      l.confirm_remove_signature_body,
      l.common_remove,
      null,
      true,
    ),
  };
  return showDkConfirm(
    context,
    title: title ?? heading,
    body: body,
    action: action,
    cancel: cancel,
    destructive: destructive,
    // "Confirm empty" (§16) is an icon dialog; the rest are plain.
    icon:
        kind == DkConfirmation.deleteForever ||
            kind == DkConfirmation.emptyTrash
        ? DkIcons.deleteForever
        : null,
  );
}
