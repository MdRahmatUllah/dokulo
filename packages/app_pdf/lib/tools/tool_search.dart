import '../l10n/app_localizations.dart';
import 'tool_catalogue.dart';

/// Other words people type for each tool, in English and German (DK-0257),
/// besides its name and its description. Lowercase; matched without
/// diacritics, so "schwarzen" finds "schwärzen".
const toolSynonyms = <String, ({List<String> en, List<String> de})>{
  'scan': (
    en: ['camera', 'photo', 'document'],
    de: ['kamera', 'foto', 'dokument', 'einscannen'],
  ),
  'merge': (
    en: ['combine', 'join', 'append'],
    de: ['zusammenfügen', 'verbinden', 'kombinieren'],
  ),
  'split': (
    en: ['separate', 'divide', 'cut'],
    de: ['trennen', 'aufteilen', 'teilen'],
  ),
  'extract': (
    en: ['pick pages', 'take out'],
    de: ['seiten herausnehmen', 'auswählen'],
  ),
  'organize': (
    en: ['reorder', 'sort', 'arrange', 'delete pages'],
    de: ['sortieren', 'anordnen', 'seiten löschen'],
  ),
  'rotate': (
    en: ['turn', 'landscape', 'portrait'],
    de: ['drehen', 'umdrehen', 'querformat'],
  ),
  'smartsplit': (
    en: ['auto split', 'documents'],
    de: ['automatisch teilen', 'stapel trennen'],
  ),
  'img2pdf': (
    en: ['jpg', 'jpeg', 'png', 'photo', 'picture'],
    de: ['foto', 'bild', 'bilder'],
  ),
  'pdf2img': (
    en: ['jpg', 'png', 'image', 'picture', 'export'],
    de: ['bild', 'bilder', 'exportieren'],
  ),
  'web': (
    en: ['website', 'url', 'link', 'html', 'internet'],
    de: ['webseite', 'seite speichern'],
  ),
  'pdfa': (
    en: ['archive', 'long term'],
    de: ['archiv', 'archivieren', 'langzeit'],
  ),
  'text': (
    en: ['txt', 'copy text', 'plain text'],
    de: ['text kopieren', 'nur text'],
  ),
  'compress': (
    en: ['shrink', 'smaller', 'reduce', 'size', 'email'],
    de: ['verkleinern', 'kleiner', 'komprimieren', 'größe'],
  ),
  'repair': (
    en: ['fix', 'broken', 'damaged', 'corrupt'],
    de: ['reparieren', 'kaputt', 'beschädigt'],
  ),
  'ocr': (
    en: ['ocr', 'recognize', 'searchable', 'copy text'],
    de: ['texterkennung', 'durchsuchbar', 'erkennen'],
  ),
  'pagenum': (
    en: ['numbers', 'numbering'],
    de: ['seitenzahlen', 'nummerieren', 'paginieren'],
  ),
  'watermark': (
    en: ['stamp', 'draft', 'confidential'],
    de: ['stempel', 'entwurf', 'vertraulich'],
  ),
  'crop': (
    en: ['trim', 'margins', 'cut edges'],
    de: ['zuschneiden', 'ränder', 'beschneiden'],
  ),
  'markup': (
    en: ['highlight', 'annotate', 'draw', 'note', 'comment'],
    de: ['markieren', 'hervorheben', 'anmerken', 'zeichnen'],
  ),
  'form': (
    en: ['fill', 'fields', 'checkbox'],
    de: ['ausfüllen', 'formular', 'felder'],
  ),
  'sign': (
    en: ['signature', 'esign', 'autograph'],
    de: ['unterschrift', 'unterschreiben', 'signieren'],
  ),
  'protect': (
    en: ['password', 'encrypt', 'lock', 'secure'],
    de: ['passwort', 'verschlüsseln', 'schützen'],
  ),
  'unlock': (
    en: ['decrypt', 'open', 'remove password'],
    de: ['entsperren', 'entschlüsseln', 'passwort entfernen'],
  ),
  'redact': (
    en: ['redact', 'black out', 'hide', 'censor'],
    de: ['schwärzen', 'zensieren', 'verbergen'],
  ),
  'compare': (
    en: ['diff', 'difference', 'changes', 'versions'],
    de: ['vergleichen', 'unterschiede', 'änderungen'],
  ),
  'summarize': (
    en: ['summary', 'tldr', 'overview'],
    de: ['zusammenfassung', 'überblick', 'ki'],
  ),
  'ask': (
    en: ['question', 'chat', 'answer'],
    de: ['frage', 'fragen', 'antwort'],
  ),
  'translate': (
    en: ['translation', 'language', 'english', 'german'],
    de: ['übersetzen', 'übersetzung', 'sprache'],
  ),
  'extractassets': (
    en: ['images', 'pictures', 'export'],
    de: ['bilder', 'herausziehen', 'exportieren'],
  ),
  'batch': (
    en: ['many files', 'bulk', 'several'],
    de: ['mehrere dateien', 'stapel', 'viele'],
  ),
  'workflows': (
    en: ['automation', 'chain', 'steps'],
    de: ['automatisierung', 'kette', 'schritte'],
  ),
};

/// [text] lowercased, without diacritics ("Schwärzen" → "schwarzen", "ß" →
/// "ss"), for matching what people type.
String foldForSearch(String text) {
  const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyy';
  final b = StringBuffer();
  for (final c in text.toLowerCase().split('')) {
    final i = from.indexOf(c);
    b.write(
      c == 'ß'
          ? 'ss'
          : i < 0
          ? c
          : to[i],
    );
  }
  return b.toString();
}

/// The tools for [query] in the Tools tab's order: each word of it found
/// in the tool's name, description or synonyms (T1 search, DK-0257). Tools
/// without a section (Scan) are left out: T1 lists sections.
List<ToolInfo> searchTools(String query, AppLocalizations l) {
  final words = foldForSearch(query).split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return const [];
  return [
    for (final tool in ToolCatalogue.all)
      if (tool.category != null)
        if (_haystack(tool, l) case final hay
            when words.every((w) => hay.contains(w)))
          tool,
  ];
}

String _haystack(ToolInfo tool, AppLocalizations l) => foldForSearch(
  [
    tool.name(l),
    tool.description(l),
    ...?toolSynonyms[tool.id]?.en,
    ...?toolSynonyms[tool.id]?.de,
  ].join(' | '),
);
