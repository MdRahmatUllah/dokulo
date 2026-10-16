import 'package:app_pdf/l10n/app_language.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/app_shortcuts.dart';
import 'package:app_pdf/providers/language_providers.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// DK-0597 (the app icon's shortcuts) and DK-0600 (direct share).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final en = lookupAppLocalizations(const Locale('en'));
  final de = lookupAppLocalizations(const Locale('de'));

  test('Scan, Merge PDF, Compress PDF, the last tool; then the two direct '
      'shares', () {
    final s = appShortcuts(en, lastTool: 'redact');
    expect(
      [for (final x in s) (x.id, x.label, x.share)],
      [
        ('scan', 'Scan', false),
        ('merge', 'Merge PDF', false),
        ('compress', 'Compress PDF', false),
        ('redact', 'Black out (redact)', false),
        ('share_compress', 'Compress with Dokulo', true),
        ('share_merge', 'Merge with Dokulo', true),
      ],
    );
    expect(s[1].route, '/tool/merge');
    expect(s[4].route, '/tool/compress');
  });

  test('a last tool among the first three, or unknown, adds none', () {
    expect(appShortcuts(en, lastTool: 'merge'), hasLength(5));
    expect(appShortcuts(en, lastTool: 'gone'), hasLength(5));
    expect(appShortcuts(en), hasLength(5));
  });

  test('German', () {
    final s = appShortcuts(de, lastTool: 'ocr');
    expect(
      [for (final x in s) x.label],
      [
        'Scannen',
        'PDF zusammenfügen',
        'PDF verkleinern',
        'Text durchsuchbar machen',
        'Mit Dokulo verkleinern',
        'Mit Dokulo zusammenfügen',
      ],
    );
  });

  test('published to the platform, again when the last tool changes', () async {
    final sent = <List<Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dokulo/shortcuts'), (
          call,
        ) async {
          if (call.method == 'set') sent.add(call.arguments as List<Object?>);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dokulo/shortcuts'),
            null,
          ),
    );
    final c = ProviderContainer(
      overrides: [
        prefsProvider.overrideWith(() => Prefs.memory()),
        appLanguageSettingProvider.overrideWithBuild(
          (ref, _) => AppLanguage.english,
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(appShortcutsPublisherProvider, (_, _) {});
    await c.read(appShortcutsPublisherProvider.future);
    expect(sent.single, hasLength(5));
    expect(sent.single.first, {
      'id': 'scan',
      'label': 'Scan',
      'link': 'dokulo://open/tool/scan',
      'glyph': 0xe5fa,
      'share': false,
    });
    await c.read(prefsProvider.notifier).set(lastToolKey, 'sign');
    await c.read(appShortcutsPublisherProvider.future);
    expect(sent, hasLength(2));
    expect((sent.last[3] as Map)['label'], 'Sign PDF');
  });
}
