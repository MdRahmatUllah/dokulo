import 'package:doc_core/doc_core.dart';
import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

/// The values of a tool's options, by [ToolOption.key].
typedef ToolValues = Map<String, Object?>;

/// What a tool runs on, as T2 shows it: the input files, in order.
class ToolSubject {
  const ToolSubject(this.files);

  final List<FileEntry> files;

  /// All pages of all files ("Compress 12 pages").
  int get pages => files.fold(0, (n, f) => n + f.pages);
}

/// Where a tool's job writes, and the words it needs (the engine has none).
class ToolEnv {
  const ToolEnv({required this.outputDir, required this.l10n});

  /// A temp folder of the file store; T3 saves from there.
  final String outputDir;
  final AppLocalizations l10n;
}

/// One option of a tool, rendered by T2 (UI spec §20.1 region 4) as a
/// DkOptionRow. A tool declares its options; the shell draws them, keeps the
/// chosen values while the user goes back and forth, and resets them.
sealed class ToolOption {
  const ToolOption({required this.key, required this.title, this.help});

  /// Its value's key in [ToolValues]; unique within a tool.
  final String key;
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations)? help;

  Object? get initial;
}

/// On or off: a DkSwitch to the right.
final class ToolSwitch extends ToolOption {
  const ToolSwitch({
    required super.key,
    required super.title,
    super.help,
    this.initial = false,
  });

  @override
  final bool initial;
}

/// One of 2–4: a DkSegmented under the text.
final class ToolSegments<T extends Object> extends ToolOption {
  const ToolSegments({
    required super.key,
    required super.title,
    super.help,
    required this.values,
    required this.label,
    required this.initial,
  });

  final List<T> values;
  final String Function(AppLocalizations, T) label;

  @override
  final T initial;

  /// The segments with their labels, typed here where [T] is known.
  List<(Object, String)> segments(AppLocalizations l) => [
    for (final v in values) (v, label(l, v)),
  ];
}

/// Anything else (level cards, chips, a range or text field): the tool
/// builds the control, under the text.
final class ToolCustom extends ToolOption {
  const ToolCustom({
    required super.key,
    required super.title,
    super.help,
    required this.initial,
    required this.builder,
  });

  @override
  final Object? initial;

  final Widget Function(
    BuildContext context,
    ToolSubject subject,
    Object? value,
    ValueChanged<Object?> onChanged,
  )
  builder;
}

/// A tool as T2 renders and runs it (DK-0370): its options, the "More
/// options" ones, the main button's label, the estimate, and how its job's
/// input is made. Each tool's own task fills in its definition; until then a
/// tool shows its input and its name on a disabled button.
class ToolDefinition {
  const ToolDefinition({
    required this.id,
    this.options = const [],
    this.moreOptions = const [],
    this.action,
    this.estimate,
    this.input,
    this.busyLabel,
    this.busyTitle,
    this.stopTitle,
  });

  final String id;
  final List<ToolOption> options;

  /// Behind the collapsible "More options" row.
  final List<ToolOption> moreOptions;

  /// The main button: verb, object, number ("Compress 12 pages", UI spec
  /// §21); null: the tool's name.
  final String Function(AppLocalizations, ToolSubject)? action;

  /// The caption above the button ("About 1.8 MB · 12 pages"); null: none.
  final String? Function(AppLocalizations, ToolSubject, ToolValues)? estimate;

  /// The job's input from the files and options; null: the tool can't run
  /// yet.
  final Object Function(ToolSubject, ToolValues, ToolEnv)? input;

  /// The button while it runs ("Compressing…", UI spec §20.2); null: "Working…".
  final String Function(AppLocalizations)? busyLabel;

  /// The progress sheet's title ("Compressing Mietvertrag.pdf"); null: the
  /// tool's name.
  final String Function(AppLocalizations, ToolSubject)? busyTitle;

  /// The cancel dialog's title ("Stop compressing?"); null: "Stop this job?".
  final String Function(AppLocalizations)? stopTitle;

  /// Every option's starting value.
  ToolValues get initialValues => {
    for (final o in [...options, ...moreOptions]) o.key: o.initial,
  };
}

/// Every tool's definition. A tool's task adds its own here.
abstract final class ToolDefinitions {
  static final Map<String, ToolDefinition> _defined = {
    for (final d in <ToolDefinition>[]) d.id: d,
  };

  /// The definition of [toolId]; a plain one for a tool without its own.
  static ToolDefinition of(String toolId) =>
      _defined[toolId] ?? ToolDefinition(id: toolId);
}
