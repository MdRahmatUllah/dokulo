import 'package:app_pdf/catalogue/detection_states.dart';
import 'package:app_pdf/catalogue/page_states.dart';
import 'package:app_pdf/components/dk_action_sheet.dart';
import 'package:app_pdf/components/dk_ai_parts.dart';
import 'package:app_pdf/components/dk_bottom_bars.dart';
import 'package:app_pdf/components/dk_button.dart';
import 'package:app_pdf/components/dk_chat_bubble.dart';
import 'package:app_pdf/components/dk_checkbox_row.dart';
import 'package:app_pdf/components/dk_crop_overlay.dart';
import 'package:app_pdf/components/dk_detection_group.dart';
import 'package:app_pdf/components/dk_dropdown.dart';
import 'package:app_pdf/components/dk_empty_state.dart';
import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/components/dk_illustration.dart';
import 'package:app_pdf/components/dk_loading_spinner.dart';
import 'package:app_pdf/components/dk_page_grid.dart';
import 'package:app_pdf/components/dk_page_thumb.dart';
import 'package:app_pdf/components/dk_page_tray.dart';
import 'package:app_pdf/components/dk_pin_pad.dart';
import 'package:app_pdf/components/dk_position_picker.dart';
import 'package:app_pdf/components/dk_radio_row.dart';
import 'package:app_pdf/components/dk_settings_row.dart';
import 'package:app_pdf/components/dk_sheet.dart';
import 'package:app_pdf/components/dk_signature_card.dart';
import 'package:app_pdf/components/dk_status_dot.dart';
import 'package:app_pdf/components/dk_switch.dart';
import 'package:app_pdf/components/dk_tab_bar.dart';
import 'package:app_pdf/components/dk_tool_options_sheet.dart';
import 'package:app_pdf/components/dk_top_bar.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/routes/app_shell.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_layout.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Visual QA (DK-0984): the components of the design frame
// 00-design-system/components-part-2.html, built from the real components
// with the frame's data and in its three columns, at 1440 wide. The goldens
// sit next to the frame's own screenshots in docs/qa/components-part-2/;
// the findings are in docs/qa/design-system.md. Text is the test font
// (Ahem), so the copy is checked below as strings.

void _none() {}

/// A frame panel: the component names in titleS over the specimens.
Widget _panel(BuildContext context, String title, List<Widget> children) {
  final t = context.tokens;
  return Container(
    margin: EdgeInsets.only(bottom: t.space.xl),
    padding: EdgeInsets.all(t.space.l),
    decoration: t.surfaceAt(
      DkLevel.raised,
      radius: BorderRadius.circular(t.radius.l),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: t.space.m,
      children: [
        Text(title, style: t.text.titleS.copyWith(color: t.color.textPrimary)),
        ...children,
      ],
    ),
  );
}

