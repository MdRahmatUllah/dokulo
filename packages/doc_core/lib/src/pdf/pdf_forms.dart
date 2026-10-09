import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as fpdf;
import 'package:pdfrx_engine/pdfrx_engine.dart' show PdfrxEntryFunctions;

import 'pdf_engine.dart';

/// What kind of form a document carries (DK-0323).
enum PdfFormKind {
  /// No interactive form.
  none,

  /// An AcroForm: Dokulo fills it.
  acroForm,

  /// An XFA form (full or foreground): "This form type can't be filled on
  /// phones." with "Open read-only".
  xfa;

  bool get fillable => this == acroForm;
}

/// A form field's kind, from PDFium's `FPDF_FORMFIELD_*`.
enum PdfFieldKind {
  text,
  checkbox,
  radio,
  combo,
  list,
  signature,
  button,
  unknown,
}

/// One widget of a form field. A radio group or a field shown on two pages
/// has one widget each, sharing [name]; [id] picks the widget.
class PdfFormField {
  const PdfFormField({
    required this.page,
    required this.annot,
    required this.name,
    required this.kind,
    required this.value,
    required this.checked,
    required this.options,
    required this.selected,
    required this.exportValue,
    required this.box,
    required this.readOnly,
    required this.required,
    required this.multiline,
  });

  /// The page and the widget's annotation index on it.
  final int page, annot;

  /// The fully qualified field name ("Person.Name").
  final String name;
  final PdfFieldKind kind;

  /// The text, or the chosen option's label; empty when unset.
  final String value;

  /// For a checkbox or radio widget: whether it is on.
  final bool checked;

  /// For a combo or list box: the option labels, and the selected indices.
  final List<String> options;
  final List<int> selected;

  /// For a checkbox or radio widget: the value it stands for ("Yes", "Herr").
  final String exportValue;

  /// Where the widget sits, in page space (points, origin bottom-left).
  final Box box;
  final bool readOnly, required, multiline;

  /// The key [PdfForms.fill] takes: "page:annot".
  String get id => '$page:$annot';

  @override
  String toString() =>
      'PdfFormField($id ${kind.name} "$name" = "$value"${checked ? ' ✓' : ''})';
}

/// A value to put into a field (by [PdfFormField.id]).
sealed class PdfFieldValue {
  const PdfFieldValue();
}

/// Text for a text field (a date field is a text field).
final class TextFieldValue extends PdfFieldValue {
  const TextFieldValue(this.text);
  final String text;
}

/// On or off for a checkbox; on for the radio widget that should be chosen.
final class CheckFieldValue extends PdfFieldValue {
  const CheckFieldValue(this.checked);
  final bool checked;
}

/// The option to choose in a combo or list box.
final class ChoiceFieldValue extends PdfFieldValue {
  const ChoiceFieldValue(this.index);
  final int index;
}

/// AcroForm filling through PDFium's form environment (DK-0323; Technology
/// plan: FPDFDOC_InitFormFillEnvironment, then the FORM_* calls, so the
/// widgets' appearances are regenerated as Acrobat does). Everything runs on
/// pdfrx's worker, like the rest of [PdfEngine].
abstract final class PdfForms {
  /// The document's form kind; XFA can't be filled on phones.
  static Future<PdfFormKind> kind(String path, {String? password}) async {
    await PdfEngine.inspect(path, password: password); // password, damage
    return PdfrxEntryFunctions.instance.compute(_kindOnWorker, (
      path,
      password,
    ));
  }

  /// Every form field widget, page by page.
  static Future<List<PdfFormField>> fields(
    String path, {
    String? password,
  }) async {
    await PdfEngine.inspect(path, password: password);
    return PdfrxEntryFunctions.instance.compute(_fieldsOnWorker, (
      path,
      password,
    ));
  }

  /// Writes [path] with [values] filled in to [outPath] (a full rewrite).
  /// With [flatten], the fields become part of the page and nothing stays
  /// editable ("Lock form values?"). An unknown id, a read-only field or a
  /// value of the wrong kind is a [DocError] (unsupportedForm), and nothing
  /// is written.
  static Future<void> fill(
    String path,
    String outPath,
    Map<String, PdfFieldValue> values, {
    String? password,
    bool flatten = false,
  }) async {
    await PdfEngine.inspect(path, password: password);
    final (bytes, error) = await PdfrxEntryFunctions.instance.compute(
      _fillOnWorker,
      (path, password, values, flatten),
    );
    // The worker hands a refusal back as a value: an exception would arrive
    // wrapped in the worker's own type.
    if (error != null) throw error;
    await File(outPath).writeAsBytes(bytes!, flush: true);
  }
}

