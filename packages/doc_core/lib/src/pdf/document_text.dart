import 'pdf_structure.dart';

/// A piece of a document's text that an AI feature reads and cites: from
/// one page ([page], 0-based), whole blocks in reading order, at most about
/// [DocumentText.read]'s `maxChars`.
class TextChunk {
  const TextChunk(this.page, this.text);

  final int page;
  final String text;

  @override
  String toString() => 'p${page + 1}: $text';
}

/// The text every AI feature starts from (DK-0548; Technology plan,
/// intelligence features): PDFium's text per page in [PdfStructure]'s
/// reading order (a scan made searchable by Make text searchable has its
/// OCR layer there too), cut into page-anchored [chunks]. No text at all
/// ([hasText] false) is the "This scan has no text yet." banner with "Make
/// it searchable".
class DocumentText {
  const DocumentText(this.chunks);

  final List<TextChunk> chunks;

  bool get hasText => chunks.isNotEmpty;

  /// The pages that have text, 0-based.
  Set<int> get pages => {for (final c in chunks) c.page};

  static Future<DocumentText> read(
    String path, {
    String? password,
    int maxChars = 2000,
  }) async => DocumentText(
    chunk(
      await PdfStructure.extract(path, password: password),
      maxChars: maxChars,
    ),
  );

  /// [blocks] into chunks: never across a page, a heading starts a new one,
  /// and a block longer than [maxChars] is cut at sentence ends (or spaces).
  static List<TextChunk> chunk(List<Block> blocks, {int maxChars = 2000}) {
    final chunks = <TextChunk>[];
    var page = -1;
    final current = StringBuffer();
    void flush() {
      final text = current.toString().trim();
      if (text.isNotEmpty) chunks.add(TextChunk(page, text));
      current.clear();
    }

    for (final b in blocks) {
      final text = b.text.trim();
      if (text.isEmpty) continue;
      if (b.page != page || b.kind == BlockKind.heading) {
        flush();
        page = b.page;
      }
      for (final piece in _pieces(text, maxChars)) {
        if (current.isNotEmpty &&
            current.length + piece.length + 2 > maxChars) {
          flush();
        }
        if (current.isNotEmpty) current.write('\n\n');
        current.write(piece);
      }
    }
    flush();
    return chunks;
  }

  /// [text] in pieces of at most [max] characters, cut after a sentence
  /// end where there is one, else at a space, else hard.
  static Iterable<String> _pieces(String text, int max) sync* {
    var rest = text;
    while (rest.length > max) {
      final window = rest.substring(0, max);
      var cut = window.lastIndexOf(RegExp(r'[.!?…]\s'));
      cut = cut > max ~/ 2 ? cut + 1 : window.lastIndexOf(' ');
      if (cut <= 0) cut = max;
      yield rest.substring(0, cut).trim();
      rest = rest.substring(cut).trim();
    }
    if (rest.isNotEmpty) yield rest;
  }
}
