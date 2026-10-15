import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';

import '../tool_job.dart';
import 'output_name.dart';

/// Convert to PDF/A's input (T2, UI spec §21.10: no options, PDF/A-2b).
class PdfaInput {
  const PdfaInput({
    required this.files,
    required this.outputDir,
    required this.suffix,
    this.passwords = const {},
  });

  factory PdfaInput.fromJson(Map<String, Object?> json) => PdfaInput(
    files: (json['files']! as List).cast<String>(),
    outputDir: json['outputDir']! as String,
    suffix: json['suffix']! as String,
  );

  final List<String> files;
  final String outputDir;

  /// The localised suffix (" – PDF-A").
  final String suffix;
  final Map<String, String> passwords;

  Map<String, Object?> toJson() => {
    'files': files,
    'outputDir': outputDir,
    'suffix': suffix,
  };
}

/// The `pdfa` tool (DK-0450): PDF/A-2b through [PdfaWriter], one new file
/// per input: pages with fonts the file doesn't embed become pictures with
/// their text kept (PDFium, here), then qpdf writes the archive file on its
/// worker. The output is not encrypted (PDF/A forbids it).
///
/// ponytail: which pages became pictures ("2 pages were converted to
/// images…") isn't passed to T3 yet; JobOutput has no place for it.
class PdfaJob extends ToolJob<PdfaInput> {
  const PdfaJob();

  @override
  String get id => 'pdfa';

  @override
  Lane get lane => Lane.pdfium;

  @override
  double get renderDpi => PdfaWriter.rasterDpi;

  @override
  String? passwordOf(PdfaInput input) => input.passwords.values.firstOrNull;

  @override
  Map<String, Object?> encode(PdfaInput input) => input.toJson();

  @override
  PdfaInput decode(Map<String, Object?> json) => PdfaInput.fromJson(json);

  @override
  List<String> inputFiles(PdfaInput input) => input.files;

  @override
  PdfaInput chain(JobOutput previous, Map<String, Object?> options) =>
      PdfaInput.fromJson({
        ...options,
        'files': switch (previous) {
          OneFile(:final path) => [path],
          ManyFiles(:final paths) => paths,
          TextOutput() => throw ArgumentError('Convert to PDF/A needs PDFs'),
        },
      });

  @override
  Future<JobOutput> run(PdfaInput input, ToolJobContext context) async {
    if (input.files.isEmpty) throw ArgumentError('no files');
    final pool = IsolatePool(tempRoot: context.tempDir);
    final outputs = <String>[];
    String? current;
    try {
      for (final (i, file) in input.files.indexed) {
        await context.checkCancelled();
        context.report(
          JobProgress(
            'converting',
            pageIndex: i,
            pageCount: input.files.length,
          ),
        );
        final password = input.passwords[file];
        final work = Directory('${context.tempDir.path}/pdfa_$i')..createSync();
        final prepared = await PdfaWriter.prepare(
          file,
          work,
          password: password,
        );
        await context.checkCancelled();
        final output = current = outputName(
          input.outputDir,
          file,
          input.suffix,
          outputs,
        );
        await pool.run(Lane.qpdf, _finish, (
          prepared.path,
          output,
          work.path,
          // The prepared copy is decrypted already.
          prepared.path == file ? password : null,
        )).result;
        outputs.add(output);
      }
    } catch (e) {
      for (final path in [...outputs, ?current]) {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      }
      if (e is DocError && e.kind == DocErrorKind.cancelled) {
        throw const JobCancelled();
      }
      rethrow;
    }
    return outputs.length == 1 ? OneFile(outputs.single) : ManyFiles(outputs);
  }
}

void _finish((String, String, String, String?) job, JobContext context) =>
    PdfaWriter.finish(job.$1, job.$2, Directory(job.$3), password: job.$4);

/// PDF to text's input (T2, UI spec §21.11).
class TextInput {
  const TextInput({
    required this.file,
    required this.outputDir,
    this.markdown = true,
    this.pageMarker = '— {n} —',
    this.password,
  });

