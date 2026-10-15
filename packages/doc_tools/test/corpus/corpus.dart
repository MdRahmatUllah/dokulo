import 'dart:io';
import 'dart:math';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:image/image.dart' as img;
import 'package:qpdf_ffi/qpdf_ffi.dart';

/// The golden PDF corpus (DK-0658): the sample documents (DK-0023) and the
/// corpus's base files (`test/fixtures/corpus/`, from tools/make_fixtures.py),
/// turned into variants with qpdf at test time, so the repo holds only the
/// bases. Everything in it is fictional.
///
/// [CorpusMode.quick] (the gate): every base as it is, and each variant once,
/// on one base in turn. [CorpusMode.full] (a release, `DK_CORPUS=full`):
/// every variant of every base.
enum CorpusMode { quick, full }

class CorpusFile {
  const CorpusFile(
    this.name,
    this.path, {
    this.password,
    this.mayFail = const {},
  });

  /// "`base · variant`", for the test names and the report.
  final String name;
  final String path;

  /// The password that opens it; the tools are given it.
  final String? password;

  /// The catalogue's errors a tool may end in on this file instead of a
  /// result (DocErrorKind names): "damaged" for a file broken on purpose that
  /// a tool can't repair on the way, "tooLarge" for a page too big for a
  /// 3 GB phone. Any other error, "unexpected" above all, fails the suite.
  final Set<String> mayFail;

  @override
  String toString() => name;
}

/// The repo's test/fixtures, from a package folder.
final fixtures = Directory('${Directory.current.path}/../../test/fixtures');

/// The bases: (file, password, the errors a tool may end in). The 300-page manual is a base only
/// as it is (its variants would cost minutes and find nothing new).
List<(String, String?, Set<String>)> get _bases => [
  for (final f in fixtures.listSync().whereType<File>())
    if (f.path.endsWith('.pdf'))
      (
        f.path,
        f.path.endsWith('encrypted-aes256.pdf') ? 'dokulo' : null,
        f.path.endsWith('damaged-xref.pdf') ? const {'damaged'} : const {},
      ),
  for (final f in Directory('${fixtures.path}/corpus').listSync())
    if (f.path.endsWith('.pdf'))
      (
        f.path,
        null,
        f.path.endsWith('extreme-pages.pdf') ? const {'tooLarge'} : const {},
      ),
]..sort((a, b) => a.$1.compareTo(b.$1));

String _base(String path) =>
    path.split(RegExp(r'[/\\]')).last.replaceAll('.pdf', '');

/// The passwords the variants use (test values, not secrets).
const variantPassword = 'corpus';
const _owner = 'corpus-owner';

/// One qpdf rewrite: its name and the job JSON's options.
typedef _Variant = (String, Map<String, Object?>);

const List<_Variant> _variants = [
  ('linearized', {'linearize': ''}),
  ('object streams', {'objectStreams': 'generate'}),
  (
    'uncompressed',
    {'qdf': '', 'objectStreams': 'disable', 'compressStreams': 'n'},
  ),
  ('rotated +90', {'rotate': '+90'}),
  (
    'AES-128, password to open',
    {
      'encrypt': {
        'userPassword': variantPassword,
        'ownerPassword': _owner,
        '128bit': {'useAes': 'y'},
      },
    },
  ),
  (
    'AES-256, owner password only',
    {
      'encrypt': {
        'userPassword': '',
        'ownerPassword': _owner,
        '256bit': {'modify': 'none', 'extract': 'n'},
      },
    },
  ),
  (
    'RC4-40 (legacy)',
    {
      'allowWeakCrypto': '',
      'encrypt': {'userPassword': '', 'ownerPassword': _owner, '40bit': {}},
    },
  ),
];

List<String> _qpdf((Map<String, Object?>, String?) job, JobContext context) =>
    QpdfService.run(() => Qpdf.run({...job.$1, 'password': ?job.$2}));

/// The first of [candidates] that opens [path] (null: no password needed).
String? _opener((String, List<String?>) a, JobContext context) =>
    QpdfService.run(() {
      for (final password in a.$2) {
        try {
          Qpdf.inspect(a.$1, password: password);
          return password;
        } on QpdfException {
          continue;
        }
      }
      throw StateError('no password opens ${a.$1}');
    });

