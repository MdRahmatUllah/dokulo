import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:web_to_pdf/web_to_pdf.dart';

import '../tool_job.dart';
import 'output_name.dart';

/// Web page to PDF's input (T2, UI spec §21.9): the address the user typed,
/// or an HTML file.
class WebInput {
  const WebInput({
    required this.outputDir,
    this.address,
    this.htmlFile,
    this.pageSize = PageSize.a4,
    this.backgrounds = true,
    this.margins = true,
  }) : assert((address == null) != (htmlFile == null));

  factory WebInput.fromJson(Map<String, Object?> json) => WebInput(
    outputDir: json['outputDir']! as String,
    address: json['address'] as String?,
    htmlFile: json['htmlFile'] as String?,
    pageSize: PageSize.values.byName(json['pageSize'] as String? ?? 'a4'),
    backgrounds: json['backgrounds'] as bool? ?? true,
    margins: json['margins'] as bool? ?? true,
  );

  final String outputDir;

  /// As typed ("example.com/artikel"); [Network.webPage] makes it a URL.
  final String? address;
  final String? htmlFile;
  final PageSize pageSize;
  final bool backgrounds;

  /// Margins: Default (true) · None.
  final bool margins;

  Map<String, Object?> toJson() => {
    'outputDir': outputDir,
    'address': ?address,
    'htmlFile': ?htmlFile,
    'pageSize': pageSize.name,
    'backgrounds': backgrounds,
    'margins': margins,
  };
}

/// The `web` tool (DK-0444): the page printed into a PDF by the platform's
/// web view ([WebToPdf]: Android's PrintDocumentAdapter, iOS's
/// UIPrintPageRenderer), named after the site (`example.com.pdf`) or the
/// HTML file. The one tool that uses the internet: the page itself, nothing
/// else (docs/compliance/network-uses.md). Offline it fails as
/// `WebToPdfException(loadFailed)`, the error catalogue's "You're offline".
class WebJob extends ToolJob<WebInput> {
  const WebJob({this.printer = const WebToPdf()});

  /// Tests replace the platform channel.
  final WebToPdf printer;

  @override
  String get id => 'web';

  /// The web view lives on the platform's main thread; its channel is only
  /// reachable from the calling isolate, so this job runs there.
  @override
  Lane get lane => Lane.pdfium;

  @override
  Map<String, Object?> encode(WebInput input) => input.toJson();

  @override
  WebInput decode(Map<String, Object?> json) => WebInput.fromJson(json);

  @override
  List<String> inputFiles(WebInput input) => [?input.htmlFile];

  @override
  WebInput chain(JobOutput previous, Map<String, Object?> options) =>
      throw ArgumentError('Web page to PDF starts a chain; it takes no files');

  @override
  Future<JobOutput> run(WebInput input, ToolJobContext context) async {
    context.report(const JobProgress('loading'));
    final html = input.htmlFile;
    final url = html == null ? Network.webPage(input.address!) : null;
    final name = html != null
        ? html.split(RegExp(r'[\\/]')).last.replaceAll(RegExp(r'\.html?$'), '')
        : url!.host.replaceFirst(RegExp(r'^www\.'), '');
    final output = outputName(input.outputDir, name, '', []);
    try {
      if (html != null) {
        final file = File(html);
        await printer.fromHtml(
          file.readAsStringSync(),
          output,
          baseUrl: file.parent.uri,
          pageSize: input.pageSize,
          backgrounds: input.backgrounds,
          margins: input.margins,
        );
      } else {
        await printer.fromUrl(
          url!,
          output,
          pageSize: input.pageSize,
          backgrounds: input.backgrounds,
          margins: input.margins,
        );
      }
      await context.checkCancelled();
    } catch (_) {
      final f = File(output);
      if (f.existsSync()) f.deleteSync();
      rethrow;
    }
    return OneFile(output);
  }
}
