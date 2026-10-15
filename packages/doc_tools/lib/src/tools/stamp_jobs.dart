import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';

import '../tool_job.dart';
import 'output_name.dart';

/// Add page numbers' input (T2, UI spec §21.15).
class PageNumbersInput {
  const PageNumbersInput({
    required this.files,
    required this.outputDir,
    required this.suffix,
    this.format = '{n}',
    this.align = (x: 0, y: 1),
    this.startAt = 1,
    this.skipFirst = false,
    this.fontSize = 10,
    this.passwords = const {},
  });

  factory PageNumbersInput.fromJson(Map<String, Object?> json) =>
      PageNumbersInput(
        files: (json['files']! as List).cast<String>(),
        outputDir: json['outputDir']! as String,
        suffix: json['suffix']! as String,
        format: json['format'] as String? ?? '{n}',
        align: (
          x: (json['x'] as num? ?? 0).toDouble(),
          y: (json['y'] as num? ?? 1).toDouble(),
        ),
        startAt: json['startAt'] as int? ?? 1,
        skipFirst: json['skipFirst'] as bool? ?? false,
        fontSize: (json['fontSize'] as num? ?? 10).toDouble(),
      );

  final List<String> files;
  final String outputDir;

  /// The localised suffix (" – numbered").
  final String suffix;

  /// The localised format, `{n}` the number and `{total}` the last one:
  /// "{n}", "{n} of {total}", "Seite {n} von {total}".
  final String format;
  final StampAlign align;

  /// The first page's number.
  final int startAt;

  /// The first page (a cover) gets none; the count goes on from it.
  final bool skipFirst;

  /// S · M · L: 8, 10, 12 pt.
  final double fontSize;
  final Map<String, String> passwords;

  Map<String, Object?> toJson() => {
    'files': files,
    'outputDir': outputDir,
    'suffix': suffix,
    'format': format,
    'x': align.x,
    'y': align.y,
    'startAt': startAt,
    'skipFirst': skipFirst,
    'fontSize': fontSize,
  };
}

/// Add watermark's input (T2, UI spec §21.16): a [text] or an [image] file.
class WatermarkInput {
  const WatermarkInput({
    required this.files,
    required this.outputDir,
    required this.suffix,
    this.text,
    this.image,
    this.opacity = 0.3,
    this.degrees = 45,
    this.size = 48,
    this.tiled = false,
    this.behind = false,
    this.pages,
    this.passwords = const {},
  });

  factory WatermarkInput.fromJson(Map<String, Object?> json) => WatermarkInput(
    files: (json['files']! as List).cast<String>(),
    outputDir: json['outputDir']! as String,
    suffix: json['suffix']! as String,
    text: json['text'] as String?,
    image: json['image'] as String?,
    opacity: (json['opacity'] as num? ?? 0.3).toDouble(),
    degrees: (json['degrees'] as num? ?? 45).toDouble(),
    size: (json['size'] as num? ?? 48).toDouble(),
    tiled: json['tiled'] as bool? ?? false,
    behind: json['behind'] as bool? ?? false,
    pages: (json['pages'] as List?)?.cast<int>().toSet(),
  );

  final List<String> files;
  final String outputDir;

  /// The localised suffix (" – watermarked").
  final String suffix;
  final String? text;

  /// An image file's path.
  final String? image;

  /// 0.1 to 1.
  final double opacity;

  /// Counter-clockwise: 0, 45, -45.
  final double degrees;

  /// The text's font size, or the image's width as a share of the page's.
  final double size;
  final bool tiled;

  /// Under the content instead of over it.
  final bool behind;

  /// 0-based; null: every page.
  final Set<int>? pages;
  final Map<String, String> passwords;

  Map<String, Object?> toJson() => {
    'files': files,
    'outputDir': outputDir,
    'suffix': suffix,
    'text': ?text,
    'image': ?image,
    'opacity': opacity,
    'degrees': degrees,
    'size': size,
    'tiled': tiled,
    'behind': behind,
    if (pages case final p?) 'pages': p.toList()..sort(),
  };
}

/// The `pagenum` tool (DK-0480): numbers laid over each page with qpdf from
/// a stamp PDF ([PdfStamp.pageNumbers]), one new file per input.
class PageNumbersJob extends ToolJob<PageNumbersInput> {
  const PageNumbersJob();

  @override
  String get id => 'pagenum';

  @override
  Lane get lane => Lane.pdfium;

  @override
  String? passwordOf(PageNumbersInput input) =>
      input.passwords.values.firstOrNull;

  @override
  Map<String, Object?> encode(PageNumbersInput input) => input.toJson();

