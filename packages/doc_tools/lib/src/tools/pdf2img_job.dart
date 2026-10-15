import 'dart:io';
import 'dart:typed_data';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:image/image.dart' as img;

import '../tool_job.dart';

/// PDF to images' input (T2, UI spec §21.8).
class Pdf2ImgInput {
  const Pdf2ImgInput({
    required this.file,
    required this.outputDir,
    required this.suffix,
    this.png = false,
    this.dpi = 150,
    this.pages,
    this.password,
  });

  factory Pdf2ImgInput.fromJson(Map<String, Object?> json) => Pdf2ImgInput(
    file: json['file']! as String,
    outputDir: json['outputDir']! as String,
    suffix: json['suffix']! as String,
    png: json['png'] as bool? ?? false,
    dpi: (json['dpi'] as num? ?? 150).toDouble(),
    pages: (json['pages'] as List?)?.cast<int>(),
  );

  final String file;
  final String outputDir;

  /// The localised suffix (" – page"): image n is `<name><suffix> n.jpg`.
  final String suffix;

  /// PNG instead of JPG.
  final bool png;

  /// Screen 72 · Standard 150 · Print 300.
  final double dpi;

  /// 0-based; null: all of them.
  final List<int>? pages;
  final String? password;

  Map<String, Object?> toJson() => {
    'file': file,
    'outputDir': outputDir,
    'suffix': suffix,
    'png': png,
    'dpi': dpi,
    'pages': ?pages,
    // No password: see CompressInput.
  };
}

/// The `pdf2img` tool (DK-0438): each chosen page rendered at the chosen dpi
/// and saved as a JPG (quality 90) or PNG, numbered so they sort
/// (`<name><suffix> 01.jpg`). PDFium renders; the encoding runs on its own
/// worker. The input is never touched.
class Pdf2ImgJob extends ToolJob<Pdf2ImgInput> {
  const Pdf2ImgJob();

  @override
  String get id => 'pdf2img';

  @override
  Lane get lane => Lane.pdfium;

  @override
  double get renderDpi => 300;

  @override
  String? passwordOf(Pdf2ImgInput input) => input.password;

  @override
  Map<String, Object?> encode(Pdf2ImgInput input) => input.toJson();

  @override
  Pdf2ImgInput decode(Map<String, Object?> json) => Pdf2ImgInput.fromJson(json);

  @override
  List<String> inputFiles(Pdf2ImgInput input) => [input.file];

  @override
  Pdf2ImgInput chain(JobOutput previous, Map<String, Object?> options) =>
      Pdf2ImgInput.fromJson({
        ...options,
        'file': switch (previous) {
          OneFile(:final path) => path,
          _ => throw ArgumentError('PDF to images takes one PDF'),
        },
      });

  @override
  Future<JobOutput> run(Pdf2ImgInput input, ToolJobContext context) async {
    final count = (await PdfEngine.inspect(
      input.file,
      password: input.password,
    )).pageCount;
    final pages = input.pages ?? [for (var p = 0; p < count; p++) p];
    if (pages.isEmpty || pages.any((p) => p < 0 || p >= count)) {
      throw ArgumentError('pages $pages of $count');
    }
    final base = input.file
        .split(RegExp(r'[\\/]'))
        .last
        .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final digits = '$count'.length;
    final ext = input.png ? 'png' : 'jpg';
    final pool = IsolatePool(tempRoot: context.tempDir);
    final outputs = <String>[];
    final encoding = <Future<void>>[];
    try {
      for (final (i, page) in pages.indexed) {
        await context.checkCancelled();
        context.report(
          JobProgress('rendering', pageIndex: i, pageCount: pages.length),
        );
        final r = await PdfEngine.render(
          input.file,
          page,
          dpi: input.dpi,
          password: input.password,
        );
        final n = '${page + 1}'.padLeft(digits, '0');
        final path = '${input.outputDir}/$base${input.suffix} $n.$ext';
        outputs.add(path);
        // The next page renders while this one encodes; at most 3 wait.
        if (encoding.length == 3) await encoding.removeAt(0);
        encoding.add(
          pool.run(Lane.opencv, _encode, (
            r.rgba,
            r.width,
            r.height,
            input.png,
            path,
          )).result,
        );
      }
      await Future.wait(encoding);
    } catch (e) {
      // Let the encodes in flight finish before their files go.
      await Future.wait(encoding).catchError((_) => <void>[]);
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

void _encode((Uint8List, int, int, bool, String) job, JobContext context) {
  final (rgba, width, height, png, path) = job;
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    numChannels: 4,
  );
  File(path).writeAsBytesSync(
    png
        ? img.encodePng(image.convert(numChannels: 3), level: 6)
        // JPEG drops the alpha by itself.
        : img.encodeJpg(image, quality: 90),
  );
}
