import 'package:flutter/material.dart';

import '../components/dk_action_sheet.dart';
import '../components/dk_icon.dart';
import '../components/dk_page_thumb.dart';
import '../components/dk_sheet.dart';
import '../theme/dk_tokens.dart';
import 'page_states.dart';

/// Sample content: a few lines of body text.
class _Lines extends StatelessWidget {
  const _Lines();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      'Sheets hold short tasks: options, a choice, a confirmation. The '
      'content scrolls; the action area stays at the bottom.',
      style: t.text.bodyM.copyWith(color: t.color.textSecondary),
    );
  }
}

/// DkSheet (DK-0182): as it is drawn, with a title, the × and an action;
/// then buttons that open it at each detent, with a confirmation, and as
/// the tablet dialog.
class SheetStates extends StatelessWidget {
  const SheetStates({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget open(String label, VoidCallback onPressed) =>
        OutlinedButton(onPressed: onPressed, child: Text(label));
    return ColoredBox(
      color: t.color.scrim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(t.space.l),
            child: Wrap(
              spacing: t.space.s,
              runSpacing: t.space.s,
              children: [
                open(
                  'Small',
                  () => showDkSheet<void>(
                    context,
                    title: 'Sort by',
                    showClose: true,
                    body: const _Lines(),
                  ),
                ),
                open(
                  'Medium',
                  () => showDkSheet<void>(
                    context,
                    title: 'Options',
                    detent: DkSheetDetent.medium,
                    body: const _Lines(),
                    actions: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Apply'),
                    ),
                  ),
                ),
                open(
                  'Large',
                  () => showDkSheet<void>(
                    context,
                    title: 'Details',
                    detent: DkSheetDetent.large,
                    body: const _Lines(),
                  ),
                ),
                open(
                  'Asks before closing',
                  () => showDkSheet<void>(
                    context,
                    title: 'Unsaved changes',
                    body: const _Lines(),
                    confirmDismiss: () async => false,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: t.space.xxl),
          const DkSheet(
            title: 'Sort by',
            body: _Lines(),
            onClose: _none,
            actions: FilledButton(onPressed: _none, child: Text('Apply')),
          ),
        ],
      ),
    );
  }

  static void _none() {}
}

/// DkActionSheet (DK-0184): a file's actions, as F1's action sheet in the
/// design export: tools, file actions, and Delete last in danger.
class ActionSheetStates extends StatelessWidget {
  const ActionSheetStates({super.key});

  static void _none() {}

  static final groups = [
    [
      DkAction(
        icon: DkIcons.tool('compress'),
        label: 'Compress PDF',
        onTap: _none,
        tool: true,
      ),
      DkAction(
        icon: DkIcons.tool('sign'),
        label: 'Sign PDF',
        onTap: _none,
        tool: true,
      ),
    ],
    [
      const DkAction(icon: DkIcons.rename, label: 'Rename', onTap: _none),
      // Listed early on purpose: the sheet moves it to the end.
      const DkAction(
        icon: DkIcons.delete,
        label: 'Delete',
        onTap: _none,
        destructive: true,
      ),
      const DkAction(icon: DkIcons.move, label: 'Move', onTap: _none),
      const DkAction(icon: DkIcons.info, label: 'Info', onTap: _none),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ColoredBox(
      color: t.color.scrim,
      child: Padding(
        padding: EdgeInsets.only(top: t.space.xxl),
        child: DkSheet(
          body: DkActionSheet(
            closeOnTap: false,
            header: DkActionSheetHeader(
              thumbnail: const DkPageThumb(
                pageNumber: 1,
                pageCount: 12,
                page: CataloguePage(),
                showNumber: false,
                aspectRatio: 40 / 52,
              ),
              name: 'Mietvertrag Musterstraße 12.pdf',
              meta: '2.4 MB · 12 pages · Today 14:32',
            ),
            groups: groups,
          ),
        ),
      ),
    );
  }
}
