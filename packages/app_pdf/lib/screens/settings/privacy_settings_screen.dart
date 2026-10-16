import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_banner.dart';
import '../../components/dk_settings_row.dart';
import '../../components/dk_switch.dart';
import '../../components/dk_toast.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/crash_providers.dart';
import '../../theme/dk_layout.dart';
import '../../theme/dk_tokens.dart';

/// M3 · Privacy (DK-0576; UI spec §23.3, me-privacy): what stays on the
/// phone, what uses the internet, "No analytics, no ads, no account", and
/// the crash reports the user keeps and sends (DK-0011: off by default,
/// sent only as an email the user sends).
// ponytail: "Full privacy policy" waits for its URL (the domain is the
// owner's, docs/compliance/store-privacy-labels.md); add the link row then.
class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final keep = ref.watch(crashReportsEnabledProvider);
    void setKeep(bool on) =>
        ref.read(crashReportsEnabledProvider.notifier).set(on);
    final tablet =
        DkGrid.forWidth(MediaQuery.sizeOf(context).width) != DkGrid.phone;

    Widget list(String title, List<String> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: t.space.s,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: t.text.titleM.copyWith(color: c.textPrimary),
          ),
        ),
        for (final item in items)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: ExcludeSemantics(
                  child: Text(
                    '•', // l10n-ignore: a list bullet
                    style: t.text.bodyL.copyWith(color: c.textPrimary),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  item,
                  style: t.text.bodyL.copyWith(color: c.textPrimary),
                ),
              ),
            ],
          ),
      ],
    );

    return Scaffold(
      backgroundColor: c.background,
      appBar: DkTopBar(title: l.me_privacy),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          t.space.l,
          t.space.s,
          t.space.l,
          t.space.l,
        ),
        children: [
          list(tablet ? l.privacy_stays_title_tablet : l.privacy_stays_title, [
            l.privacy_stays_files,
            l.privacy_stays_ai,
            l.privacy_stays_signatures,
          ]),
          SizedBox(height: t.space.l),
          list(l.privacy_internet_title, [
            l.privacy_internet_models,
            l.privacy_internet_web,
            l.privacy_internet_purchases,
          ]),
          SizedBox(height: t.space.l),
          DkBanner(text: l.privacy_none),
          DkSettingsGroup(
            title: l.privacy_crash_title,
            children: [
              DkSettingsRow(
                title: l.privacy_crash_keep,
                description: l.privacy_crash_keep_help,
                trailing: DkSwitch(value: keep, onChanged: setKeep),
                onTap: () => setKeep(!keep),
              ),
              DkSettingsRow(
                title: l.error_action_send_report,
                onTap: () async {
                  final sent = await sendCrashReport(ref);
                  if (!sent && context.mounted) {
                    showDkToast(context, l.error_no_mail_app);
                  }
                },
              ),
              DkSettingsRow(
                title: l.privacy_crash_delete,
                onTap: () async {
                  await (await ref.read(crashLogProvider.future)).clear();
                  if (context.mounted) {
                    showDkToast(context, l.privacy_crash_deleted);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
