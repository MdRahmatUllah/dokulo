import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:qpdf_ffi/qpdf_ffi.dart';

import 'ocr_text_layer.dart';
import 'pdf_engine.dart';
import 'qpdf_service.dart';
import 'srgb2014_icc.dart';

/// PDF to PDF/A-2b (DK-0395; UI spec §21.10), in two steps for the two lanes:
///
/// 1. [prepare] (PDFium): every page that shows text in a font the file
///    doesn't embed is rendered to a picture, with its own text kept as an
///    invisible layer, so it stays searchable ("2 pages were converted to
///    images because their fonts weren't included").
/// 2. [finish] (`Lane.qpdf`): decrypts; removes JavaScript, embedded files,
///    XFA and additional actions; adds the sRGB OutputIntent (the ICC's
///    sRGB2014.icc, DK-0678) and XMP metadata (pdfaid part 2, conformance B)
///    mirroring the Info dictionary; rewrites the file the way PDF/A wants it.
///
/// veraPDF checks the output in the local gate (`tools/check_pdfa.py`); it
/// is a test tool, never shipped.
abstract final class PdfaWriter {
  /// Resolution of a rasterised page.
  static const rasterDpi = 200.0;

  /// Step 1. Returns the file [finish] continues with ([input] itself when no
  /// page needs it) and the 0-based pages that became pictures.
  static Future<({String path, List<int> rasterised})> prepare(
    String input,
    Directory work, {
    String? password,
  }) async {
    final info = await PdfEngine.inspect(input, password: password);
    final rasterised = [
      for (var p = 0; p < info.pageCount; p++)
        if (await PdfEngine.usesUnembeddedFonts(input, p, password: password))
          p,
    ];
    if (rasterised.isEmpty) return (path: input, rasterised: rasterised);

    final pages = [for (final p in rasterised) info.pages[p]];
    final words = <int, List<LayerWord>>{};
    final images = <int, ({Uint8List rgba, int width, int height})>{};
    for (final (i, p) in rasterised.indexed) {
      final shot = await PdfEngine.render(
        input,
        p,
        dpi: rasterDpi,
        password: password,
      );
      images[i] = (rgba: shot.rgba, width: shot.width, height: shot.height);
      words[i] = wordsOf(
        await PdfEngine.pageText(input, p, password: password),
        info.pages[p],
      );
    }
    final pictures = '${work.path}/pdfa-pictures.pdf';
    await File(pictures)
        .writeAsBytes(await OcrTextLayer.overlay(pages, words, images: images));

    final prepared = '${work.path}/pdfa-prepared.pdf';
    await PdfEngine.assemble(
      [
        for (var p = 0; p < info.pageCount; p++)
          rasterised.contains(p)
              ? PageSource(pictures, rasterised.indexOf(p))
              : PageSource(input, p),
      ],
      prepared,
      passwords: {input: ?password},
    );
    return (path: prepared, rasterised: rasterised);
  }

  /// Step 2, inside a `Lane.qpdf` job: [input] (from [prepare]) to the PDF/A
  /// file [output]. [work] holds qpdf's JSON while it runs.
  static List<String> finish(
    String input,
    String output,
    Directory work, {
    String? password,
  }) => QpdfService.run(() {
    final exported = '${work.path}/pdfa-structure.json';
    Qpdf.run({
      'inputFile': input,
      'password': ?password,
      'outputFile': exported,
      'jsonOutput': '2',
      'jsonStreamData': 'none',
    });
    final update = '${work.path}/pdfa-update.json';
    File(update).writeAsStringSync(
      jsonEncode(
        pdfaUpdate(
          jsonDecode(File(exported).readAsStringSync()) as Map<String, Object?>,
        ),
      ),
    );
    return Qpdf.run({
      'inputFile': input,
      'password': ?password,
      'decrypt': '',
      'outputFile': output,
      'updateFromJson': update,
      'newlineBeforeEndstream': '',
    });
  });

