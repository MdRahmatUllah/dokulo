import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What Dokulo ships that isn't a Dart package (DK-0673): the native
/// libraries, the models, the colour profile and the fonts, from the
/// licence register's tables (docs/compliance/licence-register.md). The
/// Dart packages come from Flutter's [LicenseRegistry] (their LICENSE files,
/// as pub resolved them); [licences] puts both together for M3's
/// Open-source licences page (DK-0577).
class ThirdParty {
  const ThirdParty(this.name, this.licence, {this.notice = '', this.asset});

  /// As the register's first column names it.
  final String name;

  /// SPDX-style: "Apache-2.0", "BSD-3-Clause", "OFL-1.1", …
  final String licence;

  /// What the licence asks us to say (a credit, a NOTICE's contents).
  final String notice;

  /// The full licence text, bundled with the app, when one ships with it.
  final String? asset;
}

/// The register's native, model, colour-profile and font rows that ship
/// (bundled or downloaded). A row added to those tables gets an entry here
/// (third_party_test checks the names).
const thirdParty = <ThirdParty>[
  // Native libraries.
  ThirdParty(
    'PDFium',
    'BSD-3-Clause AND Apache-2.0',
    notice: 'Copyright 2014 The PDFium Authors.',
  ),
  ThirdParty(
    'qpdf',
    'Apache-2.0',
    notice:
        'qpdf, copyright Jay Berkenbilt and the qpdf contributors. Built '
        'with its native crypto only.',
  ),
  ThirdParty(
    'zlib',
    'Zlib',
    notice: 'Copyright Jean-loup Gailly and Mark Adler.',
  ),
  ThirdParty(
    'libjpeg-turbo',
    'BSD-3-Clause AND IJG',
    notice:
        'This software is based in part on the work of the Independent '
        'JPEG Group. Copyright the libjpeg-turbo Project.',
  ),
  ThirdParty(
    'OpenCV',
    'Apache-2.0',
    notice: 'Modules core, imgproc and imgcodecs only.',
  ),
  ThirdParty('libpng', 'libpng-2.0'),
  ThirdParty('libwebp', 'BSD-3-Clause'),
  ThirdParty('libtiff', 'libtiff'),
  ThirdParty('OpenJPEG', 'BSD-2-Clause'),
  ThirdParty('Carotene, KleidiCV', 'BSD-3-Clause AND Apache-2.0'),
  ThirdParty('ONNX Runtime', 'MIT', notice: 'Copyright Microsoft Corporation.'),
  ThirdParty('llama.cpp / ggml', 'MIT', notice: 'Copyright the ggml authors.'),
  ThirdParty(
    'Bergamot translator',
    'MPL-2.0',
    notice: 'Its source files are used unmodified.',
  ),
  ThirdParty('SQLite', 'blessing', notice: 'Public domain.'),
  // Models.
  ThirdParty(
    'PP-OCRv5 (detection, Latin and multilingual recognition, angle)',
    'Apache-2.0',
    notice:
        'PaddleOCR, copyright PaddlePaddle Authors. The models were '
        'converted to ONNX, not modified.',
  ),
  ThirdParty(
    'Gemma 4 E2B',
    'Apache-2.0',
    notice:
        'Gemma is provided under and subject to the Gemma Prohibited Use '
        'Policy.',
  ),
  ThirdParty('Bergamot models', 'MPL-2.0'),
  ThirdParty('Hy-MT2', 'Apache-2.0', notice: 'Copyright Tencent.'),
  // Colour profiles.
  ThirdParty(
    'ICC sRGB2014.icc',
    'ICC profile licence',
    notice:
        'Copyright International Color Consortium. Embedded unaltered in '
        'every PDF/A Dokulo writes.',
  ),
  // Fonts.
  ThirdParty(
    'Material Symbols Rounded',
    'Apache-2.0',
    notice: 'Copyright Google LLC.',
  ),
  ThirdParty('Caveat', 'OFL-1.1', asset: 'assets/fonts/Caveat-OFL.txt'),
  ThirdParty(
    'Dancing Script',
    'OFL-1.1',
    asset: 'assets/fonts/DancingScript-OFL.txt',
  ),
  ThirdParty(
    'Homemade Apple',
    'Apache-2.0',
    asset: 'assets/fonts/HomemadeApple-LICENSE.txt',
  ),
];

/// One entry of the licences page: a component and its licence texts.
typedef LicenceItem = ({String name, String licence, List<String> texts});

/// Every licence, sorted by name: the Dart packages (Flutter's registry,
/// one item per package with all its texts) and [thirdParty] with its
/// notice and bundled text.
Future<List<LicenceItem>> licences({AssetBundle? bundle}) async {
  final packages = <String, List<String>>{};
  await for (final entry in LicenseRegistry.licenses) {
    final text = [for (final p in entry.paragraphs) p.text].join('\n\n');
    for (final p in entry.packages) {
      packages.putIfAbsent(p, () => []).add(text);
    }
  }
  final assets = bundle ?? rootBundle;
  return [
    for (final MapEntry(key: name, value: texts) in packages.entries)
      (name: name, licence: '', texts: texts),
    for (final t in thirdParty)
      (
        name: t.name,
        licence: t.licence,
        texts: [
          if (t.notice.isNotEmpty) t.notice,
          if (t.asset case final a?) await assets.loadString(a),
        ],
      ),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}
