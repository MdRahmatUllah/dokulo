import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/tools/tool_catalogue.dart';
import 'package:doc_tools/doc_tools.dart' show toolJobIds;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ids = ToolCatalogue.all.map((t) => t.id).toList();

  test('all 31 tools, each once, each with its own icon', () {
    expect(ids, hasLength(31));
    expect(ids.toSet(), hasLength(31));
    expect(ids.toSet(), DkIcons.tools.keys.toSet());
    final icons = ToolCatalogue.all.map((t) => t.icon).toSet();
    expect(icons, hasLength(31), reason: 'no two tools share an icon');
    for (final t in ToolCatalogue.all) {
      expect(t.icon, DkIcons.tool(t.id), reason: 'one source for the icon');
    }
  });

  test('every ToolJob has an entry', () {
    expect(ids, containsAll(toolJobIds));
  });

  test('sections and tiers as the Tools tab shows them (UI spec §15.2)', () {
    List<String> section(ToolCategory c) =>
        ToolCatalogue.inCategory(c).map((t) => t.id).toList();
    expect(section(ToolCategory.organize), [
      'merge', 'split', 'extract', 'organize', 'rotate', 'smartsplit', //
    ]);
    expect(section(ToolCategory.ai), ['summarize', 'ask', 'translate']);
    expect(section(ToolCategory.automation), [
      'extractassets', 'batch', 'workflows', //
    ]);
    expect(ToolCatalogue.of('scan').category, isNull);
    expect(ToolCatalogue.all.where((t) => t.isPro).map((t) => t.id).toSet(), {
      'smartsplit', 'pdfa', 'text', 'ocr', 'form', 'redact', 'compare', //
      'summarize', 'ask', 'translate', 'workflows',
    });
    expect(() => ToolCatalogue.of('nope'), throwsArgumentError);
  });

  test('the fixed EN/DE names and a description in both languages', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final de = await AppLocalizations.delegate.load(const Locale('de'));
    expect(ToolCatalogue.of('compress').name(en), 'Compress PDF');
    expect(ToolCatalogue.of('compress').name(de), 'PDF verkleinern');
    expect(ToolCatalogue.of('redact').name(de), 'Schwärzen');
    expect(ToolCategory.ai.label(de), 'KI');
    for (final t in ToolCatalogue.all) {
      for (final l in [en, de]) {
        expect(t.name(l), isNotEmpty);
        expect(
          t.description(l),
          endsWith('.'),
          reason: '${t.id} ${l.localeName}',
        );
      }
      expect(t.description(en), isNot(t.description(de)));
    }
  });
}