  /// The qpdf JSON update that makes [exported] (qpdf's JSON v2 of the file,
  /// without stream data) PDF/A-2b: the new catalog, Info, XMP, ICC profile
  /// and OutputIntent objects.
  static Map<String, Object?> pdfaUpdate(Map<String, Object?> exported) {
    final qpdf = exported['qpdf']! as List<Object?>;
    final header = qpdf[0]! as Map<String, Object?>;
    final objects = qpdf[1]! as Map<String, Object?>;
    Map<String, Object?> value(Object? ref) => switch (objects['obj:$ref']) {
      {'value': final Map<String, Object?> v} => v,
      _ => const {},
    };
    Object? resolve(Object? v) =>
        v is String && v.endsWith(' R') ? value(v) : v;

    final trailer =
        (objects['trailer']! as Map<String, Object?>)['value']!
            as Map<String, Object?>;
    final rootRef = trailer['/Root']! as String;
    final infoRef = trailer['/Info'] as String?;
    final info = infoRef == null ? const <String, Object?>{} : value(infoRef);
    final title = _text(info['/Title']);
    final author = _text(info['/Author']);

    final max = header['maxobjectid']! as int;
    final metadata = '${max + 1} 0 R',
        icc = '${max + 2} 0 R',
        intent = '${max + 3} 0 R';
    final newInfo = infoRef ?? '${max + 4} 0 R';
    final changed = <String, Object?>{};

    final catalog = Map<String, Object?>.of(value(rootRef))
      ..remove('/AA')
      ..remove('/NeedsRendering')
      ..['/Metadata'] = metadata
      ..['/OutputIntents'] = [intent];
    if (resolve(catalog['/OpenAction']) case {'/S': '/JavaScript'}) {
      catalog.remove('/OpenAction');
    }
    // The name trees of JavaScript and embedded files go; the rest of /Names stays.
    switch (catalog['/Names']) {
      case final String ref:
        changed['obj:$ref'] = {
          'value': Map<String, Object?>.of(value(ref))
            ..remove('/JavaScript')
            ..remove('/EmbeddedFiles'),
        };
      case final Map<String, Object?> names:
        catalog['/Names'] = Map<String, Object?>.of(names)
          ..remove('/JavaScript')
          ..remove('/EmbeddedFiles');
    }
    // No XFA in PDF/A: the AcroForm keeps its fields, loses the XFA stream.
    switch (catalog['/AcroForm']) {
      case final String ref:
        changed['obj:$ref'] = {
          'value': Map<String, Object?>.of(value(ref))..remove('/XFA'),
        };
      case final Map<String, Object?> form:
        catalog['/AcroForm'] = Map<String, Object?>.of(form)..remove('/XFA');
    }

    changed['obj:$rootRef'] = {'value': catalog};
    changed['obj:$newInfo'] = {
      'value': {
        '/Title': ?(title == null ? null : 'u:$title'),
        '/Author': ?(author == null ? null : 'u:$author'),
        '/Producer': 'u:Dokulo',
      },
    };
    changed['obj:$metadata'] = {
      'stream': {
        'dict': {'/Type': '/Metadata', '/Subtype': '/XML'},
        'data': base64.encode(utf8.encode(xmp(title: title, author: author))),
      },
    };
    changed['obj:$icc'] = {
      'stream': {
        'dict': {'/N': 3},
        'data': srgb2014Base64,
      },
    };
    changed['obj:$intent'] = {
      'value': {
        '/Type': '/OutputIntent',
        '/S': '/GTS_PDFA1',
        '/OutputConditionIdentifier': 'u:sRGB IEC61966-2.1',
        '/Info': 'u:sRGB IEC61966-2.1',
        '/DestOutputProfile': icc,
      },
    };
    if (infoRef == null) {
      changed['trailer'] = {
        'value': Map<String, Object?>.of(trailer)..['/Info'] = newInfo,
      };
    }
    return {
      'qpdf': [
        {...header, 'maxobjectid': max + 4},
        changed,
      ],
    };
  }

