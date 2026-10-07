# Dokulo — UI/UX Design & Developer Guide

Oct 7, 2026 · @Rahmat Ullah

## How to use this guide

This guide is the source of truth for Dokulo's interface: what every screen, card and text looks like, how users move between them, what each feature takes in and gives back, and how developers build it. When code and this guide disagree, fix one of them the same day.

**Tabs**

| Tab | Contents |
| --- | --- |
| Overview & foundations (this tab) | Brand voice, copy rules, tokens, layout |
| Components | Every reusable widget: anatomy, states, sizes, copy, Flutter class |
| Navigation & app shell | Routes, tab bar, entry points, back behaviour, deep links |
| Home & Files | Screens H1, T1, F1, F2 and their cards |
| Viewer & Editor | Screens V1, V2, P1 |
| Scanner | Screens S1, S2 and the save flow |
| PDF tools | The tool shell (T2/T3) and a full spec for each of the 30 tools |
| AI features | AI panel A1, Summary, Ask, Translate, Smart Split, model cards |
| Me, onboarding & Pro | M1–M3, onboarding, permissions, paywall X3 |
| Developer guide | Project structure, state, routing, theming code, testing, accessibility checklist, definition of done |

**Screen spec template.** Every screen in the screen tabs uses the same headings, so developers know where to look:

1. Purpose — one sentence.
2. Entry points — how users arrive.
3. Layout — regions top to bottom, with the components used.
4. Inputs and outputs — what the user gives, what the screen produces.
5. Interactions — gestures and taps, and what each does.
6. States — empty, loading, error, success, Pro-gated.
7. Copy — exact English and German strings for headings, buttons and messages.
8. Accessibility — screen-reader labels and focus order.
9. Developer notes — route, providers, jobs, edge cases.

**Tool spec template** (PDF tools tab): purpose · tier · input · options with defaults · output · result card · next chips · errors · copy · developer notes.

**IDs.** Screens keep the IDs from the UX plan (H1, T1, T2, T3, S1, S2, F1, F2, V1, V2, P1, A1, M1–M3, X1–X3). Components use `Dk` prefixes (`DkToolTile`, `DkFileCard`…). Strings use ARB keys `screen_element_purpose` (e.g. `compress_button_run`).

## Brand voice and copy rules

Dokulo sounds like a calm, competent colleague: short sentences, plain words, exact numbers, no hype. The name hints at "Doku" (document) and "local".

**Tagline:** "All your PDF tools. Nothing uploaded." · DE: "Alle PDF-Werkzeuge. Nichts wird hochgeladen."

| Rule | Do | Don't |
| --- | --- | --- |
| Sentence case everywhere | "Compress PDF" | "Compress Pdf", "COMPRESS" |
| Buttons are verbs + object | "Merge 4 files" | "OK", "Submit", "Go" |
| Numbers over adjectives | "1.9 MB (−77 %)" | "Much smaller!" |
| Privacy claims are concrete | "Processed on this phone" | "Military-grade security" |
| No exclamation marks | "Saved" | "Saved!" |
| Errors say what and what next | "This PDF is locked. Enter the password." | "Error 0x12" alone |
| Address the user as "you"; German uses "du" | "Your file" / "Deine Datei" | "The user's file" / "Ihre Datei" |
| Units with a thin space (U+202F, narrow no-break), locale formats: `formatBytes`, `formatDate` in `app_pdf/lib/l10n/formats.dart` | "1,9 MB" (DE), "1.9 MB" (EN); "7. Okt. 2026" (DE), "7 Oct 2026" (EN) | Hard-coded decimals |
| Pro is named once, calmly | "Pro" badge | "PREMIUM ⭐", countdowns |

### Fixed tool names (EN / DE)

