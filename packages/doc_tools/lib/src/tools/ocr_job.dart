import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_vision/doc_vision.dart';
import 'package:flutter/services.dart'
    show BackgroundIsolateBinaryMessenger, RootIsolateToken;

import '../tool_job.dart';
import 'output_name.dart';

/// Make text searchable's input (T2): the files, where the outputs go, the
/// recognition language and the pages.
class OcrInput {
  const OcrInput({
    required this.files,
    required this.outputDir,
    required this.suffix,
    this.language = OcrLanguage.auto,
    this.pages,
    this.password,
  });

  factory OcrInput.fromJson(Map<String, Object?> json) => OcrInput(
    files: (json['files']! as List).cast<String>(),
    outputDir: json['outputDir']! as String,
    suffix: json['suffix']! as String,
    language: OcrLanguage.values.byName(json['language'] as String? ?? 'auto'),
    pages: (json['pages'] as List?)?.cast<int>(),
  );

  /// One PDF, or a batch.
  final List<String> files;

  /// A temp folder of the file store; the user saves the results from there.
  final String outputDir;

  /// The localised name suffix, "– searchable" / "– durchsuchbar" (the app's
  /// strings; this layer has none).
  final String suffix;
  final OcrLanguage language;

  /// "Pages: Choose…": 0-based pages to read (in every file); null is all.
  final List<int>? pages;

  /// For a locked file the user unlocked in T2. Never stored in the jobs
  /// table: a resumed job on a locked file fails as `locked`.
  final String? password;

  Map<String, Object?> toJson() => {
    'files': files,
    'outputDir': outputDir,
    'suffix': suffix,
    'language': language.name,
    'pages': ?pages,
  };
}

/// The `ocr` tool, Make text searchable (DK-0474): each page without text is
/// rendered, read by the platform's OCR engine (Vision on iOS, PP-OCRv5
/// elsewhere, DK-0400), and its words laid over it as invisible text
/// ([OcrTextLayer], DK-0394), so the scan looks the same and becomes
/// searchable and selectable. One new file per input; the inputs are never
/// touched. Files search indexes the output once it's saved (DK-0270).
///
/// The calling isolate only renders (PDFium through pdfrx) and writes the
/// pixels to the job's temp folder; one `Lane.onnx` job per file reads them,
/// with the engine made once and closed at the end, so OCR's Dart work never
/// runs on the UI isolate.
class OcrJob extends ToolJob<OcrInput> {
  const OcrJob();

  /// The engine's assets, loaded on the calling isolate (rootBundle only
  /// works there); tests return null.
  static Future<OcrAssets?> Function() assets = OcrEngine.loadAssets;

  /// Makes the engine on the OCR worker; tests put a fake here.
  static Future<OcrEngine> Function(OcrAssets? assets) engine = _platformEngine;

  /// What OCR reads at: sharp enough for small print.
  static const dpi = 300.0;

  @override
  String get id => 'ocr';

  @override
  Lane get lane => Lane.pdfium;

  @override
  Map<String, Object?> encode(OcrInput input) => input.toJson();

  @override
  OcrInput decode(Map<String, Object?> json) => OcrInput.fromJson(json);

  @override
  List<String> inputFiles(OcrInput input) => input.files;

  /// [options] are the step's saved options plus `outputDir` and `suffix`,
  /// which the workflow runner (DK-0536) adds per run.
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
    final selected = [
      for (final count in counts)
        [
          for (var p = 0; p < count; p++)
            if (input.pages?.contains(p) ?? true) p,
        ],
    ];
    final total = selected.fold(0, (sum, pages) => sum + pages.length);
    final _Setup setup = (
      assets: await assets(),
      token: RootIsolateToken.instance,
      engine: engine,
    );
    final pool = IsolatePool(tempRoot: context.tempDir);
    final outputs = <String>[];
    String? current;
    var done = 0;
    try {
      for (final (i, file) in input.files.indexed) {
        // On this isolate: the pages that have no text yet, rendered to raw
        // pixels on disk. A page with text (born digital, or OCR'd before)
        // keeps it and gets no second layer.
        final toRead = <_PageImage>[];
        for (final page in selected[i]) {
          await context.checkCancelled();
          if ((await PdfEngine.pageText(
            file,
            page,
            password: input.password,
          )).text.trim().isNotEmpty) {
            context.report(
              JobProgress('recognising', pageIndex: done++, pageCount: total),
            );
            continue;
          }
          final shot = await PdfEngine.render(
            file,
            page,
            dpi: dpi,
            password: input.password,
          );
          final path = '${context.tempDir.path}/ocr_${i}_$page.bgra';
          await File(path).writeAsBytes(shot.bgra);
          toRead.add((
            page: page,
            path: path,
            width: shot.width,
            height: shot.height,
          ));
        }

        // On an ONNX worker: every page read, progress per page.
        final read = pool.run(Lane.onnx, _readPages, (
          pages: toRead,
          language: input.language,
          scratch: context.tempDir.path,
          setup: setup,
        ));
        final before = done;
        final progress = read.progress.listen(
          (n) => context.report(
            JobProgress(
              'recognising',
              pageIndex: before + (n as int),
              pageCount: total,
            ),
          ),
        );
        final watch = Timer.periodic(const Duration(milliseconds: 200), (_) {
          if (context.isCancelled) read.cancel();
        });
        final Map<int, List<LayerWord>> words;
        try {
          words = await read.result;
        } finally {
          watch.cancel();
          await progress.cancel();
        }
        done = before + toRead.length;
        await context.checkCancelled();

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
        await pool.run(Lane.qpdf, _apply, (
          file,
          overlay,
          output,
          input.password,
        )).result;
        await context
            .checkCancelled(); // a cancel during the overlay counts too
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
}

typedef _PageImage = ({int page, String path, int width, int height});

typedef _Setup = ({
  OcrAssets? assets,
  RootIsolateToken? token,
  Future<OcrEngine> Function(OcrAssets?) engine,
});

Future<OcrEngine> _platformEngine(OcrAssets? assets) =>
    OcrEngine.forPlatform(assets: assets);

/// On an ONNX worker: the words of each rendered page, by page.
Future<Map<int, List<LayerWord>>> _readPages(
  ({List<_PageImage> pages, OcrLanguage language, String scratch, _Setup setup})
  job,
  JobContext context,
) async {
  if (job.setup.token case final token?) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(
      token,
    ); // platform channels (ONNX Runtime)
  }
  final engine = await job.setup.engine(job.setup.assets);
  try {
    final words = <int, List<LayerWord>>{};
    for (final (n, page) in job.pages.indexed) {
      final bgra = Uint8List.fromList(await File(page.path).readAsBytes());
      await File(page.path).delete();
      final ocr = await engine.recognizeRaster(
        Raster.fromBgra(page.width, page.height, bgra),
        language: job.language,
        scratch: Directory(job.scratch),
      );
      words[page.page] = [for (final w in ocr.words) LayerWord(w.text, w.box)];
      context.progress(n);
    }
    return words;
  } finally {
    // ponytail: a cancel kills this isolate, so the sessions of a cancelled
    // run stay open until the app restarts; a cooperative cancel if that
    // ever matters.
    await engine.close();
  }
}

/// On a qpdf worker: the words laid over the pages.
void _apply((String, String, String, String?) job, JobContext context) =>
    OcrTextLayer.apply(job.$1, job.$2, job.$3, password: job.$4);
