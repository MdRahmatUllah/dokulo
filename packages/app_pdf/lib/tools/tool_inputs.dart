import '../components/dk_file_card.dart';

/// What a tool takes (UI spec §21, each tool's "Input"): the kinds of file,
/// and how many. T2's picker lists only these; X1 offers a tool only when
/// the files fit.
class ToolInput {
  const ToolInput(this.kinds, {this.min = 1, this.max = 1});

  final Set<DkFileKind> kinds;
  final int min, max;

  bool get many => max > 1;
  bool get images => kinds.contains(DkFileKind.image);

  /// Whether [name] is a kind this tool takes.
  bool takes(String name) => kinds.contains(kindOf(name));

  static const _pdf = {DkFileKind.pdf};
  static const _batch = 500;

  /// The input of [toolId]; null for a tool without file input (Scan,
  /// Workflows, Web page to PDF from a URL).
  static ToolInput? of(String toolId) => switch (toolId) {
    'merge' => const ToolInput(
      {DkFileKind.pdf, DkFileKind.image},
      min: 2,
      max: _batch,
    ),
    'img2pdf' => const ToolInput({DkFileKind.image}, max: _batch),
    'compress' ||
    'ocr' ||
    'pagenum' ||
    'watermark' ||
    'protect' ||
    'batch' => const ToolInput(_pdf, max: _batch),
    'compare' => const ToolInput(_pdf, min: 2, max: 2),
    'scan' || 'workflows' || 'web' => null,
    _ => const ToolInput(_pdf),
  };

  /// The kind of a file by its name.
  static DkFileKind? kindOf(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.pdf')) return DkFileKind.pdf;
    if (RegExp(r'\.(jpe?g|png|heic|heif|webp)$').hasMatch(n)) {
      return DkFileKind.image;
    }
    if (n.endsWith('.html') || n.endsWith('.htm')) return DkFileKind.html;
    return null;
  }
}