| Tool | English | German |
| --- | --- | --- |
| Merge | Merge PDF | PDF zusammenfügen |
| Split | Split PDF | PDF teilen |
| Extract pages | Extract pages | Seiten extrahieren |
| Organize | Organize pages | Seiten ordnen |
| Rotate | Rotate PDF | PDF drehen |
| Smart Split | Smart Split | Smart teilen |
| Image to PDF | Image to PDF | Bild zu PDF |
| PDF to images | PDF to images | PDF zu Bildern |
| Web to PDF | Web page to PDF | Webseite zu PDF |
| PDF/A | Convert to PDF/A | In PDF/A umwandeln |
| Markdown | PDF to text | PDF zu Text |
| Compress | Compress PDF | PDF verkleinern |
| Repair | Repair PDF | PDF reparieren |
| OCR | Make text searchable | Text durchsuchbar machen |
| Page numbers | Add page numbers | Seitenzahlen hinzufügen |
| Watermark | Add watermark | Wasserzeichen hinzufügen |
| Crop | Crop pages | Seiten zuschneiden |
| Annotate | Mark up | Markieren |
| Forms | Fill form | Formular ausfüllen |
| Sign | Sign PDF | PDF unterschreiben |
| Protect | Add password | Passwort hinzufügen |
| Unlock | Remove password | Passwort entfernen |
| Redact | Black out (redact) | Schwärzen |
| Compare | Compare PDFs | PDFs vergleichen |
| Extract | Extract images & text | Bilder & Text extrahieren |
| Batch | Batch | Stapelverarbeitung |
| Workflows | Workflows | Abläufe |
| Summary | Summarize | Zusammenfassen |
| Ask | Ask this PDF | Diese PDF fragen |
| Translate | Translate PDF | PDF übersetzen |

## Design tokens