  /// The XMP packet: PDF/A-2b identification and the same title, author and
  /// producer as the Info dictionary (PDF/A wants the two to agree).
  static String xmp({String? title, String? author}) {
    String esc(String s) =>
        const HtmlEscape(HtmlEscapeMode.element)
            .convert(s)
            .replaceAll('"', '&quot;');
    return [
      '<?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>',
      '<x:xmpmeta xmlns:x="adobe:ns:meta/">',
      '<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">',
      '<rdf:Description rdf:about="" xmlns:pdfaid="http://www.aiim.org/pdfa/ns/id/">'
          '<pdfaid:part>2</pdfaid:part><pdfaid:conformance>B</pdfaid:conformance></rdf:Description>',
      '<rdf:Description rdf:about="" xmlns:pdf="http://ns.adobe.com/pdf/1.3/">'
          '<pdf:Producer>Dokulo</pdf:Producer></rdf:Description>',
      if (title != null || author != null)
        '<rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">'
            '${title == null ? '' : '<dc:title><rdf:Alt><rdf:li xml:lang="x-default">${esc(title)}</rdf:li></rdf:Alt></dc:title>'}'
            '${author == null ? '' : '<dc:creator><rdf:Seq><rdf:li>${esc(author)}</rdf:li></rdf:Seq></dc:creator>'}'
            '</rdf:Description>',
      '</rdf:RDF>',
      '</x:xmpmeta>',
      '<?xpacket end="w"?>',
    ].join('\n');
  }

  /// A page's own words as [LayerWord]s: each run of non-space characters,
  /// its boxes joined, mapped from PDF space to the page as shown.
  static List<LayerWord> wordsOf(PageText text, PageInfo page) {
    final words = <LayerWord>[];
    var start = -1;
    void close(int end) {
      if (start < 0) return;
      final boxes = text.charBoxes.sublist(start, end);
      final corners = [
        for (final b in boxes) ...[
          shownAt((b.left, b.bottom), page),
          shownAt((b.right, b.top), page),
        ],
      ];
      final xs = [for (final c in corners) c.$1],
          ys = [for (final c in corners) c.$2];
      final left = xs.reduce((a, b) => a < b ? a : b),
          right = xs.reduce((a, b) => a > b ? a : b);
      final top = ys.reduce((a, b) => a < b ? a : b),
          bottom = ys.reduce((a, b) => a > b ? a : b);
      words.add(
        LayerWord(text.text.substring(start, end), (
          left: left,
          top: top,
          width: right - left,
          height: bottom - top,
        )),
      );
      start = -1;
    }

    for (var i = 0; i < text.text.length && i < text.charBoxes.length; i++) {
      if (text.text[i].trim().isEmpty) {
        close(i);
      } else if (start < 0) {
        start = i;
      }
    }
    close(
      text.text.length < text.charBoxes.length
          ? text.text.length
          : text.charBoxes.length,
    );
    return words;
  }

  /// A point in PDF space (unrotated, origin bottom-left) as a fraction of
  /// [page] as shown (after its clockwise quarter turns, origin top-left).
  static (double, double) shownAt((double, double) point, PageInfo page) {
    final (x, y) = point;
    final turns = page.quarterTurns % 4;
    final (w0, h0) = turns.isOdd
        ? (page.height, page.width)
        : (page.width, page.height);
    final (dx, dy) = switch (turns) {
      0 => (x, h0 - y),
      1 => (y, x),
      2 => (w0 - x, y),
      _ => (h0 - y, w0 - x),
    };
    return (dx / page.width, dy / page.height);
  }
}

/// A PDF string from qpdf's JSON ("u:text"); null for anything else.
String? _text(Object? v) =>
    v is String && v.startsWith('u:') && v.length > 2 ? v.substring(2) : null;
