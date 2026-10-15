import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';

import '../tool_job.dart';
import 'smart_split.dart';

/// Smart Split's input (T2, UI spec §21.6: one PDF, "Find documents").
class SmartSplitInput {
  const SmartSplitInput({required this.file, this.password});

  factory SmartSplitInput.fromJson(Map<String, Object?> json) =>
      SmartSplitInput(file: json['file']! as String);

  final String file;
  final String? password;

  Map<String, Object?> toJson() => {'file': file};
}

/// The `smartsplit` tool (DK-0426): finds where one document ends and the
/// next begins in a bundle ([SmartSplitRules], rules only: blank separator
/// sheets, "Page 1 of N", a new letterhead, a new date), page by page at
/// 36 dpi. It writes nothing: the result is the input with the documents as
/// facts, `documents`: `[{pages: [0-based], reason: SplitReason name or
/// null, name: suggested or null}]`, for the review screen; what the user
/// confirms is split by the `split` job with those ranges.
class SmartSplitJob extends ToolJob<SmartSplitInput> {
  const SmartSplitJob();

  /// Enough to see a letterhead and a blank sheet; fast for 50 pages.
  static const dpi = 36.0;

  @override
  String get id => 'smartsplit';

  @override
  Lane get lane => Lane.pdfium;

  @override
  double get renderDpi => dpi;

  @override
  String? passwordOf(SmartSplitInput input) => input.password;

  @override
  Map<String, Object?> encode(SmartSplitInput input) => input.toJson();

  @override
  SmartSplitInput decode(Map<String, Object?> json) =>
      SmartSplitInput.fromJson(json);

  @override
  List<String> inputFiles(SmartSplitInput input) => [input.file];

  @override
  SmartSplitInput chain(JobOutput previous, Map<String, Object?> options) =>
      SmartSplitInput.fromJson({
        ...options,
        'file': switch (previous) {
          OneFile(:final path) => path,
          _ => throw ArgumentError('Smart Split takes one PDF'),
        },
      });

  @override
  Future<JobOutput> run(SmartSplitInput input, ToolJobContext context) async {
    final count = (await PdfEngine.inspect(
      input.file,
      password: input.password,
    )).pageCount;
    final pages = <PageSignals>[];
    for (var p = 0; p < count; p++) {
      await context.checkCancelled();
      context.report(JobProgress('analysing', pageIndex: p, pageCount: count));
      final render = await PdfEngine.render(
        input.file,
        p,
        dpi: dpi,
        password: input.password,
      );
      final text = (await PdfEngine.pageText(
        input.file,
        p,
        password: input.password,
      )).text;
      pages.add(SmartSplitRules.signals(render, text));
    }
    return OneFile(
      input.file,
      facts: {
        'documents': [
          for (final d in SmartSplitRules.split(pages))
            {'pages': d.pages, 'reason': d.reason?.name, 'name': d.name},
        ],
      },
    );
  }
}
