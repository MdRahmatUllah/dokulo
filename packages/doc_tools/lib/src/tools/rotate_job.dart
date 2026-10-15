import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';

import '../tool_job.dart';
import 'output_name.dart';

/// Rotate PDF's input (T2, UI spec §21.5).
class RotateInput {
  const RotateInput({
    required this.file,
    required this.turns,
    required this.outputDir,
    required this.suffix,
    this.password,
  });

  factory RotateInput.fromJson(Map<String, Object?> json) => RotateInput(
    file: json['file']! as String,
    turns: {
      for (final MapEntry(:key, :value) in (json['turns']! as Map).entries)
        int.parse('$key'): value as int,
    },
    outputDir: json['outputDir']! as String,
    suffix: json['suffix']! as String,
  );

  final String file;

  /// Clockwise quarter turns by 0-based page (negative: counter-clockwise);
  /// pages not in it stay as they are.
  final Map<int, int> turns;
  final String outputDir;

  /// The localised suffix (" – rotated").
  final String suffix;
  final String? password;

  Map<String, Object?> toJson() => {
    'file': file,
    'turns': {for (final e in turns.entries) '${e.key}': e.value},
    'outputDir': outputDir,
    'suffix': suffix,
    // No password: see CompressInput.
  };
}

/// The `rotate` tool (DK-0420): every page, the chosen ones turned (their
/// /Rotate, so nothing is re-rendered), as a new PDF (`<name><suffix>.pdf`)
/// through [PdfEngine.assemble]. The input is never touched.
///
/// ponytail: no sideways detection yet ("3 pages look sideways"); DK-1102.
class RotateJob extends ToolJob<RotateInput> {
  const RotateJob();

  @override
  String get id => 'rotate';

  @override
  Lane get lane => Lane.pdfium;

  @override
  String? passwordOf(RotateInput input) => input.password;

  @override
  Map<String, Object?> encode(RotateInput input) => input.toJson();

  @override
  RotateInput decode(Map<String, Object?> json) => RotateInput.fromJson(json);

  @override
  List<String> inputFiles(RotateInput input) => [input.file];

  @override
  RotateInput chain(JobOutput previous, Map<String, Object?> options) =>
      RotateInput.fromJson({
        ...options,
        'file': switch (previous) {
          OneFile(:final path) => path,
          _ => throw ArgumentError('Rotate PDF takes one PDF'),
        },
      });

  @override
  Future<JobOutput> run(RotateInput input, ToolJobContext context) async {
    context.report(const JobProgress('reading'));
    final count = (await PdfEngine.inspect(
      input.file,
      password: input.password,
    )).pageCount;
    if (input.turns.keys.any((p) => p < 0 || p >= count)) {
      throw ArgumentError('pages ${input.turns.keys} of $count');
    }
    final output = outputName(input.outputDir, input.file, input.suffix, []);
    await context.checkCancelled();
    context.report(JobProgress('writing', pageIndex: 0, pageCount: count));
    try {
      await PdfEngine.assemble(
        [
          for (var p = 0; p < count; p++)
            PageSource(
              input.file,
              p,
              addQuarterTurns: (input.turns[p] ?? 0) % 4,
            ),
        ],
        output,
        passwords: {input.file: ?input.password},
      );
    } catch (_) {
      final f = File(output);
      if (f.existsSync()) f.deleteSync();
      rethrow;
    }
    return OneFile(output);
  }
}
