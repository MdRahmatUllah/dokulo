import 'package:app_pdf/components/dk_button.dart';
import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/components/dk_skeleton.dart';
import 'package:app_pdf/errors/dokulo_error.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/patterns/dk_banners.dart';
import 'package:app_pdf/patterns/dk_empty_states.dart';
import 'package:app_pdf/patterns/dk_permission_banner.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Visual QA (DK-0980): the design frame 26-global-states/global-states.html,
// built from the real empty states, toasts, banners, error catalogue and
// skeleton with the frame's data, in its layout, at 1440 wide. The goldens
// sit next to the frame's own screenshots in docs/qa/global-states/; the
// findings are in docs/qa/design-system.md. Text is the test font (Ahem),
// so the copy is checked below as strings.

void _none() {}

/// The frame's error catalogue: each situation as the frame shows it, with
/// the frame's caption under the title.
final _catalogue = <(DokuloError, String)>[
  (const DokuloError(DkErrorSituation.locked), 'Locked input'),
  (const DokuloError(DkErrorSituation.damaged), 'Damaged file'),
  (
    const DokuloError(
      DkErrorSituation.notEnoughStorage,
      neededBytes: 120000000,
    ),
    'Not enough storage',
  ),
  (const DokuloError(DkErrorSituation.tooLarge), 'Too large for memory'),
  (const DokuloError(DkErrorSituation.unsupportedForm), 'Unsupported XFA form'),
  (
    const DokuloError(DkErrorSituation.modelMissing, modelBytes: 440000000),
    'Model missing',
  ),
  (const DokuloError(DkErrorSituation.lowMemory), 'Low memory'),
  (const DokuloError(DkErrorSituation.cancelled), 'Cancelled'),
  (
    const DokuloError(DkErrorSituation.unexpected, page: 13),
    'Unexpected · also: Skip this page, Send report by email',
  ),
  (const DokuloError(DkErrorSituation.offline), 'Web page to PDF only'),
];

Widget _heading(BuildContext context, String text) => Padding(
  padding: EdgeInsets.only(bottom: context.tokens.space.l),
  child: Text(
    text,
    style: context.tokens.text.titleM.copyWith(
      color: context.tokens.color.textPrimary,
    ),
  ),
);

/// A frame card: `color.surface`, a 1 dp outline, `radius.l`.
BoxDecoration _card(DkTokens t) => BoxDecoration(
  color: t.color.surface,
  border: Border.all(color: t.color.outline),
  borderRadius: BorderRadius.circular(t.radius.l),
);

/// A toast as showDkToast draws it, from the theme's SnackBar style.
Widget _toast(BuildContext context, String message, {String? action}) {
  final t = context.tokens;
  final s = Theme.of(context).snackBarTheme;
  return Container(
    height: 48,
    padding: EdgeInsets.symmetric(horizontal: t.space.l),
    decoration: ShapeDecoration(color: s.backgroundColor, shape: s.shape!),
    child: Row(
      children: [
        Expanded(child: Text(message, style: s.contentTextStyle)),
        if (action != null)
          Text(action, style: t.text.labelL.copyWith(color: s.actionTextColor)),
      ],
    ),
  );
}

