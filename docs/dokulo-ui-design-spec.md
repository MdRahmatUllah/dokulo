# Dokulo — Complete UI Design Specification

Version 1.0 · 7 October 2026 · Owner: Maruf

This document is the only brief a UI/UX designer needs to design every visual of Dokulo for iOS and Android: brand, foundations, components, every screen and state, every tool, all copy in English and German, illustrations, icons, store assets and the list of frames to deliver. Anything not defined here should be raised as a question, not invented.

---

## Table of contents

1. How to use this document
2. Product summary
3. Brand
4. Foundations: colour
5. Foundations: typography
6. Foundations: spacing, grid, radius, elevation, borders
7. Foundations: iconography
8. Foundations: illustrations and imagery
9. Foundations: motion and haptics
10. Layout system, frames and breakpoints
11. Components
12. Interaction patterns
13. App shell and navigation
14. Screens: launch and onboarding
15. Screens: Home and Tools
16. Screens: Files and locked folder
17. Screens: Viewer and edit mode
18. Screens: Organize pages
19. Screens: Scanner
20. Screens: Tool shell (options, progress, result, picker)
21. Tool-by-tool specifications (30 tools)
22. Screens: AI features
23. Screens: Me, settings, AI models
24. Screens: Pro and paywall
25. System surfaces: notifications, widgets, shortcuts, extensions
26. Global states: empty, loading, error, offline, permissions
27. Copy deck (EN / DE)
28. Accessibility requirements for visuals
29. Dark mode rules
30. Tablet and landscape rules
31. App icon and store assets brief
32. Designer deliverables and frame inventory

---

## 1. How to use this document

**What to design:** high-fidelity screens for phones (iOS and Android share one design, with the platform differences listed in section 13), tablet adaptations for the screens listed in section 30, all components as a component library, and the assets in section 31.

**Conventions**

| Convention | Meaning |
| --- | --- |
| `H1`, `F1`, `S2` … | Screen IDs. Use them as Figma frame name prefixes, e.g. `H1 Home – default – light` |
| `Dk…` | Component names. Use them as Figma component names |
| `color.primary` | Colour token. Never use a raw hex in a screen; use the style |
| `type.titleM` | Text style token |
| `space.l` | Spacing token (see section 6) |
| dp | Density-independent pixels (= pt on iOS). All sizes are in dp |
| EN / DE | English / German strings; design with both, German is about 30 % longer |
| **Free** / **Pro** | Tier of a tool. Pro tools show a Pro badge |

**Frame naming:** `<ID> <Screen name> – <state> – <theme> – <locale>`; example: `T2 Compress – options – dark – de`.

**Rule of thumb for decisions:** calm, document-first, honest. If a choice makes the app look busier, more "salesy" or less trustworthy, choose the other option.

---

## 2. Product summary

**Dokulo** is a mobile PDF toolkit and document scanner for iOS and Android. Everything runs on the phone: no uploads, no account, no watermark, no subscription (one-time Pro unlock).

**Primary users**

| Persona | Need | What they value in the UI |
| --- | --- | --- |
| Visa/rental/job applicant (expat in Germany) | Scan IDs and letters, merge, compress to upload limits, black out data | Speed, clear sizes, "under 2 MB" options, privacy reassurance |
| Freelancer / small business | Sign contracts, add passwords, compress invoices | Professional look, reliable signing, file organisation |
| Student | Scan notes, merge, summarise, translate | Fast scanner, AI summary, simple sharing |
| Privacy-conscious professional (lawyer, tax adviser, health) | Never upload client files | Visible on-device indicators, locked folder, true redaction |

**Feature scope (first release):** 30 PDF tools, a full scanner, a viewer with editing, files manager, locked folder, AI (summarise, ask, translate, smart split), workflows and batch. Not in scope: Office↔PDF conversion, full editing of existing PDF text, certificate e-signatures, cloud sync, accounts.

**UX principles (apply to every screen)**

1. No surprises: Pro badges visible before starting; free tasks never blocked at save.
2. The original is never overwritten unless the user chooses "Replace original".
3. Preview before commit; Undo after.
4. Smart defaults, easy override, "Apply to all pages", "Use as default".
5. Two taps to any tool.
6. Visible, concrete privacy ("Processed on this phone").
7. Honest progress with page counts and time left; cancel always available.
8. Files belong to the user: real files, never links.
9. One-handed: primary actions in the bottom third.
10. Stable layout: tools never move between versions.

---

## 3. Brand

| Item | Definition |
| --- | --- |
| Name | **Dokulo** (always one word, capital D only). From "Doku" (German for doc) + "lo" (local) |
| Tagline EN | All your PDF tools. Nothing uploaded. |
| Tagline DE | Alle PDF-Werkzeuge. Nichts wird hochgeladen. |
| Short promise (store, onboarding) | No uploads. No watermark. No subscription. / Keine Uploads. Kein Wasserzeichen. Kein Abo. |
| Personality | Calm, competent, precise, quietly friendly. Like a good Swiss tool, not a toy |
| Not | Playful mascot, loud gradients, "AI magic" sparkles everywhere, urgency or scarcity |
| Voice | Short sentences, plain words, exact numbers, sentence case, no exclamation marks, "you"/"du" |

### Logo and wordmark brief

- **Symbol:** a simple geometric mark combining a page (rectangle with a folded corner) and a subtle "local" cue (e.g. the fold forms a small house/shield shape, or the page sits inside a rounded square like a phone). Must read at 16 px and as a monochrome glyph (notification icon).
- **Wordmark:** "Dokulo" set in a geometric or humanist sans, medium-bold weight, slightly tight tracking (−1 %). Lowercase-friendly letterforms; the two "o" may echo the page corner.
- **Colours:** symbol in `color.primary` on light; white on primary for the app icon.
- **Deliver:** symbol, wordmark, lockup (horizontal), monochrome versions, minimum sizes, clear space (= height of the fold).

### Copy rules (summary; full deck in section 27)

| Do | Don't |
| --- | --- |
| "Compress 12 pages" | "OK", "Submit", "Go" |
| "1.9 MB (−77 %)" | "Much smaller!" |
| "Processed on this phone" | "Military-grade security" |
| "This PDF is locked. Enter the password." | "Error 0x12" alone |
| "Saved" | "Saved!" |
| Pro badge reads "Pro" | "PREMIUM ⭐", countdowns, fake discounts |

---

## 4. Foundations: colour

Colour is defined as tokens with a Light and a Dark value. Design every screen in both. The palette is calm: one blue primary, cool neutrals, a muted amber for Pro, and red only for destructive actions and redaction.

### 4.1 Core tokens

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `color.primary` | #2251E6 | #8AA8FF | Primary buttons, active tab, links, selection rings, progress |
| `color.onPrimary` | #FFFFFF | #0B1640 | Text and icons on primary |
| `color.primaryPressed` | #1A41BD | #A4BBFF | Pressed state of primary |
| `color.primaryContainer` | #E6ECFF | #1C2A5C | Selected chips, tile icon backgrounds, info banners, page chips |
| `color.onPrimaryContainer` | #0F2A8A | #DCE4FF | Text/icons on primaryContainer |
| `color.background` | #F7F8FA | #0F1115 | Screen background |
| `color.surface` | #FFFFFF | #181B21 | Cards, sheets, bars, dialogs |
| `color.surfaceRaised` | #FFFFFF | #1F232A | Sheets and menus above surface (dark mode needs the lift) |
| `color.surfaceSunken` | #EEF1F5 | #12151A | PDF canvas behind pages, input fields, search field |
| `color.outline` | #D9DEE6 | #2C313A | Card borders, dividers, thumbnail outlines |
| `color.outlineStrong` | #828C9B | #666E7B | Input borders at rest, segmented control border |
| `color.textPrimary` | #14171C | #EEF1F6 | Headings and body |
| `color.textSecondary` | #5A6270 | #A6AEBB | Meta text, help text, captions |
| `color.textDisabled` | #9AA1AD | #5F6672 | Disabled labels |
| `color.iconPrimary` | #2E3440 | #DDE2EA | Default icons |
| `color.iconSecondary` | #6B7380 | #9099A6 | Secondary icons, chevrons |
| `color.pro` | #8A5A0B | #F2C266 | Pro badge text and icon |
| `color.proContainer` | #FFF4DD | #3A2C10 | Pro badge background, Pro card tint |
| `color.success` | #117A4B | #5DD39E | Success icons, size-saved numbers |
| `color.successContainer` | #E3F5EC | #12301F | Success result card tint |
| `color.warning` | #B54708 | #FDB022 | Partial success, low memory, storage warnings |
| `color.warningContainer` | #FFF1E0 | #3A2410 | Warning banners |
| `color.danger` | #C8281E | #FF7A70 | Delete, destructive buttons, error text |
| `color.onDanger` | #FFFFFF | #14171C | Text and icons on a `color.danger` fill (Destructive button); dark in Dark for contrast |
| `color.dangerContainer` | #FDECEA | #3A1614 | Error banners, destructive confirm icon background |
| `color.scrim` | #14171C @ 40 % | #000000 @ 55 % | Behind sheets and dialogs |
| `color.cameraChrome` | #000000 @ 60 % | same | Scanner bars over the camera image |
| `color.onCamera` | #FFFFFF | same | Text/icons over the camera image |
| `color.quadFill` | #2251E6 @ 20 % | #8AA8FF @ 20 % | Detected document area in the camera |
| `color.quadStroke` | #2251E6 | #8AA8FF | Detected document edge, 2 dp |
| `color.pageWhite` | #FFFFFF | #FFFFFF | PDF page background (pages stay white in dark mode unless viewer night mode is on) |
| `color.redactBox` | #000000 | #000000 | Redaction boxes, always pure black |
| `color.focusRing` | #2251E6 | #8AA8FF | 2 dp keyboard/switch-access focus ring, 2 dp offset |
| `color.inverseSurface` | #14171C | #EEF1F6 | Toast background |
| `color.onInverseSurface` | #FFFFFF | #14171C | Text and icons on a toast |
| `color.inversePrimary` | #8AA8FF | #2251E6 | The toast's action ("Undo") |

### 4.2 Markup colours (stored inside PDFs, same in both themes)

| Token | Hex | Name shown to users (EN / DE) |
| --- | --- | --- |
| `markup.yellow` | #FFE066 | Yellow / Gelb |
| `markup.green` | #A8E6A1 | Green / Grün |
| `markup.blue` | #A7D3FF | Blue / Blau |
| `markup.pink` | #FFB3D1 | Pink / Pink |
| `markup.red` (pen) | #E5484D | Red / Rot |
| `markup.black` (pen) | #111111 | Black / Schwarz |
| `markup.ink` (signature) | #1A2B6D | Blue ink / Blaue Tinte |

### 4.3 Compare colours

| Token | Light | Dark | Label always shown |
| --- | --- | --- | --- |
| `compare.added` | #D9F2E2 bg, #117A4B text | #12301F bg, #5DD39E text | "Added" / "Hinzugefügt" + plus icon |
| `compare.removed` | #FDECEA bg, #C8281E text, strikethrough | #3A1614 bg, #FF7A70 text | "Removed" / "Entfernt" + minus icon |
| `compare.changed` | #FFF1E0 bg, #B54708 text | #3A2410 bg, #FDB022 text | "Changed" / "Geändert" + dot icon |

### 4.4 State overlays

| State | Overlay on any surface |
| --- | --- |
| Hover (tablets with pointer) | `color.textPrimary` @ 4 % |
| Pressed | `color.textPrimary` @ 8 % |
| Selected (list rows) | `color.primaryContainer` fill |
| Dragged item | `raised` elevation + 2 % scale up (pages in DkPageTray and DkPageGrid; tool tiles lift 1.04, §9 Tile reorder) |
| Disabled | 40 % opacity of the whole element |

### 4.5 Contrast requirements

The measured ratio of every pair is in `docs/design/contrast-audit.md` (DK-0035), generated by the token tests.

All text/background pairs must reach 4.5:1 (3:1 for text ≥ 18 dp bold or 24 dp regular, and for icons and borders that convey meaning). Check `color.pro` on `color.proContainer`, `color.textSecondary` on `color.surfaceSunken`, and every text on `color.cameraChrome`.

---

## 5. Foundations: typography

System fonts: **SF Pro** (iOS) and **Roboto** (Android). No custom text font in the app UI (the wordmark may use a brand font as an image). Numbers that show sizes, page counts, times and percentages use **tabular figures**.

| Token | Size / line height | Weight | Letter spacing | Use |
| --- | --- | --- | --- | --- |
| `type.display` | 28 / 34 | Bold 700 | −0.3 | Onboarding and paywall headlines |
| `type.titleL` | 22 / 28 | Bold 700 | −0.2 | Large screen titles (tab roots) |
| `type.titleM` | 18 / 24 | Semibold 600 | −0.1 | Small screen titles, sheet titles, tool name in T2 |
| `type.titleS` | 16 / 22 | Semibold 600 | 0 | Card titles, file names, section headers |
| `type.bodyL` | 16 / 24 | Regular 400 | 0 | Main text, AI answers, onboarding body |
| `type.bodyM` | 14 / 20 | Regular 400 | 0 | Descriptions, option help, list secondary lines |
| `type.labelL` | 15 / 20 | Semibold 600 | 0 | Buttons |
| `type.labelM` | 13 / 18 | Semibold 600 | 0.1 | Chips, tab labels, badges, segmented controls |
| `type.caption` | 12 / 16 | Regular 400 | 0.1 | Meta lines, legal, privacy line, page numbers under thumbnails |
| `type.mono` | 13 / 18 | Regular 400 (system mono: Menlo on iOS, the platform `monospace` on Android) | 0 | Page range inputs, error codes |
| `type.numberXL` | 32 / 38 | Bold 700, tabular | −0.3 | Result headline numbers ("1.9 MB") |

**Rules**

- Maximum line length for body text: 70 characters (tablets: constrain text columns to 640 dp).
- Truncation: file names truncate in the **middle** ("Mietvertrag_Mü…_2026.pdf") so the extension stays visible; titles truncate at the end.
- Dynamic Type / font scale: every screen must work at 200 %. Design the key screens at 100 % and 200 % (see section 32).
- German: allow buttons to wrap to two lines rather than truncate; never shrink text below the token size.

---

## 6. Foundations: spacing, grid, radius, elevation, borders

### 6.1 Spacing scale (4 dp base)

| Token | dp | Typical use |
| --- | --- | --- |
| `space.xxs` | 2 | Icon-to-badge offset |
| `space.xs` | 4 | Text to meta line, chip icon gap |
| `space.s` | 8 | Inside compact components, between chips |
| `space.m` | 12 | Card inner gaps, list row vertical padding |
| `space.l` | 16 | Screen side padding (phone), card padding |
| `space.xl` | 24 | Between sections, screen side padding (tablet) |
| `space.xxl` | 32 | Large section breaks, empty-state spacing |
| `space.xxxl` | 48 | Onboarding vertical rhythm |

### 6.2 Grid

| Device class | Side margin | Columns | Gutter |
| --- | --- | --- | --- |
| Phone (< 600 dp) | 16 | 4 | 12 |
| Small tablet (600–839) | 24 | 8 | 16 |
| Large tablet (≥ 840) | 24 + navigation rail 80 | 12 | 16 |

### 6.3 Radius

| Token | dp | Use |
| --- | --- | --- |
| `radius.xs` | 4 | Page thumbnails, small tags |
| `radius.s` | 8 | Inputs, segmented controls, image previews |
| `radius.m` | 12 | Cards, tool tiles, file cards, banners |
| `radius.l` | 16 | Buttons, dialogs |
| `radius.sheet` | 24 | Top corners of bottom sheets |
| `radius.pill` | 999 | Chips, badges, page pill, hint pill |

### 6.4 Elevation

| Token | Light | Dark |
| --- | --- | --- |
| `elevation.flat` | No shadow, 1 dp `color.outline` border | Same border |
| `elevation.raised` | Shadow 0 / 2 / 8, #14171C @ 8 % | No shadow; surface `color.surfaceRaised` + 1 dp outline |
| `elevation.floating` | Shadow 0 / 6 / 16, #14171C @ 14 % | Shadow 0 / 6 / 16, #000 @ 40 % + `color.surfaceRaised` |
| `elevation.overlay` (sheets, dialogs) | Shadow 0 / −2 / 24, #14171C @ 12 % | `color.surfaceRaised`, no shadow, 1 dp `color.outline`, scrim behind |

### 6.5 Borders and dividers

- Dividers: 1 dp `color.outline`, inset 16 dp from the left in lists with leading icons (aligned to text).
- Inputs: 1 dp `color.outlineStrong` at rest; 2 dp `color.primary` focused; 2 dp `color.danger` error.
- Selection ring on cards/thumbnails: 2 dp `color.primary`, 2 dp inside the radius.

---

## 7. Foundations: iconography

