import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_vision/doc_vision.dart';

import '../tool_job.dart';
import 'output_name.dart';

/// Image to PDF's input (T2, UI spec §21.7): the images in the strip's
/// order, where the outputs go, and the options.
class Img2PdfInput {
  const Img2PdfInput({
    required this.files,
    required this.outputDir,
    required this.suffix,
    this.size = ImagePageSize.fit,
    this.margins = false,
    this.onePerImage = false,
    this.cleanUp = false,
    this.skipPages = const [],
  });

  factory Img2PdfInput.fromJson(Map<String, Object?> json) => Img2PdfInput(
    files: (json['files']! as List).cast<String>(),
    outputDir: json['outputDir']! as String,
    suffix: json['suffix']! as String,
    size: ImagePageSize.values.byName(json['size'] as String? ?? 'fit'),
    margins: json['margins'] as bool? ?? false,
    onePerImage: json['onePerImage'] as bool? ?? false,
    cleanUp: json['cleanUp'] as bool? ?? false,
    skipPages: (json['skipPages'] as List? ?? const []).cast<int>(),
  );

  /// 1 to 500 images: JPG, PNG, WebP (and GIF, BMP, TIFF).
  final List<String> files;

  /// A temp folder of the file store; the user saves the results from there.
  final String outputDir;

  /// The localised name suffix (the app's strings; this layer has none).
  final String suffix;
  final ImagePageSize size;

  /// "Small" margins instead of none.
  final bool margins;

  /// "One per image" instead of "One PDF".
  final bool onePerImage;

  /// "Clean up like a scan": crop to the document, improve contrast.
  final bool cleanUp;

  /// Images (0-based, in the strip's order) left out: "Skip this page"
  /// after one failed (DK-1086).
  final List<int> skipPages;

  Map<String, Object?> toJson() => {
    'files': files,
    'outputDir': outputDir,
    'suffix': suffix,
    'size': size.name,
    'margins': margins,
    'onePerImage': onePerImage,
    'cleanUp': cleanUp,
    if (skipPages.isNotEmpty) 'skipPages': skipPages,
  };
}

/// The `img2pdf` tool (DK-0432): each image a page, in order, into one new
/// PDF named after the first image (`<name><suffix>.pdf`), or one PDF per
/// image. JPEGs are embedded as they are, turned by EXIF; see
/// [ImagesPdfWriter]. With [Img2PdfInput.cleanUp] each image is found,
/// flattened and colour-fixed first ([cleanUpImageSync]). The inputs are
/// never touched.
class Img2PdfJob extends ToolJob<Img2PdfInput> {
  const Img2PdfJob();

  static const maxFiles = 500;

  @override
  String get id => 'img2pdf';

  /// Its own worker: the clean-up is OpenCV, the writer pure Dart; qpdf joins
  /// the batches on its worker.
  @override
  Lane get lane => Lane.opencv;

  @override
  Map<String, Object?> encode(Img2PdfInput input) => input.toJson();

  @override
  Img2PdfInput decode(Map<String, Object?> json) => Img2PdfInput.fromJson(json);

  @override
  List<String> inputFiles(Img2PdfInput input) => input.files;

  @override
  Img2PdfInput chain(JobOutput previous, Map<String, Object?> options) =>
      Img2PdfInput.fromJson({
        ...options,
        'files': switch (previous) {
          OneFile(:final path) => [path],
          ManyFiles(:final paths) => paths,
          TextOutput() => throw ArgumentError(
            'Image to PDF needs images, not text',
          ),
        },
      });

  @override
  Future<JobOutput> run(Img2PdfInput input, ToolJobContext context) async {
    final files = input.files;
    if (files.isEmpty || files.length > maxFiles) {
      throw ArgumentError(
        'Image to PDF takes 1 to $maxFiles images, not ${files.length}',
      );
    }
    final pool = IsolatePool(tempRoot: context.tempDir);
    final outputs = <String>[];
    String? current;
    ImagesPdfWriter writer(String output) => ImagesPdfWriter(
      output,
      workDir: context.tempDir,
      size: input.size,
      margins: input.margins,
    );
    String name(String image) => outputName(
      input.outputDir,
      image.replaceAll(RegExp(r'\.[^./\\]+$'), ''),
      input.suffix,
      outputs,
    );
    try {
      ImagesPdfWriter? one;
      for (final (i, file) in files.indexed) {
        await context.checkCancelled();
        if (input.skipPages.contains(i)) continue;
        context.report(
          JobProgress('converting', pageIndex: i, pageCount: files.length),
        );
        var bytes = File(file).readAsBytesSync();
        if (input.cleanUp) {
          try {
            bytes = cleanUpImageSync(bytes);
          } on FormatException {
            // Not an image: the writer says so, with the page.
          }
        }
        final w = input.onePerImage
            ? writer(current = name(file))
            : one ??= writer(current = name(files.first));
        try {
          await w.add(bytes);
        } on DocError catch (e) {
          // The image's place in the strip, not in the writer's file.
          throw DocError(e.kind, page: i, detail: e.detail);
        }
        if (input.onePerImage) {
          await w.close(pool);
          outputs.add(current!);
          current = null;
        }
      }
      if (one != null) {
        await context.checkCancelled();
        await one.close(pool);
        outputs.add(current!);
        current = null;
      }
    } catch (_) {
      // Cancelled or failed: no partial results are left behind; the batch
      // files are in the job's temp folder, which the queue deletes.
      for (final path in [...outputs, ?current]) {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      }
      rethrow;
    }
    return outputs.length == 1 ? OneFile(outputs.single) : ManyFiles(outputs);
  }
}