// ---------------------------------------------------------------------------
// On pdfrx's worker.

/// Loads [path] with raw PDFium (from memory: PDFium's path handling isn't
/// UTF-8-safe) and its form environment, and runs [body].
T _withForm<T>(
  String path,
  String? password,
  T Function(
    fpdf.PDFium pdfium,
    fpdf.FPDF_DOCUMENT doc,
    fpdf.FPDF_FORMHANDLE form,
    Arena arena,
  )
  body,
) {
  final pdfium = fpdf.getPdfium();
  return using((arena) {
    final bytes = File(path).readAsBytesSync();
    final buffer = arena<Uint8>(bytes.length);
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    final doc = pdfium.FPDF_LoadMemDocument64(
      buffer.cast(),
      bytes.length,
      password == null
          ? nullptr
          : password.toNativeUtf8(allocator: arena).cast(),
    );
    if (doc == nullptr) {
      throw StateError(
        'FPDF_LoadMemDocument64 failed: ${pdfium.FPDF_GetLastError()}',
      );
    }
    // Version 1, no callbacks: PDFium checks each callback for null.
    final info = arena<fpdf.FPDF_FORMFILLINFO>()..ref.version = 1;
    final form = pdfium.FPDFDOC_InitFormFillEnvironment(doc, info);
    try {
      return body(pdfium, doc, form, arena);
    } finally {
      if (form != nullptr) pdfium.FPDFDOC_ExitFormFillEnvironment(form);
      pdfium.FPDF_CloseDocument(doc);
    }
  });
}

/// Runs [body] on page [index] with the form attached to it.
T _onFormPage<T>(
  fpdf.PDFium pdfium,
  fpdf.FPDF_DOCUMENT doc,
  fpdf.FPDF_FORMHANDLE form,
  int index,
  T Function(fpdf.FPDF_PAGE page) body,
) {
  final page = pdfium.FPDF_LoadPage(doc, index);
  if (form != nullptr) pdfium.FORM_OnAfterLoadPage(page, form);
  try {
    return body(page);
  } finally {
    if (form != nullptr) pdfium.FORM_OnBeforeClosePage(page, form);
    pdfium.FPDF_ClosePage(page);
  }
}

PdfFormKind _kindOf(int type) => switch (type) {
  fpdf.FORMTYPE_ACRO_FORM => PdfFormKind.acroForm,
  fpdf.FORMTYPE_XFA_FULL || fpdf.FORMTYPE_XFA_FOREGROUND => PdfFormKind.xfa,
  _ => PdfFormKind.none,
};

PdfFormKind _kindOnWorker((String, String?) m) => _withForm(
  m.$1,
  m.$2,
  (pdfium, doc, form, arena) => _kindOf(pdfium.FPDF_GetFormType(doc)),
);

PdfFieldKind _fieldKind(int t) => switch (t) {
  fpdf.FPDF_FORMFIELD_TEXTFIELD => PdfFieldKind.text,
  fpdf.FPDF_FORMFIELD_CHECKBOX => PdfFieldKind.checkbox,
  fpdf.FPDF_FORMFIELD_RADIOBUTTON => PdfFieldKind.radio,
  fpdf.FPDF_FORMFIELD_COMBOBOX => PdfFieldKind.combo,
  fpdf.FPDF_FORMFIELD_LISTBOX => PdfFieldKind.list,
  fpdf.FPDF_FORMFIELD_SIGNATURE => PdfFieldKind.signature,
  fpdf.FPDF_FORMFIELD_PUSHBUTTON => PdfFieldKind.button,
  _ => PdfFieldKind.unknown,
};

/// Reads a UTF-16LE string through PDFium's two-call pattern (length, then
/// the buffer).
String _wide(
  Arena arena,
  int Function(Pointer<fpdf.FPDF_WCHAR> buffer, int length) read,
) {
  final bytes = read(nullptr, 0);
  if (bytes <= 2) return '';
  final buffer = arena<Uint16>(bytes ~/ 2);
  read(buffer.cast(), bytes);
  return String.fromCharCodes(buffer.asTypedList(bytes ~/ 2 - 1));
}

// PDF field flags (PDF 32000-1, table 221, 226).
const _readOnly = 1 << 0, _required = 1 << 1, _multiline = 1 << 12;

