// The component catalogue is a developer page (debug builds only), so its
// labels are English-only on purpose: l10n-ignore throughout.
import 'package:flutter/material.dart';

import '../components/dk_button.dart';
import '../components/dk_icon.dart';
import '../theme/app_theme.dart';
import '../theme/dk_tokens.dart';

/// Every component in every variant and state, in Light or Dark (DK-0074 and
/// each component task after it): `/dev/catalogue`, debug builds only. A new
/// component adds its section to [catalogueSections].
class CatalogueScreen extends StatefulWidget {
  const CatalogueScreen({super.key});

  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  var _dark = false;

  @override
  Widget build(BuildContext context) => Theme(
    data: dokuloTheme(_dark ? DkTokens.dark : DkTokens.light),
    child: Builder(
      builder: (context) {
        final t = context.tokens;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Components'), // l10n-ignore
            actions: [
              Switch(value: _dark, onChanged: (v) => setState(() => _dark = v)),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.all(t.space.l),
            children: [
              for (final (name, section) in catalogueSections) ...[
                Text(name, style: t.text.titleM),
                SizedBox(height: t.space.m),
                section(context),
                SizedBox(height: t.space.xxl),
              ],
            ],
          ),
        );
      },
    ),
  );
}

/// The catalogue's sections: a component's name and its gallery.
final catalogueSections = <(String, WidgetBuilder)>[
  ('DkButton', (_) => const DkButtonGallery()),
];

/// DkButton: every variant in every state, then the sizes (UI spec §11.1).
/// The goldens draw this same gallery.
class DkButtonGallery extends StatelessWidget {
  const DkButtonGallery({super.key, this.label = 'Merge 4 files'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    void tap() {}
    Widget row(DkButtonVariant v) {
      final on = v == DkButtonVariant.onCamera;
      return Container(
        // On camera sits on the camera preview: shown on its dark chrome.
        color: on ? t.color.cameraChrome : null,
        padding: EdgeInsets.all(t.space.xs),
        child: Wrap(
          spacing: t.space.s,
          runSpacing: t.space.s,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DkButton(label: label, onPressed: tap, variant: v),
            DkButton(
              label: label,
              onPressed: tap,
              variant: v,
              showPressed: true,
            ),
            DkButton(
              label: label,
              onPressed: tap,
              variant: v,
              showFocused: true,
            ),
            DkButton(label: label, onPressed: null, variant: v),
            DkButton(
              label: label,
              onPressed: tap,
              variant: v,
              loading: true,
              icon: DkIcons.tool('merge'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: t.space.s,
      children: [
        for (final v in DkButtonVariant.values) row(v),
        Wrap(
          spacing: t.space.s,
          runSpacing: t.space.s,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final s in DkButtonSize.values)
              DkButton(
                label: label,
                onPressed: tap,
                size: s,
                icon: DkIcons.tool('merge'),
              ),
          ],
        ),
        DkButton(label: label, onPressed: tap, expand: true),
      ],
    );
  }
}