All values live in one `DkTokens` theme extension (same architecture as Sogda's `DpTokens`); widgets read tokens, never raw values. The palette below is a starting proposal to confirm with the icon design.

### Colour

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `primary` | #2251E6 | #8AA8FF | Main buttons, active tab, links, selection |
| `onPrimary` | #FFFFFF | #0B1640 | Text/icons on primary |
| `primaryContainer` | #E6ECFF | #1C2A5C | Selected chips, pinned tiles, info banners |
| `background` | #F7F8FA | #0F1115 | App background |
| `surface` | #FFFFFF | #181B21 | Cards, sheets, bars |
| `surfaceSunken` | #EEF1F5 | #12151A | Page canvas behind PDF pages, input fields |
| `outline` | #D9DEE6 | #2C313A | Card borders, dividers |
| `textPrimary` | #14171C | #EEF1F6 | Headings, body |
| `textSecondary` | #5A6270 | #A6AEBB | Meta text (size, date) |
| `textDisabled` | #9AA1AD | #5F6672 | Disabled labels |
| `pro` | #8A5A0B | #F2C266 | Pro badge text and icon |
| `proContainer` | #FFF4DD | #3A2C10 | Pro badge background |
| `success` | #13804F | #5DD39E | Success ticks, size-saved numbers |
| `warning` | #B54708 | #FDB022 | Partial success, low memory |
| `danger` | #C8281E | #FF7A70 | Delete, destructive confirms, errors |
| `redactBox` | #000000 | #000000 | Redaction boxes (always pure black) |
| `highlightYellow / Green / Blue / Pink` | #FFE066 / #A8E6A1 / #A7D3FF / #FFB3D1 | same | Markup colours (stored in the PDF, theme-independent) |
| `scrim` | #14171C at 40 % | #000000 at 55 % | Behind sheets and dialogs |
| `cameraChrome` | #000000 at 60 % | same | Scanner overlays on the camera image |
| `quadOverlay` | #2251E6 at 25 % fill, 2 dp stroke | same | Detected document edges |

Contrast: every text/background pair is at least 4.5:1; `pro` on `proContainer` is about 5.4:1 in light mode. Check every new pair with a contrast tool before merging.

### Typography

System fonts: SF Pro (iOS), Roboto (Android). Numbers use tabular figures (`FontFeature.tabularFigures()`) wherever sizes, page counts or times appear.

| Token | Size / line height | Weight | Use |
| --- | --- | --- | --- |
| `display` | 28 / 34 | 700 | Onboarding headlines, paywall headline |
| `titleL` | 22 / 28 | 700 | Screen titles (large header) |
| `titleM` | 18 / 24 | 600 | Section headers, sheet titles, tool names on T2 |
| `titleS` | 16 / 22 | 600 | Card titles, file names |
| `bodyL` | 16 / 24 | 400 | Main text, AI answers |
| `bodyM` | 14 / 20 | 400 | Descriptions, option help text |
| `labelL` | 15 / 20 | 600 | Buttons |
| `labelM` | 13 / 18 | 600 | Chips, tabs, badges |
| `caption` | 12 / 16 | 400 | Meta lines (size · pages · date), legal text |
| `mono` | 13 / 18 | 400 (system mono) | Error codes, page ranges in inputs |

### Spacing, radius, elevation

| Token | Values |
| --- | --- |
| Spacing scale (dp) | `xs` 4 · `s` 8 · `m` 12 · `l` 16 · `xl` 24 · `xxl` 32 · `xxxl` 48 |
| Screen side padding | 16 (phones), 24 (tablets) |
| Radius | `chip` 999 (pill) · `s` 8 (inputs, thumbnails) · `m` 12 (cards, tiles) · `l` 16 (buttons) · `sheet` 24 (top corners) |
| Elevation (light) | `card`: 1 dp outline, no shadow · `raised`: shadow 0/2/8 at 8 % · `floating` (Scan button, mini bar): 0/6/16 at 14 % |
| Elevation (dark) | Outlines only; raised surfaces one step lighter (`surface` +6 % white) |

### Icons

Material Symbols Rounded (Apache-2.0, `material_symbols_icons` package), weight 400, optical size 24; filled variant only for the selected tab. Each tool has exactly one icon, used in the grid, the T2 header, the share-sheet picker and notifications. Icon sizes: 20 (inline), 24 (bars, lists), 28 (tool tiles), 32 (empty states use a 64 dp illustration instead).

### Motion and haptics

| Token | Duration | Curve | Use |
| --- | --- | --- | --- |
| `fast` | 120 ms | easeOut | Press states, chip toggles |
| `standard` | 220 ms | easeInOutCubic | Sheets, page transitions, tile reorder |
| `emphasis` | 320 ms | easeOutBack (subtle) | Success tick, Scan button press |
| Reduce motion on | 0–120 ms cross-fade | linear | Replaces all movement |

Haptics: `selectionClick` on chip/tile select; `lightImpact` on scan capture and drag-drop landing; `mediumImpact` on successful save; none on errors (the message is enough).

## Layout, breakpoints and safe areas

Phones are the design target; tablets get two-pane layouts on four screens; everything respects safe areas and the thumb zone.

| Width class | Range (dp) | Columns in tool grid | Layout changes |
| --- | --- | --- | --- |
| Compact | < 600 | 4 (2 at text scale ≥ 160 %) | Single pane, bottom tab bar |
| Medium | 600–839 | 6 | Single pane, wider cards; Organize grid 5 columns |
| Expanded | ≥ 840 | 8 | Navigation rail instead of tab bar; two-pane Files (list + preview), Viewer + AI panel side by side, Organize grid 8 columns, Compare side by side |

**Thumb zone rules (compact):** primary action in the bottom 25 % of the screen (sticky action bar above the tab bar or at screen bottom on full-screen pages); destructive actions never in the bottom-centre spot; top bar holds navigation and secondary actions only.

**Safe areas:** content respects system insets; the Scan button and mini job bar sit above the home indicator; the camera preview runs edge to edge with controls inside the safe area.

**Orientation:** portrait only on phones except the Viewer, Signature pad (landscape full screen) and Compare (landscape allowed); tablets support both orientations everywhere.