**Icon set:** Material Symbols **Rounded**, weight 400, grade 0, optical size 24, outline style; **filled** style only for the selected tab icon and toggled states (e.g. favourite). Licence Apache-2.0.

**Sizes:** 16 (inside chips/badges), 20 (inline with text, buttons), 24 (bars, list rows), 28 (inside tool tiles), 32 (scanner controls).

**Tool icons (one per tool, used everywhere: grid, T2 header, share picker, notifications, workflows).** Names are Material Symbols identifiers; the designer may propose custom glyphs in the same style if a symbol is unclear, but each tool keeps exactly one icon.

| Tool | Icon | Tool | Icon |
| --- | --- | --- | --- |
| Scan | `document_scanner` | Add page numbers | `format_list_numbered` |
| Merge PDF | `merge` | Add watermark | `branding_watermark` |
| Split PDF | `content_cut` | Crop pages | `crop` |
| Extract pages | `file_export` | Mark up | `edit` |
| Organize pages | `grid_view` | Fill form | `assignment` |
| Rotate PDF | `rotate_right` | Sign PDF | `signature` |
| Smart Split | `auto_awesome_mosaic` | Add password | `lock` |
| Image to PDF | `image` | Remove password | `lock_open` |
| PDF to images | `photo_library` | Black out (redact) | `visibility_off` |
| Web page to PDF | `language` | Compare PDFs | `compare` |
| Convert to PDF/A | `inventory_2` | Extract images & text | `unarchive` |
| PDF to text | `notes` | Batch | `dynamic_feed` |
| Compress PDF | `compress` | Workflows | `account_tree` |
| Repair PDF | `build` | Summarize | `summarize` |
| Make text searchable | `manage_search` | Ask this PDF | `forum` |
| Translate PDF | `translate` | | |

**UI icons**

| Purpose | Icon | Purpose | Icon |
| --- | --- | --- | --- |
| Home tab | `home` | Back | platform (iOS chevron `arrow_back_ios_new`, Android `arrow_back`) |
| Tools tab | `apps` | Close | `close` |
| Files tab | `folder` | More / overflow | `more_horiz` (iOS) / `more_vert` (Android) |
| Me tab | `person` | Search | `search` |
| Scan button | `document_scanner` | Share | `ios_share` (iOS) / `share` (Android) |
| Folder | `folder` | Delete | `delete` |
| Locked folder | `lock` | Rename | `drive_file_rename_outline` |
| Trash | `delete_sweep` | Move | `drive_file_move` |
| Info | `info` | Duplicate | `content_copy` |
| Sort | `sort` | List view / grid view | `view_list` / `grid_view` |
| New folder | `create_new_folder` | Add | `add` |
| Undo / redo | `undo` / `redo` | Pin / unpin | `push_pin` |
| Flash off / on / auto | `flash_off` / `flash_on` / `flash_auto` | Grid overlay | `grid_on` |
| Auto-capture | `motion_photos_auto` | Import photos | `photo_library` |
| Retake | `restart_alt` | Filters | `tune` |
| Night mode | `dark_mode` | Go to page | `pageview` |
| Privacy line | `smartphone` (with a small check) | Pro | `workspace_premium` |
| Success | `check_circle` | Warning | `warning` |
| Error | `error` | Offline | `cloud_off` |
| Download model | `download` | Pause | `pause` |
| Pen / highlighter / eraser | `edit` / `ink_highlighter` / `ink_eraser` | Text box / shape / note | `title` / `shapes` / `sticky_note_2` |
| Hand (pan) | `pan_tool` | Colour | `palette` |
| Password reveal | `visibility` / `visibility_off` | Biometrics | `fingerprint` / `face` (platform) |
| Settings | `settings` | Language | `language` |
| Licences | `gavel` | Contact | `mail` |

---

## 8. Foundations: illustrations and imagery

**Style:** simple line illustrations, 2 dp stroke in `color.iconPrimary`, one accent fill in `color.primaryContainer`, optional small `color.primary` details. Flat, no gradients, no people's faces (hands are fine). Size 120 × 120 dp for empty states, 200 × 160 dp for onboarding. Dark mode: stroke `color.iconPrimary` (dark), accent `color.primaryContainer` (dark).

| ID | Where | Subject |
| --- | --- | --- |
| ILL-01 | Onboarding 1 | Phone with an airplane-mode icon, a PDF page inside the phone, small check mark |
| ILL-02 | Onboarding 2 | A receipt-like page with "no watermark" (clean corner) and a single coin / one-time tag |
| ILL-03 | Onboarding 3 | Three small icons in a row: camera, folder, toolbox (used as card icons, not one picture) |
| ILL-04 | Home empty | Stack of two pages with a soft scan frame around them |
| ILL-05 | Files empty | Open folder with a page sliding in |
| ILL-06 | Folder empty | Empty folder outline |
| ILL-07 | Search no results | Magnifier over a blank page |
| ILL-08 | Trash empty | Empty bin with a check |
| ILL-09 | Locked folder intro | Folder with a lock and a fingerprint |
| ILL-10 | Camera permission denied | Camera with a small slash and a page |
| ILL-11 | AI model needed | Page with a small chip/processor and a download arrow |
| ILL-12 | AI first-use notice | Page with a speech bubble and a small "check" magnifier |
| ILL-13 | Device not eligible for AI | Phone with a small memory chip and a dashed line |
| ILL-14 | Damaged file | Page with a torn corner |
| ILL-15 | No signatures yet | Signature line with a pen |
| ILL-16 | No workflows yet | Three connected small cards |
| ILL-17 | Find documents in photos intro | Photo grid with two items highlighted as documents |
| ILL-18 | Paywall header | The Dokulo symbol with a small Pro ribbon (no confetti) |
| ILL-19 | Offline (Web to PDF only) | Globe with a small cloud-off icon |
| ILL-20 | Generic error | Page with a small warning triangle |

**Photography:** none in the app UI. Store screenshots may show device mockups with realistic but fictional documents (see section 31).

**Sample documents for mockups:** use fictional content only: "Mietvertrag Musterstraße 12", "Invoice INV-2026-014", "Lebenslauf Max Mustermann", "Finanzamt München – Bescheid 2025" (with fictional numbers). Never use real IBANs or IDs; use `DE00 0000 0000 0000 0000 00`.

---

## 9. Foundations: motion and haptics

| Token | Duration | Curve | Use |
| --- | --- | --- | --- |
| `motion.fast` | 120 ms | ease-out | Press states, chip toggles, switch thumbs |
| `motion.standard` | 220 ms | ease-in-out cubic | Sheets, pushes, tile reorder, expand/collapse |
| `motion.emphasis` | 320 ms | ease-out with slight overshoot | Success tick, Scan button press, capture thumbnail fly-in |
| `motion.reduced` | 120 ms cross-fade | linear | Replaces all movement when Reduce Motion is on |

**Signature motions to prototype**

| Motion | Description |
| --- | --- |
| Scan capture | White flash 80 ms over the viewfinder → captured page shrinks and flies (320 ms) into the page tray thumbnail; counter badge increments with a small pop |
| Success tick | Circle draws (200 ms), check draws (120 ms), number counts up from the old to the new value (400 ms) on result cards |
| Tile reorder | Picked tile lifts (scale 1.04, floating elevation); others slide (220 ms) |
| Page drop in grid | Insertion line 2 dp `color.primary` between thumbnails; drop settles with 220 ms |
| Sheet | Slides up 220 ms; detent changes 220 ms; scrim fades 120 ms |
| Mini job bar | Progress sheet shrinks into the bar (220 ms morph) |
| Viewer open | File thumbnail expands into the first page (hero, 220 ms) |

**Haptics:** selection tick on chip/tile/segment select; light impact on capture and drag-drop landing; medium impact on successful save; none on errors.

**Sound:** none (system camera shutter sound follows the OS).

---

## 10. Layout system, frames and breakpoints

### 10.1 Frames to design

| Frame | Size (dp) | Purpose |
| --- | --- | --- |
| iPhone standard | 393 × 852 | Main design frame |
| iPhone small | 375 × 667 (SE) | Check density, scanner controls, paywall fit |
| Android standard | 412 × 915 | Main Android check (status bar 24–32, gesture bar 24) |
| iPad / large tablet portrait | 820 × 1180 | Tablet adaptations |
| Large tablet landscape | 1366 × 1024 | Two-pane layouts |

### 10.2 System insets

| Area | iOS | Android |
| --- | --- | --- |
| Status bar | 54 (Dynamic Island devices) | 24–32 |
| Home indicator / gesture bar | 34 | 24 (gesture) or 48 (3-button) |
| Keyboard | Content above keyboard; sticky action bar rides on top of keyboard | Same |

### 10.3 Thumb zone (phones)

- Primary action: bottom 25 % of the screen, inside a sticky action bar or the bottom of a sheet.
- Destructive actions: never bottom-centre; place on the right of a dialog or in a menu.
- Top bar: navigation and secondary actions only.

### 10.4 Breakpoints

| Class | Width | Navigation | Tool grid columns | Notes |
| --- | --- | --- | --- | --- |
| Compact | < 600 | Bottom tab bar + Scan button | 4 (2 at ≥ 160 % text) | Phones |
| Medium | 600–839 | Bottom tab bar | 6 | Small tablets, foldables |
| Expanded | ≥ 840 | Navigation rail (left) with Scan as a large button at the top | 8 | Two-pane screens |

---

## 11. Components

Every component below must exist in the Figma library with all listed variants and states, in Light and Dark. Sizes in dp.

### 11.1 Buttons

#### DkButton

| Property | Large | Default | Compact |
| --- | --- | --- | --- |
| Height | 52 | 44 | 36 |
| Horizontal padding | 24 | 20 | 14 |
| Icon size / gap | 20 / 8 | 20 / 8 | 16 / 6 |
| Text style | `type.labelL` | `type.labelL` | `type.labelM` |
| Radius | `radius.l` | `radius.l` | `radius.s` |
| Min width | 120 | 96 | 64 |

| Variant | Fill | Text/icon | Border |
| --- | --- | --- | --- |
| Primary | `color.primary` | `color.onPrimary` | none |
| Secondary | transparent | `color.primary` | 1 dp `color.outlineStrong` |
| Tertiary (text) | transparent | `color.primary` | none |
| Tonal | `color.primaryContainer` | `color.onPrimaryContainer` | none |
| Destructive | `color.danger` | `color.onDanger` | none |
| Destructive secondary | transparent | `color.danger` | 1 dp `color.danger` |
| On camera | #FFFFFF @ 16 % | `color.onCamera` | none |

| State | Visual |
| --- | --- |
| Default | As above |
| Pressed | Primary → `color.primaryPressed`; others → pressed overlay; scale 0.98 |
| Focused | 2 dp `color.focusRing` with 2 dp offset |
| Disabled | 40 % opacity, no shadow |
| Loading | Label stays; leading icon replaced by a 20 dp spinner in text colour; width does not change |

Content rules: verb + object (+ number). One Primary per screen. Full width inside `DkActionBar` and sheets on phones.

#### DkIconButton

