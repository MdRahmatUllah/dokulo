import 'dart:convert';
import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:crypto/crypto.dart';
import 'package:doc_core/doc_core.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

/// Step 2 on a qpdf worker.
List<String> _finish((String, String, String, String?) a, JobContext context) =>
    PdfaWriter.finish(a.$1, a.$2, Directory(a.$3), password: a.$4);

void main() {
  setUpAll(pdfrxInitialize);
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('dk_pdfa_'));
  tearDown(() async => dir.delete(recursive: true));

  test('the OutputIntent profile is the unmodified sRGB2014.icc', () {
    final bytes = base64.decode(srgb2014Base64);
    expect(bytes.length, 3024);
    expect(sha256.convert(bytes).toString(), srgb2014Sha256);
  });

  test('the update drops JavaScript, embedded files and XFA, adds the OutputIntent and XMP', () {
    final update = PdfaWriter.pdfaUpdate({
      'qpdf': [
        {'jsonversion': 2, 'maxobjectid': 6},
        {
          'trailer': {
            'value': {'/Root': '1 0 R', '/Info': '6 0 R'},
          },
          'obj:1 0 R': {
            'value': {
              '/Type': '/Catalog',
              '/Pages': '2 0 R',
              '/Names': '3 0 R',
              '/OpenAction': {'/S': '/JavaScript', '/JS': 'u:app.alert(1)'},
              '/AA': {'/WC': '4 0 R'},
              '/AcroForm': {'/Fields': [], '/XFA': '5 0 R'},
              '/NeedsRendering': true,
            },
          },
          'obj:3 0 R': {
            'value': {
              '/JavaScript': '7 0 R',
              '/EmbeddedFiles': '8 0 R',
              '/Dests': '9 0 R',
            },
          },
          'obj:6 0 R': {
            'value': {'/Title': 'u:Mietvertrag & <Anhang>', '/Creator': 'u:x'},
          },
        },
      ],
    });
    final objects = (update['qpdf']! as List)[1] as Map;
    final catalog = objects['obj:1 0 R']['value'] as Map;
    expect(catalog.keys, isNot(contains('/OpenAction')));
    expect(catalog.keys, isNot(contains('/AA')));
    expect(catalog.keys, isNot(contains('/NeedsRendering')));
    expect(catalog['/AcroForm'], {'/Fields': []});
    expect(catalog['/Metadata'], '7 0 R');
    expect(catalog['/OutputIntents'], ['9 0 R']);
    expect(objects['obj:3 0 R']['value'], {'/Dests': '9 0 R'});
    expect(objects['obj:6 0 R']['value'], {
      '/Title': 'u:Mietvertrag & <Anhang>',
      '/Producer': 'u:Dokulo',
    });
    expect(objects['obj:9 0 R']['value']['/S'], '/GTS_PDFA1');
    final xmp = utf8.decode(
      base64.decode(objects['obj:7 0 R']['stream']['data'] as String),
    );
    expect(
      xmp,
      contains(
        '<pdfaid:part>2</pdfaid:part><pdfaid:conformance>B</pdfaid:conformance>',
      ),
    );
    expect(xmp, contains('Mietvertrag &amp; &lt;Anhang&gt;'));
    expect((update['qpdf']! as List)[0], containsPair('maxobjectid', 10));
  });

  group('end to end on the sample documents', () {
    final out =
        Platform.environment['PDFA_OUT']; // tools/check_pdfa.py validates these
    final cases = {
      'Invoice INV-2026-014.pdf': (null, [0], 'Invoice INV-2026-014'),
      'Mietvertrag Musterstraße 12.pdf': (null, [0, 1, 2], 'Grundmiete'),
      'scanned-letters-bundle.pdf': (null, <int>[], null),
      'encrypted-aes256.pdf': ('dokulo', [0], 'Invoice INV-2026-014'),
      'form-acroform.pdf': (null, [0], 'Sportverein'),
      'form-xfa.pdf': (null, [0], 'XFA form'),
    };
    for (final MapEntry(key: name, value: (password, rasterised, text))
        in cases.entries) {
      test(name, () async {
        final input = fixture(name);
        final pool = IsolatePool(tempRoot: dir);
        final prepared = await PdfaWriter.prepare(
          input,
          dir,
          password: password,
        );
        expect(prepared.rasterised, rasterised);
        final output = '${dir.path}/pdfa.pdf';
        // A prepared copy is no longer encrypted (PDFium wrote it).
        final stillLocked = prepared.path == input ? password : null;
        await pool.run(Lane.qpdf, _finish, (
          prepared.path,
          output,
          dir.path,
          stillLocked,
        )).result;

        final before = await PdfEngine.inspect(input, password: password);
        final after = await PdfEngine.inspect(output);
        expect(after.pageCount, before.pageCount);
        if (text != null) {
          expect((await PdfEngine.pageText(output, 0)).text, contains(text));
        }
        expect(await PdfEngine.usesUnembeddedFonts(output, 0), isFalse);
        if (out != null) {
          await File(output).copy('$out/${name.replaceAll(' ', '_')}');
        }
      });
    }
  });
}
