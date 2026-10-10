import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';

import '../l10n/formats.dart';
import 'tool_definition.dart';

/// Image to PDF's T2 (DK-0433; UI spec §21.7, the tools-convert-img2pdf
/// frame): Page size (Fit image · A4 · Letter), Margins (None · Small),
/// Output (One PDF · One per image), Clean up like a scan. The button:
/// "Create PDF · 12 images"; the estimate: "1 PDF · 12 pages · about
/// 4.1 MB". No name suffix (§27.3): the PDF is named after the first image.
final img2pdfDefinition = ToolDefinition(
  id: 'img2pdf',
  options: [
    ToolSegments<ImagePageSize>(
      key: 'size',
      title: (l) => l.img2pdf_page_size,
      values: ImagePageSize.values,
      label: (l, v) => switch (v) {
        ImagePageSize.fit => l.img2pdf_size_fit,
        ImagePageSize.a4 => 'A4', // l10n-ignore: the paper's name
        ImagePageSize.letter => l.img2pdf_size_letter,
      },
      initial: ImagePageSize.fit,
    ),
    ToolSegments<bool>(
      key: 'margins',
      title: (l) => l.img2pdf_margins,
      values: const [false, true],
      label: (l, v) => v ? l.img2pdf_margins_small : l.img2pdf_margins_none,
      initial: false,
    ),
    ToolSegments<bool>(
      key: 'onePerImage',
      title: (l) => l.img2pdf_output,
      values: const [false, true],
      label: (l, v) => v ? l.img2pdf_output_each : l.img2pdf_output_one,
      initial: false,
    ),
    ToolSwitch(
      key: 'cleanUp',
      title: (l) => l.img2pdf_clean_up,
      help: (l) => l.img2pdf_clean_up_help,
    ),
  ],
  action: (l, s) => l.img2pdf_action(s.files.length),
  estimate: (l, s, v) {
    if (s.files.isEmpty) return null;
    // JPEGs go in as they are, so the PDF is about the images' size.
    // ponytail: PNG and WebP are re-encoded; measure if this misleads.
    final bytes = s.files.fold(0, (n, f) => n + f.size);
    final pdfs = v['onePerImage'] == true ? s.files.length : 1;
    return l.img2pdf_estimate(
      pdfs,
      s.files.length,
      formatBytes(bytes, l.localeName),
    );
  },
  input: (s, v, env) => Img2PdfInput(
    files: [for (final f in s.files) f.path],
    outputDir: env.outputDir,
    suffix: '',
    size: v['size']! as ImagePageSize,
    margins: v['margins']! as bool,
    onePerImage: v['onePerImage']! as bool,
    cleanUp: v['cleanUp']! as bool,
    skipPages: env.skipPages.toList(),
  ),
  canSkipPages: true,
  next: const ['compress', 'ocr'],
);
