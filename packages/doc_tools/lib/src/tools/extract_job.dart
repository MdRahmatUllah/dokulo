import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';

import '../tool_job.dart';
import 'output_name.dart';

/// Extract pages' input (T2, UI spec §21.3).
class ExtractInput {
  const ExtractInput({
    required this.file,
    required this.pages,
    required this.outputDir,
    required this.suffix,
    this.password,
  });

  factory ExtractInput.fromJson(Map<String, Object?> json) => ExtractInput(
    file: json['file']! as String,
    pages: (json['pages']! as List).cast<int>(),
    outputDir: json['outputDir']! as String,
    suffix: json['suffix']! as String,
  );

  final String file;

  /// 0-based, in the output's order: the original order or the order they
  /// were selected in (T2's Order).
  final List<int> pages;
  final String outputDir;

  /// The localised suffix (" – extract").
  final String suffix;
  final String? password;

  Map<String, Object?> toJson() => {
    'file': file,
    'pages': pages,
    'outputDir': outputDir,
    'suffix': suffix,
    // No password: see CompressInput.
  };
}

/// The `extract` tool (DK-0414): the chosen pages, in the chosen order, as
/// one new PDF (`<name><suffix>.pdf`), written by qpdf on its worker. The
/// input is never touched.
class ExtractJob extends ToolJob<ExtractInput> {
  const ExtractJob();

  @override
  String get id => 'extract';

  @override
  Lane get lane => Lane.pdfium;

  @override
  String? passwordOf(ExtractInput input) => input.password;

  @override
  Map<String, Object?> encode(ExtractInput input) => input.toJson();

  @override
  ExtractInput decode(Map<String, Object?> json) => ExtractInput.fromJson(json);

  @override
  List<String> inputFiles(ExtractInput input) => [input.file];

  @override
  ExtractInput chain(JobOutput previous, Map<String, Object?> options) =>
      ExtractInput.fromJson({
        ...options,
        'file': switch (previous) {
          OneFile(:final path) => path,
          _ => throw ArgumentError('Extract pages takes one PDF'),
        },
      });

  @override
  Future<JobOutput> run(ExtractInput input, ToolJobContext context) async {
    context.report(const JobProgress('reading'));
    final count = (await PdfEngine.inspect(
      input.file,
      password: input.password,
    )).pageCount;
    if (input.pages.isEmpty || input.pages.any((p) => p < 0 || p >= count)) {
      throw ArgumentError('pages ${input.pages} of $count');
    }
    final output = outputName(input.outputDir, input.file, input.suffix, []);
    await context.checkCancelled();
    context.report(
      JobProgress('writing', pageIndex: 0, pageCount: input.pages.length),
    );
    final pool = IsolatePool(tempRoot: context.tempDir);
    try {
      await pool.run(Lane.qpdf, _write, (
        [
          {
            'file': input.file,
            'password': ?input.password,
            'range': input.pages.map((p) => p + 1).join(','),
          },
        ],
        output,
      )).result;
    } catch (_) {
      final f = File(output);
      if (f.existsSync()) f.deleteSync();
      rethrow;
    }
    return OneFile(output);
  }
}

void _write((List<Map<String, Object?>>, String) job, JobContext context) =>
    QpdfService.joinPages(job.$1, job.$2);
