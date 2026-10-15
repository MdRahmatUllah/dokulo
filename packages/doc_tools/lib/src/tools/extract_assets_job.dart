import 'dart:io';
import 'dart:typed_data';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:image/image.dart' as img;

import '../tool_job.dart';

/// Extract images & text's input (T2, UI spec §21.25).
class ExtractAssetsInput {
  const ExtractAssetsInput({
    required this.file,
    required this.outputDir,
    required this.suffix,
    this.images = true,
    this.text = false,
    this.minPixels = 100,
    this.password,
  });

  factory ExtractAssetsInput.fromJson(Map<String, Object?> json) =>
      ExtractAssetsInput(
        file: json['file']! as String,
        outputDir: json['outputDir']! as String,
        suffix: json['suffix']! as String,
        images: json['images'] as bool? ?? true,
        text: json['text'] as bool? ?? false,
        minPixels: json['minPixels'] as int? ?? 100,
      );

  final String file;
  final String outputDir;

  /// The localised suffix (" – image"): `<name><suffix> 01.jpg`, and the
  /// text as `<name>.txt`.
  final String suffix;

  /// Extract: Images · Text · Both.
  final bool images, text;

  /// Minimum image size: Any (0) · Over 100 px · Over 500 px, on the longer
  /// side.
  final int minPixels;
  final String? password;

  Map<String, Object?> toJson() => {
    'file': file,
    'outputDir': outputDir,
    'suffix': suffix,
    'images': images,
    'text': text,
    'minPixels': minPixels,
    // No password: see CompressInput.
  };
}

/// The `extractassets` tool (DK-0510): the PDF's images as files (JPEGs as
/// they are stored, everything else as PNG; an image drawn on several pages
/// once) and its text as a .txt, pages split by a blank line. Nothing found
/// is an empty [ManyFiles] ("No images found in this PDF."). The input is
/// never touched.
class ExtractAssetsJob extends ToolJob<ExtractAssetsInput> {
  const ExtractAssetsJob();

  @override
  String get id => 'extractassets';

  @override
  Lane get lane => Lane.pdfium;

  @override
  String? passwordOf(ExtractAssetsInput input) => input.password;

  @override
  Map<String, Object?> encode(ExtractAssetsInput input) => input.toJson();

  @override
  ExtractAssetsInput decode(Map<String, Object?> json) =>
      ExtractAssetsInput.fromJson(json);

  @override
  List<String> inputFiles(ExtractAssetsInput input) => [input.file];

  @override
  ExtractAssetsInput chain(JobOutput previous, Map<String, Object?> options) =>
      ExtractAssetsInput.fromJson({
        ...options,
        'file': switch (previous) {
          OneFile(:final path) => path,
          _ => throw ArgumentError('Extract images & text takes one PDF'),
        },
      });

  @override
  Future<JobOutput> run(
    ExtractAssetsInput input,
    ToolJobContext context,
  ) async {
    if (!input.images && !input.text) throw ArgumentError('nothing to extract');
    final count = (await PdfEngine.inspect(
      input.file,
      password: input.password,
    )).pageCount;
    final base = input.file
        .split(RegExp(r'[\\/]'))
        .last
        .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final pool = IsolatePool(tempRoot: context.tempDir);
    final outputs = <String>[];
    try {
      if (input.images) {
        final seen = <int>{};
        for (var p = 0; p < count; p++) {
          await context.checkCancelled();
          context.report(
            JobProgress('extracting', pageIndex: p, pageCount: count),
          );
          for (final image in await PdfEngine.imageData(
            input.file,
            p,
            minPixels: input.minPixels,
            password: input.password,
          )) {
            final bytes = image.jpeg ?? image.pixels!.bgr;
            // The same image on several pages: one file.
            if (!seen.add(
              Object.hashAll([bytes.length, ...bytes.take(4096)]),
            )) {
              continue;
            }
            final n = '${outputs.length + 1}'.padLeft(2, '0');
            final path =
                '${input.outputDir}/$base${input.suffix} $n.${image.jpeg != null ? 'jpg' : 'png'}';
            outputs.add(path);
            if (image.jpeg case final jpeg?) {
              File(path).writeAsBytesSync(jpeg);
            } else {
              final px = image.pixels!;
              await pool.run(Lane.opencv, _png, (
                px.bgr,
                px.width,
                px.height,
                px.channels,
                px.alpha,
                path,
              )).result;
            }
          }
        }
      }
      if (input.text) {
        await context.checkCancelled();
        context.report(
          JobProgress('reading', pageIndex: count - 1, pageCount: count),
        );
        final pages = await PdfEngine.pageTexts(
          input.file,
          password: input.password,
        );
        final path = '${input.outputDir}/$base.txt';
        outputs.add(path);
        File(path).writeAsStringSync(pages.map((t) => t.trim()).join('\n\n'));
      }
    } catch (e) {
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

void _png((Uint8List, int, int, int, bool, String) job, JobContext context) {
  final (bgr, width, height, channels, alpha, path) = job;
  final image = img.Image(
    width: width,
    height: height,
    numChannels: alpha ? 4 : (channels == 1 ? 1 : 3),
  );
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * channels;
      if (channels == 1) {
        image.setPixelRgb(x, y, bgr[i], bgr[i], bgr[i]);
      } else if (alpha) {
        image.setPixelRgba(x, y, bgr[i + 2], bgr[i + 1], bgr[i], bgr[i + 3]);
      } else {
        image.setPixelRgb(x, y, bgr[i + 2], bgr[i + 1], bgr[i]);
      }
    }
  }
  File(path).writeAsBytesSync(img.encodePng(image, level: 6));
}
