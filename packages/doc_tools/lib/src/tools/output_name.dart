import 'dart:io';

/// A tool's output path: `<name><suffix>.pdf` in [outputDir], with " (2)"
/// and up when the name is taken in this batch ([taken]) or on disk. The
/// suffix is the app's localised one ("– compressed" / "– verkleinert").
String outputName(
  String outputDir,
  String input,
  String suffix,
  List<String> taken,
) {
  final base = input
      .split(RegExp(r'[\\/]'))
      .last
      .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  for (var n = 1; ; n++) {
    final name = '$outputDir/$base$suffix${n == 1 ? '' : ' ($n)'}.pdf';
    if (!taken.contains(name) && !File(name).existsSync()) return name;
  }
}
