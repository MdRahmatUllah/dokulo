import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

/// The shared sample corpus (DK-0023), from the repo root.
String fixture(String name) => '../../test/fixtures/$name';

void main() {
  late Directory out;
  setUpAll(pdfrxInitialize);
  setUp(() async => out = await Directory.systemTemp.createTemp('dk_forms_'));
  tearDown(() => out.delete(recursive: true));

  final form = fixture('form-acroform.pdf');

  Future<Map<String, PdfFormField>> byName(String path) async {
    final all = await PdfForms.fields(path);
    return {
      for (final f in all)
        f.kind == PdfFieldKind.radio ? '${f.name}=${f.exportValue}' : f.name: f,
    };
  }

  group('kind', () {
    test('AcroForm, XFA and none', () async {
      expect(await PdfForms.kind(form), PdfFormKind.acroForm);
      expect(await PdfForms.kind(fixture('form-xfa.pdf')), PdfFormKind.xfa);
      expect(
        await PdfForms.kind(fixture('Invoice INV-2026-014.pdf')),
        PdfFormKind.none,
      );
      expect(PdfFormKind.xfa.fillable, isFalse);
    });

    test('a document without a form has no fields', () async {
      expect(
        await PdfForms.fields(fixture('Invoice INV-2026-014.pdf')),
        isEmpty,
      );
    });
  });

  test('fields: every kind, with options, export values and boxes', () async {
    final f = await byName(form);
    expect(f['name']!.kind, PdfFieldKind.text);
    expect(f['department']!.kind, PdfFieldKind.combo);
    expect(f['department']!.options, [
      'Fußball',
      'Schwimmen',
      'Tennis',
      'Turnen',
    ]);
    expect(f['membership=Familie']!.kind, PdfFieldKind.radio);
    expect(f['membership=Erwachsene']!.checked, isTrue);
    expect(f['consent']!.kind, PdfFieldKind.checkbox);
    expect(f['consent']!.checked, isFalse);
    final box = f['name']!.box;
    expect(box.right, greaterThan(box.left));
    expect(box.top, greaterThan(box.bottom));
  });

  test(
    'fill every kind; the values are there when the file is reopened',
    () async {
      final f = await byName(form);
      final done = '${out.path}/filled.pdf';
      await PdfForms.fill(form, done, {
        f['name']!.id: const TextFieldValue('Jürgen Groß'),
        f['birthdate']!.id: const TextFieldValue('03.05.1990'),
        f['department']!.id: const ChoiceFieldValue(2),
        f['membership=Familie']!.id: const CheckFieldValue(true),
        f['consent']!.id: const CheckFieldValue(true),
        f['newsletter']!.id: const CheckFieldValue(false),
      });
      final g = await byName(done);
      expect(g['name']!.value, 'Jürgen Groß');
      expect(g['birthdate']!.value, '03.05.1990');
      expect(
        g['address']!.value,
        '',
        reason: 'untouched fields stay as they were',
      );
      expect(g['department']!.selected, [2]);
      expect(g['department']!.value, 'Tennis');
      expect(g['membership=Familie']!.checked, isTrue);
      expect(
        g['membership=Erwachsene']!.checked,
        isFalse,
        reason: 'one radio per group',
      );
      expect(g['consent']!.checked, isTrue);
      expect(g['newsletter']!.checked, isFalse);
      expect(
        await PdfForms.kind(done),
        PdfFormKind.acroForm,
        reason: 'still editable',
      );
    },
  );

  test('flatten: no editable fields; the values are page content', () async {
    final f = await byName(form);
    final done = '${out.path}/flat.pdf';
    await PdfForms.fill(form, done, {
      f['name']!.id: const TextFieldValue('Erika Mustermann'),
    }, flatten: true);
    expect(await PdfForms.fields(done), isEmpty);
    final text = await PdfEngine.pageText(done, 0);
    expect(text.text, contains('Erika Mustermann'));
    expect((await PdfEngine.inspect(done)).pageCount, 1);
  });

  group('refuses, and writes nothing', () {
    Future<void> refused(
      Map<String, PdfFieldValue> values, {
      String? path,
    }) async {
      final done = '${out.path}/nope.pdf';
      await expectLater(
        PdfForms.fill(path ?? form, done, values),
        throwsA(
          isA<DocError>().having(
            (e) => e.kind,
            'kind',
            DocErrorKind.unsupportedForm,
          ),
        ),
      );
      expect(File(done).existsSync(), isFalse);
    }

    test(
      'an unknown field',
      () => refused({'0:99': const TextFieldValue('x')}),
    );
    test('a bad id', () => refused({'name': const TextFieldValue('x')}));
    test('the wrong kind of value', () async {
      final f = await byName(form);
      await refused({f['consent']!.id: const TextFieldValue('x')});
    });
    test('an option that does not exist', () async {
      final f = await byName(form);
      await refused({f['department']!.id: const ChoiceFieldValue(9)});
    });
    test('unchecking a radio (choose another instead)', () async {
      final f = await byName(form);
      await refused({
        f['membership=Erwachsene']!.id: const CheckFieldValue(false),
      });
    });
    test(
      'an XFA form',
      () => refused({
        '0:0': const TextFieldValue('x'),
      }, path: fixture('form-xfa.pdf')),
    );
  });
}
