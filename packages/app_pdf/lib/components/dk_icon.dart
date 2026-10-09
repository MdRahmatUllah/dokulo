import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';

/// The icon sizes (UI spec §7). There are no others.
enum DkIconSize {
  /// Inside chips and badges.
  s(16),

  /// Inline with text, in buttons.
  m(20),

  /// Bars and list rows.
  l(24),

  /// Inside tool tiles.
  xl(28),

  /// Scanner controls.
  xxl(32);

  const DkIconSize(this.dp);
  final double dp;
}

/// An icon the way the spec draws it (DK-0048): Material Symbols Rounded,
/// weight 400, grade 0, optical size 24, outlined; [filled] only for the
/// selected tab and toggled states (a favourite). Colour from the tokens
/// unless [color] says otherwise. Icon-only controls give [semanticLabel].
class DkIcon extends StatelessWidget {
  const DkIcon(
    this.icon, {
    super.key,
    this.size = DkIconSize.l,
    this.filled = false,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final DkIconSize size;
  final bool filled;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Icon(
    icon,
    size: size.dp,
    fill: filled ? 1 : 0,
    weight: 400,
    grade: 0,
    opticalSize: 24,
    color: color ?? context.tokens.color.iconPrimary,
    semanticLabel: semanticLabel,
  );
}

/// Every icon the app uses, by purpose (UI spec §7), so a screen never names
/// a glyph itself. Platform icons follow the theme's platform.
/// A Material Symbols Rounded glyph: the font is ours (pubspec `fonts:`),
/// fetched and hash-checked by tools/fetch_icon_font.py, so the build ships
/// one icon font, tree-shaken, instead of the package's three in full.
/// Codepoints from material_symbols_icons 4.2960.0's `Symbols.*_rounded`.
/// (Each glyph is a const IconData: the release build's icon tree-shaker
/// needs them const to keep only the glyphs we use.)
const _font = 'MaterialSymbolsRounded';

abstract final class DkIcons {
  /// One icon per tool, used everywhere (grid, T2 header, share picker,
  /// notifications, workflows), keyed by the tool id of `/tool/:toolId`.
  static const tools = <String, IconData>{
    'scan': IconData(0xe5fa, fontFamily: _font) /* document_scanner */,
    'merge': IconData(0xeb98, fontFamily: _font) /* merge */,
    'split': IconData(0xe14e, fontFamily: _font) /* content_cut */,
    'extract': IconData(0xf3b2, fontFamily: _font) /* file_export */,
    'organize': IconData(0xe9b0, fontFamily: _font) /* grid_view */,
    'rotate': IconData(0xe41a, fontFamily: _font) /* rotate_right */,
    'smartsplit': IconData(0xe660, fontFamily: _font) /* auto_awesome_mosaic */,
    'img2pdf': IconData(0xe3f4, fontFamily: _font) /* image */,
    'pdf2img': IconData(0xe413, fontFamily: _font) /* photo_library */,
    'web': IconData(0xea07, fontFamily: _font) /* language */,
    'pdfa': IconData(0xe1a1, fontFamily: _font) /* inventory_2 */,
    'text': IconData(0xe26c, fontFamily: _font) /* notes */,
    'compress': IconData(0xe94d, fontFamily: _font) /* compress */,
    'repair': IconData(0xf8cd, fontFamily: _font) /* build */,
    'ocr': IconData(0xf02f, fontFamily: _font) /* manage_search */,
    'translate': IconData(0xe8e2, fontFamily: _font) /* translate */,
    'pagenum': IconData(0xe242, fontFamily: _font) /* format_list_numbered */,
    'watermark': IconData(0xe06b, fontFamily: _font) /* branding_watermark */,
    'crop': IconData(0xe3be, fontFamily: _font) /* crop */,
    'markup': IconData(0xf097, fontFamily: _font) /* edit */,
    'form': IconData(0xe85d, fontFamily: _font) /* assignment */,
    'sign': IconData(0xf74c, fontFamily: _font) /* signature */,
    'protect': IconData(0xe899, fontFamily: _font) /* lock */,
    'unlock': IconData(0xe898, fontFamily: _font) /* lock_open */,
    'redact': IconData(0xe8f5, fontFamily: _font) /* visibility_off */,
    'compare': IconData(0xe3b9, fontFamily: _font) /* compare */,
    'extractassets': IconData(0xe169, fontFamily: _font) /* unarchive */,
    'batch': IconData(0xea14, fontFamily: _font) /* dynamic_feed */,
    'workflows': IconData(0xe97a, fontFamily: _font) /* account_tree */,
    'summarize': IconData(0xf071, fontFamily: _font) /* summarize */,
    'ask': IconData(0xe8af, fontFamily: _font) /* forum */,
  };

  /// The tool's icon; an unknown id is a bug, so it throws.
  static IconData tool(String id) =>
      tools[id] ?? (throw ArgumentError('no icon for tool "$id"'));

  // Tabs and the shell.
  static const home = IconData(0xe9b2, fontFamily: _font) /* home */;
  static const toolsTab = IconData(0xe5c3, fontFamily: _font) /* apps */;
  static const files = IconData(0xe2c7, fontFamily: _font) /* folder */;
  static const me = IconData(0xf0d3, fontFamily: _font) /* person */;
  static const scan = IconData(
    0xe5fa,
    fontFamily: _font,
  ) /* document_scanner */;

  // Actions.
  static const close = IconData(0xe5cd, fontFamily: _font) /* close */;
  static const open = IconData(0xe89e, fontFamily: _font) /* open_in_new */;
  static const search = IconData(0xef7a, fontFamily: _font) /* search */;
  static const previousField = IconData(
    0xe316,
    fontFamily: _font,
  ) /* keyboard_arrow_up */;
  static const delete = IconData(0xe92e, fontFamily: _font) /* delete */;
  static const deleteForever = IconData(
    0xe92b,
    fontFamily: _font,
  ) /* delete_forever */;
  static const rename = IconData(
    0xe9a2,
    fontFamily: _font,
  ) /* drive_file_rename_outline */;
  static const move = IconData(0xe9a1, fontFamily: _font) /* drive_file_move */;
  static const duplicate = IconData(
    0xe14d,
    fontFamily: _font,
  ) /* content_copy */;
  static const sort = IconData(0xe164, fontFamily: _font) /* sort */;
  static const listView = IconData(0xe8ef, fontFamily: _font) /* view_list */;
  static const gridView = IconData(0xe9b0, fontFamily: _font) /* grid_view */;
  static const newFolder = IconData(
    0xe2cc,
    fontFamily: _font,
  ) /* create_new_folder */;
  static const add = IconData(0xe145, fontFamily: _font) /* add */;
  static const lock = IconData(0xe899, fontFamily: _font) /* lock */;
  static const backspace = IconData(0xe14a, fontFamily: _font) /* backspace */;
  static const fingerprint = IconData(
    0xe90d,
    fontFamily: _font,
  ) /* fingerprint */;
  static const faceId = IconData(0xf008, fontFamily: _font) /* face */;
  static const palette = IconData(0xe40a, fontFamily: _font) /* palette */;
  static const remove = IconData(0xe15b, fontFamily: _font) /* remove */;
  static const dot = IconData(
    0xe061,
    fontFamily: _font,
  ) /* fiber_manual_record */;
  static const arrowForward = IconData(
    0xe5c8,
    fontFamily: _font,
  ) /* arrow_forward */;
  static const expandMore = IconData(
    0xe5cf,
    fontFamily: _font,
  ) /* expand_more */;
  static const expandLess = IconData(
    0xe5ce,
    fontFamily: _font,
  ) /* expand_less */;
  static const scanDocument = IconData(
    0xe873,
    fontFamily: _font,
  ) /* description */;
  static const scanIdCard = IconData(0xea67, fontFamily: _font) /* badge */;
  static const scanBook = IconData(0xea19, fontFamily: _font) /* menu_book */;
  static const scanBatch = IconData(0xe43c, fontFamily: _font) /* burst_mode */;
  static const cut = IconData(0xe14e, fontFamily: _font) /* content_cut */;
  static const forum = IconData(0xe8af, fontFamily: _font) /* forum */;
  static const check = IconData(0xe5ca, fontFamily: _font) /* check */;
  static const chevronRight = IconData(
    0xe5cc,
    fontFamily: _font,
  ) /* chevron_right */;
  static const undo = IconData(0xe166, fontFamily: _font) /* undo */;
  static const redo = IconData(0xe15a, fontFamily: _font) /* redo */;
  static const pin = IconData(0xf10d, fontFamily: _font) /* push_pin */;
  static const info = IconData(0xe88e, fontFamily: _font) /* info */;
  static const input = IconData(0xe890, fontFamily: _font) /* input */;
  static const output = IconData(0xebbe, fontFamily: _font) /* output */;
  static const internet = IconData(0xe80b, fontFamily: _font) /* public */;

  // Files.
  static const folder = IconData(0xe2c7, fontFamily: _font) /* folder */;
  static const lockedFolder = IconData(0xe899, fontFamily: _font) /* lock */;
  static const trash = IconData(0xe16c, fontFamily: _font) /* delete_sweep */;

  // Scanner.
  static const flashOff = IconData(0xe3e6, fontFamily: _font) /* flash_off */;
  static const flashOn = IconData(0xe3e7, fontFamily: _font) /* flash_on */;
  static const flashAuto = IconData(0xe3e5, fontFamily: _font) /* flash_auto */;
  static const gridOverlay = IconData(0xe3ec, fontFamily: _font) /* grid_on */;
  static const autoCapture = IconData(
    0xf03a,
    fontFamily: _font,
  ) /* motion_photos_auto */;
  static const importPhotos = IconData(
    0xe413,
    fontFamily: _font,
  ) /* photo_library */;
  static const retake = IconData(0xf053, fontFamily: _font) /* restart_alt */;
  static const camera = IconData(0xe412, fontFamily: _font) /* photo_camera */;
  static const filters = IconData(0xe429, fontFamily: _font) /* tune */;

  // Viewer and editor.
  static const nightMode = IconData(0xe51c, fontFamily: _font) /* dark_mode */;
  static const goToPage = IconData(0xe8a0, fontFamily: _font) /* pageview */;
  static const pen = IconData(0xf097, fontFamily: _font) /* edit */;
  static const highlighter = IconData(
    0xe6d1,
    fontFamily: _font,
  ) /* ink_highlighter */;
  static const eraser = IconData(0xe6d0, fontFamily: _font) /* ink_eraser */;
  static const textBox = IconData(0xe264, fontFamily: _font) /* title */;
  static const shape = IconData(0xe602, fontFamily: _font) /* shapes */;
  static const note = IconData(0xf1fc, fontFamily: _font) /* sticky_note_2 */;
  static const pan = IconData(0xe925, fontFamily: _font) /* pan_tool */;
  static const copy = IconData(0xe14d, fontFamily: _font) /* content_copy */;
  static const underline = IconData(
    0xe249,
    fontFamily: _font,
  ) /* format_underlined */;
  static const strike = IconData(
    0xe257,
    fontFamily: _font,
  ) /* strikethrough_s */;
  static const colour = IconData(0xe40a, fontFamily: _font) /* palette */;
  static const reveal = IconData(0xe8f4, fontFamily: _font) /* visibility */;
  static const conceal = IconData(
    0xe8f5,
    fontFamily: _font,
  ) /* visibility_off */;

  // States and system.
  static const privacy = IconData(0xe7ba, fontFamily: _font) /* smartphone */;
  static const pro = IconData(
    0xe7af,
    fontFamily: _font,
  ) /* workspace_premium */;
  static const success = IconData(0xf0be, fontFamily: _font) /* check_circle */;
  static const warning = IconData(0xf083, fontFamily: _font) /* warning */;
  static const error = IconData(0xf8b6, fontFamily: _font) /* error */;
  static const offline = IconData(0xe2c1, fontFamily: _font) /* cloud_off */;
  static const download = IconData(0xf090, fontFamily: _font) /* download */;
  static const pause = IconData(0xe034, fontFamily: _font) /* pause */;
  static const settings = IconData(0xe8b8, fontFamily: _font) /* settings */;
  static const language = IconData(0xea07, fontFamily: _font) /* language */;
  static const licences = IconData(0xe90e, fontFamily: _font) /* gavel */;
  static const contact = IconData(0xe159, fontFamily: _font) /* mail */;

  // Platform icons (UI spec §13.2).
  static bool _ios(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.iOS;

  static IconData back(BuildContext context) => _ios(context)
      ? IconData(0xe2ea, fontFamily: _font) /* arrow_back_ios_new */
      : IconData(0xe5c4, fontFamily: _font) /* arrow_back */;

  static IconData overflow(BuildContext context) => _ios(context)
      ? IconData(0xe5d3, fontFamily: _font) /* more_horiz */
      : IconData(0xe5d4, fontFamily: _font) /* more_vert */;

  static IconData share(BuildContext context) => _ios(context)
      ? IconData(0xe6b8, fontFamily: _font) /* ios_share */
      : IconData(0xe80d, fontFamily: _font) /* share */;

  /// Face ID on an iPhone that has it; a fingerprint everywhere else.
  static IconData biometrics(BuildContext context, {required bool faceId}) =>
      _ios(context) && faceId
      ? IconData(0xf008, fontFamily: _font) /* face */
      : IconData(0xe90d, fontFamily: _font) /* fingerprint */;
}
