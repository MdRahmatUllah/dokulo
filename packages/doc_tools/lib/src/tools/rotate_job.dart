import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_vision/doc_vision.dart';
import 'package:flutter/services.dart'
    show BackgroundIsolateBinaryMessenger, RootIsolateToken;

import '../tool_job.dart';
import 'ocr_job.dart';
import 'output_name.dart';

/// Rotate PDF's input (T2, UI spec §21.5).
class RotateInput {
  const RotateInput({
    required this.file,
    required this.turns,
    required this.outputDir,
    required this.suffix,
    this.password,
    this.detect = false,
  });

  factory RotateInput.fromJson(Map<String, Object?> json) => RotateInput(
    file: json['file']! as String,
    turns: {
      for (final MapEntry(:key, :value) in (json['turns']! as Map).entries)
        int.parse('$key'): value as int,
    },
    outputDir: json['outputDir']! as String,
    suffix: json['suffix']! as String,
    detect: json['detect'] as bool? ?? false,
  );

  final String file;

  /// Clockwise quarter turns by 0-based page (negative: counter-clockwise);
  /// pages not in it stay as they are.
  final Map<int, int> turns;
  final String outputDir;

  /// The localised suffix (" – rotated").
  final String suffix;
  final String? password;

  /// T2's look before the user turns anything (DK-1102): write nothing, and
  /// answer the pages that look sideways or upside down as the result's
  /// facts, `sideways: {page: quarter turns clockwise that fix it}`.
  final bool detect;

  Map<String, Object?> toJson() => {
    'file': file,
    'turns': {for (final e in turns.entries) '${e.key}': e.value},
    if (detect) 'detect': true,
    'outputDir': outputDir,
    'suffix': suffix,
    // No password: see CompressInput.
  };
}

/// The `rotate` tool (DK-0420): every page, the chosen ones turned (their
/// /Rotate, so nothing is re-rendered), as a new PDF (`<name><suffix>.pdf`)
/// through [PdfEngine.assemble]. The input is never touched.
///
/// With [RotateInput.detect] it only looks: which pages are sideways
/// (DK-1102).
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
    if (input.detect) return _detect(input, count, context);
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

  /// A page with text: its characters' angle (PDFium). A scan: PP-OCR's
  /// line detector and classifier on a 150 dpi render, on an ONNX worker.
  static Future<JobOutput> _detect(
    RotateInput input,
    int count,
    ToolJobContext context,
  ) async {
    final sideways = <String, int>{};
    final scans = <({int page, String path, int width, int height})>[];
    for (var p = 0; p < count; p++) {
      await context.checkCancelled();
      context.report(JobProgress('reading', pageIndex: p, pageCount: count));
      final turns = await PdfEngine.textTurns(
        input.file,
        p,
        password: input.password,
      );
      if (turns != null) {
        if (turns != 0) sideways['$p'] = turns;
        continue;
      }
      final shot = await PdfEngine.render(
        input.file,
        p,
        dpi: 150,
        password: input.password,
      );
      final path = '${context.tempDir.path}/turn_$p.bgra';
      await File(path).writeAsBytes(shot.bgra);
      scans.add((page: p, path: path, width: shot.width, height: shot.height));
    }
    if (scans.isNotEmpty) {
      final pool = IsolatePool(tempRoot: context.tempDir);
      final found = await pool.run(Lane.onnx, _orient, (
        pages: scans,
        assets: await OcrJob.assets(),
        token: RootIsolateToken.instance,
        engine: OcrJob.engine,
      )).result;
      for (final MapEntry(key: p, value: turns) in found.entries) {
        if (turns != 0) sideways['$p'] = turns;
      }
    }
    return OneFile(input.file, facts: {'sideways': sideways});
  }
}

/// On an ONNX worker: each scanned page's orientation.
Future<Map<int, int>> _orient(
  ({
    List<({int page, String path, int width, int height})> pages,
    OcrAssets? assets,
    RootIsolateToken? token,
    Future<OcrEngine> Function(OcrAssets?) engine,
  })
  job,
  JobContext context,
) async {
  if (job.token case final token?) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  }
  final engine = await job.engine(job.assets);
  try {
    return {
      for (final page in job.pages)
        page.page: ?await engine.orientation(
          Raster.fromBgra(
            page.width,
            page.height,
            File(page.path).readAsBytesSync(),
          ),
        ),
    };
  } finally {
    await engine.close();
  }
}