List<PdfFormField> _fieldsOnWorker(
  (String, String?) m,
) => _withForm(m.$1, m.$2, (pdfium, doc, form, arena) {
  final found = <PdfFormField>[];
  if (form == nullptr ||
      _kindOf(pdfium.FPDF_GetFormType(doc)) != PdfFormKind.acroForm) {
    return found;
  }
  final rect = arena<fpdf.FS_RECTF>();
  for (var p = 0; p < pdfium.FPDF_GetPageCount(doc); p++) {
    _onFormPage(pdfium, doc, form, p, (page) {
      for (var i = 0; i < pdfium.FPDFPage_GetAnnotCount(page); i++) {
        final annot = pdfium.FPDFPage_GetAnnot(page, i);
        try {
          if (pdfium.FPDFAnnot_GetSubtype(annot) != fpdf.FPDF_ANNOT_WIDGET) {
            continue;
          }
          final kind = _fieldKind(
            pdfium.FPDFAnnot_GetFormFieldType(form, annot),
          );
          final flags = pdfium.FPDFAnnot_GetFormFieldFlags(form, annot);
          final options = <String>[];
          final selected = <int>[];
          if (kind == PdfFieldKind.combo || kind == PdfFieldKind.list) {
            for (
              var o = 0;
              o < pdfium.FPDFAnnot_GetOptionCount(form, annot);
              o++
            ) {
              options.add(
                _wide(
                  arena,
                  (b, n) =>
                      pdfium.FPDFAnnot_GetOptionLabel(form, annot, o, b, n),
                ),
              );
              if (pdfium.FPDFAnnot_IsOptionSelected(form, annot, o) != 0) {
                selected.add(o);
              }
            }
          }
          pdfium.FPDFAnnot_GetRect(annot, rect);
          found.add(
            PdfFormField(
              page: p,
              annot: i,
              name: _wide(
                arena,
                (b, n) => pdfium.FPDFAnnot_GetFormFieldName(form, annot, b, n),
              ),
              kind: kind,
              value: _wide(
                arena,
                (b, n) => pdfium.FPDFAnnot_GetFormFieldValue(form, annot, b, n),
              ),
              checked: pdfium.FPDFAnnot_IsChecked(form, annot) != 0,
              options: options,
              selected: selected,
              exportValue: _wide(
                arena,
                (b, n) =>
                    pdfium.FPDFAnnot_GetFormFieldExportValue(form, annot, b, n),
              ),
              box: (
                left: rect.ref.left,
                top: rect.ref.top,
                right: rect.ref.right,
                bottom: rect.ref.bottom,
              ),
              readOnly: flags & _readOnly != 0,
              required: flags & _required != 0,
              multiline: kind == PdfFieldKind.text && flags & _multiline != 0,
            ),
          );
        } finally {
          pdfium.FPDFPage_CloseAnnot(annot);
        }
      }
    });
  }
  return found;
});

(Uint8List?, DocError?) _fillOnWorker(
  (String, String?, Map<String, PdfFieldValue>, bool) m,
) {
  try {
    return (_fill(m), null);
  } on DocError catch (e) {
    return (null, e);
  }
}

