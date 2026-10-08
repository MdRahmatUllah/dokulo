import 'tool_job.dart';
import 'tools/compress_job.dart';

/// The tools that run as a ToolJob: one engine task each in the plan
/// ("Merge PDF: implement the merge ToolJob"). Organize, Mark up, Sign, Fill form
/// and the AI tools open screens instead.
const toolJobIds = [
  'merge', 'split', 'extract', 'rotate', 'smartsplit', 'img2pdf', 'pdf2img', //
  'web', 'pdfa', 'text', 'compress', 'repair', 'ocr', 'pagenum', 'watermark',
  'crop', 'protect', 'unlock', 'extractassets',
];

/// Every ToolJob the app has. A tool's engine task adds its job here.
const List<ToolJob<Object?>> allToolJobs = [CompressJob()];

/// ToolJobs by id.
class ToolRegistry {
  ToolRegistry(Iterable<ToolJob<Object?>> jobs)
    : _jobs = {for (final job in jobs) job.id: job} {
    if (_jobs.length != jobs.length) {
      throw ArgumentError('two ToolJobs share an id');
    }
  }

  /// The app's registry.
  factory ToolRegistry.app() => ToolRegistry(allToolJobs);

  final Map<String, ToolJob<Object?>> _jobs;

  Iterable<String> get ids => _jobs.keys;

  ToolJob<Object?> operator [](String id) =>
      _jobs[id] ?? (throw ArgumentError('no ToolJob "$id"'));
}
