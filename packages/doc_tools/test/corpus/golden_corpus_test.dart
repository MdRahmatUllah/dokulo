@Timeout(Duration(minutes: 20))
library;

import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:doc_vision/doc_vision.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:qpdf_ffi/qpdf_ffi.dart';
import 'package:test/test.dart';

import 'corpus.dart';

/// The golden PDF corpus suite (DK-0658): every ToolJob over the corpus.
/// Each output must open in PDFium and pass qpdf --check, the input must be
/// left as it was, and a tool may only fail with an error the file allows
/// ([CorpusFile.mayFail]). The gate runs the quick corpus; a release runs
///
///     DK_CORPUS=full DK_CORPUS_REPORT=<file.md> flutter test test/corpus
///
/// and records the report in docs/qa/regression-checklist.md's log.
///
/// A tool's engine task adds its input below when it registers its job: the
/// first test fails until it does.
final corpusInputs = <String, Object Function(CorpusFile file, String out)>{
  'compress': (f, out) => CompressInput(
    files: [f.path],
    outputDir: out,
    suffix: ' – compressed',
    password: f.password,
  ),
  'ocr': (f, out) => OcrInput(
    files: [f.path],
    outputDir: out,
    suffix: ' – searchable',
    password: f.password,
    // The first and last page: every page is the same work, and the
    // 300-page manual would take minutes.
    pages: f.name.startsWith('long-300-pages') ? const [0, 299] : null,
  ),
  'img2pdf': (f, out) =>
      Img2PdfInput(files: [f.path], outputDir: out, suffix: ''),
  'merge': (f, out) => MergeInput(
    files: [f.path, f.path],
    outputDir: out,
    suffix: ' – merged',
    ranges: {0: '1'},
    passwords: {f.path: ?f.password},
  ),
  'split': (f, out) => SplitInput(
    file: f.path,
    outputDir: out,
    suffix: ' – split',
    mode: SplitMode.everyN,
    every: 50,
    password: f.password,
  ),
  'extract': (f, out) => ExtractInput(
    file: f.path,
    pages: const [0],
    outputDir: out,
    suffix: ' – extract',
    password: f.password,
  ),
  'rotate': (f, out) => RotateInput(
    file: f.path,
    turns: const {0: 1},
    outputDir: out,
    suffix: ' – rotated',
    password: f.password,
  ),
  'crop': (f, out) => CropInput(
    file: f.path,
    outputDir: out,
    suffix: ' – cropped',
    insets: const {0: (left: 0.1, top: 0.1, right: 0.1, bottom: 0.1)},
    password: f.password,
  ),
  'repair': (f, out) => RepairInput(
    file: f.path,
    outputDir: out,
    suffix: ' – repaired',
    password: f.password,
  ),
  'protect': (f, out) => ProtectInput(
    files: [f.path],
    outputDir: out,
    suffix: ' – protected',
    password: _protected,
    passwords: {f.path: ?f.password},
  ),
  'unlock': (f, out) => UnlockInput(
    file: f.path,
    outputDir: out,
    suffix: ' – unlocked',
    password: f.password ?? '',
  ),
  'pagenum': (f, out) => PageNumbersInput(
    files: [f.path],
    outputDir: out,
    suffix: ' – numbered',
    format: '{n} / {total}',
    passwords: {f.path: ?f.password},
  ),
  'watermark': (f, out) => WatermarkInput(
    files: [f.path],
    outputDir: out,
    suffix: ' – watermarked',
    text: 'KOPIE',
    passwords: {f.path: ?f.password},
  ),
  'pdf2img': (f, out) => Pdf2ImgInput(
    file: f.path,
    outputDir: out,
    suffix: ' – page',
    dpi: 72,
    pages: const [0],
    password: f.password,
  ),
  'extractassets': (f, out) => ExtractAssetsInput(
    file: f.path,
    outputDir: out,
    suffix: ' – image',
    text: true,
    password: f.password,
  ),
  'pdfa': (f, out) => PdfaInput(
    files: [f.path],
    outputDir: out,
    suffix: ' – PDF-A',
    passwords: {f.path: ?f.password},
  ),
  'text': (f, out) =>
      TextInput(file: f.path, outputDir: out, password: f.password),
};

/// Add password's new password: its output opens with this one.
const _protected = 'korpus-2026';

/// What a tool may end in beyond each file's mayFail: Remove password on a
/// file that has none says so ("This file has no password.").
const _alsoAllowed = {
  'unlock': {'NotEncrypted'},
};

/// Tools whose inputs are images, not PDFs.
const _imageTools = {'img2pdf'};

/// Reads every page as one word, whatever its size: the corpus checks the
/// file handling; DK-0661 checks recognition.
class _OneWord implements OcrEngine {
  const _OneWord();

  static const _page = PageOcr('corpus', [
    (
      text: 'Korpus',
      box: (left: 0.1, top: 0.1, width: 0.3, height: 0.03),
      confidence: 0.9,
    ),
  ], PageQuality.ok);

  @override
  String get name => 'corpus';

  @override
  Future<PageOcr> recognize(
    String imagePath, {
    OcrLanguage language = OcrLanguage.auto,
  }) async => _page;

