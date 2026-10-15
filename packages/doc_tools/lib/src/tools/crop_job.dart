import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';

import '../tool_job.dart';
import 'output_name.dart';

/// Crop pages' input (T2, UI spec §21.17): the crop of each page, or with
/// [auto] each page's own content bounds (Auto margins).
class CropInput {
  const CropInput({
    required this.file,
    required this.outputDir,
    required this.suffix,
    this.insets = const {},
    this.auto = false,
    this.password,
  });

  factory CropInput.fromJson(Map<String, Object?> json) => CropInput(
    file: json['file']! as String,
    outputDir: json['outputDir']! as String,
    suffix: json['suffix']! as String,
    insets: {
      for (final MapEntry(:key, :value)
          in (json['insets'] as Map? ?? const {}).entries)
        int.parse('$key'): switch ((value as List).cast<num>()) {
          [final l, final t, final r, final b] => (
            left: l.toDouble(),
            top: t.toDouble(),
            right: r.toDouble(),
            bottom: b.toDouble(),
          ),
          _ => throw FormatException('insets $value'),
        },
    },
    auto: json['auto'] as bool? ?? false,
  );

  final String file;
  final String outputDir;

  /// The localised suffix (" – cropped").
  final String suffix;

  /// By 0-based page; Apply to All pages repeats one crop on every page.
  final Map<int, CropInsets> insets;
  final bool auto;
  final String? password;

  Map<String, Object?> toJson() => {
    'file': file,
    'outputDir': outputDir,
    'suffix': suffix,
    if (insets.isNotEmpty)
      'insets': {
        for (final MapEntry(:key, value: i) in insets.entries)
          '$key': [i.left, i.top, i.right, i.bottom],
      },
    if (auto) 'auto': true,
    // No password: see CompressInput.
  };
}

/// The `crop` tool (DK-0492): each page's crop box set ([PdfCrop]; the
/// content outside stays in the file), as a new PDF (`<name><suffix>.pdf`).
/// The input is never touched.
class CropJob extends ToolJob<CropInput> {
  const CropJob();

  @override
  String get id => 'crop';

  @override
  Lane get lane => Lane.pdfium;

  @override
  double get renderDpi => 50;

  @override
  String? passwordOf(CropInput input) => input.password;

  @override
  Map<String, Object?> encode(CropInput input) => input.toJson();

  @override
  CropInput decode(Map<String, Object?> json) => CropInput.fromJson(json);

  @override
  List<String> inputFiles(CropInput input) => [input.file];

  @override
  CropInput chain(JobOutput previous, Map<String, Object?> options) =>
      CropInput.fromJson({
        ...options,
        'file': switch (previous) {
          OneFile(:final path) => path,
          _ => throw ArgumentError('Crop pages takes one PDF'),
        },
      });

  @override
  Future<JobOutput> run(CropInput input, ToolJobContext context) async {
    final count = (await PdfEngine.inspect(
      input.file,
      password: input.password,
    )).pageCount;
    final insets = {...input.insets};
    if (input.auto) {
      for (var p = 0; p < count; p++) {
        await context.checkCancelled();
        context.report(JobProgress('reading', pageIndex: p, pageCount: count));
        insets[p] = await PdfCrop.contentInsets(
          input.file,
          p,
          password: input.password,
        );
      }
    }
    if (insets.isEmpty) throw ArgumentError('nothing to crop');
    await context.checkCancelled();
    context.report(
      JobProgress('writing', pageIndex: count - 1, pageCount: count),
    );
    final output = outputName(input.outputDir, input.file, input.suffix, []);
    try {
      await PdfCrop.crop(input.file, output, insets, password: input.password);
    } catch (_) {
      final f = File(output);
      if (f.existsSync()) f.deleteSync();
      rethrow;
    }
    return OneFile(output);
  }
}
