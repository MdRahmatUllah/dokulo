import 'package:flutter/widgets.dart';

import '../components/dk_icon.dart';
import '../l10n/app_localizations.dart';

/// Free or Pro (UI spec §2): Pro tools always show `DkProBadge`.
enum ToolTier { free, pro }

/// The Tools tab's sections and chips, in their order (UI spec §15.2).
enum ToolCategory {
  organize,
  convert,
  optimize,
  edit,
  security,
  ai,
  automation;

  String label(AppLocalizations l) => switch (this) {
    organize => l.tools_category_organize,
    convert => l.tools_category_convert,
    optimize => l.tools_category_optimize,
    edit => l.tools_category_edit,
    security => l.tools_category_security,
    ai => l.tools_category_ai,
    automation => l.tools_category_automation,
  };
}

/// One tool: what the grid, the T2 header, the X1 picker, search, About this
/// tool and the notifications show for it. The icon comes from
/// [DkIcons.tools], so every place shows the same one.
@immutable
class ToolInfo {
  const ToolInfo._(this.id, this.tier, this.category, this._name, this._text);

  /// The tool id of `/tool/:toolId` and of its ToolJob.
  final String id;
  final ToolTier tier;

  /// Its section in the Tools tab; null for Scan, which has its own button.
  final ToolCategory? category;

  final String Function(AppLocalizations) _name, _text;

  IconData get icon => DkIcons.tool(id);
  bool get isPro => tier == ToolTier.pro;

  /// The fixed EN/DE name (Overview & foundations → Fixed tool names).
  String name(AppLocalizations l) => _name(l);

  /// The one-line description (UI spec §21).
  String description(AppLocalizations l) => _text(l);
}

/// Every tool, in the Tools tab's order (DK-0049; UI spec §15.2, §21).
abstract final class ToolCatalogue {
  static const _free = ToolTier.free, _pro = ToolTier.pro;

