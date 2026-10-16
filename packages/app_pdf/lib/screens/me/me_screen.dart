import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_icon.dart';
import '../../components/dk_logo.dart';
import '../../components/dk_promo_cards.dart';
import '../../components/dk_settings_row.dart';
import '../../components/dk_toast.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_language.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/formats.dart';
import '../../providers/language_providers.dart';
import '../../providers/link_providers.dart';
import '../../providers/mail_providers.dart';
import '../../providers/signature_providers.dart';
import '../../providers/theme_providers.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';
import '../settings/files_settings_screen.dart' show modelsSizeProvider;

/// The app's version as the footer shows it; tests keep it equal to
/// pubspec.yaml's `version:` (DK-0570).
// ponytail: a constant, not package_info_plus; read the platform's when the
// build number starts to differ per store.
const appVersion = '1.0.0';
const appBuild = 100;

/// Dokulo's page on Google Play (Me → Rate Dokulo, DK-0578): the store app
/// opens it.
final playPage = Uri.parse(
  'https://play.google.com/store/apps/details?id=app.dokulo',
);

/// Me → Contact (DK-0578): the subject names the version, so a reply knows
/// which build it is about. No recipient yet (the owner's support address).
Uri contactEmail() => Uri(
  scheme: 'mailto',
  query: 'subject=${Uri.encodeComponent('Dokulo $appVersion ($appBuild)')}',
);

/// Whether the one-time Pro unlock is owned (DK-0579 brings the store).
// ponytail: free until in_app_purchase's entitlement cache exists.
final isProProvider = Provider<bool>((ref) => false);

/// M1 · Me (DK-0570; UI spec §23.1): the large top bar; Pro (the card for
/// free users, "Pro – yours for good · Thank you" for Pro); Your things;
/// Settings; About (Restore purchase always there); the footer.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final pro = ref.watch(isProProvider);
    final theme = ref.watch(appThemeModeProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    // Your things' values (UI spec §23.1).
    // ponytail: Workflows shows its count once saved workflows exist.
    final signatures = ref.watch(signaturesProvider).value?.length;
    final models = ref.watch(modelsSizeProvider).value;
    final language = ref.watch(appLanguageSettingProvider);
    void go(String location) => context.push(location);
    return Scaffold(
      backgroundColor: t.color.background,
      body: CustomScrollView(
        slivers: [
          DkLargeTopBar(title: l.shell_tab_me),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(t.space.l, 0, t.space.l, t.space.xl),
            sliver: SliverList.list(
              children: [
                if (pro)
                  DkSettingsGroup(children: [_ProOwned(l: l)])
                else
                  // ponytail: X3, the paywall sheet, comes with DK-0579.
                  DkProCard(onOpen: () {}),
                DkSettingsGroup(
                  title: l.me_your_things,
                  children: [
                    DkSettingsRow(
                      icon: DkIcons.tool('sign'),
                      title: l.me_signatures,
                      value: signatures?.toString(),
                      onTap: () => go(Routes.tool('sign')),
                    ),
                    DkSettingsRow(
                      icon: DkIcons.tool('workflows'),
                      title: l.tool_workflows_name,
                      onTap: () => go(Routes.tool('workflows')),
                    ),
                    DkSettingsRow(
                      icon: DkIcons.memory,
                      title: l.me_ai_models,
                      value: models == null
                          ? null
                          : formatBytes(models, locale),
                      onTap: () => go(Routes.models),
                    ),
                  ],
                ),
                DkSettingsGroup(
                  title: l.home_settings,
                  children: [
                    DkSettingsRow(
                      icon: DkIcons.scan,
                      title: l.me_scanning,
                      onTap: () => go(Routes.settings('scanning')),
                    ),
                    DkSettingsRow(
                      icon: DkIcons.folder,
                      title: l.me_files_storage,
                      onTap: () => go(Routes.settings('files')),
                    ),
                    DkSettingsRow(
                      icon: DkIcons.lock,
                      title: l.tools_category_security,
                      onTap: () => go(Routes.settings('security')),
                    ),
                    DkSettingsRow(
                      icon: DkIcons.contrast,
                      title: l.me_appearance,
                      value: switch (theme) {
                        ThemeMode.light => l.me_theme_light,
                        ThemeMode.dark => l.me_theme_dark,
                        ThemeMode.system => l.settings_language_system,
                      },
                      onTap: () => go(Routes.settings('appearance')),
                    ),
                    DkSettingsRow(
                      icon: DkIcons.language,
                      title: l.settings_language_title,
                      value: switch (language) {
                        AppLanguage.system => l.settings_language_system,
                        AppLanguage.english => l.settings_language_english,
                        AppLanguage.deutsch => l.settings_language_deutsch,
                      },
                      onTap: () => go(Routes.settings('language')),
                    ),
                  ],
                ),
                DkSettingsGroup(
                  title: l.me_about,
                  children: [
                    DkSettingsRow(
                      icon: DkIcons.shield,
                      title: l.me_privacy,
                      onTap: () => go(Routes.settings('privacy')),
                    ),
                    DkSettingsRow(
                      icon: DkIcons.gavel,
                      title: l.me_licences,
                      onTap: () => go(Routes.settings('licences')),
                    ),
                    DkSettingsRow(
                      icon: DkIcons.replay,
                      title: l.me_replay_intro,
                      onTap: () => context.go(Routes.welcome),
                    ),
                    // Contact: a draft in the user's mail app with the
                    // version (DK-0578); the recipient waits for the
                    // owner's support address, as the crash report's.
                    DkSettingsRow(
                      icon: DkIcons.mail,
                      title: l.me_contact,
                      onTap: () async {
                        final sent = await ref.read(mailComposerProvider)(
                          contactEmail(),
                        );
                        if (!sent && context.mounted) {
                          showDkToast(context, l.error_no_mail_app);
                        }
                      },
                    ),
                    // ponytail: Rate opens Dokulo's Play page; on iOS the
                    // row waits for the App Store id (DK-1141).
                    if (Theme.of(context).platform == TargetPlatform.android)
                      DkSettingsRow(
                        icon: DkIcons.star,
                        title: l.me_rate,
                        onTap: () => ref.read(linkOpenerProvider)(playPage),
                      ),
                    DkSettingsRow(
                      icon: DkIcons.restore,
                      title: l.me_restore_purchase,
                    ),
                  ],
                ),
                SizedBox(height: t.space.xl),
                MergeSemantics(
                  child: Column(
                    spacing: t.space.xs,
                    children: [
                      const DkLogo.symbol(size: 24),
                      Text(
                        // l10n-ignore: the name and the version number
                        'Dokulo $appVersion ($appBuild)',
                        style: t.text.caption.copyWith(
                          color: t.color.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pro, owned (UI spec §23.1 row 2, me-mepro): the row on
/// `color.proContainer`, the filled Pro icon, the title in `type.titleS` and
/// "Thank you" under it; nothing to open.
class _ProOwned extends StatelessWidget {
  const _ProOwned({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    return MergeSemantics(
      child: Container(
        color: c.proContainer,
        constraints: const BoxConstraints(minHeight: 56),
        padding: EdgeInsets.symmetric(
          horizontal: t.space.l,
          vertical: t.space.s,
        ),
        child: Row(
          spacing: t.space.m,
          children: [
            DkIcon(DkIcons.pro, filled: true, color: c.pro),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.me_pro_owned,
                    style: t.text.titleS.copyWith(color: c.textPrimary),
                  ),
                  Text(
                    l.me_pro_thanks,
                    style: t.text.caption.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
