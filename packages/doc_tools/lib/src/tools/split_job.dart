import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';

import '../tool_job.dart';
import 'output_name.dart';

/// How Split PDF cuts (UI spec §21.2).
enum SplitMode { ranges, everyN, eachPage, bookmarks }

/// Split PDF's input (T2, UI spec §21.2).
class SplitInput {
  const SplitInput({
    required this.file,
    required this.outputDir,
    required this.suffix,
    this.mode = SplitMode.ranges,
    this.ranges = const [],
    this.every = 2,
    this.password,
  });

  factory SplitInput.fromJson(Map<String, Object?> json) => SplitInput(
    file: json['file']! as String,
    outputDir: json['outputDir']! as String,
    suffix: json['suffix']! as String,
    mode: SplitMode.values.byName(json['mode'] as String? ?? 'ranges'),
    ranges: (json['ranges'] as List? ?? const []).cast<String>(),
    every: json['every'] as int? ?? 2,
  );

  final String file;

  /// A temp folder of the file store; the user saves the parts from there.
  final String outputDir;

  /// The localised suffix (" – split"); part n is `<name><suffix> n.pdf`.
  final String suffix;
  final SplitMode mode;

  /// [SplitMode.ranges]: one part per range, 1-based ("1-3", "4-8", "9-z";
  /// `z` is the last page), as the T2 field has checked them.
  final List<String> ranges;

  /// [SplitMode.everyN]: pages per part.
  final int every;
  final String? password;

  Map<String, Object?> toJson() => {
    'file': file,
    'outputDir': outputDir,
    'suffix': suffix,
    'mode': mode.name,
    if (ranges.isNotEmpty) 'ranges': ranges,
    if (mode == SplitMode.everyN) 'every': every,
    // No password: see CompressInput.
  };
}

/// The `split` tool (DK-0408): one new PDF per part, cut by ranges, every
/// N pages, each page, or at the top-level bookmarks; qpdf writes the parts
/// on its worker, keeping links and annotations. The input is never touched.
class SplitJob extends ToolJob<SplitInput> {
  const SplitJob();

  @override
  String get id => 'split';

  /// Page counts and bookmarks come through pdfrx; qpdf runs on its worker.
  @override
  Lane get lane => Lane.pdfium;

  @override
  String? passwordOf(SplitInput input) => input.password;

  @override
  Map<String, Object?> encode(SplitInput input) => input.toJson();

  @override
  SplitInput decode(Map<String, Object?> json) => SplitInput.fromJson(json);

  @override
  List<String> inputFiles(SplitInput input) => [input.file];

  @override
  SplitInput chain(JobOutput previous, Map<String, Object?> options) =>
      SplitInput.fromJson({
        ...options,
        'file': switch (previous) {
          OneFile(:final path) => path,
          _ => throw ArgumentError('Split PDF takes one PDF'),
        },
      });

  /// The parts as qpdf ranges, 1-based.
  static Future<List<String>> partsOf(SplitInput input) async {
    final pages = (await PdfEngine.inspect(
      input.file,
      password: input.password,
    )).pageCount;
    String span(int from, int to) => from == to ? '$from' : '$from-$to';
    switch (input.mode) {
      case SplitMode.ranges:
        if (input.ranges.isEmpty) throw ArgumentError('no ranges');
        return input.ranges;
      case SplitMode.everyN:
        if (input.every < 1) throw ArgumentError('every ${input.every}');
        return [
          for (var p = 1; p <= pages; p += input.every)
            span(p, (p + input.every - 1).clamp(1, pages)),
        ];
      case SplitMode.eachPage:
        return [for (var p = 1; p <= pages; p++) '$p'];
      case SplitMode.bookmarks:
        // Each top-level bookmark starts a part; pages before the first
        // belong to it.
        final starts = {
          for (final e in await PdfEngine.outline(
            input.file,
            password: input.password,
          ))
            ?e.page,
        }.toList()..sort();
        if (starts.isEmpty) throw ArgumentError('no bookmarks');
        starts[0] = 0;
        return [
          for (final (i, s) in starts.indexed)
            span(s + 1, i + 1 < starts.length ? starts[i + 1] : pages),
        ];
    }
  }

  @override
  Future<JobOutput> run(SplitInput input, ToolJobContext context) async {
    context.report(const JobProgress('reading'));
    final parts = await partsOf(input);
    final base = input.file
        .split(RegExp(r'[\\/]'))
        .last
        .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final outputs = <String>[];
    for (var n = 1; n <= parts.length; n++) {
      outputs.add(
        outputName(input.outputDir, '$base${input.suffix} $n', '', outputs),
      );
    }
    final pool = IsolatePool(tempRoot: context.tempDir);
    try {
      // ponytail: qpdf in batches of 20 parts, so cancel and progress have a
      // say between them without a qpdf start per page.
      for (var i = 0; i < parts.length; i += 20) {
        await context.checkCancelled();
        context.report(
          JobProgress('writing', pageIndex: i, pageCount: parts.length),
        );
        final end = (i + 20).clamp(0, parts.length);
        await pool.run(Lane.qpdf, _write, [
          for (var j = i; j < end; j++)
            (
              [
                {
                  'file': input.file,
                  'password': ?input.password,
                  'range': parts[j],
                },
              ],
              outputs[j],
            ),
        ]).result;
      }
    } catch (e) {
      // Cancelled or failed: no partial results are left behind.
      for (final path in outputs) {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      }
      if (e is DocError && e.kind == DocErrorKind.cancelled) {
        throw const JobCancelled();
      }
      rethrow;
    }
    return ManyFiles(outputs);
  }
}

void _write(
  List<(List<Map<String, Object?>>, String)> parts,
  JobContext context,
) {
  for (final (pages, output) in parts) {
    QpdfService.joinPages(pages, output);
  }
}