  @override
  PageNumbersInput decode(Map<String, Object?> json) =>
      PageNumbersInput.fromJson(json);

  @override
  List<String> inputFiles(PageNumbersInput input) => input.files;

  @override
  PageNumbersInput chain(JobOutput previous, Map<String, Object?> options) =>
      PageNumbersInput.fromJson({...options, 'files': _files(previous)});

  @override
  Future<JobOutput> run(PageNumbersInput input, ToolJobContext context) =>
      _stampEach(
        input.files,
        input.outputDir,
        input.suffix,
        input.passwords,
        context,
        (sizes, stamp) {
          final last = input.startAt + sizes.length - 1;
          return PdfStamp.pageNumbers(
            sizes,
            stamp,
            align: input.align,
            fontSize: input.fontSize,
            label: (i) => input.skipFirst && i == 0
                ? null
                : input.format
                      .replaceAll('{n}', '${input.startAt + i}')
                      .replaceAll('{total}', '$last'),
          );
        },
      );
}

/// The `watermark` tool (DK-0486): a text or an image over (or behind) the
/// pages, with qpdf from a stamp PDF ([PdfStamp.watermark]).
class WatermarkJob extends ToolJob<WatermarkInput> {
  const WatermarkJob();

  @override
  String get id => 'watermark';

  @override
  Lane get lane => Lane.pdfium;

  @override
  String? passwordOf(WatermarkInput input) =>
      input.passwords.values.firstOrNull;

  @override
  Map<String, Object?> encode(WatermarkInput input) => input.toJson();

  @override
  WatermarkInput decode(Map<String, Object?> json) =>
      WatermarkInput.fromJson(json);

  @override
  List<String> inputFiles(WatermarkInput input) => [
    ...input.files,
    ?input.image,
  ];

  @override
  WatermarkInput chain(JobOutput previous, Map<String, Object?> options) =>
      WatermarkInput.fromJson({...options, 'files': _files(previous)});

  @override
  Future<JobOutput> run(WatermarkInput input, ToolJobContext context) {
    final image = input.image == null
        ? null
        : File(input.image!).readAsBytesSync();
    return _stampEach(
      input.files,
      input.outputDir,
      input.suffix,
      input.passwords,
      context,
      (sizes, stamp) => PdfStamp.watermark(
        sizes,
        stamp,
        text: input.text,
        image: image,
        opacity: input.opacity,
        degrees: input.degrees,
        size: input.size,
        tiled: input.tiled,
        pages: input.pages,
      ),
      underlay: input.behind,
    );
  }
}

List<String> _files(JobOutput previous) => switch (previous) {
  OneFile(:final path) => [path],
  ManyFiles(:final paths) => paths,
  TextOutput() => throw ArgumentError('this tool needs PDFs, not text'),
};

/// For each file: its page sizes, a stamp PDF made by [make] in the job's
/// temp folder, and qpdf laying it over (or under) the pages.
Future<JobOutput> _stampEach(
  List<String> files,
  String outputDir,
  String suffix,
  Map<String, String> passwords,
  ToolJobContext context,
  Future<void> Function(
    List<({double width, double height})> sizes,
    String stamp,
  )
  make, {
  bool underlay = false,
}) async {
  if (files.isEmpty) throw ArgumentError('no files');
  final pool = IsolatePool(tempRoot: context.tempDir);
  final outputs = <String>[];
  String? current;
  try {
    for (final (i, file) in files.indexed) {
      await context.checkCancelled();
      context.report(
        JobProgress('writing', pageIndex: i, pageCount: files.length),
      );
      final password = passwords[file];
      final info = await PdfEngine.inspect(file, password: password);
      final stamp = '${context.tempDir.path}/stamp_$i.pdf';
      await make([
        for (final p in info.pages) (width: p.width, height: p.height),
      ], stamp);
      final output = current = outputName(outputDir, file, suffix, outputs);
      await pool.run(Lane.qpdf, _stamp, (
        file,
        stamp,
        output,
        underlay,
        password,
      )).result;
      outputs.add(output);
    }
  } catch (e) {
    for (final path in [...outputs, ?current]) {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    }
    if (e is DocError && e.kind == DocErrorKind.cancelled) {
      throw const JobCancelled();
    }
    rethrow;
  }
  return outputs.length == 1 ? OneFile(outputs.single) : ManyFiles(outputs);
}

void _stamp((String, String, String, bool, String?) job, JobContext context) =>
    QpdfService.stamp(
      job.$1,
      job.$2,
      job.$3,
      underlay: job.$4,
      password: job.$5,
    );
