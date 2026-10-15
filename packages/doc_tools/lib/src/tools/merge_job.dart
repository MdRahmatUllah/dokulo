import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';

import '../tool_job.dart';
import 'output_name.dart';

/// Merge PDF's input (T2, UI spec §21.1): the files in the cards' order,
/// each with its page range, where the output goes, and the name suffix.
class MergeInput {
  const MergeInput({
    required this.files,
    required this.outputDir,
    required this.suffix,
    this.ranges = const {},
    this.passwords = const {},
  });

  factory MergeInput.fromJson(Map<String, Object?> json) => MergeInput(
    files: (json['files']! as List).cast<String>(),
    outputDir: json['outputDir']! as String,
    suffix: json['suffix']! as String,
    ranges: {
      for (final MapEntry(:key, :value)
          in (json['ranges'] as Map? ?? const {}).entries)
        int.parse('$key'): value as String,
    },
  );

  /// 2 to 500 files: PDFs and images (JPG, PNG, WebP; HEIC arrives as JPEG,
  /// DK-1081).
  final List<String> files;

  /// A temp folder of the file store; the user saves the result from there.
  final String outputDir;

  /// The localised name suffix (the app's strings; this layer has none).
  final String suffix;

  /// "Pages: 1-3, 7" per card (by index in [files]), in qpdf's syntax
  /// (1-based, `z` the last page); a card without one gives all its pages.
  final Map<int, String> ranges;

  /// The passwords of locked PDFs, by path; never stored (see [toJson]).
  final Map<String, String> passwords;

  Map<String, Object?> toJson() => {
    'files': files,
    'outputDir': outputDir,
    'suffix': suffix,
    if (ranges.isNotEmpty)
      'ranges': {for (final e in ranges.entries) '${e.key}': e.value},
    // No passwords: they would sit in the jobs table in plain text. A
    // resumed job on a locked file fails as `locked`, and T2 asks again.
  };
}

/// The `merge` tool (DK-0402): one new PDF of every file's pages (or its
/// range), in the cards' order, named after the first file
/// (`<name><suffix>.pdf`). Images become a page each first
/// ([ImagesPdfWriter]); qpdf joins everything on its worker, keeping links,
/// annotations and form fields. The inputs are never touched.
///
/// ponytail: bookmarks are not carried over (qpdf's page selection drops
/// the outlines); DK-1101 rebuilds them from [PdfEngine.outline].
class MergeJob extends ToolJob<MergeInput> {
  const MergeJob();

  static const minFiles = 2, maxFiles = 500;

  @override
  String get id => 'merge';

  /// The work is qpdf's and the image writer's, on their own workers; this
  /// isolate only reads page counts through pdfrx.
  @override
  Lane get lane => Lane.pdfium;

  @override
  String? passwordOf(MergeInput input) => input.passwords.values.firstOrNull;

  @override
  Map<String, Object?> encode(MergeInput input) => input.toJson();

  @override
  MergeInput decode(Map<String, Object?> json) => MergeInput.fromJson(json);

  @override
  List<String> inputFiles(MergeInput input) => input.files;

  @override
  MergeInput chain(JobOutput previous, Map<String, Object?> options) =>
      MergeInput.fromJson({
        ...options,
        'files': switch (previous) {
          OneFile(:final path) => [path],
          ManyFiles(:final paths) => paths,
          TextOutput() => throw ArgumentError(
            'Merge PDF needs files, not text',
          ),
        },
      });

  static bool _isPdf(String path) => path.toLowerCase().endsWith('.pdf');

  @override
  Future<JobOutput> run(MergeInput input, ToolJobContext context) async {
    final files = input.files;
    if (files.length < minFiles || files.length > maxFiles) {
      throw ArgumentError(
        'Merge PDF takes $minFiles to $maxFiles files, not ${files.length}',
      );
    }
    final pool = IsolatePool(tempRoot: context.tempDir);
    // Named after the first file, an image's extension dropped too.
    final output = outputName(
      input.outputDir,
      files.first.replaceAll(RegExp(r'\.[^./\\]+$'), ''),
      input.suffix,
      [],
    );
    try {
      final parts = <Map<String, Object?>>[];
      for (final (i, file) in files.indexed) {
        await context.checkCancelled();
        context.report(
          JobProgress('reading', pageIndex: i, pageCount: files.length),
        );
        if (_isPdf(file)) {
          final password = input.passwords[file];
          // Opens it: a locked or damaged file fails here, with its card.
          await PdfEngine.inspect(file, password: password);
          parts.add({
            'file': file,
            'password': ?password,
            'range': ?input.ranges[i],
          });
        } else {
          final page = '${context.tempDir.path}/image_$i.pdf';
          final writer = ImagesPdfWriter(page, workDir: context.tempDir);
          try {
            await writer.add(File(file).readAsBytesSync());
          } on DocError catch (e) {
            throw DocError(e.kind, page: i, detail: e.detail);
          }
          await writer.close(pool);
          parts.add({'file': page});
        }
      }
      await context.checkCancelled();
      context.report(
        JobProgress(
          'writing',
          pageIndex: files.length - 1,
          pageCount: files.length,
        ),
      );
      await pool.run(Lane.qpdf, _join, (parts, output)).result;
    } catch (e) {
      // Cancelled or failed: no partial result is left behind.
      final f = File(output);
      if (f.existsSync()) f.deleteSync();
      if (e is DocError && e.kind == DocErrorKind.cancelled) {
        throw const JobCancelled();
      }
      rethrow;
    }
    return OneFile(output);
  }
}

void _join((List<Map<String, Object?>>, String) job, JobContext context) =>
    QpdfService.joinPages(job.$1, job.$2);
