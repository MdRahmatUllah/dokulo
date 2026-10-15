import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';

import '../tool_job.dart';
import 'output_name.dart';

/// Repair PDF's input (T2, UI spec §21.13: no options).
class RepairInput {
  const RepairInput({
    required this.file,
    required this.outputDir,
    required this.suffix,
    this.password,
  });

  factory RepairInput.fromJson(Map<String, Object?> json) => RepairInput(
    file: json['file']! as String,
    outputDir: json['outputDir']! as String,
    suffix: json['suffix']! as String,
  );

  final String file;
  final String outputDir;

  /// The localised suffix (" – repaired").
  final String suffix;
  final String? password;

  Map<String, Object?> toJson() => {
    'file': file,
    'outputDir': outputDir,
    'suffix': suffix,
    // No password: see CompressInput.
  };
}

/// The `repair` tool (DK-0468): qpdf rewrites the file, rebuilding a broken
/// cross-reference table or stream lengths as it reads; when qpdf can't,
/// PDFium opens what it can and saves a clean copy of every page. A file
/// neither can open fails as `damaged` ("This file is too damaged to
/// repair."). The input is never touched.
///
/// ponytail: the result's one line ("Rebuilt the page table") is T3's to
/// word; qpdf's warnings are only logged for now.
class RepairJob extends ToolJob<RepairInput> {
  const RepairJob();

  @override
  String get id => 'repair';

  /// The fallback is PDFium; qpdf runs on its worker.
  @override
  Lane get lane => Lane.pdfium;

  @override
  String? passwordOf(RepairInput input) => input.password;

  @override
  Map<String, Object?> encode(RepairInput input) => input.toJson();

  @override
  RepairInput decode(Map<String, Object?> json) => RepairInput.fromJson(json);

  @override
  List<String> inputFiles(RepairInput input) => [input.file];

  @override
  RepairInput chain(JobOutput previous, Map<String, Object?> options) =>
      RepairInput.fromJson({
        ...options,
        'file': switch (previous) {
          OneFile(:final path) => path,
          _ => throw ArgumentError('Repair PDF takes one PDF'),
        },
      });

  @override
  Future<JobOutput> run(RepairInput input, ToolJobContext context) async {
    final output = outputName(input.outputDir, input.file, input.suffix, []);
    final pool = IsolatePool(tempRoot: context.tempDir);
    context.report(const JobProgress('repairing'));
    try {
      try {
        await pool.run(Lane.qpdf, _repair, (
          input.file,
          output,
          input.password,
        )).result;
        // qpdf wrote something PDFium can open: done.
        await PdfEngine.inspect(output, password: input.password);
      } on Object catch (e) {
        // A wrong password is not damage.
        if ('$e'.contains('DocError(locked')) rethrow;
        await context.checkCancelled();
        final f = File(output);
        if (f.existsSync()) f.deleteSync();
        final pages = (await PdfEngine.inspect(
          input.file,
          password: input.password,
        )).pageCount;
        await PdfEngine.assemble(
          [for (var p = 0; p < pages; p++) PageSource(input.file, p)],
          output,
          passwords: {input.file: ?input.password},
        );
      }
    } on Object catch (e) {
      final f = File(output);
      if (f.existsSync()) f.deleteSync();
      if (e is DocError && e.kind == DocErrorKind.locked) rethrow;
      if (e is JobCancelled) rethrow;
      throw DocError(DocErrorKind.damaged, detail: 'repair: $e');
    }
    return OneFile(output);
  }
}

void _repair((String, String, String?) job, JobContext context) =>
    QpdfService.repair(job.$1, job.$2, password: job.$3);
