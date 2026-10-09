import 'package:flutter/material.dart';

import '../components/dk_button.dart';
import '../components/dk_empty_state.dart';
import '../components/dk_icon.dart';
import '../components/dk_illustration.dart';
import '../l10n/app_localizations.dart';

/// The empty states of UI spec §26.1 (DK-0601…DK-0608): each place's
/// illustration, copy (EN/DE) and first action, on DkEmptyState. A screen
/// shows one where its list is empty; the illustration follows the theme.
abstract final class DkEmptyStates {
  /// H1 recents (DK-0601): ILL-04, Scan a document.
  static Widget homeRecents(
    BuildContext context, {
    required VoidCallback onScan,
  }) {
    final l = AppLocalizations.of(context);
    return DkEmptyState(
      illustration: DkIllustrations.homeEmpty,
      title: l.empty_home_title,
      body: l.empty_home_body,
      action: l.empty_action_scan,
      actionIcon: DkIcons.scan,
      onAction: onScan,
    );
  }

  /// F1, the Files root (DK-0602): ILL-05, Scan a document · Open a file.
  static Widget filesRoot(
    BuildContext context, {
    required VoidCallback onScan,
    required VoidCallback onOpenFile,
  }) {
    final l = AppLocalizations.of(context);
    return DkEmptyState(
      illustration: DkIllustrations.filesEmpty,
      title: l.empty_files_title,
      body: l.empty_home_body,
      action: l.empty_action_scan,
      actionIcon: DkIcons.scan,
      onAction: onScan,
      secondaryAction: l.empty_action_open_file,
      onSecondaryAction: onOpenFile,
    );
  }

  /// A folder (DK-0603): ILL-06, Move files here (secondary, as the export).
  static Widget folder(BuildContext context, {required VoidCallback onMove}) {
    final l = AppLocalizations.of(context);
    return DkEmptyState(
      illustration: DkIllustrations.folderEmpty,
      title: l.empty_folder_title,
      body: l.empty_folder_body,
      action: l.empty_action_move_here,
      actionIcon: DkIcons.move,
      actionVariant: DkButtonVariant.secondary,
      onAction: onMove,
    );
  }

  /// Search with no results for [query] (DK-0604): ILL-07, no button.
  static Widget search(BuildContext context, {required String query}) {
    final l = AppLocalizations.of(context);
    return DkEmptyState(
      illustration: DkIllustrations.searchNoResults,
      title: l.empty_search_title(query),
      body: l.empty_search_body,
    );
  }

  /// Recently deleted (DK-0605): ILL-08, no button.
  static Widget trash(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DkEmptyState(
      illustration: DkIllustrations.trashEmpty,
      title: l.empty_trash_title,
      body: l.empty_trash_body,
    );
  }

  /// Saved signatures (DK-0606): ILL-15, Add signature.
  static Widget signatures(
    BuildContext context, {
    required VoidCallback onAdd,
  }) {
    final l = AppLocalizations.of(context);
    return DkEmptyState(
      illustration: DkIllustrations.noSignatures,
      title: l.empty_signatures_title,
      body: l.empty_signatures_body,
      action: l.empty_action_add_signature,
      onAction: onAdd,
    );
  }

  /// Workflows (DK-0607): ILL-16, New workflow · Use a template.
  static Widget workflows(
    BuildContext context, {
    required VoidCallback onNew,
    required VoidCallback onTemplate,
  }) {
    final l = AppLocalizations.of(context);
    return DkEmptyState(
      illustration: DkIllustrations.noWorkflows,
      title: l.empty_workflows_title,
      body: l.empty_workflows_body,
      action: l.empty_action_new_workflow,
      onAction: onNew,
      secondaryAction: l.empty_action_use_template,
      onSecondaryAction: onTemplate,
    );
  }

  /// Photo finder found nothing (DK-0608): ILL-17 small (80), Close.
  static Widget photoFinder(
    BuildContext context, {
    required VoidCallback onClose,
  }) {
    final l = AppLocalizations.of(context);
    return DkEmptyState(
      illustration: DkIllustrations.findInPhotos,
      illustrationSize: 80,
      title: l.empty_photos_title,
      body: l.empty_photos_body,
      action: l.common_close,
      actionVariant: DkButtonVariant.secondary,
      onAction: onClose,
    );
  }
}
