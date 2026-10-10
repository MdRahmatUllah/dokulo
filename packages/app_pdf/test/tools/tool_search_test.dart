import 'package:app_pdf/l10n/app_localizations_de.dart';
import 'package:app_pdf/l10n/app_localizations_en.dart';
import 'package:app_pdf/tools/tool_catalogue.dart';
import 'package:app_pdf/tools/tool_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = AppLocalizationsEn();
  final de = AppLocalizationsDe();
  List<String> ids(String q, [dynamic l]) => [
    for (final t in searchTools(q, l ?? en)) t.id,
  ];

  test('every tool has English and German synonyms', () {
    for (final tool in ToolCatalogue.all) {
      final s = toolSynonyms[tool.id];
      expect(s, isNotNull, reason: tool.id);
      expect(s!.en, isNotEmpty, reason: '${tool.id} en');
      expect(s.de, isNotEmpty, reason: '${tool.id} de');
    }
    expect(toolSynonyms.keys.toSet(), {
      for (final t in ToolCatalogue.all) t.id,
    });
  });

  test("the spec's examples", () {
    for (final q in ['shrink', 'smaller', 'verkleinern']) {
      expect(ids(q), contains('compress'), reason: q);
    }
    expect(ids('redact'), contains('redact'));
    expect(ids('schwärzen'), contains('redact'));
    expect(ids('zusammenfügen'), contains('merge'));
    expect(ids('combine'), contains('merge'));
    expect(ids('seitenzahlen'), contains('pagenum'));
  });

  test('diacritics and case do not matter', () {
    expect(ids('schwarzen'), contains('redact'));
    expect(ids('SCHWÄRZEN'), contains('redact'));
    expect(ids('ubersetzen'), contains('translate'));
    expect(foldForSearch('Größe'), 'grosse');
  });

  test('every word must match; results keep the Tools order', () {
    expect(ids('add password'), ['protect']);
    final all = ids('pdf');
    final order = [for (final t in ToolCatalogue.all) t.id];
    expect(
      all,
      orderedEquals(
        [...all]..sort((a, b) => order.indexOf(a) - order.indexOf(b)),
      ),
    );
    expect(ids('fax'), isEmpty);
    expect(ids('   '), isEmpty);
  });

  test('names and descriptions match in the reader\'s language', () {
    expect(ids('Webseite', de), contains('web'));
    expect(ids('scan'), isNot(contains('scan')), reason: 'no section');
  });
}
