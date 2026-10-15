import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_icon.dart';
import '../../components/dk_settings_row.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_language.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/language_providers.dart';
import '../../theme/dk_tokens.dart';

/// M3 · Language (DK-0575; UI spec §25): System · English · Deutsch, the
/// choice checked; it applies at once, no restart.
class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final current = ref.watch(appLanguageSettingProvider);
    return Scaffold(
      backgroundColor: t.color.background,
      appBar: DkTopBar(title: l.settings_language_title),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          t.space.l,
          t.space.s,
          t.space.l,
          t.space.l,
        ),
        children: [
          DkSettingsGroup(
            children: [
              for (final (language, label) in [
                (AppLanguage.system, l.settings_language_system),
                (AppLanguage.english, l.settings_language_english),
                (AppLanguage.deutsch, l.settings_language_deutsch),
              ])
                // Read out as a radio: "English, not selected, 2 of 3".
                MergeSemantics(
                  child: Semantics(
                    checked: language == current,
                    inMutuallyExclusiveGroup: true,
                    child: DkSettingsRow(
                      title: label,
                      trailing: language == current
                          ? DkIcon(DkIcons.check, color: t.color.primary)
                          : const SizedBox.square(dimension: 24),
                      onTap: () => ref
                          .read(appLanguageSettingProvider.notifier)
                          .select(language),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: t.space.s),
            child: Text(
              l.settings_language_caption,
              style: t.text.caption.copyWith(color: t.color.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