Uint8List _fill((String, String?, Map<String, PdfFieldValue>, bool) m) {
  final (path, password, values, flatten) = m;
  return _withForm(path, password, (pdfium, doc, form, arena) {
    if (form == nullptr ||
        _kindOf(pdfium.FPDF_GetFormType(doc)) != PdfFormKind.acroForm) {
      throw const DocError(DocErrorKind.unsupportedForm, detail: 'no AcroForm');
    }
    final byPage = <int, Map<int, PdfFieldValue>>{};
    for (final MapEntry(key: id, value: v) in values.entries) {
      final parts = id.split(':');
      final p = parts.length == 2 ? int.tryParse(parts[0]) : null;
      final a = parts.length == 2 ? int.tryParse(parts[1]) : null;
      if (p == null ||
          a == null ||
          p < 0 ||
          p >= pdfium.FPDF_GetPageCount(doc)) {
        throw DocError(DocErrorKind.unsupportedForm, detail: 'no field $id');
      }
      (byPage[p] ??= {})[a] = v;
    }
    final rect = arena<fpdf.FS_RECTF>();
    for (final MapEntry(key: p, value: onPage) in byPage.entries) {
      _onFormPage(pdfium, doc, form, p, (page) {
        for (final MapEntry(key: a, value: v) in onPage.entries) {
          if (a < 0 || a >= pdfium.FPDFPage_GetAnnotCount(page)) {
            throw DocError(
              DocErrorKind.unsupportedForm,
              detail: 'no field $p:$a',
            );
          }
          final annot = pdfium.FPDFPage_GetAnnot(page, a);
          try {
            final kind = _fieldKind(
              pdfium.FPDFAnnot_GetFormFieldType(form, annot),
            );
            if (pdfium.FPDFAnnot_GetFormFieldFlags(form, annot) & _readOnly !=
                0) {
              throw DocError(
                DocErrorKind.unsupportedForm,
                detail: '$p:$a is read-only',
              );
            }
            switch ((kind, v)) {
              case (PdfFieldKind.text, TextFieldValue(:final text)):
                pdfium.FORM_SetFocusedAnnot(form, annot);
                pdfium.FORM_SelectAllText(form, page);
                final wide = text.toNativeUtf16(allocator: arena);
                pdfium.FORM_ReplaceSelection(form, page, wide.cast());
              case (
                PdfFieldKind.checkbox || PdfFieldKind.radio,
                CheckFieldValue(:final checked),
              ):
                // A click toggles a checkbox and chooses a radio widget, as a
                // user would; only click when the state must change.
                if ((pdfium.FPDFAnnot_IsChecked(form, annot) != 0) != checked) {
                  if (kind == PdfFieldKind.radio && !checked) {
                    throw DocError(
                      DocErrorKind.unsupportedForm,
                      detail: '$p:$a: choose another radio instead',
                    );
                  }
                  pdfium.FPDFAnnot_GetRect(annot, rect);
                  final x = (rect.ref.left + rect.ref.right) / 2,
                      y = (rect.ref.top + rect.ref.bottom) / 2;
                  pdfium.FORM_OnLButtonDown(form, page, 0, x, y);
                  pdfium.FORM_OnLButtonUp(form, page, 0, x, y);
                }
              case (
                PdfFieldKind.combo || PdfFieldKind.list,
                ChoiceFieldValue(:final index),
              ):
                if (index < 0 ||
                    index >= pdfium.FPDFAnnot_GetOptionCount(form, annot)) {
                  throw DocError(
                    DocErrorKind.unsupportedForm,
                    detail: '$p:$a has no option $index',
                  );
                }
                pdfium.FORM_SetFocusedAnnot(form, annot);
                pdfium.FORM_SetIndexSelected(form, page, index, 1);
              default:
                throw DocError(
                  DocErrorKind.unsupportedForm,
                  detail: '$p:$a is ${kind.name}, not ${v.runtimeType}',
                );
            }
            // Commits the edit, which regenerates the widget's appearance.
            pdfium.FORM_ForceToKillFocus(form);
          } finally {
            pdfium.FPDFPage_CloseAnnot(annot);
          }
        }
      });
    }
    if (flatten) {
      for (var p = 0; p < pdfium.FPDF_GetPageCount(doc); p++) {
        _onFormPage(pdfium, doc, form, p, (page) {
          if (pdfium.FPDFPage_Flatten(page, fpdf.FLAT_NORMALDISPLAY) ==
              fpdf.FLATTEN_FAIL) {
            throw DocError(
              DocErrorKind.unexpected,
              detail: 'FPDFPage_Flatten failed on page $p',
            );
          }
        });
      }
    }
    return _save(pdfium, doc);
  });
}

final _saved = BytesBuilder(copy: false);

int _writeBlock(
  Pointer<fpdf.FPDF_FILEWRITE> self,
  Pointer<Void> data,
  int size,
) {
  _saved.add(Uint8List.fromList(data.cast<Uint8>().asTypedList(size)));
  return 1;
}

/// The whole document, rewritten (never incremental).
Uint8List _save(fpdf.PDFium pdfium, fpdf.FPDF_DOCUMENT doc) {
  final write =
      NativeCallable<
        Int Function(Pointer<fpdf.FPDF_FILEWRITE>, Pointer<Void>, UnsignedLong)
      >.isolateLocal(_writeBlock, exceptionalReturn: 0);
  final fw = calloc<fpdf.FPDF_FILEWRITE>()
    ..ref.version = 1
    ..ref.WriteBlock = write.nativeFunction;
  try {
    _saved.clear();
    if (pdfium.FPDF_SaveAsCopy(doc, fw, fpdf.FPDF_NO_INCREMENTAL) == 0) {
      throw StateError('FPDF_SaveAsCopy failed');
    }
    return _saved.takeBytes();
  } finally {
    calloc.free(fw);
    write.close();
  }
}
