import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../components/dk_icon.dart';
import '../l10n/app_localizations.dart';
import '../routes/routes.dart';
import '../tools/tool_catalogue.dart';
import 'job_notices.dart' show appL10n;
import 'language_providers.dart';
import 'prefs_providers.dart';

part 'app_shortcuts.g.dart';

/// The prefs key of the tool a job last ran with: the app icon's fourth
/// shortcut (DK-0597).
const lastToolKey = 'shortcuts.lastTool';

/// The app icon's long-press menu (DK-0597; UI spec §25, the design's
/// "App-icon shortcuts"): Scan, Merge PDF, Compress PDF and the last used
/// tool; and the share sheet's direct-share targets (DK-0600, §25.5):
/// "Compress with Dokulo", "Merge with Dokulo". [share] ones open the tool
/// with the shared files, the others its route. The icon is the tool's
/// glyph in our Material Symbols font; the platform draws it on primary.
typedef AppShortcut = ({
  String id,
  String label,
  String route,
  int glyph,
  bool share,
});

/// The shortcuts in [l]'s words, [lastTool] fourth unless it's one of the
/// first three.
List<AppShortcut> appShortcuts(AppLocalizations l, {String? lastTool}) {
  AppShortcut tool(String id, {String? label, bool share = false}) => (
    id: share ? 'share_$id' : id,
    label: label ?? ToolCatalogue.of(id).name(l),
    route: Routes.tool(id),
    glyph: DkIcons.tool(id).codePoint,
    share: share,
  );
  const fixed = ['scan', 'merge', 'compress'];
  return [
    for (final id in fixed) tool(id),
    if (lastTool != null &&
        !fixed.contains(lastTool) &&
        DkIcons.tools.containsKey(lastTool))
      tool(lastTool),
    tool('compress', label: l.shortcut_share_compress, share: true),
    tool('merge', label: l.shortcut_share_merge, share: true),
  ];
}

/// Publishes the shortcuts to the platform (`dokulo/shortcuts`,
/// MainActivity.kt) and again when the language or the last tool changes.
/// iOS: not yet (its Quick Actions need the Mac, DK-0598's turn).
@Riverpod(keepAlive: true)
Future<void> appShortcutsPublisher(Ref ref) async {
  ref.watch(appLanguageSettingProvider);
  final prefs = await ref.watch(prefsProvider.future);
  final shortcuts = appShortcuts(
    appL10n(ref),
    lastTool: prefs[lastToolKey] as String?,
  );
  try {
    await const MethodChannel('dokulo/shortcuts').invokeMethod<void>('set', [
      for (final s in shortcuts)
        {
          'id': s.id,
          'label': s.label,
          'link': 'dokulo://open${s.route}',
          'glyph': s.glyph,
          'share': s.share,
        },
    ]);
  } on MissingPluginException {
    // Tests, desktop and (for now) iOS: no shortcuts.
  }
}
