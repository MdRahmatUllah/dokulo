import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_vision/doc_vision.dart';
import 'package:image/image.dart' as img;

import '../tool_job.dart';
import 'output_name.dart';

/// Make text searchable's input (T2): the files, where the outputs go, the
/// recognition language.
class OcrInput {
  const OcrInput({
    required this.files,
    required this.outputDir,
    required this.suffix,
    this.language = OcrLanguage.auto,
    this.password,
  });

  factory OcrInput.fromJson(Map<String, Object?> json) => OcrInput(
    files: (json['files']! as List).cast<String>(),
    outputDir: json['outputDir']! as String,
    suffix: json['suffix']! as String,
    language: OcrLanguage.values.byName(json['language'] as String? ?? 'auto'),
    password: json['password'] as String?,
  );

  /// One PDF, or a batch.
  final List<String> files;

  /// A temp folder of the file store; the user saves the results from there.
  final String outputDir;

  /// The localised name suffix, "– searchable" / "– durchsuchbar" (the app's
  /// strings; this layer has none).
  final String suffix;
  final OcrLanguage language;
  final String? password;

  Map<String, Object?> toJson() => {
    'files': files,
    'outputDir': outputDir,
    'suffix': suffix,
    'language': language.name,
    // ponytail: plain text in the jobs table, as for compress (DK-0282).
    'password': ?password,
  };
}

/// The `ocr` tool, Make text searchable (DK-0474): each page without text is
/// rendered, read by the platform's OCR engine (Vision on iOS, PP-OCRv5
/// elsewhere, DK-0400), and its words laid over it as invisible text
/// ([OcrTextLayer], DK-0394), so the scan looks the same and becomes
/// searchable and selectable. One new file per input; the inputs are never
/// touched. Files search indexes the output once it's saved (DK-0270).
class OcrJob extends ToolJob<OcrInput> {
  const OcrJob();

  /// The engine; tests put a fake here (the job runs on the calling isolate).
  static Future<OcrEngine> Function() engine = OcrEngine.forPlatform;

  /// What OCR reads at: sharp enough for small print, fast enough per page.
  static const dpi = 300.0;

  @override
  String get id => 'ocr';

  /// Pages are rendered through pdfrx, so it runs on the calling isolate;
  /// qpdf's overlay goes to its own worker.
  @override
  Lane get lane => Lane.pdfium;

  @override
  Map<String, Object?> encode(OcrInput input) => input.toJson();

  @override
  OcrInput decode(Map<String, Object?> json) => OcrInput.fromJson(json);

  @override
  List<String> inputFiles(OcrInput input) => input.files;

  @override
  OcrInput chain(JobOutput previous, Map<String, Object?> options) =>
      OcrInput.fromJson({
        ...options,
        'files': switch (previous) {
          OneFile(:final path) => [path],
          ManyFiles(:final paths) => paths,
          TextOutput() => throw ArgumentError(
            'Make text searchable needs PDFs, not text',
          ),
        },
      });

  @override
  Future<JobOutput> run(OcrInput input, ToolJobContext context) async {
    if (input.files.isEmpty) {
      throw ArgumentError('Make text searchable needs a file');
    }
    final counts = [
      for (final file in input.files)
        (await PdfEngine.inspect(file, password: input.password)).pageCount,
    ];
    final total = counts.fold(0, (a, b) => a + b);
    final reader = await engine();
    final pool = IsolatePool(tempRoot: context.tempDir);
    final outputs = <String>[];
    String? current;
    var done = 0;
    try {
      for (final (i, file) in input.files.indexed) {
        final words = <int, List<LayerWord>>{};
        for (var page = 0; page < counts[i]; page++) {
          await context.checkCancelled();
          // A page that has text already (born digital, or OCR'd before)
          // keeps it and gets no second layer.
          final existing = await PdfEngine.pageText(
            file,
            page,
            password: input.password,
          );
          if (existing.text.trim().isEmpty) {
            final picture = await _png(
              file,
              page,
              input.password,
              context.tempDir,
            );
            final ocr = await reader.recognize(
              picture,
              language: input.language,
            );
            words[page] = [for (final w in ocr.words) LayerWord(w.text, w.box)];
            await File(picture).delete();
          }
          context.report(
            JobProgress('recognising', pageIndex: done++, pageCount: total),
          );
        }
        final output = current = outputName(
          input.outputDir,
          file,
          input.suffix,
          outputs,
        );
        final overlay = await OcrTextLayer.writeOverlay(
          file,
          words,
          '${context.tempDir.path}/overlay_$i.pdf',
          password: input.password,
        );
        await pool.run(Lane.qpdf, _apply, (file, overlay, output)).result;
        outputs.add(output);
      }
    } catch (e) {
      // Cancelled or failed: no partial results are left behind.
      for (final path in [...outputs, ?current]) {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      }
      rethrow;
    }
    return outputs.length == 1 ? OneFile(outputs.single) : ManyFiles(outputs);
  }

  /// Page [page] at [dpi] as a PNG in [dir], for the OCR engine.
  static Future<String> _png(
    String file,
    int page,
    String? password,
    Directory dir,
  ) async {
    final shot = await PdfEngine.render(
      file,
      page,
      dpi: dpi,
      password: password,
    );
    final path = '${dir.path}/ocr_page_$page.png';
    await File(path).writeAsBytes(
      img.encodePng(
        img.Image.fromBytes(
          width: shot.width,
          height: shot.height,
          bytes: shot.bgra.buffer,
          numChannels: 4,
          order: img.ChannelOrder.bgra,
        ),
      ),
    );
    return path;
  }
}

/// On a qpdf worker: the words laid over the pages.
void _apply((String, String, String) job, JobContext context) =>
    OcrTextLayer.apply(job.$1, job.$2, job.$3);