class _Board extends StatelessWidget {
  const _Board();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final empties = [
      (DkEmptyStates.homeRecents(context, onScan: _none), 'ILL-04 · Home'),
      (
        DkEmptyStates.filesRoot(context, onScan: _none, onOpenFile: _none),
        'ILL-05 · Files root',
      ),
      (DkEmptyStates.folder(context, onMove: _none), 'ILL-06 · Folder'),
      (DkEmptyStates.search(context, query: 'Kaution'), 'ILL-07 · Search'),
      (DkEmptyStates.trash(context), 'ILL-08 · Trash'),
      (DkEmptyStates.signatures(context, onAdd: _none), 'ILL-15 · Signatures'),
      (
        DkEmptyStates.workflows(context, onNew: _none, onTemplate: _none),
        'ILL-16 · Workflows',
      ),
      (
        DkEmptyStates.photoFinder(context, onClose: _none),
        'ILL-17 · Photo finder',
      ),
    ];
    Widget emptyCard((Widget, String) e) => Expanded(
      child: Container(
        padding: EdgeInsets.all(t.space.l),
        decoration: _card(t),
        child: Column(
          children: [
            Expanded(child: Center(child: e.$1)),
            Text(
              e.$2,
              style: t.text.caption.copyWith(color: t.color.textSecondary),
            ),
          ],
        ),
      ),
    );
    // The frame's cards are 385 tall; the test font (Ahem) runs wider, so
    // its lines wrap more.
    Widget row(List<(Widget, String)> four) => SizedBox(
      height: 500,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: t.space.l,
        children: [for (final e in four) emptyCard(e)],
      ),
    );

    return ColoredBox(
      color: t.color.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(64, 48, 64, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(context, 'Empty states'),
            row(empties.sublist(0, 4)),
            SizedBox(height: t.space.l),
            row(empties.sublist(4)),
            SizedBox(height: t.space.xxl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 48,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: t.space.m,
                    children: [
                      _heading(context, 'Toasts and banners'),
                      _toast(
                        context,
                        l.toast_moved_trash,
                        action: l.common_undo,
                      ),
                      _toast(
                        context,
                        l.toast_saved_to('Files › Taxes'),
                        action: l.common_open,
                      ),
                      _toast(
                        context,
                        '2 pages deleted', // the copy deck has the singular
                        action: l.common_undo,
                      ),
                      _toast(context, l.toast_copied),
                      DkBanners.noSearchableText(
                        context,
                        count: 3,
                        onMakeSearchable: _none,
                      ),
                      DkPermissionBanner(
                        permission: DkPermission.camera,
                        onOpenSettings: _none,
                      ),
                      DkBanners.purchaseFailed(context),
                      DkBanners.proFreeTry(context),
                      SizedBox(height: t.space.m),
                      _heading(context, 'Loading'),
                      Container(
                        decoration: _card(t),
                        padding: EdgeInsets.all(t.space.s),
                        child: DkSkeleton.fileRows(count: 2),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heading(context, 'Error catalogue'),
                      Container(
                        decoration: _card(t),
                        padding: EdgeInsets.symmetric(
                          horizontal: t.space.xl,
                          vertical: t.space.xs,
                        ),
                        child: Column(
                          children: [
                            for (final (i, (error, caption))
                                in _catalogue.indexed)
                              _ErrorRow(
                                error: error,
                                caption: caption,
                                divider: i < _catalogue.length - 1,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of the frame's error catalogue: the situation's icon, its title
/// with the frame's caption, and its first recovery as a small secondary
/// button.
class _ErrorRow extends StatelessWidget {
  const _ErrorRow({
    required this.error,
    required this.caption,
    required this.divider,
  });

  final DokuloError error;
  final String caption;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final s = error.situation;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: EdgeInsets.symmetric(vertical: t.space.s),
      decoration: BoxDecoration(
        border: divider
            ? Border(bottom: BorderSide(color: t.color.outline))
            : null,
      ),
      child: Row(
        spacing: t.space.l,
        children: [
          DkIcon(s.icon, size: DkIconSize.m, color: s.iconColor(t.color)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error.title(l),
                  style: t.text.bodyL.copyWith(color: t.color.textPrimary),
                ),
                Text(
                  caption,
                  style: t.text.caption.copyWith(color: t.color.textSecondary),
                ),
              ],
            ),
          ),
          if (error.actions.isNotEmpty)
            DkButton(
              label: error.actions.first.label(l),
              onPressed: _none,
              variant: DkButtonVariant.secondary,
              size: DkButtonSize.compact,
            ),
        ],
      ),
    );
  }
}

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('golden: global_states_$theme, the board at 1440 wide', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(1440, 1700),
            disableAnimations: true, // a still skeleton
          ),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dokuloTheme(tokens),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SingleChildScrollView(child: _Board())),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(_Board),
        matchesGoldenFile('goldens/global_states_$theme.png'),
      );
    });
  }

  test("the frame's error catalogue copy and actions, EN (UI spec §26.3)", () {
    final en = lookupAppLocalizations(const Locale('en'));
    final frame = {
      DkErrorSituation.locked: ('This PDF is locked.', 'Enter password'),
      DkErrorSituation.damaged: ("This file can't be opened.", 'Try Repair'),
      DkErrorSituation.notEnoughStorage: (
        'Not enough space on this phone (needs about 120 MB).',
        'Manage storage',
      ),
      DkErrorSituation.tooLarge: (
        'This file is too large to process at once on this phone.',
        'Split it first',
      ),
      DkErrorSituation.unsupportedForm: (
        "This form type can't be filled on phones.",
        'Open read-only',
      ),
      DkErrorSituation.modelMissing: (
        'Translation needs a language model (440 MB).',
        'Download',
      ),
      DkErrorSituation.lowMemory: (
        'Close other apps to use AI – it needs about 2 GB free.',
        'Try again',
      ),
      DkErrorSituation.cancelled: (
        "Cancelled. Your original file wasn't changed.",
        null,
      ),
      // The frame's code is the spec's example; ours is the situation's.
      DkErrorSituation.unexpected: (
        'Something went wrong on page 14. (code DK-0190)',
        'Try again',
      ),
      DkErrorSituation.offline: ("You're offline.", 'Try again'),
    };
    for (final (error, _) in _catalogue) {
      final (title, action) = frame[error.situation]!;
      expect(error.title(en), title, reason: error.situation.name);
      expect(
        error.actions.firstOrNull?.label(en),
        action,
        reason: error.situation.name,
      );
    }
  });

  test("the frame's icons and colours for each situation", () {
    final c = DkTokens.light.color;
    final frame = {
      DkErrorSituation.locked: (DkIcons.lock, c.warning),
      DkErrorSituation.damaged: (DkIcons.damaged, c.danger),
      DkErrorSituation.notEnoughStorage: (DkIcons.storage, c.warning),
      DkErrorSituation.tooLarge: (DkIcons.memory, c.warning),
      DkErrorSituation.unsupportedForm: (DkIcons.formUnsupported, c.warning),
      DkErrorSituation.modelMissing: (DkIcons.download, c.primary),
      DkErrorSituation.lowMemory: (DkIcons.memory, c.warning),
      DkErrorSituation.cancelled: (DkIcons.cancelled, c.iconSecondary),
      DkErrorSituation.unexpected: (DkIcons.error, c.danger),
      DkErrorSituation.offline: (DkIcons.offline, c.iconSecondary),
    };
    for (final s in DkErrorSituation.values) {
      expect((s.icon, s.iconColor(c)), frame[s], reason: s.name);
    }
  });

  testWidgets("the toasts' and banners' copy, EN", (tester) async {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.toast_moved_trash, 'Moved to Recently deleted');
    expect(en.toast_saved_to('Files › Taxes'), 'Saved to Files › Taxes');
    expect(en.toast_copied, 'Copied');
    expect(en.banner_no_text(3), '3 scans have no searchable text yet.');
    expect(en.banner_make_searchable, 'Make searchable');
    expect(
      en.permission_off_camera,
      "Camera access is off, so scanning doesn't work.",
    );
    expect(
      en.banner_purchase_failed,
      "Purchase didn't complete. You weren't charged.",
    );
    expect(en.banner_pro_free_try, 'Free try · Pro unlocks unlimited use');
  });
}
