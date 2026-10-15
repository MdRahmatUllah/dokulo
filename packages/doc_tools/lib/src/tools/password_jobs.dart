import 'dart:io';
import 'dart:math';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';

import '../tool_job.dart';
import 'output_name.dart';

/// Add password's input (T2, UI spec §21.21). [password] is never stored:
/// a protect job resumed after the app was killed fails, and T2 asks again.
class ProtectInput {
  const ProtectInput({
    required this.files,
    required this.outputDir,
    required this.suffix,
    this.password = '',
    this.printing = true,
    this.copying = true,
    this.editing = false,
    this.passwords = const {},
  });

  factory ProtectInput.fromJson(Map<String, Object?> json) => ProtectInput(
    files: (json['files']! as List).cast<String>(),
    outputDir: json['outputDir']! as String,
    suffix: json['suffix']! as String,
    printing: json['printing'] as bool? ?? true,
    copying: json['copying'] as bool? ?? true,
    editing: json['editing'] as bool? ?? false,
  );

  /// One or more PDFs (a batch): each gets the same password.
  final List<String> files;
  final String outputDir;

  /// The localised suffix (" – protected").
  final String suffix;

  /// The new password, to open the file.
  final String password;
  final bool printing, copying, editing;

  /// The current passwords of files that are locked already, by path.
  final Map<String, String> passwords;

  Map<String, Object?> toJson() => {
    'files': files,
    'outputDir': outputDir,
    'suffix': suffix,
    'printing': printing,
    'copying': copying,
    'editing': editing,
  };
}

/// The `protect` tool (DK-0498): AES-256 (R6) with the user's password and
/// the chosen permissions, one new file per input (`<name><suffix>.pdf`).
/// The inputs are never touched.
class ProtectJob extends ToolJob<ProtectInput> {
  const ProtectJob();

  @override
  String get id => 'protect';

  /// All qpdf: the job runs on qpdf's worker.
  @override
  Lane get lane => Lane.qpdf;

  @override
  String? passwordOf(ProtectInput input) => input.passwords.values.firstOrNull;

  @override
  Map<String, Object?> encode(ProtectInput input) => input.toJson();

  @override
  ProtectInput decode(Map<String, Object?> json) => ProtectInput.fromJson(json);

  @override
  List<String> inputFiles(ProtectInput input) => input.files;

  @override
  ProtectInput chain(JobOutput previous, Map<String, Object?> options) =>
      ProtectInput.fromJson({
        ...options,
        'files': switch (previous) {
          OneFile(:final path) => [path],
          ManyFiles(:final paths) => paths,
          TextOutput() => throw ArgumentError('Add password needs PDFs'),
        },
      });

  @override
  Future<JobOutput> run(ProtectInput input, ToolJobContext context) async {
    if (input.password.isEmpty) {
      throw ArgumentError('no password (it is never stored)');
    }
    // Enforces the permissions; nobody needs to know it.
    final random = Random.secure();
    final owner = String.fromCharCodes([
      for (var i = 0; i < 32; i++) 33 + random.nextInt(94),
    ]);
    final outputs = <String>[];
    String? current;
    try {
      for (final (i, file) in input.files.indexed) {
        await context.checkCancelled();
        context.report(
          JobProgress('writing', pageIndex: i, pageCount: input.files.length),
        );
        final output = current = outputName(
          input.outputDir,
          file,
          input.suffix,
          outputs,
        );
        QpdfService.protect(
          file,
          output,
          password: input.password,
          owner: owner,
          printing: input.printing,
          copying: input.copying,
          editing: input.editing,
          currentPassword: input.passwords[file],
        );
        outputs.add(output);
      }
    } catch (_) {
      _delete([...outputs, ?current]);
      rethrow;
    }
    return outputs.length == 1 ? OneFile(outputs.single) : ManyFiles(outputs);
  }
}

/// Remove password's input (T2, UI spec §21.22). [password] is never
/// stored, as for [ProtectInput].
class UnlockInput {
  const UnlockInput({
    required this.file,
    required this.outputDir,
    required this.suffix,
    this.password = '',
  });

  factory UnlockInput.fromJson(Map<String, Object?> json) => UnlockInput(
    file: json['file']! as String,
    outputDir: json['outputDir']! as String,
    suffix: json['suffix']! as String,
  );

  final String file;
  final String outputDir;

  /// The localised suffix (" – unlocked").
  final String suffix;
  final String password;

  Map<String, Object?> toJson() => {
    'file': file,
    'outputDir': outputDir,
    'suffix': suffix,
  };
}

/// The `unlock` tool (DK-0504): the file without its encryption, with the
/// password the user knows, as a new file (`<name><suffix>.pdf`). A wrong
/// password fails as `locked` ("That password doesn't open this file."); a
/// file without one as [NotEncrypted] ("This file has no password.").
class UnlockJob extends ToolJob<UnlockInput> {
  const UnlockJob();

  @override
  String get id => 'unlock';

  @override
  Lane get lane => Lane.qpdf;

  @override
  String? passwordOf(UnlockInput input) => input.password;

  @override
  Map<String, Object?> encode(UnlockInput input) => input.toJson();

  @override
  UnlockInput decode(Map<String, Object?> json) => UnlockInput.fromJson(json);

  @override
  List<String> inputFiles(UnlockInput input) => [input.file];

  @override
  UnlockInput chain(JobOutput previous, Map<String, Object?> options) =>
      UnlockInput.fromJson({
        ...options,
        'file': switch (previous) {
          OneFile(:final path) => path,
          _ => throw ArgumentError('Remove password takes one PDF'),
        },
      });

  @override
  Future<JobOutput> run(UnlockInput input, ToolJobContext context) async {
    context.report(const JobProgress('reading'));
    if (!QpdfService.isEncrypted(input.file, password: input.password)) {
      throw const NotEncrypted();
    }
    final output = outputName(input.outputDir, input.file, input.suffix, []);
    await context.checkCancelled();
    context.report(const JobProgress('writing', pageIndex: 0, pageCount: 1));
    try {
      QpdfService.unlock(input.file, output, password: input.password);
    } catch (_) {
      _delete([output]);
      rethrow;
    }
    return OneFile(output);
  }
}

/// Remove password on a file that has none (UI spec §21.22).
class NotEncrypted implements Exception {
  const NotEncrypted();

  @override
  String toString() => 'NotEncrypted: this file has no password';
}

void _delete(List<String> paths) {
  for (final path in paths) {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
  }
}