/// Builds the corpus in [dir]: the bases' variants written there, the bases
/// themselves read in place. [pool] runs qpdf on its lane.
Future<List<CorpusFile>> buildCorpus(
  Directory dir,
  IsolatePool pool, {
  CorpusMode mode = CorpusMode.quick,
}) async {
  final bases = _bases;
  final out = <CorpusFile>[
    for (final (path, password, mayFail) in bases)
      CorpusFile(
        '${_base(path)} · as is',
        path,
        password: password,
        mayFail: mayFail,
      ),
  ];
  // Variants of the bases that read cleanly as they are.
  final plain = [
    for (final b in bases)
      if (!b.$3.contains('damaged') && !b.$1.endsWith('long-300-pages.pdf')) b,
  ];
  var n = 0;
  for (final (vi, (variant, options)) in _variants.indexed) {
    final targets = mode == CorpusMode.full
        ? plain
        : [plain[(vi * 3) % plain.length]];
    for (final (path, password, mayFail) in targets) {
      final file = '${dir.path}/v${n++}.pdf';
      await pool.run(Lane.qpdf, _qpdf, (
        {'inputFile': path, 'outputFile': file, ...options},
        password,
      )).result;
      // qpdf keeps an encrypted base's cipher unless the variant sets a
      // new one (or QDF mode drops it): ask the file which password it takes.
      final opens = await pool.run(Lane.qpdf, _opener, (
        file,
        [null, variantPassword, password],
      )).result;
      out.add(
        CorpusFile(
          '${_base(path)} · $variant',
          file,
          password: opens,
          mayFail: mayFail,
        ),
      );
    }
  }
  // Truncated: the last tenth cut off, the trailer and xref with it.
  final truncate = mode == CorpusMode.full ? plain : [plain[1], plain[5]];
  for (final (path, password, mayFail) in truncate) {
    final bytes = File(path).readAsBytesSync();
    final file = File('${dir.path}/v${n++}.pdf')
      ..writeAsBytesSync(bytes.sublist(0, bytes.length * 9 ~/ 10));
    out.add(
      CorpusFile(
        '${_base(path)} · truncated',
        file.path,
        password: password,
        mayFail: {...mayFail, 'damaged'},
      ),
    );
  }
  // Every base's first page in one file: mixed fonts, sizes and rotations.
  final merged = '${dir.path}/merged.pdf';
  await pool.run(Lane.qpdf, _qpdf, (
    {
      'inputFile': plain.first.$1,
      'outputFile': merged,
      'pages': [
        for (final (path, password, _) in plain)
          {'file': path, 'password': ?password, 'range': '1'},
      ],
    },
    null,
  )).result;
  out.add(
    CorpusFile(
      'every base, page 1 · merged',
      merged,
      mayFail: const {'tooLarge'},
    ),
  );
  // PDF/A-2b, written by the app's own writer (DK-0395).
  // A page too big to render (the 5 m one) isn't written: the PDF/A tool's
  // preflight stops it first, as "tooLarge" (DK-0020).
  final pdfa = [
    for (final b in plain)
      if (!b.$3.contains('tooLarge') &&
          (mode == CorpusMode.full ||
              b.$1.endsWith('non-latin.pdf') ||
              b.$1.endsWith('Invoice INV-2026-014.pdf')))
        b,
  ];
  for (final (path, password, mayFail) in pdfa) {
    final work = Directory('${dir.path}/pdfa${n++}')..createSync();
    final prepared = await PdfaWriter.prepare(path, work, password: password);
    final file = '${work.path}/out.pdf';
    await pool.run(Lane.qpdf, _pdfa, (
      prepared.path,
      file,
      work.path,
      prepared.path == path ? password : null,
    )).result;
    out.add(CorpusFile('${_base(path)} · PDF/A-2b', file, mayFail: mayFail));
  }
  return out;
}

List<String> _pdfa((String, String, String, String?) a, JobContext context) =>
    PdfaWriter.finish(a.$1, a.$2, Directory(a.$3), password: a.$4);

/// Images for Image to PDF: a photo-like JPEG, a PNG with alpha, a
/// greyscale PNG, a portrait JPEG, a 1 × 1 pixel, a long receipt and (full
/// mode) a 24-megapixel photo.
List<String> buildImages(Directory dir, {CorpusMode mode = CorpusMode.quick}) {
  final rng = Random(658);
  String save(String name, img.Image image) {
    final path = '${dir.path}/$name';
    File(path).writeAsBytesSync(
      name.endsWith('.png') ? img.encodePng(image) : img.encodeJpg(image),
    );
    return path;
  }

  img.Image noisy(int w, int h, {int channels = 3}) {
    final image = img.Image(width: w, height: h, numChannels: channels);
    for (final p in image) {
      p
        ..r = (p.x * 255 ~/ w + rng.nextInt(20)).clamp(0, 255)
        ..g = (p.y * 255 ~/ h + rng.nextInt(20)).clamp(0, 255)
        ..b = rng.nextInt(256);
      if (channels == 4) p.a = p.x < w ~/ 2 ? 255 : 90;
    }
    return image;
  }

  return [
    save('photo.jpg', noisy(1200, 800)),
    save('alpha.png', noisy(400, 400, channels: 4)),
    save('grey.png', img.grayscale(noisy(600, 600))),
    save('portrait.jpg', noisy(600, 1000)),
    save('pixel.png', img.Image(width: 1, height: 1)),
    save('receipt.jpg', noisy(300, 3000)),
    if (mode == CorpusMode.full) save('24mp.jpg', noisy(6000, 4000)),
  ];
}
