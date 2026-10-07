import 'dart:convert';
import 'dart:io';

import 'package:qpdf_ffi/qpdf_ffi.dart';

import '../qpdf_service.dart';

/// Compress PDF's "Remove metadata" option (DK-0392): the document
/// information (title, author, creator, producer, dates, custom keys) and the
/// document's XMP metadata stream go; pages are untouched.
abstract final class MetadataStrip {
  /// [input] without its metadata into [output]; call it inside a `Lane.qpdf`
  /// job. [work] holds qpdf's JSON while it runs.
  static List<String> strip(
    String input,
    String output,
    Directory work, {
    String? password,
  }) => QpdfService.run(() {
    final exported = '${work.path}/strip-structure.json';
    Qpdf.run({
      'inputFile': input,
      'password': ?password,
      'outputFile': exported,
      'jsonOutput': '2',
      'jsonStreamData': 'none',
    });
    final update = '${work.path}/strip-update.json';
    File(update).writeAsStringSync(
      jsonEncode(
        stripUpdate(
          jsonDecode(File(exported).readAsStringSync()) as Map<String, Object?>,
        ),
      ),
    );
    return Qpdf.run({
      'inputFile': input,
      'password': ?password,
      'outputFile': output,
      'updateFromJson': update,
    });
  });

  /// The qpdf JSON update: the trailer without /Info, the catalog without
  /// /Metadata.
  static Map<String, Object?> stripUpdate(Map<String, Object?> exported) {
    final qpdf = exported['qpdf']! as List<Object?>;
    final objects = qpdf[1]! as Map<String, Object?>;
    final trailer = Map<String, Object?>.of(
      (objects['trailer']! as Map<String, Object?>)['value']!
          as Map<String, Object?>,
    );
    final rootRef = trailer['/Root']! as String;
    final catalog = Map<String, Object?>.of(
      (objects['obj:$rootRef']! as Map<String, Object?>)['value']!
          as Map<String, Object?>,
    )..remove('/Metadata');
    trailer.remove('/Info');
    return {
      'qpdf': [
        qpdf[0],
        {
          'trailer': {'value': trailer},
          'obj:$rootRef': {'value': catalog},
        },
      ],
    };
  }
}
