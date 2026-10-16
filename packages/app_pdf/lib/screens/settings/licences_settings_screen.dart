import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_settings_row.dart';
import '../../components/dk_skeleton.dart';
import '../../components/dk_text_field.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../legal/third_party.dart';
import '../../theme/dk_tokens.dart';

/// Every licence (DK-0673's [licences]), read once.
final licencesProvider = FutureProvider<List<LicenceItem>>((ref) => licences());

/// M3 · Open-source licences (DK-0577; UI spec §23.3, me-licences): a
/// search field, then every component with its licence; a row opens the
/// full text (me-licence).
class LicencesSettingsScreen extends ConsumerStatefulWidget {
  const LicencesSettingsScreen({super.key});

  @override
  ConsumerState<LicencesSettingsScreen> createState() =>
      _LicencesSettingsScreenState();
}

class _LicencesSettingsScreenState
    extends ConsumerState<LicencesSettingsScreen> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final q = _query.trim().toLowerCase();
    final items = [
      for (final i
          in ref.watch(licencesProvider).value ?? const <LicenceItem>[])
        if (q.isEmpty ||
            i.name.toLowerCase().contains(q) ||
            i.licence.toLowerCase().contains(q))
          i,
    ];
    final loading = !ref.watch(licencesProvider).hasValue;
    return Scaffold(
      backgroundColor: t.color.background,
      appBar: DkTopBar(title: l.me_licences),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          t.space.l,
          t.space.s,
          t.space.l,
          t.space.l,
        ),
        children: [
          DkSearchField(
            hint: l.licences_search,
            onChanged: (v) => setState(() => _query = v),
          ),
          SizedBox(height: t.space.l),
          if (loading)
            for (var i = 0; i < 6; i++) const DkSkeletonFileRow()
          else
            DkSettingsGroup(
              children: [
                for (final i in items)
                  DkSettingsRow(
                    title: i.name,
                    description: i.licence.isEmpty ? null : i.licence,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LicenceScreen(item: i),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// One licence's full text (me-licence): "Name · Licence" as a caption over
/// the texts in the platform's mono.
class LicenceScreen extends StatelessWidget {
  const LicenceScreen({super.key, required this.item});

  final LicenceItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: DkTopBar(title: l.licence_title),
      body: SelectionArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            t.space.l,
            t.space.s,
            t.space.l,
            t.space.l,
          ),
          children: [
            Text(
              [
                item.name,
                if (item.licence.isNotEmpty) item.licence,
              ].join(' · '),
              style: t.text.caption.copyWith(color: c.textSecondary),
            ),
            for (final text in item.texts) ...[
              SizedBox(height: t.space.m),
              Text(text, style: t.text.mono.copyWith(color: c.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}
