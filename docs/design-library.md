# Design library

The design library of UI spec §32.1 (1) (DK-1009): foundations as styles for
Light and Dark, the icon set, the illustrations ILL-01…20, and every component
of §11 with its variants and states. The team works in the Dokulo design
canvas, not Figma; the canvas is the library, and the app's code holds the
same parts bound one to one. This page says where each part lives and records
engineering's review (2026-10-10).

## Where it lives

| Part | Design canvas (`dokulo-design/<theme>/00-design-system/`) | In the app | Checked by |
| --- | --- | --- | --- |
| Colour, type, spacing, radius, elevation | `foundations.html` (Light, Dark) | `DkTokens` (`lib/theme/dk_tokens.dart`); screens and components use only tokens (`tools/check_tokens.py`) | `test/qa/design_parity_test.dart` (DK-0982): the export's 27 colour variables and 9 type classes against `DkTokens` |
| Motion | `motion.html` | `DkMotion`, `context.motion(kind)` | the same test (DK-0986) |
| Icons | Material Symbols Rounded in every board | `DkIcons` (`lib/components/dk_icon.dart`), the font hash-checked by `tools/fetch_icon_font.py` | the catalogue's icon entry |
| Illustrations ILL-01…20 | `illustrations/`, `illustrations-overview.html` (Light, Dark) | `DkIllustrations` (`lib/components/dk_illustration.dart`) | `tools/qa_illustrations.py` (DK-0985, DK-0988…DK-1007): 40/40 |
| Components (§11) | `components.html`, `components-part-2.html` (Light, Dark) | `lib/components/`, `lib/patterns/`; each in the catalogue at `/dev/catalogue` (debug builds), every variant and state in Light and Dark | the table below; visual QA of `components.html` is DK-0983, of part 2 DK-0984 |

Every screen state has its own board in the same canvas
(`dokulo-design/<theme>/<area>/<screen>-<state>.html`; `deutsch/` for German),
and the design QA tasks (DK-0838…DK-1007) compare them with the app; their
findings are in `docs/qa/design-system.md`.

## The components of §11

Every component the spec's §11 names, where it is in the code, and its
catalogue entry. All 63 are built; `DkToast` is the function `showDkToast`.