  @override
  Future<PageOcr> recognizeRaster(
    Raster raster, {
    OcrLanguage language = OcrLanguage.auto,
    required Directory scratch,
  }) async => _page;

  @override
  Future<void> close() async {}
}

Future<OcrEngine> _oneWord(OcrAssets? assets) async => const _OneWord();

List<String> _check((String, String?) a, JobContext context) =>
    QpdfService.run(() => Qpdf.check(a.$1, password: a.$2));

void main() {
  final mode = Platform.environment['DK_CORPUS'] == 'full'
      ? CorpusMode.full
      : CorpusMode.quick;
  final report = Platform.environment['DK_CORPUS_REPORT'];
  late Directory dir;
  late IsolatePool pool;
  late DokuloDatabase db;
  late JobQueue queue;
  late List<CorpusFile> corpus, images;

  setUpAll(() async {
    pdfrxInitialize();
    dir = Directory.systemTemp.createTempSync('dk_corpus_');
    pool = IsolatePool(tempRoot: Directory('${dir.path}/jobs')..createSync());
    db = DokuloDatabase.memory();
    // The low-end target: 3 GB of RAM, half of it free (DK-0668).
    queue = JobQueue(
      pool,
      db,
      ToolRegistry.app(),
      preflight: Preflight(
        () async => const DeviceCapabilities(
          totalRam: 3 << 30,
          availableRam: 3 << 29,
          freeStorage: 8 << 30,
        ),
      ),
    );
    OcrJob.assets = () async => null;
    OcrJob.engine = _oneWord;
    corpus = await buildCorpus(
      Directory('${dir.path}/corpus')..createSync(),
      pool,
      mode: mode,
    );
    images = [
      for (final path in buildImages(
        Directory('${dir.path}/images')..createSync(),
        mode: mode,
      ))
        CorpusFile(path.split('/').last, path),
    ];
    if (report != null) {
      File(report).writeAsStringSync(
        '| Tool | Files | Results | Allowed errors |\n| --- | --- | --- | --- |\n',
      );
    }
  });
  tearDownAll(() async {
    await db.close();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // A file PDFium still holds on Windows: the OS cleans temp.
    }
  });

  test('every ToolJob has its corpus input', () {
    expect(corpusInputs.keys.toSet(), ToolRegistry.app().ids.toSet());
  });

  test('the corpus: the bases, their variants, PDF/A, images', () {
    final names = corpus.map((f) => f.name).join('\n');
    for (final kind in [
      'as is',
      'linearized',
      'object streams',
      'uncompressed',
      'rotated +90',
      'AES-128',
      'owner password only',
      'RC4-40',
      'truncated',
      'merged',
      'PDF/A-2b',
    ]) {
      expect(names, contains(kind));
    }
    expect(
      corpus.length,
      mode == CorpusMode.full ? greaterThan(100) : greaterThan(25),
    );
    expect(images, isNotEmpty);
  });

  for (final id in corpusInputs.keys) {
    test('$id over the corpus', () async {
      final files = _imageTools.contains(id) ? images : corpus;
      final problems = <String>[];
      var ok = 0;
      final allowed = <String, int>{};
      for (final (i, f) in files.indexed) {
        final out = Directory('${dir.path}/out/$id/$i')
          ..createSync(recursive: true);
        final before = File(f.path).readAsBytesSync();
        try {
          final run = await queue.start(id, corpusInputs[id]!(f, out.path));
          final output = await run.result;
          final paths = switch (output) {
            OneFile(:final path) => [path],
            ManyFiles(:final paths) => paths,
            TextOutput() => const <String>[],
          };
          for (final path in paths) {
            if (!path.toLowerCase().endsWith('.pdf')) continue;
            // A locked input's output keeps its encryption (and password).
            final password = id == 'protect' ? _protected : f.password;
            final pages = (await PdfEngine.inspect(
              path,
              password: password,
            )).pageCount;
            final warnings = await pool.run(Lane.qpdf, _check, (
              path,
              password,
            )).result;
            if (pages == 0 || warnings.isNotEmpty) {
              problems.add('$f: $pages pages, qpdf: ${warnings.join('; ')}');
            }
          }
          ok++;
        } on Object catch (e) {
          // The preflight throws a DocError before the job starts; a job
          // ends in JobFailed with the DocError in its message.
          final kind = switch (e) {
            DocError(:final kind) => kind.name,
            JobFailed(:final message) =>
              RegExp(r'DocError\((\w+)').firstMatch(message)?[1] ??
                  RegExp(r'^(\w+):').firstMatch(message)?[1],
            _ => null,
          };
          if (kind != null &&
              (f.mayFail.contains(kind) ||
                  (_alsoAllowed[id]?.contains(kind) ?? false))) {
            allowed.update(kind, (n) => n + 1, ifAbsent: () => 1);
          } else {
            problems.add('$f: ${e.runtimeType}: $e');
          }
        }
        if (!_same(File(f.path).readAsBytesSync(), before)) {
          problems.add('$f: the input changed');
        }
        out.deleteSync(recursive: true);
      }
      if (report != null) {
        File(report).writeAsStringSync(
          '| $id | ${files.length} | $ok ok, ${problems.length} failed | '
          '${allowed.entries.map((e) => '${e.key} × ${e.value}').join(', ')} |\n',
          mode: FileMode.append,
        );
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