  factory TextInput.fromJson(Map<String, Object?> json) => TextInput(
    file: json['file']! as String,
    outputDir: json['outputDir']! as String,
    markdown: json['markdown'] as bool? ?? true,
    pageMarker: json['pageMarker'] as String?,
  );

  final String file;
  final String outputDir;

  /// Markdown (headings, lists, tables) or plain text.
  final bool markdown;

  /// The localised page marker, `{n}` the page number ("Seite {n}"); null:
  /// Page markers off.
  final String? pageMarker;
  final String? password;

  Map<String, Object?> toJson() => {
    'file': file,
    'outputDir': outputDir,
    'markdown': markdown,
    'pageMarker': pageMarker,
    // No password: see CompressInput.
  };
}

/// The `text` tool (DK-0456): the PDF's text in reading order
/// ([PdfStructure]: columns, headings, lists, simple tables; running headers
/// and footers dropped) as `<name>.md` or `<name>.txt`. A scan without a
/// text layer gives an empty file: T2 offers Make text searchable first.
class TextJob extends ToolJob<TextInput> {
  const TextJob();

  @override
  String get id => 'text';

  @override
  Lane get lane => Lane.pdfium;

  @override
  String? passwordOf(TextInput input) => input.password;

  @override
  Map<String, Object?> encode(TextInput input) => input.toJson();

  @override
  TextInput decode(Map<String, Object?> json) => TextInput.fromJson(json);

  @override
  List<String> inputFiles(TextInput input) => [input.file];

  @override
  TextInput chain(JobOutput previous, Map<String, Object?> options) =>
      TextInput.fromJson({
        ...options,
        'file': switch (previous) {
          OneFile(:final path) => path,
          _ => throw ArgumentError('PDF to text takes one PDF'),
        },
      });

  @override
  Future<JobOutput> run(TextInput input, ToolJobContext context) async {
    context.report(const JobProgress('reading'));
    final blocks = await PdfStructure.extract(
      input.file,
      password: input.password,
    );
    await context.checkCancelled();
    final base = input.file
        .split(RegExp(r'[\\/]'))
        .last
        .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final output = outputName(
      input.outputDir,
      base,
      '',
      [],
    ).replaceAll(RegExp(r'\.pdf$'), input.markdown ? '.md' : '.txt');
    File(output).writeAsStringSync(
      renderText(
        blocks,
        markdown: input.markdown,
        pageMarker: input.pageMarker,
      ),
    );
    return OneFile(output);
  }

  /// [blocks] as Markdown or plain text, a blank line between blocks and
  /// the page marker before each page.
  static String renderText(
    List<Block> blocks, {
    required bool markdown,
    String? pageMarker,
  }) {
    final out = <String>[];
    int? page;
    for (final b in blocks) {
      if (pageMarker != null && b.page != page) {
        out.add(pageMarker.replaceAll('{n}', '${b.page + 1}'));
      }
      page = b.page;
      out.add(switch (b.kind) {
        _ when !markdown => b.text,
        BlockKind.heading => '${'#' * b.level} ${b.text}',
        // A numbered item keeps its number; a bullet becomes Markdown's.
        BlockKind.listItem when RegExp(r'^\d+[.)]\s').hasMatch(b.text) =>
          b.text,
        BlockKind.listItem =>
          '- ${b.text.replaceFirst(RegExp(r'^[•·▪‣◦*\-–]\s*'), '')}',
        BlockKind.table when b.rows.isNotEmpty => [
          for (final (i, row) in b.rows.indexed) ...[
            '| ${row.map((c) => c.replaceAll('|', r'\|')).join(' | ')} |',
            if (i == 0) '|${' --- |' * row.length}',
          ],
        ].join('\n'),
        _ => b.text,
      });
    }
    return '${out.join('\n\n')}\n';
  }
}