  static final List<ToolInfo> all = [
    ToolInfo._(
      'scan',
      _free,
      null,
      (l) => l.tool_scan_name,
      (l) => l.tool_scan_description,
    ),
    // Organize
    ToolInfo._(
      'merge',
      _free,
      ToolCategory.organize,
      (l) => l.tool_merge_name,
      (l) => l.tool_merge_description,
    ),
    ToolInfo._(
      'split',
      _free,
      ToolCategory.organize,
      (l) => l.tool_split_name,
      (l) => l.tool_split_description,
    ),
    ToolInfo._(
      'extract',
      _free,
      ToolCategory.organize,
      (l) => l.tool_extract_name,
      (l) => l.tool_extract_description,
    ),
    ToolInfo._(
      'organize',
      _free,
      ToolCategory.organize,
      (l) => l.tool_organize_name,
      (l) => l.tool_organize_description,
    ),
    ToolInfo._(
      'rotate',
      _free,
      ToolCategory.organize,
      (l) => l.tool_rotate_name,
      (l) => l.tool_rotate_description,
    ),
    ToolInfo._(
      'smartsplit',
      _pro,
      ToolCategory.organize,
      (l) => l.tool_smartsplit_name,
      (l) => l.tool_smartsplit_description,
    ),
    // Convert
    ToolInfo._(
      'img2pdf',
      _free,
      ToolCategory.convert,
      (l) => l.tool_img2pdf_name,
      (l) => l.tool_img2pdf_description,
    ),
    ToolInfo._(
      'pdf2img',
      _free,
      ToolCategory.convert,
      (l) => l.tool_pdf2img_name,
      (l) => l.tool_pdf2img_description,
    ),
    ToolInfo._(
      'web',
      _free,
      ToolCategory.convert,
      (l) => l.tool_web_name,
      (l) => l.tool_web_description,
    ),
    ToolInfo._(
      'pdfa',
      _pro,
      ToolCategory.convert,
      (l) => l.tool_pdfa_name,
      (l) => l.tool_pdfa_description,
    ),
    ToolInfo._(
      'text',
      _pro,
      ToolCategory.convert,
      (l) => l.tool_text_name,
      (l) => l.tool_text_description,
    ),
    // Optimize
    ToolInfo._(
      'compress',
      _free,
      ToolCategory.optimize,
      (l) => l.tool_compress_name,
      (l) => l.tool_compress_description,
    ),
    ToolInfo._(
      'repair',
      _free,
      ToolCategory.optimize,
      (l) => l.tool_repair_name,
      (l) => l.tool_repair_description,
    ),
    ToolInfo._(
      'ocr',
      _pro,
      ToolCategory.optimize,
      (l) => l.tool_ocr_name,
      (l) => l.tool_ocr_description,
    ),
    // Edit
    ToolInfo._(
      'pagenum',
      _free,
      ToolCategory.edit,
      (l) => l.tool_pagenum_name,
      (l) => l.tool_pagenum_description,
    ),
    ToolInfo._(
      'watermark',
      _free,
      ToolCategory.edit,
      (l) => l.tool_watermark_name,
      (l) => l.tool_watermark_description,
    ),
    ToolInfo._(
      'crop',
      _free,
      ToolCategory.edit,
      (l) => l.tool_crop_name,
      (l) => l.tool_crop_description,
    ),
    ToolInfo._(
      'markup',
      _free,
      ToolCategory.edit,
      (l) => l.tool_markup_name,
      (l) => l.tool_markup_description,
    ),
    ToolInfo._(
      'form',
      _pro,
      ToolCategory.edit,
      (l) => l.tool_form_name,
      (l) => l.tool_form_description,
    ),
    // Security
    ToolInfo._(
      'sign',
      _free,
      ToolCategory.security,
      (l) => l.tool_sign_name,
      (l) => l.tool_sign_description,
    ),
    ToolInfo._(
      'protect',
      _free,
      ToolCategory.security,
      (l) => l.tool_protect_name,
      (l) => l.tool_protect_description,
    ),
    ToolInfo._(
      'unlock',
      _free,
      ToolCategory.security,
      (l) => l.tool_unlock_name,
      (l) => l.tool_unlock_description,
    ),
    ToolInfo._(
      'redact',
      _pro,
      ToolCategory.security,
      (l) => l.tool_redact_name,
      (l) => l.tool_redact_description,
    ),
    ToolInfo._(
      'compare',
      _pro,
      ToolCategory.security,
      (l) => l.tool_compare_name,
      (l) => l.tool_compare_description,
    ),
    // AI
    ToolInfo._(
      'summarize',
      _pro,
      ToolCategory.ai,
      (l) => l.tool_summarize_name,
      (l) => l.tool_summarize_description,
    ),
    ToolInfo._(
      'ask',
      _pro,
      ToolCategory.ai,
      (l) => l.tool_ask_name,
      (l) => l.tool_ask_description,
    ),
    ToolInfo._(
      'translate',
      _pro,
      ToolCategory.ai,
      (l) => l.tool_translate_name,
      (l) => l.tool_translate_description,
    ),
    // Automation
    ToolInfo._(
      'extractassets',
      _free,
      ToolCategory.automation,
      (l) => l.tool_extractassets_name,
      (l) => l.tool_extractassets_description,
    ),
    ToolInfo._(
      'batch',
      _free,
      ToolCategory.automation,
      (l) => l.tool_batch_name,
      (l) => l.tool_batch_description,
    ),
    ToolInfo._(
      'workflows',
      _pro,
      ToolCategory.automation,
      (l) => l.tool_workflows_name,
      (l) => l.tool_workflows_description,
    ),
  ];

  static final _byId = {for (final t in all) t.id: t};

  /// The tool with [id]; an unknown id is a bug, so it throws.
  static ToolInfo of(String id) =>
      _byId[id] ?? (throw ArgumentError('no tool "$id"'));

  /// A section of the Tools tab, in order.
  static Iterable<ToolInfo> inCategory(ToolCategory category) =>
      all.where((t) => t.category == category);
}
