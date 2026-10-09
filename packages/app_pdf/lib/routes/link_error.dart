import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/dk_button.dart';
import '../components/dk_empty_state.dart';
import '../components/dk_illustration.dart';
import '../components/dk_loading_spinner.dart';
import '../l10n/app_localizations.dart';
import '../screens/v1_viewer/viewer_providers.dart';
import '../theme/dk_tokens.dart';
import 'routes.dart';

/// A deep link that leads nowhere (DK-0236): an unknown route or tool, a
/// file that's gone. It says so, with a way Home, instead of crashing.
class LinkErrorScreen extends StatelessWidget {
  const LinkErrorScreen({super.key, this.fileMissing = false});

  /// The link named a file that isn't in Dokulo any more.
  final bool fileMissing;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.tokens.color.surface,
      body: SafeArea(
        child: Center(
          child: DkEmptyState(
            illustration: DkIllustrations.searchNoResults,
            title: fileMissing ? l.viewer_file_missing : l.link_broken_title,
            body: l.link_broken_body,
            action: l.link_action_home,
            actionVariant: DkButtonVariant.secondary,
            onAction: () => context.go(Routes.home),
          ),
        ),
      ),
    );
  }
}

/// [child] once the link's file handle ([fileId], a row id) is found;
/// [LinkErrorScreen] when it's malformed or the file is gone.
class LinkedFileGate extends ConsumerWidget {
  const LinkedFileGate({super.key, required this.fileId, required this.child});

  final String fileId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(fileId);
    if (id == null) return const LinkErrorScreen(fileMissing: true);
    return switch (ref.watch(viewerFileProvider(id))) {
      AsyncData() => child,
      AsyncError() => const LinkErrorScreen(fileMissing: true),
      _ => const Scaffold(body: Center(child: DkLoadingSpinner())),
    };
  }
}