class _Board extends StatelessWidget {
  const _Board();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget column(List<Widget> panels) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: panels,
      ),
    );
    final page = const CataloguePage();
    return ColoredBox(
      color: t.color.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(56, 48, 56, 48),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 24,
          children: [
            column([
              _panel(context, 'DkSettingsRow', [
                DkSettingsGroup(
                  title: 'Section header',
                  children: [
                    DkSettingsRow(
                      title: 'Single line + chevron',
                      icon: DkIcons.scanDocument,
                      onTap: _none,
                    ),
                    DkSettingsRow(
                      title: 'With description',
                      description: 'Help text in textSecondary',
                      trailing: DkSwitch(value: true, onChanged: (_) {}),
                    ),
                    const DkSettingsRow(
                      title: 'Value + chevron',
                      value: '30 days',
                      onTap: _none,
                    ),
                  ],
                ),
              ]),
              _panel(context, 'DkCheckboxRow · DkRadioRow · DkDropdown', [
                DkCheckboxRow(
                  label: 'IBAN',
                  value: true,
                  count: 2,
                  onChanged: (_) {},
                ),
                DkCheckboxRow(
                  label: 'Names (AI)',
                  value: false,
                  count: 4,
                  onChanged: (_) {},
                ),
                RadioGroup<int>(
                  groupValue: 0,
                  onChanged: (_) {},
                  child: const Column(
                    children: [
                      DkRadioRow(
                        value: 0,
                        label: 'One PDF',
                        description: 'All photos in one file',
                      ),
                      DkRadioRow(value: 1, label: 'One PDF per photo'),
                    ],
                  ),
                ),
                DkDropdown<String>(
                  label: 'Language',
                  options: const [
                    ('auto', 'Auto (German, English)'),
                    ('de', 'German'),
                    ('en', 'English'),
                    ('fr', 'French'),
                  ],
                  value: 'auto',
                  onChanged: (_) {},
                ),
              ]),
              _panel(context, 'DkPinPad', [
                DkPinPad(
                  onComplete: (_) {},
                  onBiometric: _none,
                  biometricIcon: DkIcons.faceId,
                ),
              ]),
              _panel(context, 'DkEmptyState', [
                const DkEmptyState(
                  illustration: DkIllustrations.folderEmpty,
                  title: 'This folder is empty',
                  body: 'Move files here from Files or save tool results here.',
                  action: 'Move files here',
                  onAction: _none,
                  actionVariant: DkButtonVariant.secondary,
                ),
              ]),
            ]),
            column([
              _panel(context, 'DkPositionPicker', [
                Row(
                  spacing: t.space.l,
                  children: [
                    DkPositionPicker(
                      selected: DkPagePosition.bottomCentre,
                      onChanged: (_) {},
                      withCentre: true,
                    ),
                  ],
                ),
              ]),
              _panel(context, 'DkPageTray · DkPageGrid', [
                DkPageTray(
                  pageIds: const [1, 2, 3, 4],
                  pageBuilder: (_, _) => page,
                  current: 1,
                  onSelect: (_) {},
                  onAdd: _none,
                ),
                SizedBox(
                  height: 190,
                  child: DkPageGrid(
                    pageIds: const [1, 2, 3],
                    pageBuilder: (_, _) => page,
                    selected: const {1},
                    onTap: (_) {},
                  ),
                ),
              ]),
              _panel(context, 'DkCropOverlay · DkMagnifier', [
                DkCropOverlay(
                  image: const ColoredBox(color: Color(0xFFF2F0EA)),
                  aspectRatio: 16 / 9,
                  quad: const [
                    Offset(0.1, 0.1),
                    Offset(0.9, 0.1),
                    Offset(0.9, 0.9),
                    Offset(0.1, 0.9),
                  ],
                  rectangle: true,
                  onChanged: (_) {},
                  onAuto: _none,
                  onFullPage: _none,
                  onReset: _none,
                ),
              ]),
              _panel(context, 'DkToolOptionsSheet', [
                DkSheet(
                  title: 'Highlighter',
                  onClose: _none,
                  body: DkToolOptionsSheet(
                    kind: DkMarkupKind.highlighter,
                    options: DkToolOptions(color: t.markup.yellow),
                    onChanged: (_) {},
                  ),
                ),
              ]),
            ]),
            column([
              _panel(context, 'DkSelectionBar · DkViewerBar', [
                DkTopBar.editing(
                  title: '3 selected',
                  onCancel: _none,
                  onDone: _none,
                  doneLabel: 'Select all',
                ),
                DkSelectionBar(
                  actions: [
                    DkBarAction(
                      icon: DkIcons.share(context),
                      label: 'Share',
                      onPressed: _none,
                    ),
                    const DkBarAction(
                      icon: DkIcons.move,
                      label: 'Move',
                      onPressed: _none,
                    ),
                    DkBarAction(
                      icon: DkIcons.tool('merge'),
                      label: 'Merge',
                      onPressed: _none,
                    ),
                    DkBarAction(
                      icon: DkIcons.tool('compress'),
                      label: 'Compress',
                      onPressed: _none,
                    ),
                    DkBarAction(
                      icon: DkIcons.overflow(context),
                      label: 'More',
                      onPressed: _none,
                    ),
                  ],
                ),
                DkViewerBar(
                  actions: [
                    const DkBarAction(
                      icon: DkIcons.pen,
                      label: 'Edit',
                      onPressed: _none,
                    ),
                    DkBarAction(
                      icon: DkIcons.tool('sign'),
                      label: 'Sign',
                      onPressed: _none,
                    ),
                    DkBarAction(
                      icon: DkIcons.tool('summarize'),
                      label: 'AI',
                      onPressed: _none,
                    ),
                    const DkBarAction(
                      icon: DkIcons.toolsTab,
                      label: 'Tools',
                      onPressed: _none,
                    ),
                    DkBarAction(
                      icon: DkIcons.share(context),
                      label: 'Share',
                      onPressed: _none,
                    ),
                  ],
                ),
              ]),
              _panel(context, 'DkNavRail (tablet ≥ 840)', [
                SizedBox(
                  height: 420,
                  child: Row(
                    children: [
                      DkNavRail(
                        items: shellTabs(context),
                        currentIndex: 0,
                        onSelect: (_) {},
                        onScan: _none,
                      ),
                    ],
                  ),
                ),
              ]),
              _panel(context, 'DkActionSheet header · DkSignatureCard', [
                DkActionSheetHeader(
                  thumbnail: DkPageThumb(
                    pageNumber: 1,
                    pageCount: 12,
                    page: page,
                    showNumber: false,
                    aspectRatio: 40 / 52,
                  ),
                  name: 'Mietvertrag Musterstraße 12.pdf',
                  meta: '2.4 MB · 12 pages',
                ),
                // The file action sheet's primary row (§16.3).
                Row(
                  spacing: t.space.s,
                  children: [
                    Expanded(
                      child: DkButton(
                        label: 'Open',
                        icon: DkIcons.open,
                        variant: DkButtonVariant.tonal,
                        size: DkButtonSize.large,
                        expand: true,
                        onPressed: _none,
                      ),
                    ),
                    Expanded(
                      child: DkButton(
                        label: 'Share',
                        icon: DkIcons.share(context),
                        variant: DkButtonVariant.tonal,
                        size: DkButtonSize.large,
                        expand: true,
                        onPressed: _none,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    DkSignatureCard(
                      signature: Text(
                        'M. Mustermann',
                        style: TextStyle(
                          fontFamily: 'HomemadeApple',
                          fontSize: 18,
                          color: t.markup.ink,
                        ),
                      ),
                      onTap: _none,
                    ),
                  ],
                ),
              ]),
              _panel(context, 'AI: streaming, detection group', [
                const DkChatBubble(
                  role: DkChatRole.ai,
                  text: 'Rent is **1,240 EUR** plus operating costs',
                  streaming: true,
                ),
                DkDetectionGroup(
                  icon: DetectionGroupStates.iban,
                  name: 'IBAN',
                  items: const [
                    DkDetection(
                      preview: 'DE00 •••• •••• 0000 00',
                      page: 1,
                      checked: true,
                    ),
                    DkDetection(
                      preview: 'DE00 •••• •••• 0000 01',
                      page: 3,
                      checked: true,
                    ),
                  ],
                  expanded: true,
                  onExpanded: (_) {},
                  onCheckedAll: (_) {},
                  onChecked: (_, _) {},
                  onPage: (_) {},
                ),
                const Row(
                  spacing: 8,
                  children: [
                    DkLoadingSpinner(),
                    DkLoadingSpinner(size: DkSpinnerSize.large),
                    DkStatusDot(DkStatus.running),
                  ],
                ),
                const DkAIFooter(model: 'Gemma 4 E2B'),
              ]),
            ]),
          ],
        ),
      ),
    );
  }
}

Widget _app(DkTokens tokens) => ProviderScope(
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dokuloTheme(tokens),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(body: SingleChildScrollView(child: _Board())),
  ),
);

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('components part 2, $name, beside the frame', (tester) async {
      tester.view.physicalSize = const Size(1440, 2264);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(tokens));
      // Spinners and the running dot repeat: no settling.
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(_Board),
        matchesGoldenFile('goldens/components_part2_$name.png'),
      );
    });
  }

  testWidgets("the copy matches the frame's (EN)", (tester) async {
    tester.view.physicalSize = const Size(1440, 2264);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(DkTokens.light));
    await tester.pump(const Duration(milliseconds: 300));
    // Strings the components produce themselves (from the ARB files), as
    // the frame writes them.
    for (final text in [
      'Auto',
      'Full page',
      'Reset',
      'Opacity',
      '40 %',
      'Cancel',
      'Home',
      'Tools',
      'Files',
      'Me',
      'p. 1',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
  });
}