44 × 44 hit area, 24 icon. Variants: Plain (icon `color.iconPrimary`), Tonal (36 circle `color.primaryContainer`, icon `color.onPrimaryContainer`), On camera (40 circle #000 @ 35 %, icon white). States: default, pressed (overlay), selected (filled icon, tonal background), disabled. Always has a tooltip/label.

#### DkScanButton

- 64 × 64 circle, `color.primary`, icon `document_scanner` 28 in `color.onPrimary`, `elevation.floating`.
- Sits centred in the tab bar, raised so its centre is 12 dp above the tab bar's top edge; a 4 dp `color.background` ring separates it from the bar.
- Label "Scan" / "Scannen" below the bar line in `type.labelM`, `color.primary`.
- Pressed: scale 0.94 → 1.0 with `motion.emphasis`. Long-press: mode menu (popover above) with Document, ID card, Book, Batch, Import photos.

#### DkShutterButton (scanner)

72 dp outer ring (4 dp white), 58 dp inner white disc; pressed inner disc shrinks to 52. Auto-capture countdown: a `color.quadStroke` arc fills the outer ring over 0.5 s. Disabled (no permission): 40 % opacity.

### 11.2 Tiles and cards

#### DkToolTile (grid)

| Property | Value |
| --- | --- |
| Size | Fills grid cell; min 76 wide; height 96 |
| Icon container | 48 × 48, `radius.m`, `color.primaryContainer` |
| Icon | 28, `color.onPrimaryContainer` |
| Label | `type.labelM`, `color.textPrimary`, centred, max 2 lines, 4 dp below icon container |
| Pro badge | `DkProBadge` small, top-right of the icon container, offset −4 / −4 |
| New dot | 8 dp `color.primary` dot top-left, shown 14 days after a tool is added |
| Pressed | Overlay on the whole tile, `radius.m` |
| Focus | Focus ring around the tile |

Do not grey out Pro tiles; they look identical to free ones apart from the badge.

#### DkToolRow (list variant: share picker, search)

56 tall; 40 × 40 icon container left; name `type.titleS`; optional one-line description `type.bodyM` `color.textSecondary`; Pro badge right; chevron.

#### DkFileCard

| Variant | Layout |
| --- | --- |
| List row | Height 72; thumbnail 44 × 56 (`radius.xs`, 1 dp outline) at left; 12 gap; name `type.titleS` (middle truncation); meta `type.caption` `color.textSecondary` "2.4 MB · 12 pages · Today 14:32"; trailing more button |
| Grid card | Width = column; thumbnail area 3:4 ratio on `color.surfaceSunken` with the page centred; below: name (2 lines max) and meta (1 line); more button overlays the thumbnail's top-right (28 tonal circle) |
| Compact (Home recents carousel, optional) | 120 wide, thumbnail 120 × 150, name 1 line |

| State | Visual |
| --- | --- |
| Default | `color.surface`, `elevation.flat` for grid; list rows have no card background, only dividers |
| Pressed | Pressed overlay |
| Selected (multi-select) | 24 check circle (filled `color.primary` with white check) at top-left of thumbnail; row tint `color.primaryContainer` |
| Unselected in multi-select | 24 empty circle 2 dp `color.outlineStrong` |
| Locked file | Thumbnail blurred (16 dp blur) with a 20 lock icon centred |
| Processing | 2 dp progress line along the bottom of the row/card in `color.primary` |
| Encrypted PDF | Small 16 lock icon after the meta text |
| Has no text (scan) | No special mark (avoid clutter) |

Thumbnail for non-PDF files: images show the image; HTML shows a `language` icon page; folders use `DkFolderCard`.

#### DkFolderCard

List row 64 tall: 40 folder icon (tinted with the folder colour tag, default `color.iconSecondary`), name `type.titleS`, meta "8 files" `type.caption`. Grid: 3:4 tile with a large folder glyph. Folder colour tags: Blue #2251E6, Green #13804F, Orange #B54708, Red #C8281E, Purple #6E4AD8, Grey #6B7380.

#### DkResultCard

| Part | Spec |
| --- | --- |
| Container | `color.successContainer` tint (warning tint for partial), `radius.m`, padding 16 |
| Icon | 32 `check_circle` `color.success` (or `warning`) top-left |
| Headline | `type.numberXL` e.g. "1.9 MB" with secondary part "(−77 %)" in `type.titleM` `color.success` |
| Sub line | `type.bodyM` "From 8.4 MB · 12 pages" |
| Before/after toggle | Segmented control "Before · After" (only for Compress, Watermark, Crop, Black out) |
| Preview | Thumbnail strip (64 tall) below the card; tap opens preview |

Headline per tool is listed in section 21.

#### DkLevelCard

Row of 3 equal cards (stack vertically below 360 dp width or at ≥ 160 % text). Each: padding 12, `radius.m`, 1 dp `color.outline`; title `type.titleS` ("Recommended"), estimate `type.titleM` tabular ("≈ 1.9 MB"), description `type.caption` ("Good for email and uploads"). Selected: 2 dp `color.primary` border, 20 check circle top-right, background `color.primaryContainer` @ 50 %.

#### DkModelCard

| Part | Spec |
| --- | --- |
| Header | Model name `type.titleS` + quality badge pill ("Best quality" / "Fast" / "Small") |
| Role line | `type.bodyM` "Summaries and questions" |
| Facts row | `type.caption`: "1.3 GB · needs 3 GB memory · Apache-2.0" (licence is a link) |
| Action | Right-aligned: Download (secondary compact) / Pause + progress ring with % / Delete (tertiary danger) / "Not available on this phone" text |
| Progress | Linear bar under the facts row with "420 MB of 1.3 GB · Wi-Fi" |

#### DkContinueCard

Full-width card `color.primaryContainer` @ 60 %, `radius.m`, padding 12; leading 32 icon (scan or tool icon); title `type.titleS`; sub `type.caption`; primary compact button right ("Continue" / "Open"); close × top-right (dismiss).

#### DkProCard

Card `color.proContainer`, `radius.m`, padding 16; `workspace_premium` 24 in `color.pro`; title `type.titleS` "Unlock every tool, for good"; sub `type.bodyM`; tertiary button "See Pro"; close ×. No animation.

#### DkSettingsRow

Height 56 (single line) / 72 (with description). Leading 24 icon (optional), title `type.bodyL`, description `type.bodyM` `color.textSecondary`, trailing: switch / value text + chevron / chevron. Grouped in inset cards (`radius.m`, `color.surface`) with section header `type.labelM` `color.textSecondary` uppercase-free, sentence case, 24 above / 8 below.

### 11.3 Badges, chips, indicators

| Component | Spec |
| --- | --- |
| `DkProBadge` | Pill; height 20 (small 16); padding 6; `workspace_premium` 12 icon + "Pro" `type.labelM`; the word "Pro" is always shown, never the icon alone; colours `color.pro` on `color.proContainer` |
| `DkChip` filter | Height 32; padding 12; `radius.pill`; unselected: 1 dp `color.outlineStrong`, text `color.textPrimary`; selected: fill `color.primaryContainer`, text `color.onPrimaryContainer`, leading check 16 |
| `DkChip` choice | Same sizes; single-select group; selected fill `color.primary`, text `color.onPrimary` |
| `DkNextChip` | Height 36; leading tool icon 18; label tool name; 1 dp `color.outline`; `color.surface`; used on result screens; trailing arrow 16 |
| `DkPageChip` | Height 22; "p. 3" / "S. 3" `type.labelM`; `color.primaryContainer`; tap target expanded to 44 |
| `DkPrivacyLine` | `smartphone` 16 icon + text `type.caption` `color.textSecondary` "Processed on this phone"; left-aligned under titles |
| `DkStatusDot` | 8 dp circle; `color.primary` (new), `color.warning` (unsaved), animated pulse for running jobs (static with reduced motion) |
| `DkCountBadge` | Min 18 tall pill, `color.primary` fill, `color.onPrimary` `type.labelM` (white in Light; Dark's light primary needs the dark `onPrimary`, white would be 2.3:1); on scanner tray and tab icons |
| `DkHintPill` (camera) | Height 32, padding 14, `radius.pill`, `color.cameraChrome`, text `type.labelL` white |
| `DkPagePill` (viewer) | Height 28, `radius.pill`, `color.surfaceRaised` @ 92 % with `elevation.raised`, "3 / 12" `type.labelM` tabular |

### 11.4 Inputs and controls

| Component | Spec |
| --- | --- |
| `DkTextField` | Label above `type.labelM` `color.textSecondary`; field 48 tall, `radius.s`, `color.surfaceSunken`, 1 dp `color.outlineStrong`; text `type.bodyL`; placeholder `color.textDisabled`; helper/error `type.caption` 4 below; error: 2 dp `color.danger` + `error` 16 icon + message in `color.danger`; clear button (×) when filled |
| `DkPasswordField` | `DkTextField` + trailing reveal toggle; optional strength meter: 4 segments (4 dp tall) + label "Weak / OK / Strong" (`color.danger` / `color.warning` / `color.success`) |
| `DkRangeField` | `DkTextField` with `type.mono`; trailing "Pick pages" icon button; example placeholder "1–3, 5, 8–end" |
| `DkSearchField` | 40 tall, `radius.s`, `color.surfaceSunken`, leading `search` 20, placeholder `type.bodyL`, trailing clear; optional trailing filter button |
| `DkSwitch` | Platform switch look (iOS 51 × 31; Android Material 3), on colour `color.primary` |
| `DkSegmented` | 2–4 segments; height 36; `radius.s`; container `color.surfaceSunken`; selected segment `color.surface` with `elevation.raised`, text `type.labelM` |
| `DkSlider` | Track 4 dp (`color.outline`; active `color.primary`), thumb 20 white with `elevation.raised`; value label right of the title ("30 %") |
| `DkStepper` | − value + (for start number, N pages); buttons 36, value `type.titleS` tabular |
| `DkDropdown` | Looks like a `DkTextField` with trailing chevron; opens a menu (phones: sheet with options for > 5 items); an option may end in a trailing item, e.g. a language's download size ("18 MB") |
| `DkOptionRow` | Container for a control: title `type.titleS`, help `type.bodyM` `color.textSecondary` (max 2 lines), control right (switch) or below (segmented, slider, chips, fields); vertical padding 12; dividers between rows |
| `DkPositionPicker` | 120 × 160 page diagram (`color.pageWhite`, outline) with 6 targets (top/bottom × left/centre/right) as 28 circles; selected filled `color.primary`; plus "Centre" for watermark |
| `DkColorRow` | Swatches 32 circles with 2 dp outline; selected: 3 dp `color.primary` ring + check; last item "Custom" opens a simple hue/brightness picker |
| `DkCheckboxRow` | 24 checkbox + label `type.bodyL` + optional count badge right ("3"; `DkCountBadge`, muted `color.iconSecondary` while unchecked) |
| `DkRadioRow` | 24 radio + label + optional description |
| `DkPinPad` | 6 dot indicators (12 dp) + 3×4 keypad (keys 72 circles, `type.titleL`), biometric key bottom-left, delete bottom-right |

### 11.5 Pages and thumbnails

| Component | Spec |
| --- | --- |
| `DkPageThumb` | Page rendered on `color.pageWhite`, `radius.xs`, 1 dp `color.outline`, `elevation.flat`; page number below `type.caption` centred; selected: 2 dp `color.primary` ring + 20 check circle top-right; loading: `color.surfaceSunken` block with page number; rotated pages show rotated content |
| `DkPageTray` | Horizontal strip, height 88 (thumb 56 × 72 + number); 8 gap; trailing "+" tile (56 × 72, dashed 1 dp `color.outlineStrong`, `add` icon); current page has primary ring; drag to reorder |
| `DkPageGrid` | Grid of `DkPageThumb`; default 3 columns on phones (pinch 2–6); 12 gutter; insertion line 2 dp `color.primary` with 8 dp end caps during drag |
| `DkCropOverlay` | Outside area darkened (#000 @ 50 %); quad border 2 dp `color.quadStroke`; 4 corner handles (24 circles, white fill, 2 dp primary stroke, 44 hit) and 4 edge handles (24 × 8 pills); buttons below the image: Auto · Full page · Reset |
| `DkMagnifier` | 96 circle, 2 dp white border + `elevation.floating`, shows 4× zoom of the area under the finger, with crosshair (1 dp primary); positioned 80 above the finger (flips below near the top edge) |
| `DkRedactionBox` | Edit state: black fill @ 85 % with 1 dp white inner border, category label tag above (`type.caption` white on #000, "IBAN"), corner handles, delete × (20 circle); applied state: solid #000, no label |
| `DkSignatureStamp` | Placed signature image with dashed 1 dp `color.primary` bounding box while selected, 4 corner handles, delete ×; unselected: no box |

### 11.6 Bars

| Component | Spec |
| --- | --- |
| `DkTopBar` small | Height 56 (+ status bar); back/close left; title `type.titleM` centred on iOS, left-aligned on Android; up to 2 action icons + overflow right; `color.surface` with hairline bottom border when content scrolls under |
| `DkTopBar` large | Collapsing: expanded 112 with title `type.titleL` left at bottom; collapses into small bar on scroll; actions stay top-right |
| `DkTopBar` editing | Cancel (tertiary text) left, title centre ("Editing"), Done (primary text, `type.labelL` bold) right |
| `DkTabBar` | Height 64 (+ home indicator); `color.surface` with top hairline; 4 items + centre gap for `DkScanButton`; item: icon 24 + label `type.labelM`; selected: filled icon + `color.primary` label; unselected `color.iconSecondary` / `color.textSecondary` |
| `DkNavRail` (tablets) | Width 80; Scan button (56 rounded-square) at top; 4 destinations below with icon + label |
| `DkActionBar` | Sticky bottom container, `color.surface`, top hairline, padding 16 / 12, safe area below; holds 1 primary full-width button (optionally a secondary above or to the left); optional caption line above the button ("About 1.8 MB · 12 pages", or "Free try · Pro unlocks unlimited use") |
| `DkSelectionBar` | Replaces tab bar in multi-select: 4–5 icon+label actions; header shows "3 selected" with Cancel and Select all |
| `DkMiniJobBar` | 48 tall, inset 8 from screen edges, `radius.m`, `color.surfaceRaised`, `elevation.floating`; leading tool icon, text "Compressing · 18 of 40" `type.labelM`, progress 2 dp along the bottom, trailing expand chevron; sits above the tab bar / action bar |
| `DkToolStrip` (edit mode) | Height 64; `color.surface`; 7 tool buttons (icon 24 + label `type.caption`) scrollable; selected tool: tonal circle behind icon; Undo/Redo at the far right separated by a divider |
| `DkViewerBar` | Bottom bar in viewer: 5 actions (icon + label), `color.surface` @ 94 % with blur; auto-hides |
| `DkCameraTopBar` | 56 tall on `color.cameraChrome`: close, flash, auto-capture, grid, settings (white icons) |

### 11.7 Sheets, dialogs, menus, toasts, banners

| Component | Spec |
| --- | --- |
| `DkSheet` | `color.surfaceRaised`; top radius `radius.sheet`; grab handle 36 × 4 `color.outlineStrong` 8 below top; title `type.titleM` 16 below handle, left-aligned, with optional close ×; content padding 16; detents: small (auto height), medium (50 %), large (92 %); sticky action area at bottom when needed; scrim `color.scrim` |
| `DkActionSheet` | `DkSheet` with a header (thumbnail 40 + name + meta) and `DkSettingsRow`-style rows (icon + label), destructive rows in `color.danger` at the bottom |
| `DkConfirmDialog` | Width min(320, screen − 48); `radius.l`; padding 24; optional 40 icon circle (`color.dangerContainer` with `color.danger` icon for destructive); title `type.titleM`; body `type.bodyM`; buttons right-aligned: Cancel (tertiary) + Action (primary or destructive); stacked full-width if labels don't fit |
| `DkMenu` (popover) | `color.surfaceRaised`, `radius.m`, `elevation.floating`, item height 44, icon 20 + label `type.bodyL`, dividers between groups |
| `DkToast` | Max width 560; 48 tall; `radius.m`; inverse colours (light theme: #14171C bg, white text; dark theme: #EEF1F6 bg, #14171C text); text `type.bodyM`; optional action `type.labelL` in `color.primary` (dark-on-light inverse: #8AA8FF / #2251E6); bottom placement above bars; 4 s |
| `DkBanner` | Inline in content; `radius.m`; padding 12; leading icon 20; text `type.bodyM`; optional action (tertiary compact); variants: info (`color.primaryContainer`), warning, error, Pro (`color.proContainer`) |
| `DkProgressSheet` | Small detent sheet; tool icon 40 tonal; title `type.titleM` "Compressing Mietvertrag.pdf"; progress bar 6 dp `radius.pill` with % right; line `type.bodyM` "Page 18 of 40 · about 20 s left"; buttons: Cancel (secondary) + Keep working (primary) |
| `DkEmptyState` | Centred column: illustration 120, 24 gap, title `type.titleM`, 8 gap, body `type.bodyM` `color.textSecondary` (max 280 wide), 24 gap, primary button, 12 gap, optional secondary button |
| `DkSkeleton` | Blocks in `color.surfaceSunken`, `radius.xs`; gentle opacity pulse 1.2 s (static if reduced motion) |
| `DkLoadingSpinner` | Platform activity indicator, 20/32 sizes, `color.primary` |

### 11.8 Editor and AI components

| Component | Spec |
| --- | --- |
| `DkMarkupBar` | Floating pill 44 tall, `color.surfaceRaised`, `elevation.floating`, `radius.pill`; items: Copy · Highlight · Underline · Strike · Ask AI (icon 20 + label `type.labelM`); positioned 8 above selection, flips below |
| `DkToolOptionsSheet` | Small sheet for the selected markup tool: `DkColorRow`, thickness slider with live stroke preview (a 120 × 24 sample line), opacity slider (highlighter), font size stepper (text) |
| `DkSignaturePad` | Full screen landscape: top bar Cancel / title "Add signature" / Save; segmented Draw · Type · Image; canvas `color.pageWhite` with a baseline 1 dp `color.outlineStrong` at 70 % height and hint "Sign on the line" in `type.caption`; ink colour toggle (Black / Blue ink); Clear (tertiary) bottom-left |
| `DkSignatureCard` | 160 × 72 card with the signature image on white, `radius.s`, outline; long-press: Delete |
| `DkChatBubble` | User: right-aligned, `color.primaryContainer`, `radius.m` (bottom-right 4), `type.bodyL`; AI: left-aligned, `color.surface` with outline, contains text, bold numbers, `DkPageChip`s; streaming caret 2 × 16 `color.primary` blinking (static with reduced motion) |
| `DkSuggestionChip` | Ask empty state: full-width outline chip, `type.bodyM`, `forum` 16 icon, max 2 lines |
| `DkAIFooter` | `type.caption` `color.textSecondary`: "On this phone · Gemma 4 E2B · AI can make mistakes" |
| `DkSplitMarker` | Vertical marker between page thumbnails in Smart Split: 2 dp `color.primary` line + scissor `content_cut` 16 in a 24 circle + reason tag (`type.caption` pill, `color.primaryContainer`) |
| `DkDiffRow` | Compare change list item: change type tag (Added/Removed/Changed with colour + icon), text excerpt `type.bodyM` (2 lines), page chip |
| `DkDetectionGroup` | Redaction category row: checkbox + category icon + name ("IBAN") + count + expand chevron; expanded: list of found items (masked preview "DE89 •••• •••• 3000") each with page chip and its own checkbox |

---

## 12. Interaction patterns

### 12.1 Selection mode (Files, Organize, Extract, PDF to images)

Long-press an item → selection mode: top bar shows "1 selected", Cancel (left), Select all (right); tab bar replaced by `DkSelectionBar`; tapping items toggles; haptic tick on each.

### 12.2 Drag and drop

Long-press (300 ms) lifts the item (scale 1.04, floating shadow); others make room; auto-scroll when within 48 dp of the edges; drop with light haptic; Undo via toast for moves between folders.

### 12.3 Swipe actions (Files list rows)

Swipe left reveals Share (`color.primary`) and Delete (`color.danger`) buttons, each 80 wide, icon + label; full swipe = Delete with toast "Moved to Recently deleted · Undo".

### 12.4 Confirmations

Use `DkConfirmDialog` only for: delete forever, empty trash, apply redaction, replace original, discard a scan, discard edits, cancel a job running > 30 s, remove a saved signature. Everything else uses Undo toasts.

### 12.5 Pro gating

1. Pro tools always show `DkProBadge` (tile, T2 header).
2. First run: T2 action bar caption "Free try · Pro unlocks unlimited use"; the run is complete and saved normally.
3. Next runs: tapping the action button opens the paywall sheet (X3) before work starts.
4. After purchase: the sheet closes and the run starts automatically.

### 12.6 Undo

Toast with "Undo" for: delete (to trash), move, page delete in review, organize operations, replace original (10 s), unpin tool.

### 12.7 Keyboard

Sheets with text fields move above the keyboard; the primary action stays visible above the keyboard (action bar rides the keyboard). "Next field" accessory bar for forms: Previous · Next · Done.

### 12.8 Pull to refresh

Only on Home and Files (re-scans the app folder). Standard platform spinner.

---

## 13. App shell and navigation

### 13.1 Structure

| Position | Destination | Icon | Label EN / DE |
| --- | --- | --- | --- |
| 1 | Home (H1) | `home` | Home / Start |
| 2 | Tools (T1) | `apps` | Tools / Werkzeuge |
| Centre | Scan (S1) raised button | `document_scanner` | Scan / Scannen |
| 3 | Files (F1) | `folder` | Files / Dateien |
| 4 | Me (M1) | `person` | Me / Ich |

Full-screen flows hide the tab bar: Scanner (S1, S2), Viewer (V1, V2), Organize pages (P1), Tool shell (T2, T3), Onboarding, Signature pad.

### 13.2 Platform differences to design

| Element | iOS | Android |
| --- | --- | --- |
| Back | Chevron + previous title (≤ 12 chars) or chevron only | Arrow |
| Title alignment (small bar) | Centred | Left |
| Overflow icon | `more_horiz` | `more_vert` |
| Share icon | `ios_share` | `share` |
| Switches | iOS style | Material 3 style |
| Dialogs | Same `DkConfirmDialog` design on both (custom) | Same |
| Sheets | Custom `DkSheet` on both | Same |
| Date/time pickers | System | System |
| Biometric icon | Face ID `face` / Touch ID `fingerprint` | `fingerprint` |

### 13.3 Global overlays (design once, show on top of any screen)

- `DkMiniJobBar` above the tab bar or action bar while jobs run; "3 jobs running" when several.
- `DkToast` queue above the mini bar.
- App lock screen (see 16.4) covering everything on resume after the timeout.
- App-switcher privacy cover: `color.background` with the Dokulo symbol centred (when locked content is open or "Hide previews" is on).

### 13.4 Transitions

| Move | Transition |
| --- | --- |
| Tab switch | Instant cross-fade 120 ms |
| Push (pages) | iOS: slide from right; Android: shared-axis X |
| Scanner open / close | Slide up / down 220 ms |
| Viewer open from a file | Hero: thumbnail expands to the first page |
| Sheets | Slide up; scrim fade |
| Result after progress | Cross-fade 220 ms |

---

## 14. Screens: launch and onboarding

### 14.1 Launch screen

- Background `color.background`; Dokulo symbol 72 dp centred; no text, no spinner. Matches the native splash on both platforms (Android 12+ splash: symbol on background, no branding image).

### 14.2 Onboarding (shown once; `/welcome`)

Common layout per screen: top-right "Skip" (tertiary); illustration 200 × 160 centred at 22 % from top; headline `type.display` centred, max 2 lines, 24 below illustration; body `type.bodyL` `color.textSecondary` centred, max 3 lines, 12 below; page dots (8 dp, active 24 × 8 pill `color.primary`) 32 above the button; primary button full width "Next" in the action area.

| Screen | Illustration | Headline EN | Headline DE | Body EN | Body DE | Button |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | ILL-01 | All your PDF tools. Nothing uploaded. | Alle PDF-Werkzeuge. Nichts wird hochgeladen. | Scan, merge, compress, sign and more – right on this phone. | Scannen, zusammenfügen, verkleinern, unterschreiben und mehr – direkt auf diesem Handy. | Next / Weiter |
| O2 | ILL-02 | No watermark. No subscription. | Kein Wasserzeichen. Kein Abo. | Most tools are free with no limits. Pro is a one-time unlock. | Die meisten Werkzeuge sind kostenlos und unbegrenzt. Pro schaltest du einmalig frei. | Next / Weiter |
| O3 | none (cards) | What do you want to do first? | Womit möchtest du anfangen? | — | — | (cards act as buttons) |

**O3 cards:** three full-width cards (72 tall, `radius.m`, outline, 16 padding): leading 40 tonal icon, title `type.titleS`, sub `type.caption`:

| Card | Icon | Title EN / DE | Sub EN / DE | Goes to |
| --- | --- | --- | --- | --- |
| 1 | `document_scanner` | Scan a document / Dokument scannen | Use the camera / Mit der Kamera | S1 |
| 2 | `folder_open` | Open a PDF / PDF öffnen | From Files or another app / Aus Dateien oder einer anderen App | System picker → V1 |
| 3 | `apps` | Look around / Erst mal umsehen | See all tools / Alle Werkzeuge ansehen | H1 |

Frames: O1, O2, O3 × light/dark × EN/DE; O1 at 375 × 667.

---

## 15. Screens: Home and Tools

### 15.1 H1 · Home

**Purpose:** resume recent work and start common tasks in one tap.

**Layout (top to bottom, phone 393 wide)**

| # | Region | Spec |
| --- | --- | --- |
| 1 | Large top bar | Title "Dokulo" (`type.titleL`; may use the wordmark instead, 24 tall); actions: `search` (opens Files search), `settings` (opens M3) |
| 2 | Privacy line | `DkPrivacyLine` "Everything stays on this phone" 4 below title |
| 3 | Continue card (conditional) | `DkContinueCard`, 16 below privacy line |
| 4 | Section header | "Your tools" `type.titleS` left; "Edit" tertiary compact right; 24 above |
| 5 | Pinned tools grid | 4 columns × 2 rows of `DkToolTile`; 12 gutters |
| 6 | Open a file | `DkButton` secondary default, full width, leading `folder_open`, "Open a file"; 16 above |
| 7 | Section header | "Recent" + "See all" tertiary; 24 above |
| 8 | Recent list | Up to 20 `DkFileCard` list rows |
| 9 | Pro card (conditional) | `DkProCard` after the 5th recent row (free users, max once a month) |
| 10 | Bottom | `DkTabBar` with `DkScanButton`; `DkMiniJobBar` above when jobs run |

**Default pinned tools (8):** Merge PDF, Compress PDF, Sign PDF, Image to PDF, Add password, Black out, Make text searchable, Summarize. (Scan is always the centre button, so it is not pinned.)

**States to design**

| State | Spec |
| --- | --- |
| First launch | Rows 1–6 + empty state replacing 7–8: ILL-04, title "Your scans and PDFs will appear here", body "Scan a document or open a PDF to get started.", buttons "Scan a document" (primary), "Open a file" hidden here (already above) |
| Default | 6 recent files with mixed thumbnails (letter, invoice, ID scan, photo-based PDF) |
| Continue: unsaved scan | Card: scan icon, "Scan of 6 pages not saved", sub "Started today 14:32", button "Continue" |
| Continue: job finished | Card: tool icon, "Compressed Mietvertrag.pdf", sub "1.9 MB (−77 %)", button "Open" |
| Edit pinned tools | Tiles jiggle-free: each tile gets a 20 minus badge (top-left, `color.danger`); drag handles implied by long-press; header button "Done"; an "Add tool" tile (dashed outline, `add` icon) appears in the next free slot; tapping it opens a sheet listing all tools (`DkToolRow`) |
| Job running | Mini bar visible above tab bar |
| Pro card visible | As in table |
| Find documents card | After 7 days: `DkBanner` info style "Find documents in your photos?" with "Look now" and × |

**Interactions:** tap tile → T2; long-press tile → `DkMenu`: Unpin, About this tool; tap file → V1; long-press file → file action sheet (16.3); pull to refresh.

### 15.2 T1 · Tools

**Layout**

| # | Region | Spec |
| --- | --- | --- |
| 1 | Large top bar | "Tools" / "Werkzeuge" |
| 2 | Search | `DkSearchField` placeholder "Search tools" / "Werkzeuge suchen" |
| 3 | Category chips | Horizontal scroll of `DkChip` choice: All · Organize · Convert · Optimize · Edit · Security · AI · Automation (DE: Alle · Ordnen · Umwandeln · Optimieren · Bearbeiten · Sicherheit · KI · Automatisierung); tapping scrolls to the section; selected follows scroll |
| 4 | Sections | Section header `type.titleS` + count `type.caption` ("5 tools"); grid of `DkToolTile`, 4 columns |

**Sections and order**

| Section | Tools in order |
| --- | --- |
| Organize / Ordnen | Merge PDF, Split PDF, Extract pages, Organize pages, Rotate PDF, Smart Split (Pro) |
| Convert / Umwandeln | Image to PDF, PDF to images, Web page to PDF, Convert to PDF/A (Pro), PDF to text (Pro) |
| Optimize / Optimieren | Compress PDF, Repair PDF, Make text searchable (Pro) |
| Edit / Bearbeiten | Add page numbers, Add watermark, Crop pages, Mark up, Fill form (Pro) |
| Security / Sicherheit | Sign PDF, Add password, Remove password, Black out (Pro), Compare PDFs (Pro) |
| AI / KI | Summarize (Pro), Ask this PDF (Pro), Translate PDF (Pro) |
| Automation / Automatisierung | Extract images & text, Batch, Workflows (Pro) |

**Search states:** typing filters to a `DkToolRow` list (name + one-line description); synonyms match (e.g. "shrink", "smaller", "verkleinern" → Compress). No result: ILL-07 small (80), "No tool for “{query}”", "Try “compress” or “sign”."

**Tool descriptions (used in search rows and "About this tool")** are listed per tool in section 21.

---

## 16. Screens: Files and locked folder

### 16.1 F1 · Files (root)

| # | Region | Spec |
| --- | --- | --- |
| 1 | Large top bar | "Files" / "Dateien"; actions: view toggle (`view_list`/`grid_view`), `sort`, `create_new_folder` |
| 2 | Search | `DkSearchField` "Search names and text" / "Namen und Text durchsuchen" |
| 3 | Special rows | Inset card with two rows: "Locked folder" (`lock`, chevron) and "Recently deleted" (`delete_sweep`, count "3", chevron) |
| 4 | Folders | Header "Folders" + list/grid of `DkFolderCard` |
| 5 | Files | Header "Files" + list/grid of `DkFileCard` |
| 6 | Bottom | Tab bar, or `DkSelectionBar` in selection mode |

**Sort menu (`DkMenu`):** Date modified (default) · Name · Size · Date created; second group: Ascending / Descending (checkmarks).

**Folder screen (pushed within the tab):** small top bar with folder name and back; breadcrumb row under the bar (`type.caption`, e.g. "Files › Taxes › 2026", each part tappable); same content layout without special rows; overflow: Rename folder, Colour, Delete folder.

**Selection bar actions:** Share · Move · Merge (≥ 2 PDFs) · Compress · More (Delete, Duplicate, Move to locked folder, Run a tool…).

**States**

| State | Spec |
| --- | --- |
| Empty root | ILL-05, "No files yet", "Scan a document or open a PDF to get started.", Scan a document / Open a file |
| Empty folder | ILL-06, "This folder is empty", "Move files here from Files or save tool results here.", "Move files here" |
| Loading | 6 skeleton rows |
| Grid view | 2 columns on phones |
| Selection mode | 3 items selected, bar visible |
| Drag file to folder (grid) | Folder card highlighted with 2 dp primary ring when hovered |

### 16.2 Search results

Search field focused at top, keyboard open. Results in two groups:

| Group | Row content |
| --- | --- |
| "Names" / "Namen" | `DkFileCard` rows with the matched part of the name in bold |
| "Text inside files" / "Text in Dateien" | `DkFileCard` row + one extra line `type.bodyM` showing the matching sentence with the term highlighted (`markup.yellow` background) + `DkPageChip` |

No results: ILL-07, "Nothing found for “{query}”". If unsearchable scans exist, a `DkBanner` info: "{n} scans have no searchable text yet." + "Make searchable" (Pro badge if free user).

### 16.3 File action sheet

`DkActionSheet`, medium detent.

| Part | Content |
| --- | --- |
| Header | Thumbnail 40 × 52, name `type.titleS`, meta `type.caption` |
| Primary row | Open · Share (two large tonal buttons side by side) |
| Suggested tools | Up to 5 `DkToolRow` (most used for this file type) |
| More | "All tools…" row |
| File actions | Rename · Duplicate · Move · Move to locked folder · Info |
| Destructive | Delete (`color.danger`) |

### 16.4 Dialogs and sheets in Files

| Item | Spec |
| --- | --- |
| Rename | `DkConfirmDialog` with `DkTextField` prefilled, name selected without extension; buttons Cancel / Rename; error "A file with this name already exists." |
| New folder | Same pattern: "New folder" / "Neuer Ordner", field placeholder "Folder name" |
| Move | `DkSheet` large: folder tree with breadcrumb, "New folder" row at top, sticky button "Move here" |
| Info | `DkSheet` medium: thumbnail, then key/value rows: Location, Size, Pages, Created, Modified, PDF version, Password (Yes/No), Searchable text (Yes/No + "Make searchable" link), Versions (list of up to 5 with "Restore") |
| Delete | Toast-based (moves to trash): "Moved to Recently deleted · Undo" |

### 16.5 Recently deleted

Small top bar "Recently deleted" + action "Empty" (danger text). Banner info: "Files are deleted for good after 30 days." Rows show "{n} days left" in meta. Row tap → action sheet: Restore · Delete for good. Empty: ILL-08 "Nothing here".

Confirm empty: icon dialog (danger), "Delete {n} files for good?", "This can't be undone.", Cancel / Delete for good.

### 16.6 F2 · Locked folder

**First-time setup flow (full-screen pages)**

| Step | Content |
| --- | --- |
| L1 Intro | ILL-09, title "Keep files private", body "Files here are encrypted on this phone and need Face ID or your PIN to open.", warning `DkBanner` (warning): "If you forget the PIN and biometrics stop working, these files can't be recovered.", button "Set up" |
| L2 Create PIN | Title "Create a 6-digit PIN", `DkPinPad` |
| L3 Confirm PIN | Title "Enter the PIN again"; mismatch → shake animation + "PINs don't match. Try again." |
| L4 Biometrics | Title "Use Face ID?" / "Fingerabdruck verwenden?", buttons "Use Face ID" (primary) / "Not now" |

**Unlock screen:** `color.background`, lock icon 48, title "Locked folder", `DkPinPad` with biometric key; automatic biometric prompt on open.

**Content:** like a folder screen with a lock badge next to the title and an action "Lock now" (`lock` icon). Thumbnails decrypted only while open.

**App lock screen (global, if enabled):** Dokulo symbol 56, "Dokulo is locked" `type.titleM`, `DkPinPad`, biometric prompt auto.

---

## 17. Screens: Viewer and edit mode

### 17.1 V1 · Viewer (read mode)

| # | Region | Spec |
| --- | --- | --- |
| 1 | Top bar | `DkTopBar` small on `color.surface` @ 94 % + background blur; back, file name (middle-truncated; tap → rename), `search`, overflow |
| 2 | Canvas | `color.surfaceSunken` background; pages on `color.pageWhite` with 1 dp outline and `elevation.raised`; 8 gap between pages; side margins 8 at fit-width |
| 3 | Page pill | `DkPagePill` bottom-right, 16 from edges, above the bottom bar |
| 4 | Bottom bar | `DkViewerBar`: Edit (`edit`) · Sign (`signature`) · AI (`summarize`) · Tools (`apps`) · Share |
| 5 | Thumbnail strip (toggle) | Above the bottom bar, 96 tall, `color.surface` @ 94 %, `DkPageThumb` 48 × 64 |

**Overflow menu:** Info · Go to page · Pages (thumbnail strip) · Night mode (switch) · Organize pages · Print · Share as images · Share text · Move to locked folder · Delete.

**Chrome behaviour:** bars hide on scroll after 3 s or on single tap; show again on tap; never hide while a screen reader is on.

**States to design**

| State | Spec |
| --- | --- |
| Default | Multi-page letter at fit width, bars visible |
| Chrome hidden | Only the page pill visible |
| Loading | First page skeleton (page-shaped `color.surfaceSunken` block) + spinner small; then progressive render |
| Search active | Top bar replaced by search field + "4 of 17" counter + up/down arrows + Done; matches highlighted `markup.yellow` @ 60 %, current match outlined 2 dp `color.primary` |
| Search, scan without text | `DkBanner` under the search bar: "This scan has no searchable text." + "Make searchable" (Pro badge) |
| Text selected | Selection handles (`color.primary`), selection fill `color.primary` @ 25 %, `DkMarkupBar` above |
| Locked PDF | Pages replaced by a centred card (max 360 wide): lock icon 40, "This PDF is locked", `DkPasswordField`, button "Unlock"; error "That password doesn't open this file." |
| After unlock | Toast "Unlocked for viewing · Remove password" |
| Night mode | Pages inverted (dark background, light text), images not inverted; canvas `#0B0D10` |
| Damaged file | ILL-14 empty state: "This file can't be opened", "It may be damaged.", buttons "Try Repair" / "Close" |
| Form detected | `DkBanner` info at top of first page: "This PDF has fillable fields." + "Fill form" |
| Go to page | Small `DkConfirmDialog`-style dialog with number field: "Go to page", helper "1–32" |
| External link tapped | Dialog "Open example.com in your browser?" Cancel / Open |

### 17.2 V2 · Edit mode

**Layout:** top bar becomes `DkTopBar` editing ("Editing" / "Bearbeiten", Cancel, Done); bottom `DkToolStrip`; pages stay at full brightness; a 2 dp `color.primary` top border on the canvas signals edit mode.

**Tool strip items (in order):** Pan (`pan_tool`) · Pen · Highlighter · Text · Shapes · Note · Sign · Eraser | Undo · Redo.

| Tool | Second tap opens options | Canvas behaviour | Visual details |
| --- | --- | --- | --- |
| Pan | — | Scroll/zoom only | Default when entering edit mode from Sign |
| Pen | Colour (black, blue ink, red, + custom), thickness 1–8 pt | Freehand ink | Stroke preview in options |
| Highlighter | Colour (yellow, green, blue, pink), opacity 30–60 % | Snaps to text lines over text | Highlight rectangles follow text line height |
| Text | Colour, font size 8–24 pt | Tap to place a text box with a blinking caret | Box: dashed outline while editing, handles to resize width |
| Shapes | Rectangle · Ellipse · Line · Arrow (segmented), colour, thickness | Drag to draw | Shows dimensions guide only while drawing |
| Note | Colour | Tap to drop a 24 note icon; sheet "Note" with text field opens | Note icon `sticky_note_2` in `markup.yellow` |
| Sign | — | Opens signatures sheet (17.3) | Placed stamp selected after placing |
| Eraser | Mode: Object · Stroke | Tap annotations to delete / drag across ink | Eraser cursor circle 24 |

**Selected annotation:** handles + floating mini bar (`DkMarkupBar` style) with Colour · Duplicate · Note · Delete.

**Form filling:** tapping a field shows a 2 dp `color.primary` outline on the field; keyboard opens with accessory bar (Previous · Next · Done); checkboxes toggle on tap; dropdowns open a sheet; all fields have a faint `color.primaryContainer` @ 40 % fill so users see what is fillable; toggle "Highlight fields" in overflow.

**Done:** toast "Saved · Undo". **Cancel with changes:** dialog "Discard your changes?" / "Änderungen verwerfen?", body "Your edits since opening edit mode will be lost.", buttons Keep editing / Discard (danger).

### 17.3 Signatures

| Screen | Spec |
| --- | --- |
| Signatures sheet (medium) | Title "Your signatures"; grid of `DkSignatureCard` (2 columns); "Add signature" card (dashed); toggles below: "Add date next to signature" · "Initials on every page"; empty: ILL-15 "No signatures yet" + "Add signature" |
| Signature pad | `DkSignaturePad` full-screen landscape. Draw tab: canvas. Type tab: text field + 3 handwriting-style font previews to choose (fonts: "Caveat" and "Dancing Script", SIL OFL 1.1, and "Homemade Apple", Apache-2.0; fetched by `tools/fetch_signature_fonts.py`); Image tab: "Choose photo" button → crops to the signature, removes white background |
| Placement | Stamp appears centred on the visible page at 40 % page width, selected; drag/resize; tap outside deselects; "Sign" chips on pages with signature fields ("Sign here" pill on the field) |
| Date stamp | Date in locale format `type.bodyM` size relative to the signature height, right of it, grouped with it |

### 17.4 Tablet viewer

Expanded: viewer + AI panel side by side (AI pane 400 wide right); thumbnail sidebar 120 wide on the left (toggle); top bar actions shown inline instead of overflow where space allows.

---

## 18. Screens: Organize pages (P1)

| # | Region | Spec |
| --- | --- | --- |
| 1 | Top bar | Cancel (left), "Organize pages" / "Seiten ordnen", Save (right, primary text; menu on long-press: Save as copy · Replace original) |
| 2 | Sub-bar | `type.caption` "12 pages" left; Undo / Redo icons right |
| 3 | Grid | `DkPageGrid`, 3 columns, page numbers under each |
| 4 | FAB | 56 circle `color.primary` with `add`, bottom-right 16 above bottom; opens Insert sheet |
| 5 | Selection bar (when selected) | Rotate · Duplicate · Delete · Extract; header shows "3 selected" |

**Insert sheet:** rows: Blank page · From another PDF · From a scan · From photos; then a position choice: "After page {n}" / "At the end".

**States:** default; one page lifted mid-drag with insertion line; 3 selected; after delete (toast "2 pages deleted · Undo"); pinch to 5 columns; 300-page document scrolled (thumbnails loading skeletons).

**Save result:** returns to the viewer with toast "Saved as “{name} – organized.pdf”" (or "Saved" when replacing).

---

## 19. Screens: Scanner

### 19.1 Camera permission pre-prompt

`DkSheet` (small) over a dark background: ILL-10 (80), title "Allow camera access", body "Dokulo uses the camera only to scan. Images stay on this phone.", primary "Continue" (opens the system dialog), tertiary "Not now".

Denied state (S1): full-screen `#000` with centred white content: ILL-10 (inverted), "Camera access is off", "Turn it on in Settings to scan, or import photos instead.", buttons "Open settings" (on-camera primary white) and "Import from photos".

### 19.2 S1 · Camera

Full-bleed camera preview (`#000` letterboxing). All chrome on `color.cameraChrome`.

| # | Region | Spec |
| --- | --- | --- |
| 1 | `DkCameraTopBar` | Close (×) left; right: flash (cycles Off / On / Auto with icon + tiny label), auto-capture toggle ("Auto" pill: off = outline white, on = filled white with dark text), grid toggle, settings (`tune`) |
| 2 | Hint pill | `DkHintPill` centred 16 below the top bar |
| 3 | Viewfinder | Detected document: `color.quadFill` + 2 dp `color.quadStroke` with 12 dp rounded corners on the quad points; grid overlay (thirds, 1 dp white @ 30 %) when on |
| 4 | Mode switcher | Text segments above the shutter, `type.labelL`: Document · ID card · Book · Batch; selected white, others white @ 60 %, small dot under the selected |
| 5 | Bottom row (height 120 on `color.cameraChrome`) | Left: Import (`photo_library` 32 in 48 circle); centre: `DkShutterButton`; right: page tray stack (last thumbnail 48 × 60 with 2 dp white border, `DkCountBadge` top-right); tap → S2 |

**Hint pill messages (priority order):**

| Condition | EN | DE |
| --- | --- | --- |
| No document detected | Point at a document | Richte die Kamera auf ein Dokument |
| Too far | Move closer | Näher herangehen |
| Moving | Hold steady | Ruhig halten |
| Too dark | More light needed | Mehr Licht nötig |
| Cut off | Fit the whole page in view | Ganze Seite ins Bild bringen |
| Ready, auto off | Ready | Bereit |
| Auto capturing | Capturing… | Wird aufgenommen… |

**Mode-specific overlays**

| Mode | Overlay |
| --- | --- |
| Document | Quad detection only |
| Batch | Auto pill forced on (locked state, small lock); counter larger (`type.titleM` "12 pages") above the tray |
| ID card | Rounded rectangle guide (ID-1 ratio 85.6:54) centred, 80 % of width, 2 dp white dashed; label above the guide: "Front side" → after capture "Turn the card over" (with a small flip icon); after both: auto-advance to S2 |
| Book | Vertical dashed centre line (spine guide) and label "Align the spine with the line"; quad detection for the whole spread |

**Capture feedback:** white flash 80 ms; thumbnail flies to the tray; badge pop; light haptic.

**Frames:** default (no doc), document detected (quad), auto-capture countdown ring, ID front, ID back prompt, Book, Batch with 12 pages, flash menu open, permission denied, iPhone SE size.

### 19.3 S2 · Review

| # | Region | Spec |
| --- | --- | --- |
| 1 | Top bar | Back arrow labelled "Add pages" (returns to camera), title "Review 6 pages" / "6 Seiten prüfen", "Save" (primary text) |
| 2 | Preview | Current page large, centred on `color.surfaceSunken`, with the applied filter; swipe between pages; page number "3 of 6" `type.caption` below |
| 3 | Edit row | 5 actions (icon 24 + label `type.caption`): Crop · Rotate · Filter · Retake · Delete |
| 4 | Context area | Shows the active editor: filter strip, crop controls, or nothing |
| 5 | Page tray | `DkPageTray` with drag reorder and "+" |

**Crop mode:** preview switches to the uncropped original with `DkCropOverlay`; buttons under the image: Auto · Full page · Reset; bottom: Cancel / Apply. After applying a change, a `DkChip` appears: "Apply to all pages" (for Full page and rotation). Magnifier while dragging handles.

**Filter mode:** horizontal strip of 5 previews (64 × 80 thumbnails with name `type.caption` below): Original · Auto colour · Greyscale · Black & white · Remove shadows. Selected: 2 dp primary ring. Below: "Adjust" row with Brightness and Contrast sliders. Chips after change: "Apply to all pages" · "Use as default" (or via long-press on a filter).

**Retake:** opens S1 single-capture mode with a top label "Retake page 3".

**Delete:** page removed with toast "Page deleted · Undo"; deleting the last page → dialog "Discard this scan?", "All pages of this scan will be deleted.", Keep / Discard (danger).

**Frames:** default, crop with magnifier, filter strip, apply-to-all chip visible, reordering in tray, discard dialog.

### 19.4 Save sheet

`DkSheet` large over S2:

| Row | Control | Default |
| --- | --- | --- |
| Name | `DkTextField`, text selected | "Scan 2026-10-07 14.32" |
| Format | `DkSegmented`: PDF · JPG | PDF |
| Page size | `DkSegmented`: Auto · A4 · Letter | Auto (A4 shown first in DE locale) |
| Quality | `DkLevelCard` ×3: Smaller · Recommended · Best with size estimates | Recommended |
| Folder | Row with folder name + chevron → folder picker | Last used |
| Make text searchable | `DkSwitch` + Pro badge for free users after their free try | On (Pro) / Off (free) |

Sticky button: **"Save PDF · 6 pages"** / **"PDF speichern · 6 Seiten"**. JPG format changes it to "Save 6 images".

After save: T3-style result screen (section 20.4) with Next chips: Compress · Add password · Sign · Summarize · Share.

### 19.5 Find documents in photos

| Step | Spec |
| --- | --- |
| Intro sheet | ILL-17, title "Find documents in your photos", body "Dokulo looks through your photos on this phone to find documents and receipts. Nothing is uploaded.", primary "Allow photo access", tertiary "Not now" |
| Scanning | Home card shows progress "Looking through photos · 1,240 of 5,800" with a thin bar; can leave |
| Results | Full screen: top bar "Documents in photos" with "Select"; grid 3 columns grouped by month headers; each photo with a small `description` badge; multi-select; bottom action bar "Convert 8 to PDF" |
| Convert options | Sheet: One PDF · One PDF per photo; Clean up like a scan (switch, on) |
| False positive | Long-press → "Not a document" (removes, remembered) |
| Empty | "No documents found in your photos." |

---

## 20. Screens: Tool shell (options, progress, result, picker)

Every tool uses this shell. Section 21 defines what fills it per tool.

### 20.1 T2 · Tool options screen

| # | Region | Spec |
| --- | --- | --- |
| 1 | Top bar | Back; title = tool icon 20 + tool name `type.titleM`; Pro badge after the name for Pro tools; overflow: About this tool · Reset options |
| 2 | Privacy line | `DkPrivacyLine`, 4 below the bar, left-aligned with content |
| 3 | Input section | Header "File" / "Files (4)" `type.titleS`; `DkFileCard` rows; multi-file tools: drag handles (`drag_indicator`) on the right, × remove, and an "Add files" tertiary button with `add`; files that need a password show an inline `DkPasswordField` row under the card |
| 4 | Options | Header "Options" `type.titleS`; `DkOptionRow`s; "More options" collapsible row (chevron) at the end when advanced options exist |
| 5 | Estimate | Inside the action bar: caption line above the button |
| 6 | Action bar | `DkActionBar` with the primary button (label from section 21) |

**Empty input state (opened from grid without a file):** input section replaced by a picker card: title "Choose a PDF" (or "Choose images", "Choose files"), list of 5 recent compatible files (tap to select; multi-select tools show checkboxes), and two buttons: "Browse device" (secondary, `folder_open`) and, for image tools, "Choose photos" (secondary, `photo_library`). The action button is disabled with caption "Choose a file to continue".

**Pro first-try caption:** "Free try · Pro unlocks unlimited use" (`type.caption` with `workspace_premium` 12 in `color.pro`).

### 20.2 X2 · Progress

| Duration | Visual |
| --- | --- |
| < 2 s | No indicator (button press state only) |
| 2–10 s | Primary button enters loading state with label "Compressing…" |
| > 10 s | `DkProgressSheet` slides up: title "Compressing Mietvertrag.pdf", bar with %, "Page 18 of 40 · about 20 s left", buttons Cancel / Keep working |
| Keep working | Sheet morphs into `DkMiniJobBar`; user can navigate anywhere |
| Background finished | Local notification (section 25) + Home continue card |
| Cancel confirm (> 30 s done) | Dialog "Stop compressing?", "Your original file stays unchanged.", Keep going / Stop |
| Failure | Sheet switches to error state: ILL-20 small (64), error title + body + action (section 26) |

### 20.3 X1 · Tool picker (from share sheet / "Tools" in viewer)

`DkSheet` large. Header: file thumbnail + name (or "4 files" with stacked thumbnails). Search field "Search tools". First row (single PDF only): "Open in viewer". Then sections "Suggested" (top 4 by use) and "All tools" (only compatible tools, grouped by category) as `DkToolRow` list or 4-column tile grid (designer: tile grid on tablets, list on phones).

### 20.4 T3 · Result

| # | Region | Spec |
| --- | --- | --- |
| 1 | Top bar | Close (×) left (returns to where the tool was started), title = tool name |
| 2 | Result card | `DkResultCard` with headline per tool |
| 3 | Preview strip | Thumbnails of output pages (or file list for multi-output tools: "5 files" with each file as a `DkFileCard` row) |
| 4 | Name | `DkTextField` "File name", default "{original} – {suffix}" |
| 5 | Save location | Row "Save to: Files › Taxes" with chevron |
| 6 | Next chips | Header "Next" / "Weiter mit" + wrap of 2–4 `DkNextChip`; after two chained tools a chip "Save as workflow" (`account_tree`) appears |
| 7 | Action bar | Primary "Save" (split button: tap = Save as copy; chevron opens menu: Save as copy · Replace original · Save to…), secondary row: Share · Open |

**Replace original:** dialog "Replace the original file?", "The original will be kept in Versions for 30 days.", Cancel / Replace. Toast "Replaced · Undo" (10 s).

**After Save:** toast "Saved to Files › Taxes · Open"; button area switches to "Done" (primary) + Share/Open remain.

**Discard:** closing an unsaved result whose job took > 10 s → dialog "Discard this result?", "You'll need to run the tool again to get it back.", Keep / Discard.

**Partial success:** result card in warning tint: "Text found on 11 of 12 pages", sub "Page 7 is too blurry.", inline action "Retake page 7" (when source is a scan from Dokulo).

### 20.5 About this tool (sheet)

Small sheet: tool icon 40 tonal, name, tier badge, description (2–3 sentences, from section 21), "What you need" (input), "What you get" (output), and "Works offline" line with `smartphone` icon.

---

## 21. Tool-by-tool specifications

Each tool fills the shell from section 20. Format per tool: identity, input, options (control · default · EN / DE labels), button, result, errors, special UI. "Suffix" is added to the output file name.

### 21.1 Merge PDF · `merge` · Free

- **Description:** Combine PDFs and images into one PDF, in the order you choose. / Füge PDFs und Bilder in der gewünschten Reihenfolge zu einer PDF zusammen.
- **Input:** 2–500 files (PDF, JPG, PNG, HEIC, WebP). Cards draggable; each card has a "Pages: All" link opening a page-range sheet (`DkRangeField` + thumbnail grid).
- **Options:** Keep bookmarks · switch · on · "Keep bookmarks" / "Lesezeichen behalten".
- **Estimate:** "38 pages · about 6.2 MB".
- **Button:** "Merge 4 files" / "4 Dateien zusammenfügen".
- **Result:** headline "38 pages" + sub "From 4 files · 6.2 MB". Suffix: merged / zusammengefügt. Next: Compress · Add page numbers · Add password.
- **Errors:** locked file → password row on that card ("This file is locked" / "Diese Datei ist gesperrt"); fewer than 2 files → button disabled, caption "Add at least 2 files".

### 21.2 Split PDF · `content_cut` · Free

- **Description:** Split a PDF into several files by page ranges, every few pages, or one file per page. / Teile eine PDF nach Seitenbereichen, alle paar Seiten oder in Einzelseiten.
- **Input:** 1 PDF.
- **Options:** Split mode · `DkSegmented` (wraps to a radio list at large text) · By ranges · Every N pages · Each page · By bookmarks / Nach Bereichen · Alle N Seiten · Jede Seite · Nach Lesezeichen. Ranges: `DkRangeField` "Ranges" placeholder "1–3, 4–8, 9–end"; Every N: `DkStepper` (2); Visual: thumbnail strip with tappable gaps showing scissor markers (`DkSplitMarker` without reason tags) that sync with the text field.
- **Button:** "Split into 3 files" / "In 3 Dateien teilen".
- **Result:** headline "3 files" + list of parts ("Part 1 · pages 1–3"). Output folder "{name} – split". Next: Compress · Share all.
- **Errors:** invalid range → field error "Page 40 doesn't exist – this PDF has 32 pages." / "Seite 40 gibt es nicht – diese PDF hat 32 Seiten."; no bookmarks → "By bookmarks" disabled with note.

### 21.3 Extract pages · `file_export` · Free

- **Description:** Save selected pages as a new PDF. / Speichere ausgewählte Seiten als neue PDF.
- **Input:** 1 PDF.
- **Options:** Page selection grid (`DkPageGrid` with checkboxes) inline in T2; quick chips: All · Odd · Even · Range…; Order · segmented · Original order · Selection order (Original).
- **Button:** "Extract 4 pages" / "4 Seiten extrahieren" (disabled at 0, caption "Select pages").
- **Result:** headline "4 pages". Suffix: extract / Auszug. Next: Merge · Share.

### 21.4 Organize pages · `grid_view` · Free

- **Description:** Reorder, rotate, delete and add pages in one view. / Ordne, drehe, lösche und füge Seiten in einer Ansicht hinzu.
- Opens P1 directly (section 18). Result toast instead of T3.

### 21.5 Rotate PDF · `rotate_right` · Free

- **Description:** Turn pages that are sideways or upside down. / Drehe Seiten, die quer oder auf dem Kopf stehen.
- **Input:** 1 PDF.
- **Options:** inline `DkPageGrid`; tap a page to rotate it 90° clockwise (rotation animates 220 ms; badge "90°" on rotated pages); buttons Rotate all ↻ / ↺; if sideways pages are detected, `DkBanner` info "3 pages look sideways." + "Fix them".
- **Button:** "Save rotation" / "Drehung speichern" (disabled until a change).
- **Result:** "5 pages rotated". Suffix: rotated / gedreht.

### 21.6 Smart Split · `auto_awesome_mosaic` · Pro

- **Description:** Find where one document ends and the next begins in a bundle of scans, then split them. / Erkennt, wo in einem Scan-Stapel ein Dokument endet und das nächste beginnt, und teilt sie.
- **Input:** 1 PDF.
- **Flow:** T2 (input only, button "Find documents" / "Dokumente finden") → progress ("Checking 3 uncertain pages…" if AI is used) → **review screen**: vertical list of document groups; each group = header (editable suggested name `type.titleS`, page count) + horizontal thumbnail strip; between groups a `DkSplitMarker` with reason tag ("New letterhead" / "Neuer Briefkopf", "Page 1 of 3" / "Seite 1 von 3", "Blank page" / "Leere Seite", "Different date" / "Anderes Datum"); tap the gap between any two pages to add/remove a cut; action bar "Split into 5 documents".
- **Result:** "5 documents" with file list. Next: Make text searchable · Add password.
- **No AI model:** works with rules only; small `DkBanner`: "Install the AI model for better suggestions." + "Download".

### 21.7 Image to PDF · `image` · Free

- **Description:** Turn photos and images into a PDF. / Wandle Fotos und Bilder in eine PDF um.
- **Input:** 1–500 images; shown in a `DkPageTray`-style horizontal strip with reorder.
- **Options:** Page size · segmented · Fit image · A4 · Letter (Fit image); Margins · segmented · None · Small (None); Output · segmented · One PDF · One per image (One PDF); Clean up like a scan · switch · off (help: "Crop to the document and improve contrast").
- **Button:** "Create PDF · 12 images" / "PDF erstellen · 12 Bilder".
- **Result:** "1 PDF · 12 pages · 4.1 MB". Next: Compress · Make text searchable.
- **Errors:** unsupported file → banner "2 files aren't images and were skipped."

### 21.8 PDF to images · `photo_library` · Free

- **Description:** Save PDF pages as JPG or PNG images. / Speichere PDF-Seiten als JPG- oder PNG-Bilder.
- **Options:** Pages · chips All / Choose… (All); Format · segmented JPG · PNG (JPG); Resolution · `DkLevelCard` ×3: Screen 72 dpi · Standard 150 dpi · Print 300 dpi with size estimates (Standard); Save to · segmented Files · Photos (Files).
- **Button:** "Export 12 images" / "12 Bilder exportieren".
- **Result:** "12 images · 8.4 MB". Next: Share all.

### 21.9 Web page to PDF · `language` · Free

- **Description:** Save a web page or HTML file as a PDF. / Speichere eine Webseite oder HTML-Datei als PDF.
- **Input:** URL field (`DkTextField`, keyboard type URL, paste button) or "Choose HTML file".
- **Preview:** after entering a URL, a 3:4 preview card renders the page (loading skeleton first).
- **Options:** Page size (A4); Backgrounds · switch · on; Margins · segmented · Default · None.
- **Network note:** `DkBanner` info always visible on this tool: "This tool loads the page from the internet. Nothing else leaves your phone." / "Dieses Werkzeug lädt die Seite aus dem Internet. Sonst verlässt nichts dein Handy."
- **Button:** "Create PDF". **Result:** "3 pages". Next: Compress · Mark up.
- **Offline:** ILL-19 state "You're offline", "Web pages need an internet connection to load."

### 21.10 Convert to PDF/A · `inventory_2` · Pro

- **Description:** Convert to the archive format many authorities and courts ask for. / Wandle in das Archivformat um, das viele Behörden und Gerichte verlangen.
- **Options:** Level · fixed label "PDF/A-2b" with info icon (sheet explains in 2 sentences).
- **Button:** "Convert to PDF/A". **Result:** "PDF/A-2b ready"; if pages had to be converted to images: warning sub "2 pages were converted to images because their fonts weren't included."
- **Errors:** locked file → unlock first.

### 21.11 PDF to text · `notes` · Pro

- **Description:** Get the text of a PDF as Markdown or plain text. / Hol dir den Text einer PDF als Markdown oder reinen Text.
- **Options:** Format · segmented Markdown · Plain text (Markdown); Page markers · switch · on.
- **Button:** "Extract text". **Result:** "5,240 words" + scrollable preview card (Markdown rendered: headings, lists) 320 tall + "Copy all" button. Next: Translate · Share.
- **No text:** banner "This PDF has no text yet." + "Make text searchable first".

### 21.12 Compress PDF · `compress` · Free

- **Description:** Make PDFs smaller for email and upload portals. / Verkleinere PDFs für E-Mails und Upload-Portale.
- **Input:** 1–500 PDFs (batch).
- **Options:** Level · `DkLevelCard` ×3: Light "≈ 5.1 MB" "Best quality" / Recommended "≈ 1.9 MB" "Good for email and uploads" / Strong "≈ 0.9 MB" "Smallest, lower image quality" (Recommended); Target size · `DkChip` choice row: Under 1 MB · Under 2 MB · Under 5 MB · Custom… (none selected by default; selecting a target deselects levels and shows "Dokulo will find the best quality under 2 MB"); More options: Greyscale · switch · off; Remove metadata · switch · off.
- **Button:** "Compress 12 pages" / "12 Seiten verkleinern" (batch: "Compress 4 files").
- **Result:** headline "1.9 MB" + "(−77 %)" in `color.success`, sub "From 8.4 MB"; Before/After segmented toggle showing a zoomed crop (200 × 200) of the same page area. Suffix: compressed / verkleinert. Next: Add password · Share.
- **Edge states:** already small → result info card "This file is already small (0.3 MB). Compressing further would lower quality." with "Keep original"; target unreachable → dialog "Smallest possible: 2.4 MB" / "Kleinstmöglich: 2,4 MB", body "Use it anyway?", Cancel / Use 2.4 MB.

### 21.13 Repair PDF · `build` · Free

- **Description:** Try to fix PDFs that won't open or show errors. / Versuche, PDFs zu reparieren, die sich nicht öffnen lassen.
- **Options:** none (T2 shows only input + note "Dokulo rebuilds the file structure. Your original stays unchanged.").
- **Button:** "Repair PDF". **Result success:** "Repaired" + sub (e.g. "Rebuilt the page table"). **Failure:** ILL-14 state "This file is too damaged to repair."

### 21.14 Make text searchable (OCR) · `manage_search` · Pro

- **Description:** Recognise text in scans so you can search, copy and use AI on it. / Erkennt Text in Scans, damit du ihn suchen, kopieren und mit KI nutzen kannst.
- **Options:** Language · dropdown · Auto (Auto / German / English / more… with "Download" tags for extra languages); Pages · chips All / Choose… (All); Existing text · segmented Keep · Redo (Keep).
- **Button:** "Recognise text · 12 pages" / "Text erkennen · 12 Seiten".
- **Result:** "Text found on 12 of 12 pages"; preview: tap a page → page with recognised words outlined faintly (`color.primary` @ 30 %). Partial: warning card "Text found on 11 of 12 pages", "Page 7 is too blurry." Next: Search in file · Summarize · PDF to text.

### 21.15 Add page numbers · `format_list_numbered` · Free

- **Description:** Number the pages, in the position and format you choose. / Nummeriere die Seiten, an der Stelle und im Format deiner Wahl.
- **Options:** Position · `DkPositionPicker` (bottom centre); Format · segmented "1" · "1 of N" · "Page 1 of N" (DE: "1" · "1 von N" · "Seite 1 von N") ("1"); Start at · stepper (1); Skip first page · switch · off; Size · segmented S · M · L (M = 10 pt). **Live preview:** two page thumbnails 120 tall showing the number.
- **Button:** "Add numbers to 12 pages" / "Seitenzahlen zu 12 Seiten hinzufügen". **Result:** "Numbers added to 12 pages".

### 21.16 Add watermark · `branding_watermark` · Free

- **Description:** Put text or an image across your pages, like “Draft” or “Copy”. / Setze Text oder ein Bild auf deine Seiten, etwa „Entwurf“ oder „Kopie“.
- **Options:** Type · segmented Text · Image (Text); Text field with preset chips: Copy · Confidential · Draft · Kopie · Entwurf · Vertraulich (shown by locale; "Copy"/"Kopie" default); Image: picker; Opacity · slider 10–100 % (30 %); Angle · segmented 0° · 45° · −45° (45°); Size · slider; Layout · segmented Centre · Tiled (Centre); Behind content · switch · off; Pages · All / Choose.
- **Live preview:** first page 200 tall.
- **Button:** "Add watermark". **Result:** "Watermark added to 12 pages" with Before/After toggle.

### 21.17 Crop pages · `crop` · Free

- **Description:** Trim the margins of one page or of all pages. / Schneide die Ränder einer Seite oder aller Seiten zu.
- **Options:** large page preview with `DkCropOverlay` (rectangle, no perspective); buttons Auto margins · Reset; Apply to · segmented This page · All pages (All); page stepper below the preview to check other pages.
- **Button:** "Crop 12 pages". **Result:** "Cropped 12 pages" with Before/After.

### 21.18 Mark up · `edit` · Free

- **Description:** Highlight, underline, draw and add notes on a PDF. / Markiere, unterstreiche, zeichne und füge Notizen in einer PDF hinzu.
- Opens the file in V2 edit mode with the Highlighter selected. Saved as a new version; toast instead of T3.

### 21.19 Fill form · `assignment` · Pro

- **Description:** Fill in PDF forms, and lock the values if you want. / Fülle PDF-Formulare aus und fixiere die Werte, wenn du möchtest.
- Opens V2 with form filling active and "Highlight fields" on. Extra on Done: dialog "Lock form values?" with switch "Flatten form (fields can't be edited later)" default off; buttons Save.
- **No fields:** dialog "This PDF has no fillable fields.", "Use Mark up to add text anywhere.", Cancel / Mark up. **XFA:** "This form type can't be filled on phones."

### 21.20 Sign PDF · `signature` · Free

- **Description:** Add your signature, initials or a stamp to a PDF. / Füge deine Unterschrift, Initialen oder einen Stempel in eine PDF ein.
- Opens V2 with the signatures sheet (section 17.3). Result toast "Signed on page 3 · Undo".

### 21.21 Add password · `lock` · Free

- **Description:** Lock a PDF with a password and choose what others may do with it. / Sperre eine PDF mit einem Passwort und lege fest, was andere damit dürfen.
- **Options:** Password · `DkPasswordField` with strength meter; Confirm password · `DkPasswordField`; More options: Allow printing · on; Allow copying text · on; Allow editing · off. Always-visible `DkBanner` warning: "If you forget this password, the file can't be opened." / "Wenn du dieses Passwort vergisst, lässt sich die Datei nicht mehr öffnen."
- **Button:** "Add password". **Result:** "Protected with AES-256" + lock icon. Suffix: protected / geschützt.
- **Errors:** "The passwords don't match." / "Die Passwörter stimmen nicht überein."

### 21.22 Remove password · `lock_open` · Free

- **Description:** Remove the password from a PDF you can open. / Entferne das Passwort aus einer PDF, die du öffnen kannst.
- **Options:** Password field. **Button:** "Remove password". **Result:** "Password removed". **Errors:** "That password doesn't open this file."; not encrypted → "This file has no password."

### 21.23 Black out (redact) · `visibility_off` · Pro

- **Description:** Remove names, numbers and other details for good, not just cover them. / Entferne Namen, Nummern und andere Angaben dauerhaft, statt sie nur abzudecken.

Dedicated screen (replaces T2 options):

| Region | Spec |
| --- | --- |
| Top bar | Back, "Black out" / "Schwärzen", Pro badge |
| Step indicator | `type.caption`: "1 Find · 2 Review · 3 Apply" |
| Find panel (sheet over page preview, medium) | Search field "Find text to black out"; `DkDetectionGroup` list: IBAN (2) · Tax ID (1) · Email (3) · Phone (2) · Date of birth (1); separate group "Suggested by AI" (names, addresses) unchecked with caption "Check before blacking out"; button "Draw a box" (manual) |
| Review | Page view with `DkRedactionBox` in edit state on every checked item; page stepper; tap a box to remove it; drag to draw new boxes |
| Apply | Action bar primary button "Black out 14 items" → confirm dialog (danger icon) "Black out 14 items?", "The text under the boxes is removed for good in the new file.", Cancel / Black out |
| Result | Headline "14 items blacked out", sub badge with `verified_user` icon: "Verified: no hidden text left" / "Geprüft: kein versteckter Text mehr"; Next: Add password · Share |
| Scan without text | Before Find: step "Recognising text…" progress (OCR) |
| Verification failed | Error state: "Redaction couldn't be verified. Nothing was saved." / "Die Schwärzung konnte nicht geprüft werden. Es wurde nichts gespeichert." |

Masking in lists: show found values partially masked ("DE89 •••• •••• •••• 3000").

### 21.24 Compare PDFs · `compare` · Pro

- **Description:** See what changed between two versions of a PDF. / Sieh, was sich zwischen zwei Versionen einer PDF geändert hat.
- **Input:** 2 PDFs labelled "Older version" / "Ältere Version" and "Newer version" / "Neuere Version" with a swap button between them.
- **Options:** Mode · segmented Text · Visual (Text).
- **Button:** "Compare".
- **Comparison screen:** top bar with "23 changes" and filter chips (All · Added · Removed · Changed); phone portrait: single page view with a toggle Older · Newer · Overlay and highlighted changes (colours from 4.3, each with label tag); landscape/tablet: side by side, synced scrolling; bottom sheet (small→medium) "Changes" list of `DkDiffRow`; tap a row jumps to it. Overflow: Export report (PDF).
- **Scans without text:** banner "These look like scans. Visual mode works better." + "Switch".

### 21.25 Extract images & text · `unarchive` · Free

- **Description:** Save the images and the text in a PDF as separate files. / Speichere die Bilder und den Text einer PDF als einzelne Dateien.
- **Options:** Extract · segmented Images · Text · Both (Images); Minimum image size · segmented Any · Over 100 px · Over 500 px (Over 100 px).
- **Button:** "Extract". **Result:** "18 images · 4,800 words": grid of found images (3 columns) with multi-select + "Save selected" and "Save all"; text in a preview card with Copy.
- **None found:** "No images found in this PDF."

### 21.26 Batch · `dynamic_feed` · Free

- **Description:** Run one tool on many files at once. / Wende ein Werkzeug auf viele Dateien auf einmal an.
- **Step 1:** choose a tool (sheet of batch-capable tools: Compress, Add watermark, Add password, Make text searchable, Add page numbers, Convert to PDF/A, Image to PDF, PDF to images).
- **Step 2:** choose files (multi-select picker, folders allowed).
- **Step 3:** that tool's options (shared for all files).
- **Run:** queue screen: list of files with status icons (waiting `schedule`, running spinner, done `check_circle`, skipped `error` with reason), overall progress bar "32 of 50".
- **Result:** "48 of 50 done · 2 skipped" with expandable skipped reasons; outputs in a new folder "Batch – Compress – 2026-10-07".

### 21.27 Workflows · `account_tree` · Pro

- **Description:** Chain tools into steps you can run again with one tap. / Verkette Werkzeuge zu Abläufen, die du mit einem Tipp wiederholst.
- **List (Me → Workflows):** cards with name, step icons in a row connected by arrows, "Run" button; templates section: "Scan → Text → Compress", "Merge → Page numbers → Password".
- **Builder:** top bar "New workflow" + Save; name field; vertical list of step cards (tool icon, tool name, one-line option summary "Recommended · under 2 MB"), connected by a 2 dp line; drag to reorder; tap to edit options (opens that tool's options in a sheet); "Add step" dashed card; validation message if a step can't follow the previous ("Remove password can't run after Add password").
- **Run:** pick files → progress per step ("Step 2 of 3 · Compress") → result of the last step.

### 21.28 Summarize · `summarize` · Pro

- **Description:** Get a short summary of a PDF, made on your phone. / Lass dir eine PDF kurz zusammenfassen, direkt auf deinem Handy.

Opens the file picker (if needed) → V1 with the AI panel on the Summary tab (section 22).

### 21.29 Ask this PDF · `forum` · Pro

- **Description:** Ask questions about a PDF and get answers with the page they come from. / Stell Fragen zu einer PDF und bekomme Antworten mit der Seite, aus der sie stammen.

Same, Ask tab.

### 21.30 Translate PDF · `translate` · Pro

- **Description:** Translate a PDF on your phone, without uploading it. / Übersetze eine PDF auf deinem Handy, ohne sie hochzuladen.

Same, Translate tab.

---

## 22. Screens: AI features

### 22.1 Readiness states (shown before the AI panel can work)

| State | Where | Spec |
| --- | --- | --- |
| Device not eligible | AI button in viewer still visible; tapping opens a small sheet | ILL-13, "AI isn't available on this phone", "It needs at least {ram} GB of memory. This phone has {have} GB." / "Dafür braucht es mindestens {ram} GB Arbeitsspeicher. Dieses Handy hat {have} GB.", button "OK"; AI tools in T1 show the same sheet |
| Model not installed | Sheet (medium) | ILL-11, title "Download the AI model", `DkModelCard` (Gemma 4 E2B, 1.3 GB), switch "Download only on Wi-Fi" (on), primary "Download 1.3 GB", note "You can keep using Dokulo while it downloads." |
| Downloading | Same sheet / Home card | Progress in the model card; sheet can be closed; mini bar shows "Downloading AI model · 42 %" |
| First use | Full-screen page | ILL-12, title "AI runs on this phone", body "It reads only this document and can make mistakes. Check important details against the document.", primary "I understand" |
| No text in document | Inside the AI panel | `DkBanner`: "This scan has no text yet." + "Make it searchable (about 20 s)" |
| Low memory now | Inside the panel | Warning banner "Close other apps to use AI – it needs about 2 GB free." + "Try again" |

### 22.2 A1 · AI panel

| # | Region | Spec |
| --- | --- | --- |
| 1 | Container | `DkSheet` over V1 at medium detent (drag to large); tablets: right pane 400 wide |
| 2 | Header | Grab handle; `DkSegmented` Summary · Ask · Translate (DE: Zusammenfassung · Fragen · Übersetzen); overflow (Clear conversation, Change model) |
| 3 | Content | Per tab below |
| 4 | Footer | `DkAIFooter` |

**Summary tab**

| Element | Spec |
| --- | --- |
| Options row | Chips: Short · Detailed (Short); Language dropdown chip: Same as document · English · Deutsch |
| Progress | "Reading page 12 of 40…" with a thin bar, then streaming text |
| Output | Bulleted list `type.bodyL`, 12 between points; key numbers/dates bold; each point ends with one or more `DkPageChip`; detailed mode uses `type.titleS` section headings |
| Actions row | Tertiary icon buttons with labels: Copy · Save as note · Save as text · Regenerate |
| Cached | Caption "Summarised on 7 Oct 2026" above the list |

**Ask tab**

| Element | Spec |
| --- | --- |
| Empty state | Title "Ask about this document" `type.titleS`; 3 `DkSuggestionChip`s generated from the document ("What is the notice period?", "When is the payment due?", "Who are the parties?") |
| Thread | `DkChatBubble`s; AI bubbles include page chips; while streaming: Stop button replaces Send |
| Not found | AI bubble: "I couldn't find this in the document." / "Das habe ich im Dokument nicht gefunden." + "Closest passages:" with 2 page chips |
| Composer | Pinned bottom: text field (multi-line up to 4 lines, `radius.l`, `color.surfaceSunken`), send `DkIconButton` tonal (`arrow_upward`), disabled when empty |
| From text selection | Composer prefilled with "“{selected text}” – " and the keyboard open |

**Translate tab**

| Element | Spec |
| --- | --- |
| Options row | Target language chip (dropdown sheet with search, installed languages first, others with size tags "32 MB"); Engine chip "Auto" (sheet: Auto · Bergamot (fast) · Hy-MT2 (best quality) · EuroLLM · Gemma, each with installed/size state); Pages chip "All" |
| Button | "Translate 12 pages" / "12 Seiten übersetzen" |
| View (phone portrait) | Segmented Original · Translation · Both; Both = paragraphs stacked, original in `color.textSecondary`, translation in `color.textPrimary` |
| View (landscape/tablet) | Two columns with synced scrolling |
| Protected items | IBANs, numbers, emails, names unchanged, with `markup.yellow` @ 40 % background |
| Engine caption | "Translated on this phone with Hy-MT2" + "Change" link |
| Export | Action row: Save as PDF · Save as text · Copy all |
| Missing language pack | Inline card: "German → English needs a 32 MB download." + "Download" |

### 22.3 States to design (frames)

Summary streaming, summary done, summary detailed, Ask empty, Ask with 3 messages, Ask not found, Translate options, Translate both view, Translate side by side (tablet), model download sheet, first-use notice, not eligible sheet, no-text banner.

---

## 23. Screens: Me, settings, AI models

### 23.1 M1 · Me

| # | Section | Rows |
| --- | --- | --- |
| 1 | Large top bar | "Me" / "Ich" |
| 2 | Pro | Free: `DkProCard` (no close button here). Pro: inset card row `workspace_premium` + "Pro – yours for good" / "Pro – für immer deins" + "Thank you" caption |
| 3 | Your things | Signatures (count) · Workflows (count) · AI models (size used) |
| 4 | Settings | Scanning · Files & storage · Security · Appearance · Language |
| 5 | About | Privacy · Open-source licences · Replay intro · Contact · Rate Dokulo · Restore purchase |
| 6 | Footer | Dokulo symbol 24 + "Dokulo 1.0.0 (100)" `type.caption` centred |

### 23.2 M2 · AI models

Top bar "AI models" / "KI-Modelle". Storage summary card: bar "Models 1.8 GB · Free on phone 41 GB". Groups with headers: "AI assistant" (Gemma 4 E2B), "Translation" (Hy-MT2, EuroLLM-1.7B, Bergamot language packs as a nested list with per-pair rows: "German → English · 32 MB · Download"), "Text recognition" (extra OCR languages). Each a `DkModelCard`. Ineligible: card shows "Not available on this phone" with the reason.

**Model detail (tap a card):** sheet with what it does, size, memory need, languages, licence (link), source, version, "Delete model".

### 23.3 M3 · Settings pages

Each section is a pushed page of grouped `DkSettingsRow`s.

| Page | Rows (control · default) |
| --- | --- |
| Scanning / Scannen | Auto-capture (switch, off) · Auto-crop (switch, on) · Default filter (value → picker: Original / Auto colour / Greyscale / Black & white / Remove shadows; Auto colour) · Page size (Auto) · File name (value → editor with token chips {date} {time} {n}; "Scan {date} {time}") · Text recognition language (Auto) · Find documents in photos (switch, off) |
| Files & storage / Dateien & Speicher | Default save folder (Dokulo) · Keep deleted files (7 / 30 days; 30) · Storage (bar: Files / AI models / Cache + "Clear cache" button) · Export all files (opens system share/save) |
| Security / Sicherheit | App lock (switch, off) · Unlock with Face ID (switch) · Lock after (Immediately / 1 min / 5 min; 1 min) · Hide previews in app switcher (switch, on) · Change locked folder PIN |
| Appearance / Darstellung | Theme: three preview tiles (Light / Dark / System) 96 × 140 each with a mini Home mock; selected ring · Viewer night mode (switch, off) |
| Language / Sprache | Radio list: System · English · Deutsch |
| Privacy / Datenschutz | Text page: "What stays on this phone" (bullets: files, scans, AI, signatures), "What uses the internet" (model downloads, Web page to PDF, purchases), "No analytics, no ads, no account"; link to full privacy policy |
| Open-source licences | Searchable list of packages and models → licence text page |

---

## 24. Screens: Pro and paywall

### 24.1 X3 · Paywall sheet (large detent)

| # | Region | Spec |
| --- | --- | --- |
| 1 | Close | × top-right, always visible, 44 hit |
| 2 | Illustration | ILL-18, 96 tall |
| 3 | Headline | `type.display` "Unlock every tool, for good" / "Alle Werkzeuge freischalten – für immer" |
| 4 | Context line (when opened from a tool) | `type.bodyM` `color.textSecondary`: "Black out is part of Pro." / "Schwärzen ist Teil von Pro." |
| 5 | Benefits | 5 rows, each: 24 tool icon in tonal circle + `type.bodyL`: Black out sensitive data · Make scans searchable · Summarize, ask and translate · Compare, fill forms, PDF/A · Workflows and locked folder |
| 6 | Reassurance | `type.caption` row with three items separated by dots: One-time purchase · No subscription · Works offline |
| 7 | Price + button | Primary large button "Unlock Pro · {price}" / "Pro freischalten · {price}" (price comes from the store; final price not decided, €9.99–14.99; use €12.99 in mockups) |
| 8 | Footer | Tertiary "Restore purchase"; caption links: Terms · Privacy; iOS: "Shared with your family via Family Sharing" |

**States:** default; purchasing (button loading); success (sheet content replaced: success tick animation, "Pro is unlocked" / "Pro ist freigeschaltet", "Thank you for supporting Dokulo.", button "Continue" → returns and runs the tool); error inline banner "Purchase didn't complete. You weren't charged." / "Kauf nicht abgeschlossen. Dir wurde nichts berechnet."; restore success toast "Pro restored"; restore nothing found "No purchase found for this account."

### 24.2 Pro touchpoints (inventory)

Tool tiles (badge) · T2 header badge · T2 first-try caption · Save sheet OCR switch badge · Home `DkProCard` · Me Pro card · Search banner "Make searchable" badge · AI entry points. No other placements.

---

## 25. System surfaces

### 25.1 Notifications

Small icon: Dokulo symbol monochrome (24, white on transparent for Android). Title/body:

| Event | Title EN / DE | Body EN / DE |
| --- | --- | --- |
| Job finished | Compression finished / Verkleinern abgeschlossen | Mietvertrag.pdf · 1.9 MB (−77 %) |
| Job failed | Couldn't finish Merge / Zusammenfügen fehlgeschlagen | Tap to see what happened / Tippe für Details |
| Batch finished | Batch finished / Stapel abgeschlossen | 48 of 50 done · 2 skipped |
| Model downloaded | AI model ready / KI-Modell bereit | You can now summarize, ask and translate. |
| Photo finder done | Found 37 documents in your photos / 37 Dokumente in deinen Fotos gefunden | Tap to review / Zum Ansehen tippen |

Android progress notification for long jobs: tool name, file name, determinate bar, Cancel action.

### 25.2 Home-screen widgets

| Widget | Size | Content |
| --- | --- | --- |
| Scan | Small (2×2 / iOS small) | `color.primary` background, symbol + `document_scanner` icon large, label "Scan"; tap → S1 |
| Quick tools | Medium (4×2 / iOS medium) | Scan button left; 3 pinned tool icons right with labels (Merge, Compress, Sign) |
| Last scan | Small | Thumbnail of the last scan + name; tap → V1 |

Light and dark versions; follow platform widget corner radii.

### 25.3 App icon shortcuts (long-press)

Scan · Merge PDF · Compress PDF · {last used tool}; each with its tool icon (monochrome glyph per platform rules).

### 25.4 iOS Share Extension and Files Action Extension

- **Share extension UI:** compact card: Dokulo symbol + "Open in Dokulo", file thumbnail and name, list of 6 quick tools (Open, Compress, Merge, Add password, Sign, Black out) as rows; tapping hands off to the app at that tool.
- **Files action ("Dokulo"):** no UI of its own; opens the app at the X1 picker. Design the action icon (symbol glyph).

### 25.5 Android share target

The system share sheet shows "Dokulo" with the app icon; direct-share shortcuts for "Compress with Dokulo" and "Merge with Dokulo" (tool icons on the app-icon background).

---

## 26. Global states: empty, loading, error, offline, permissions

### 26.1 Empty states (all use `DkEmptyState`)

| Where | Illustration | Title EN / DE | Body EN / DE | Buttons |
| --- | --- | --- | --- | --- |
| Home recents | ILL-04 | Your scans and PDFs will appear here / Deine Scans und PDFs erscheinen hier | Scan a document or open a PDF to get started. / Scanne ein Dokument oder öffne eine PDF. | Scan a document |
| Files root | ILL-05 | No files yet / Noch keine Dateien | (same body) | Scan a document · Open a file |
| Folder | ILL-06 | This folder is empty / Dieser Ordner ist leer | Move files here or save tool results here. | Move files here |
| Search | ILL-07 | Nothing found for “{q}” / Nichts gefunden für „{q}“ | Try another word or check the spelling. | — |
| Trash | ILL-08 | Nothing here / Hier ist nichts | Deleted files stay here for 30 days. | — |
| Signatures | ILL-15 | No signatures yet / Noch keine Unterschriften | Add one to sign PDFs in seconds. | Add signature |
| Workflows | ILL-16 | No workflows yet / Noch keine Abläufe | Chain tools you use together, then run them in one tap. | New workflow · Use a template |
| Photo finder | ILL-17 (small) | No documents found / Keine Dokumente gefunden | — | Close |

### 26.2 Loading

Skeletons for lists, grids, thumbnails, model cards; page skeleton for the viewer; spinners only inside buttons and for < 2 s waits in sheets.

### 26.3 Error catalogue (message + action)

| Situation | Title EN | Title DE | Action |
| --- | --- | --- | --- |
| Locked input | This PDF is locked. | Diese PDF ist gesperrt. | Enter password |
| Damaged file | This file can't be opened. | Diese Datei lässt sich nicht öffnen. | Try Repair |
| Not enough storage | Not enough space on this phone (needs about 120 MB). | Nicht genug Speicher auf diesem Handy (etwa 120 MB nötig). | Manage storage |
| Too large for memory | This file is too large to process at once on this phone. | Diese Datei ist zu groß, um sie auf diesem Handy auf einmal zu verarbeiten. | Split it first |
| Unsupported form | This form type can't be filled on phones. | Dieser Formulartyp lässt sich auf Handys nicht ausfüllen. | Open read-only |
| Model missing | Translation needs a language model (440 MB). | Für die Übersetzung wird ein Sprachmodell benötigt (440 MB). | Download |
| Low memory | Close other apps to use AI – it needs about 2 GB free. | Schließe andere Apps, um KI zu nutzen – sie braucht etwa 2 GB freien Speicher. | Try again |
| Cancelled | Cancelled. Your original file wasn't changed. | Abgebrochen. Deine Originaldatei wurde nicht verändert. | — |
| Unexpected | Something went wrong on page 14. (code DK-0142) | Auf Seite 14 ist etwas schiefgegangen. (Code DK-0142) | Try again · Skip this page · Send report by email |
| Offline (web tool) | You're offline. | Du bist offline. | Try again |

Error presentation: inline in the step (field errors, banners) whenever possible; full error state inside the progress sheet for job failures; never a generic modal "Error".

### 26.4 Permissions denied

Inline `DkBanner` (warning) at the point of use with "Open settings"; never repeated system prompts.

---

## 27. Copy deck (EN / DE)

Screen-specific strings are in their sections. This deck lists shared strings used across the app.

### 27.1 Common actions

| Key | EN | DE |
| --- | --- | --- |
| `common_cancel` | Cancel | Abbrechen |
| `common_done` | Done | Fertig |
| `common_save` | Save | Speichern |
| `common_save_copy` | Save as copy | Als Kopie speichern |
| `common_replace_original` | Replace original | Original ersetzen |
| `common_save_to` | Save to… | Speichern unter… |
| `common_share` | Share | Teilen |
| `common_open` | Open | Öffnen |
| `common_undo` | Undo | Rückgängig |
| `common_delete` | Delete | Löschen |
| `common_delete_forever` | Delete for good | Endgültig löschen |
| `common_restore` | Restore | Wiederherstellen |
| `common_rename` | Rename | Umbenennen |
| `common_duplicate` | Duplicate | Duplizieren |
| `common_move` | Move | Verschieben |
| `common_info` | Info | Info |
| `common_next` | Next | Weiter |
| `common_skip` | Skip | Überspringen |
| `common_continue` | Continue | Fortfahren |
| `common_try_again` | Try again | Erneut versuchen |
| `common_open_settings` | Open settings | Einstellungen öffnen |
| `common_not_now` | Not now | Nicht jetzt |
| `common_select_all` | Select all | Alle auswählen |
| `common_selected` | {n} selected | {n} ausgewählt |
| `common_add_files` | Add files | Dateien hinzufügen |
| `common_browse` | Browse device | Gerät durchsuchen |
| `common_more_options` | More options | Weitere Optionen |
| `common_apply_all` | Apply to all pages | Auf alle Seiten anwenden |
| `common_use_default` | Use as default | Als Standard verwenden |
| `common_download` | Download | Herunterladen |
| `common_pause` | Pause | Pausieren |
| `common_keep_working` | Keep working | Weiterarbeiten |

### 27.2 Common labels and toasts

| Key | EN | DE |
| --- | --- | --- |
| `privacy_line_tool` | Processed on this phone | Wird auf diesem Handy verarbeitet |
| `privacy_line_home` | Everything stays on this phone | Alles bleibt auf diesem Handy |
| `pro_badge` | Pro | Pro |
| `pro_free_try` | Free try · Pro unlocks unlimited use | Kostenlos testen · Pro für unbegrenzte Nutzung |
| `meta_pages` | {n, plural, one{1 page} other{{n} pages}} | {n, plural, one{1 Seite} other{{n} Seiten}} |
| `meta_files` | {n, plural, one{1 file} other{{n} files}} | {n, plural, one{1 Datei} other{{n} Dateien}} |
| `meta_today` | Today {time} | Heute {time} |
| `meta_yesterday` | Yesterday {time} | Gestern {time} |
| `toast_saved` | Saved | Gespeichert |
| `toast_saved_to` | Saved to {folder} | Gespeichert in {folder} |
| `toast_moved_trash` | Moved to Recently deleted | In „Zuletzt gelöscht“ verschoben |
| `toast_moved` | Moved to {folder} | Nach {folder} verschoben |
| `toast_copied` | Copied | Kopiert |
| `toast_page_deleted` | Page deleted | Seite gelöscht |
| `toast_replaced` | Replaced | Ersetzt |
| `progress_page` | Page {i} of {n} | Seite {i} von {n} |
| `progress_time_left` | about {t} left | noch etwa {t} |
| `size_change` | {before} → {after} (−{p} %) | {before} → {after} (−{p} %) |
| `job_running_many` | {n} jobs running | {n} Aufgaben laufen |

### 27.3 Tool names, button and suffix patterns

| Tool | Name EN | Name DE | Button EN | Button DE | Suffix EN / DE |
| --- | --- | --- | --- | --- | --- |
| Merge | Merge PDF | PDF zusammenfügen | Merge {n} files | {n} Dateien zusammenfügen | merged / zusammengefügt |
| Split | Split PDF | PDF teilen | Split into {n} files | In {n} Dateien teilen | part {i} / Teil {i} |
| Extract pages | Extract pages | Seiten extrahieren | Extract {n} pages | {n} Seiten extrahieren | extract / Auszug |
| Organize | Organize pages | Seiten ordnen | Save | Speichern | organized / geordnet |
| Rotate | Rotate PDF | PDF drehen | Save rotation | Drehung speichern | rotated / gedreht |
| Smart Split | Smart Split | Smart teilen | Find documents | Dokumente finden | (names suggested) |
| Image to PDF | Image to PDF | Bild zu PDF | Create PDF · {n} images | PDF erstellen · {n} Bilder | — |
| PDF to images | PDF to images | PDF zu Bildern | Export {n} images | {n} Bilder exportieren | page {i} / Seite {i} |
| Web to PDF | Web page to PDF | Webseite zu PDF | Create PDF | PDF erstellen | (page title) |
| PDF/A | Convert to PDF/A | In PDF/A umwandeln | Convert to PDF/A | In PDF/A umwandeln | PDF-A / PDF-A |
| PDF to text | PDF to text | PDF zu Text | Extract text | Text extrahieren | text / Text |
| Compress | Compress PDF | PDF verkleinern | Compress {n} pages | {n} Seiten verkleinern | compressed / verkleinert |
| Repair | Repair PDF | PDF reparieren | Repair PDF | PDF reparieren | repaired / repariert |
| OCR | Make text searchable | Text durchsuchbar machen | Recognise text · {n} pages | Text erkennen · {n} Seiten | searchable / durchsuchbar |
| Page numbers | Add page numbers | Seitenzahlen hinzufügen | Add numbers to {n} pages | Seitenzahlen zu {n} Seiten hinzufügen | numbered / nummeriert |
| Watermark | Add watermark | Wasserzeichen hinzufügen | Add watermark | Wasserzeichen hinzufügen | watermarked / mit Wasserzeichen |
| Crop | Crop pages | Seiten zuschneiden | Crop {n} pages | {n} Seiten zuschneiden | cropped / zugeschnitten |
| Mark up | Mark up | Markieren | — | — | (new version) |
| Fill form | Fill form | Formular ausfüllen | — | — | (new version) |
| Sign | Sign PDF | PDF unterschreiben | — | — | (new version) |
| Protect | Add password | Passwort hinzufügen | Add password | Passwort hinzufügen | protected / geschützt |
| Unlock | Remove password | Passwort entfernen | Remove password | Passwort entfernen | unlocked / entsperrt |
| Redact | Black out | Schwärzen | Black out {n} items | {n} Stellen schwärzen | redacted / geschwärzt |
| Compare | Compare PDFs | PDFs vergleichen | Compare | Vergleichen | comparison / Vergleich |
| Extract assets | Extract images & text | Bilder & Text extrahieren | Extract | Extrahieren | — |
| Batch | Batch | Stapelverarbeitung | Run on {n} files | Auf {n} Dateien anwenden | — |
| Workflows | Workflows | Abläufe | Run workflow | Ablauf starten | — |
| Summarize | Summarize | Zusammenfassen | — | — | — |
| Ask | Ask this PDF | Diese PDF fragen | — | — | — |
| Translate | Translate PDF | PDF übersetzen | Translate {n} pages | {n} Seiten übersetzen | translated / übersetzt |

### 27.4 Writing checklist for any new string

Sentence case · verb-first buttons · numbers instead of adjectives · no exclamation marks · "du" in German · ≤ 2 lines in buttons at 200 % text · tested in German.

---

## 28. Accessibility requirements for visuals

| Area | Requirement |
| --- | --- |
| Contrast | 4.5:1 text; 3:1 large text, icons with meaning, input borders, focus rings; check every pair in Light and Dark and on camera chrome |
| Colour alone | Never: Pro uses the word, compare uses labels and icons, errors use icon + text, redaction categories have names, selected states use a check, not only a tint |
| Touch targets | ≥ 48 × 48 dp everywhere; crop handles get a 44+ invisible hit area plus the magnifier |
| Text scaling | Design H1, T1, T2 (Compress), T3, S2, X3 at 200 % text: grids drop to 2 columns, level cards stack, buttons wrap |
| Focus | Visible 2 dp focus ring for keyboard/switch access on every interactive element |
| Motion | Every signature motion has a reduced version (cross-fade); no flashing above 3 Hz; capture flash disabled with Reduce Motion |
| Screen readers | Provide labels in the design file for icon-only buttons; specify reading order on complex screens (viewer, scanner, result) |
| Scanner | Hint pill text is also spoken; capture confirmation is spoken ("Page 3 captured") |
| Thumbnails | Page numbers always visible as text under thumbnails |
| Errors | Error text placed next to the field it refers to |

---

## 29. Dark mode rules

1. Every screen and component is designed in Dark as well as Light (frame inventory counts both).
2. Elevation in dark mode uses lighter surfaces (`color.surfaceRaised`) and outlines instead of shadows.
3. PDF pages stay white in dark mode (documents look like documents); only Viewer night mode inverts them.
4. Thumbnails keep white pages with a 1 dp `color.outline` so they don't glow; reduce page brightness to 92 % in dark mode to soften glare.
5. Illustrations switch to the dark stroke/accent tokens.
6. The camera UI is identical in both themes (always dark chrome).
7. Pro colours: `color.pro` amber is lighter in dark mode; check contrast on `color.proContainer` dark.
8. Toasts use inverse colours (light toast in dark mode).

---

## 30. Tablet and landscape rules

| Screen | Medium (600–839) | Expanded (≥ 840) |
| --- | --- | --- |
| Navigation | Tab bar | Navigation rail 80 wide, Scan button on top |
| H1 Home | Tools grid 6 columns; recents in 2 columns | Left: tools (8 columns); right column 360: recents |
| T1 Tools | 6 columns | 8 columns, category list as a left sidebar (200) |
| F1 Files | Grid 4 columns | Two panes: list (360) + preview (thumbnail strip, info, actions) |
| V1 Viewer | Same as phone, wider pages | Thumbnail sidebar (120, toggle) + pages + AI pane (400, toggle) |
| P1 Organize | 5 columns | 8 columns |
| S1 Scanner | Controls on the right edge in landscape | Same |
| T2/T3 Tool shell | Content max width 640 centred | Options left (480) + live preview right |
| Compare | Side by side in landscape | Side by side always + change list as right sidebar |
| X3 Paywall | Centred dialog 480 wide instead of sheet | Same |
| Sheets | Become centred dialogs (max 560) or popovers when anchored to a button | Same |

**Phone landscape:** only Viewer, Signature pad (landscape-only), Compare, Translate side-by-side and the Scanner (controls move to the right edge) support landscape; all other screens are portrait-locked on phones.

---

## 31. App icon and store assets brief

### 31.1 App icon

| Item | Spec |
| --- | --- |
| Concept | Dokulo symbol in white on a `color.primary` background; optional subtle vertical gradient #2A5BF0 → #1E49D1 (max 6 % difference) |
| iOS | 1024 × 1024 master, no transparency; light, dark (symbol in `#8AA8FF` on near-black) and tinted (monochrome) variants per iOS 18+ |
| Android | Adaptive icon: foreground symbol (safe zone 66 dp of 108), background solid `color.primary`; monochrome layer for themed icons |
| Notification icon (Android) | White symbol silhouette, 24 dp, transparent background |
| Avoid | Text in the icon, "PDF" lettering, red (reserved for danger), scanner-camera clichés |

### 31.2 Store screenshots (6.9" iPhone and Android phone; tablets later)

| # | Caption EN | Caption DE | Screen shown |
| --- | --- | --- | --- |
| 1 | All your PDF tools. Nothing uploaded. | Alle PDF-Werkzeuge. Nichts wird hochgeladen. | Home with tools and recents, airplane-mode status icon visible |
| 2 | Scan anything in seconds | Alles in Sekunden scannen | S1 with detected document quad |
| 3 | Under 2 MB for any upload portal | Unter 2 MB für jedes Upload-Portal | T3 Compress result "1.9 MB (−77 %)" |
| 4 | Black out what others shouldn't see | Schwärze, was andere nicht sehen sollen | Black out review with IBAN boxes |
| 5 | Sign without printing | Unterschreiben ohne Drucker | V2 with signature placed |
| 6 | Summarize and translate – offline | Zusammenfassen und übersetzen – offline | AI panel summary with page chips |
| 7 | No watermark. No subscription. | Kein Wasserzeichen. Kein Abo. | Tools grid with a small "Pay once" card |

Style: device frames on `color.primaryContainer` background, caption `type.display`-like at 64 px (store pixel size) in `color.onPrimaryContainer`, fictional documents only.

### 31.3 Other assets

- Google Play feature graphic 1024 × 500: symbol + wordmark + tagline on primary.
- App preview video storyboard (optional, 20 s): scan → compress → black out → share, airplane-mode icon on screen.
- In-app "About" header: wordmark 32 tall.

---

## 32. Designer deliverables and frame inventory

### 32.1 Deliverables

1. Figma library: foundations (colour/text/effect styles for Light and Dark), icons, illustrations ILL-01…ILL-20, all components from section 11 with variants and states.
2. Screens: every frame in 32.2, in Light and Dark, phone standard size; EN for all, DE for the ones marked; iPhone SE and 200 % text checks where marked.
3. Tablet frames listed in 32.3.
4. Prototype: flows in 32.4, clickable, with the signature motions from section 9.
5. App icon set, notification icon, widgets, store screenshots and feature graphic (section 31).
6. Redlines or Dev Mode annotations for spacing and tokens on each screen; every layer uses styles, no raw values.

### 32.2 Phone frame inventory

| Area | Frames (states) | DE | SE / 200 % |
| --- | --- | --- | --- |
| Launch + onboarding | Launch, O1, O2, O3 | All | O1 SE |
| Home | First launch, default, continue (scan), continue (job), edit pinned, add-tool sheet, Pro card, photo-finder banner, mini job bar | Default | Default 200 % |
| Tools | Default, scrolled with chip selected, search results, search empty, About-tool sheet | Default | Default 200 % |
| Files | Root list, root grid, folder with breadcrumb, selection mode, empty root, empty folder, search results, search empty with OCR banner, sort menu, action sheet, info sheet, rename dialog, move sheet, new folder dialog, recently deleted, empty-trash dialog | Root, action sheet | — |
| Locked folder | L1 intro, L2 PIN, L3 mismatch, L4 biometrics, unlock, content, app lock screen, app-switcher cover | L1 | — |
| Viewer | Default, chrome hidden, loading, search, search no-text banner, text selected with markup bar, locked PDF, wrong password, night mode, damaged file, form banner, go to page, link dialog, overflow menu, thumbnail strip | Default, locked | — |
| Edit mode | Pen selected, options sheet (pen), highlighter on text, text box editing, shapes, note sheet, annotation selected, form filling with accessory bar, discard dialog | Default | — |
| Signatures | Sheet empty, sheet with 2 signatures, pad Draw, pad Type, pad Image, placed signature with date | Pad | — |
| Organize | Default, dragging, 3 selected, insert sheet, after delete toast | Default | — |
| Scanner | Pre-prompt, denied, S1 no doc, S1 quad, auto countdown, flash menu, ID front, ID back, Book, Batch 12 pages, S2 default, crop + magnifier, filter strip, apply-to-all chip, retake label, discard dialog, save sheet, scan result | S1 quad, save sheet | S1 SE |
| Photo finder | Intro sheet, scanning card, results grid with selection, convert sheet, empty | Intro | — |
| Tool shell | T2 empty input, T2 Compress (options), T2 Merge (4 files), T2 Pro first-try caption, T2 locked input row, progress button state, progress sheet, mini bar, cancel dialog, failure state, X1 picker (single PDF), X1 picker (4 files), T3 Compress result, T3 multi-file result (Split), T3 partial (OCR), save menu, replace dialog, discard dialog | T2 Compress, T3 Compress | T2 Compress 200 %, T3 200 % |
| Tools (dedicated) | Split (ranges + visual markers), Extract (grid), Rotate (grid + banner), Smart Split review, Image to PDF, PDF to images, Web to PDF (preview + offline), PDF/A result with warning, PDF to text result, Compress edge states (already small, target dialog), OCR result, Page numbers, Watermark, Crop, Fill form dialogs, Add password, Remove password, Black out (find, review, confirm, result, failed), Compare (setup, single view, side-by-side landscape, change list), Extract assets result, Batch (tool choice, queue, result), Workflows (list, builder, run) | Black out, Compress | — |
| AI | Not eligible, model download, downloading, first-use notice, summary streaming, summary done, detailed, Ask empty, Ask thread, Ask not found, Translate options, Translate both view, engine sheet, language sheet, no-text banner, low-memory banner | Summary, Ask | Summary 200 % |
| Me & settings | Me (free), Me (Pro), AI models, model detail, Scanning, Files & storage, Security, Appearance, Language, Privacy, Licences list, Licence detail | Me | — |
| Paywall | Default (from tool), default (from Me), purchasing, success, error, restore none found | Default | Default SE, 200 % |
| System | Notifications (5), Android progress notification, widgets (3 × light/dark), shortcuts, iOS share extension | Notifications | — |
| Global | Toast (with action), banners (info/warning/error/Pro), empty states (8), error catalogue examples | — | — |

### 32.3 Tablet frames (820 × 1180 portrait and 1366 × 1024 landscape)

Home, Tools, Files two-pane, Viewer with AI pane, Organize, T2/T3 Compress with live preview, Compare side by side, Paywall dialog, Scanner landscape.

### 32.4 Prototype flows

1. First launch → onboarding → scan 3 pages → review (crop, filter, apply to all) → save → compress from Next chip → share.
2. Share a PDF from another app → X1 picker → Black out → review → confirm → result → add password.
3. Home → Merge 4 files (reorder, page range) → progress sheet → keep working → notification → result → save.
4. Open PDF → select text → Ask AI → answer with page chip → jump to page.
5. Pro tool second use → paywall → purchase success → tool runs.
6. Files → long-press → multi-select → move to locked folder → set PIN → open locked folder.

### 32.5 Acceptance checklist for the design

- [ ] Every frame uses tokens/styles only (no detached colours or text)
- [ ] Every component has Light, Dark, pressed, disabled, focused states
- [ ] All strings come from this document; German frames checked for wrapping
- [ ] Contrast checked on every new colour pair
- [ ] 200 % text frames show no clipping
- [ ] Pro badges appear only at the touchpoints in 24.2
- [ ] Every destructive action uses the confirmation rules in 12.4
- [ ] Every tool's result card shows a number (section 21)
- [ ] No real personal data in mockups

---

*End of specification. Questions or gaps: add a comment in the design file referencing the section number.*
