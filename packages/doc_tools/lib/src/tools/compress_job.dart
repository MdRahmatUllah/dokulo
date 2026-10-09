import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';

import '../tool_job.dart';
import 'output_name.dart';

/// Compress PDF's input (T2): the files, where the outputs go, and the
/// options.
class CompressInput {
  const CompressInput({
    required this.files,
    required this.outputDir,
    required this.suffix,
    this.preset = CompressPreset.recommended,
    this.greyscale = false,
    this.removeMetadata = false,
    this.targetBytes,
    this.password,
  });

  factory CompressInput.fromJson(Map<String, Object?> json) => CompressInput(
    files: (json['files']! as List).cast<String>(),
    outputDir: json['outputDir']! as String,
    suffix: json['suffix']! as String,
    preset: CompressPreset.values.byName(
      json['preset'] as String? ?? 'recommended',
    ),
    greyscale: json['greyscale'] as bool? ?? false,
    removeMetadata: json['removeMetadata'] as bool? ?? false,
    targetBytes: json['targetBytes'] as int?,
    password: json['password'] as String?,
  );

  /// 1 to 500 PDFs (batch).
  final List<String> files;

  /// A temp folder of the file store; the user saves the results from there.
  final String outputDir;

  /// The localised name suffix, "– compressed" / "– verkleinert" (the app's
  /// strings; this layer has none).
  final String suffix;
  final CompressPreset preset;
  final bool greyscale;
  final bool removeMetadata;

  /// "Under X MB", per file.
  final int? targetBytes;

  /// For a locked file the user unlocked in T2.
  final String? password;

  Map<String, Object?> toJson() => {
    'files': files,
    'outputDir': outputDir,
    'suffix': suffix,
    'preset': preset.name,
    'greyscale': greyscale,
    'removeMetadata': removeMetadata,
    'targetBytes': ?targetBytes,
    // No password: it would sit in the jobs table in plain text. A resumed
    // job on a locked file fails as `locked`, and T2 asks again.
  };
}

/// The `compress` tool (DK-0462): [PdfCompress] on each file, one new file
/// per input named `<name><suffix>.pdf`; the inputs are never touched.
class CompressJob extends ToolJob<CompressInput> {
  const CompressJob();

  static const maxFiles = 500;

  @override
  String get id => 'compress';

  /// PdfCompress calls PDFium through pdfrx, so it runs on the calling
  /// isolate; its image work and qpdf go to their own workers.
  @override
  Lane get lane => Lane.pdfium;

  /// Scan pages may be rendered whole (the raster fallback) at up to 200 dpi.
  @override
  double get renderDpi => 200;

  @override
  String? passwordOf(CompressInput input) => input.password;

  @override
  Map<String, Object?> encode(CompressInput input) => input.toJson();

  @override
  CompressInput decode(Map<String, Object?> json) =>
      CompressInput.fromJson(json);

  @override
  List<String> inputFiles(CompressInput input) => input.files;

  /// [options] are the step's saved options plus `outputDir` and `suffix`,
  /// which the workflow runner (DK-0536) adds per run.
  @override
  CompressInput chain(JobOutput previous, Map<String, Object?> options) =>
      CompressInput.fromJson({
        ...options,
        'files': switch (previous) {
          OneFile(:final path) => [path],
          ManyFiles(:final paths) => paths,
          TextOutput() => throw ArgumentError(
            'Compress PDF needs PDFs, not text',
          ),
        },
      });

  @override
  Future<JobOutput> run(CompressInput input, ToolJobContext context) async {
    if (input.files.isEmpty || input.files.length > maxFiles) {
      throw ArgumentError(
        'Compress PDF takes 1 to $maxFiles files, not ${input.files.length}',
      );
    }
    final counts = [
      for (final file in input.files)
        (await PdfEngine.inspect(file, password: input.password)).pageCount,
    ];
    final total = counts.fold(0, (a, b) => a + b);
    final pool = IsolatePool(tempRoot: context.tempDir);
    final outputs = <String>[];
    String? current;
    var before = 0;
    try {
      for (final (i, file) in input.files.indexed) {
        final output = current = outputName(
          input.outputDir,
          file,
          input.suffix,
          outputs,
        );
        await PdfCompress(pool).compress(
          file,
          output,
          CompressOptions(
            preset: input.preset,
            greyscale: input.greyscale,
            removeMetadata: input.removeMetadata,
            targetBytes: input.targetBytes,
          ),
          password: input.password,
          workDir: context.tempDir,
          onPage: (done, _) => context.report(
            JobProgress(
              'compressing',
              pageIndex: before + done - 1,
              pageCount: total,
            ),
          ),
          isCancelled: () => context.isCancelled,
        );
        outputs.add(output);
        before += counts[i];
      }
    } catch (e) {
      // Cancelled or failed: no partial results are left behind.
      for (final path in [...outputs, ?current]) {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      }
      // The queue reports a cancel as cancelled, not as a failure.
      if (e is DocError && e.kind == DocErrorKind.cancelled) {
        throw const JobCancelled();
      }
      rethrow;
    }
    return outputs.length == 1 ? OneFile(outputs.single) : ManyFiles(outputs);
  }
}