| § | Component | In code (`packages/app_pdf/lib/`) | Catalogue entry (`lib/catalogue/`) |
| --- | --- | --- | --- |
| 11.1 | `DkActionBar` | `components/dk_action_bar.dart` | `feedback_states.dart` |
| 11.2 | `DkProBadge` | `components/dk_pro_badge.dart` | `pro_chip_states.dart` |
| 11.2 | `DkFolderCard` | `components/dk_folder_card.dart` | `folder_settings_states.dart` |
| 11.3 | `DkChip` | `components/dk_chip.dart` | `pro_chip_states.dart` |
| 11.3 | `DkNextChip` | `components/dk_next_chip.dart` | `next_page_chip_states.dart` |
| 11.3 | `DkPageChip` | `components/dk_page_chip.dart` | `next_page_chip_states.dart` |
| 11.3 | `DkPrivacyLine` | `components/dk_privacy_line.dart` | `privacy_status_states.dart` |
| 11.3 | `DkStatusDot` | `components/dk_status_dot.dart` | `privacy_status_states.dart` |
| 11.3 | `DkCountBadge` | `components/dk_count_badge.dart` | `badge_pill_states.dart` |
| 11.3 | `DkHintPill` | `components/dk_hint_pill.dart` | `badge_pill_states.dart` |
| 11.3 | `DkPagePill` | `components/dk_page_pill.dart` | `page_pill_states.dart` |
| 11.4 | `DkTextField` | `components/dk_text_field.dart` | `text_field_states.dart` |
| 11.4 | `DkPasswordField` | `components/dk_text_field.dart` | `text_field_states.dart` |
| 11.4 | `DkRangeField` | `components/dk_text_field.dart` | `range_search_states.dart` |
| 11.4 | `DkSearchField` | `components/dk_text_field.dart` | `range_search_states.dart` |
| 11.4 | `DkSwitch` | `components/dk_switch.dart` | `option_row_states.dart` |
| 11.4 | `DkSegmented` | `components/dk_segmented.dart` | `option_row_states.dart` |
| 11.4 | `DkSlider` | `components/dk_slider.dart` | `slider_stepper_states.dart` |
| 11.4 | `DkStepper` | `components/dk_stepper.dart` | `slider_stepper_states.dart` |
| 11.4 | `DkDropdown` | `components/dk_dropdown.dart` | `dropdown_states.dart` |
| 11.4 | `DkOptionRow` | `components/dk_option_row.dart` | `option_row_states.dart` |
| 11.4 | `DkPositionPicker` | `components/dk_position_picker.dart` | `option_row_states.dart` |
| 11.4 | `DkColorRow` | `components/dk_color_row.dart` | `color_pin_states.dart` |
| 11.4 | `DkCheckboxRow` | `components/dk_checkbox_row.dart` | `choice_row_states.dart` |
| 11.4 | `DkRadioRow` | `components/dk_radio_row.dart` | `choice_row_states.dart` |
| 11.4 | `DkPinPad` | `components/dk_pin_pad.dart` | `color_pin_states.dart` |
| 11.5 | `DkPageThumb` | `components/dk_page_thumb.dart` | `overlay_states.dart` |
| 11.5 | `DkPageTray` | `components/dk_page_tray.dart` | `page_states.dart` |
| 11.5 | `DkPageGrid` | `components/dk_page_grid.dart` | `page_states.dart` |
| 11.5 | `DkCropOverlay` | `components/dk_crop_overlay.dart` | `crop_states.dart` |
| 11.5 | `DkMagnifier` | `components/dk_magnifier.dart` | `page_states.dart` |
| 11.5 | `DkRedactionBox` | `components/dk_redaction_box.dart` | `page_states.dart` |
| 11.5 | `DkSignatureStamp` | `components/dk_signature_stamp.dart` | `page_states.dart` |
| 11.6 | `DkTopBar` | `components/dk_top_bar.dart` | `bar_states.dart` |
| 11.6 | `DkTabBar` | `components/dk_tab_bar.dart` | `bar_states.dart` |
| 11.6 | `DkScanButton` | `components/dk_scan_button.dart` | `bar_states.dart` |
| 11.6 | `DkNavRail` | `components/dk_tab_bar.dart` | `bar_states.dart` |
| 11.6 | `DkSelectionBar` | `components/dk_bottom_bars.dart` | `bar_states.dart` |
| 11.6 | `DkMiniJobBar` | `components/dk_mini_job_bar.dart` | `feedback_states.dart` |
| 11.6 | `DkToolStrip` | `components/dk_editor_bars.dart` | `bar_states.dart` |
| 11.6 | `DkViewerBar` | `components/dk_bottom_bars.dart` | `bar_states.dart` |
| 11.6 | `DkCameraTopBar` | `components/dk_camera_top_bar.dart` | `bar_states.dart` |
| 11.7 | `DkSheet` | `components/dk_sheet.dart` | `overlay_states.dart` |
| 11.7 | `DkActionSheet` | `components/dk_action_sheet.dart` | `overlay_states.dart` |
| 11.7 | `DkSettingsRow` | `components/dk_settings_row.dart` | `folder_settings_states.dart` |
| 11.7 | `DkConfirmDialog` | `components/dk_confirm_dialog.dart` | `dialog_states.dart` |
| 11.7 | `DkMenu` | `components/dk_menu.dart` | `overlay_states.dart` |
| 11.7 | `DkToast` | components/dk_toast.dart (`showDkToast`) | `overlay_states.dart` |
| 11.7 | `DkBanner` | `components/dk_banner.dart` | `dialog_states.dart` |
| 11.7 | `DkProgressSheet` | `components/dk_progress_sheet.dart` | `progress_states.dart` |
| 11.7 | `DkEmptyState` | `components/dk_empty_state.dart` | `feedback_states.dart` |
| 11.7 | `DkSkeleton` | `components/dk_skeleton.dart` | `overlay_states.dart` |
| 11.7 | `DkLoadingSpinner` | `components/dk_loading_spinner.dart` | `overlay_states.dart` |
| 11.8 | `DkMarkupBar` | `components/dk_editor_bars.dart` | `bar_states.dart` |
| 11.8 | `DkToolOptionsSheet` | `components/dk_tool_options_sheet.dart` | `tool_options_states.dart` |
| 11.8 | `DkSignaturePad` | `components/dk_signature_pad.dart` | `signature_pad_states.dart` |
| 11.8 | `DkSignatureCard` | `components/dk_signature_card.dart` | `sign_states.dart` |
| 11.8 | `DkChatBubble` | `components/dk_chat_bubble.dart` | `chat_states.dart` |
| 11.8 | `DkSuggestionChip` | `components/dk_ai_parts.dart` | `ai_states.dart` |
| 11.8 | `DkAIFooter` | `components/dk_ai_parts.dart` | `ai_states.dart` |
| 11.8 | `DkSplitMarker` | `components/dk_split_marker.dart` | `sign_states.dart` |
| 11.8 | `DkDiffRow` | `components/dk_diff_row.dart` | `chat_states.dart` |
| 11.8 | `DkDetectionGroup` | `components/dk_detection_group.dart` | `detection_states.dart` |

## Review (engineering, 2026-10-10)

- Delivered: the canvas covers every foundation, the icons, ILL-01…20 and the
  §11 components with their variants and states, in Light and Dark; the
  screen boards cover every state the spec lists.
- Bound to code: the tokens, motion and illustrations are checked against
  the canvas in the gate; every §11 component has its code and its catalogue
  entry (the table above).
- Figma: not used. Rebuilding the canvas in Figma with variables would be a
  separate task if the owner asks for it.
- What the canvas and the spec disagree on is decided per board in the QA
  log (`docs/qa/design-system.md`): the spec wins, and an approved change is
  recorded there.
