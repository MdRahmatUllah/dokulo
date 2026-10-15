import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_icon.dart';
import '../../components/dk_logo.dart';
import '../../components/dk_promo_cards.dart';
import '../../components/dk_settings_row.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/theme_providers.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';

/// The app's version as the footer shows it; tests keep it equal to
/// pubspec.yaml's `version:` (DK-0570).
// ponytail: a constant, not package_info_plus; read the platform's when the
// build number starts to differ per store.
const appVersion = '1.0.0';
const appBuild = 100;

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
                  DkSettingsGroup(
                    children: [
                      DkSettingsRow(
                        icon: DkIcons.pro,
                        title: l.me_pro_owned,
                        value: l.me_pro_thanks,
                      ),
                    ],
                  )
                else
                  // ponytail: X3, the paywall sheet, comes with DK-0579.
                  DkProCard(onOpen: () {}),
                DkSettingsGroup(
                  title: l.me_your_things,
                  children: [
                    DkSettingsRow(
                      icon: DkIcons.tool('sign'),
                      title: l.me_signatures,
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
                      value: l.settings_language_system,
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
                    // ponytail: Contact and Rate open mail and the store
                    // with DK-0578; Restore with DK-0579.
                    DkSettingsRow(icon: DkIcons.mail, title: l.me_contact),
                    DkSettingsRow(icon: DkIcons.star, title: l.me_rate),
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
