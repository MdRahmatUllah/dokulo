# Frame inventory check: §32.2 / §32.3 vs dokulo-design/ (DK-1010)

Spec: docs/dokulo-ui-design-spec.md §32.2 (phone) and §32.3 (tablet). Export: dokulo-design/{light,dark,deutsch}/. File existence was checked by a script against light/, dark/ and deutsch/, not by hand (2026-10-16). SE = the `-iphone-se` file; 200 % = a section heading in `27-accessibility/text-200-percent.html`.

**Counts:** 217 inventory frames/states (incl. 20 tablet portrait/landscape), 217 matched to an export file in every theme and language the inventory asks for. The 2 German gaps found were filled in DK-1010 (see Gaps).


## Launch + onboarding

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| Launch | `01-onboarding/onboarding-launch.html` | yes | yes | yes |  |  |
| O1 | `01-onboarding/onboarding-o1.html` | yes | yes | yes | SE `01-onboarding/onboarding-o1-iphone-se.html`: light+dark; DE yes |  |
| O2 | `01-onboarding/onboarding-o2.html` | yes | yes | yes |  |  |
| O3 | `01-onboarding/onboarding-o3.html` | yes | yes | yes |  |  |

## Home

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| First launch | `02-home/home-first.html` | yes | yes | n/a |  |  |
| Default | `02-home/home-default.html` | yes | yes | yes | 200 % "H1 Home – default – 200 %": light+dark |  |
| Continue (scan) | `02-home/home-contscan.html` | yes | yes | n/a |  | index: "continue (unsaved scan)" |
| Continue (job) | `02-home/home-contjob.html` | yes | yes | n/a |  | index: "continue (job finished)" |
| Edit pinned | `02-home/home-edit.html` | yes | yes | n/a |  |  |
| Add-tool sheet | `02-home/home-addtool.html` | yes | yes | n/a |  |  |
| Pro card | `02-home/home-procard.html` | yes | yes | n/a |  |  |
| Photo-finder banner | `02-home/home-photobanner.html` | yes | yes | n/a |  | index: "find documents banner" |
| Mini job bar | `02-home/home-job.html` | yes | yes | n/a |  | index: "mini job bar" |

## Tools

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| Default | `03-tools/tools-default.html` | yes | yes | yes | 200 % "T1 Tools – default – 200 %": light+dark |  |
| Scrolled with chip selected | `03-tools/tools-chip.html` | yes | yes | n/a |  | index: "scrolled, Security selected" |
| Search results | `03-tools/tools-search.html` | yes | yes | n/a |  |  |
| Search empty | `03-tools/tools-searchempty.html` | yes | yes | n/a |  |  |
| About-tool sheet | `03-tools/tools-about.html` | yes | yes | n/a |  |  |

## Files

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| Root list | `04-files/files-list.html` | yes | yes | yes |  | DE "Root" |
| Root grid | `04-files/files-grid.html` | yes | yes | n/a |  |  |
| Folder with breadcrumb | `04-files/files-folder.html` | yes | yes | n/a |  |  |
| Selection mode | `04-files/files-select.html` | yes | yes | n/a |  |  |
| Empty root | `04-files/files-empty.html` | yes | yes | n/a |  |  |
| Empty folder | `04-files/files-emptyfolder.html` | yes | yes | n/a |  |  |
| Search results | `04-files/files-search.html` | yes | yes | n/a |  |  |
| Search empty with OCR banner | `04-files/files-searchempty.html` | yes | yes | n/a |  |  |
| Sort menu | `04-files/files-sort.html` | yes | yes | n/a |  |  |
| Action sheet | `04-files/files-action.html` | yes | yes | yes |  |  |
| Info sheet | `04-files/files-info.html` | yes | yes | n/a |  |  |
| Rename dialog | `04-files/files-rename.html` | yes | yes | n/a |  | index: "rename dialog (error)" |
| Move sheet | `04-files/files-move.html` | yes | yes | n/a |  |  |
| New folder dialog | `04-files/files-newfolder.html` | yes | yes | n/a |  |  |
| Recently deleted | `04-files/files-trash.html` | yes | yes | n/a |  |  |
| Empty-trash dialog | `04-files/files-emptytrash.html` | yes | yes | n/a |  |  |

## Locked folder

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| L1 intro | `05-locked-folder/locked-folder-l1.html` | yes | yes | yes |  |  |
| L2 PIN | `05-locked-folder/locked-folder-l2.html` | yes | yes | n/a |  |  |
| L3 mismatch | `05-locked-folder/locked-folder-l3.html` | yes | yes | n/a |  |  |
| L4 biometrics | `05-locked-folder/locked-folder-l4.html` | yes | yes | n/a |  |  |
| Unlock | `05-locked-folder/locked-folder-unlock.html` | yes | yes | n/a |  |  |
| Content | `05-locked-folder/locked-folder-content.html` | yes | yes | n/a |  | index: "content + move toast" |
| App lock screen | `05-locked-folder/locked-folder-applock.html` | yes | yes | n/a |  |  |
| App-switcher cover | `05-locked-folder/locked-folder-cover.html` | yes | yes | n/a |  |  |

## Viewer

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| Default | `06-viewer/viewer-default.html` | yes | yes | yes |  |  |
| Chrome hidden | `06-viewer/viewer-hidden.html` | yes | yes | n/a |  |  |
| Loading | `06-viewer/viewer-loading.html` | yes | yes | n/a |  |  |
| Search | `06-viewer/viewer-search.html` | yes | yes | n/a |  |  |
| Search no-text banner | `06-viewer/viewer-searchnotext.html` | yes | yes | n/a |  | index: "search, scan without text" |
| Text selected with markup bar | `06-viewer/viewer-select.html` | yes | yes | n/a |  |  |
| Locked PDF | `06-viewer/viewer-locked.html` | yes | yes | yes |  |  |
| Wrong password | `06-viewer/viewer-wrongpw.html` | yes | yes | n/a |  |  |
| Night mode | `06-viewer/viewer-night.html` | yes | yes | n/a |  |  |
| Damaged file | `06-viewer/viewer-damaged.html` | yes | yes | n/a |  |  |
| Form banner | `06-viewer/viewer-form.html` | yes | yes | n/a |  | index: "form detected" |
| Go to page | `06-viewer/viewer-goto.html` | yes | yes | n/a |  |  |
| Link dialog | `06-viewer/viewer-link.html` | yes | yes | n/a |  | index: "external link dialog" |
| Overflow menu | `06-viewer/viewer-menu.html` | yes | yes | n/a |  |  |
| Thumbnail strip | `06-viewer/viewer-thumbs.html` | yes | yes | n/a |  |  |

## Edit mode

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| Pen selected | `07-edit/edit-pen.html` | yes | yes | yes |  | DE "Default": taken as pen selected (first edit-mode state); all 07-edit files exist in deutsch/ |
| Options sheet (pen) | `07-edit/edit-penopts.html` | yes | yes | n/a |  |  |
| Highlighter on text | `07-edit/edit-highlight.html` | yes | yes | n/a |  |  |
| Text box editing | `07-edit/edit-text.html` | yes | yes | n/a |  |  |
| Shapes | `07-edit/edit-shapes.html` | yes | yes | n/a |  |  |
| Note sheet | `07-edit/edit-note.html` | yes | yes | n/a |  |  |
| Annotation selected | `07-edit/edit-annsel.html` | yes | yes | n/a |  |  |
| Form filling with accessory bar | `07-edit/edit-form.html` | yes | yes | n/a |  |  |
| Discard dialog | `07-edit/edit-discard.html` | yes | yes | n/a |  |  |

## Signatures

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| Sheet empty | `08-sign/sign-empty.html` | yes | yes | n/a |  |  |
| Sheet with 2 signatures | `08-sign/sign-list.html` | yes | yes | n/a |  | index: "2 saved" |
| Pad Draw | `08-sign/signature-pad-draw.html` | yes | yes | yes |  | landscape 852×393 |
| Pad Type | `08-sign/signature-pad-type.html` | yes | yes | yes |  | landscape 852×393 |
| Pad Image | `08-sign/signature-pad-image.html` | yes | yes | yes |  | landscape 852×393 |
| Placed signature with date | `08-sign/sign-placed.html` | yes | yes | n/a |  |  |

## Organize

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| Default | `09-organize-pages/organize-default.html` | yes | yes | yes |  |  |
| Dragging | `09-organize-pages/organize-drag.html` | yes | yes | n/a |  | index: "page lifted mid-drag" |
| 3 selected | `09-organize-pages/organize-selected.html` | yes | yes | n/a |  |  |
| Insert sheet | `09-organize-pages/organize-insert.html` | yes | yes | n/a |  |  |
| After delete toast | `09-organize-pages/organize-deleted.html` | yes | yes | n/a |  |  |

## Scanner

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| Pre-prompt | `10-scanner/scanner-camera-prompt.html` | yes | yes | n/a |  |  |
| Denied | `10-scanner/scanner-camera-denied.html` | yes | yes | n/a |  |  |
| S1 no doc | `10-scanner/scanner-camera-nodoc.html` | yes | yes | n/a |  |  |
| S1 quad | `10-scanner/scanner-camera-quad.html` | yes | yes | yes | SE `10-scanner/scanner-camera-quad-iphone-se.html`: light+dark; DE yes | S1 SE = the quad state on SE |
| Auto countdown | `10-scanner/scanner-camera-countdown.html` | yes | yes | n/a |  |  |
| Flash menu | `10-scanner/scanner-camera-flash.html` | yes | yes | n/a |  |  |
| ID front | `10-scanner/scanner-camera-idfront.html` | yes | yes | n/a |  |  |
| ID back | `10-scanner/scanner-camera-idback.html` | yes | yes | n/a |  | index: "ID card · turn over" |
| Book | `10-scanner/scanner-camera-book.html` | yes | yes | n/a |  |  |
| Batch 12 pages | `10-scanner/scanner-camera-batch.html` | yes | yes | n/a |  |  |
| S2 default | `10-scanner/scanner-review-review.html` | yes | yes | n/a |  |  |
| Crop + magnifier | `10-scanner/scanner-review-crop.html` | yes | yes | n/a |  |  |
| Filter strip | `10-scanner/scanner-review-filter.html` | yes | yes | n/a |  |  |
| Apply-to-all chip | `10-scanner/scanner-review-applyall.html` | yes | yes | n/a |  |  |
| Retake label | `10-scanner/scanner-camera-retake.html` | yes | yes | n/a |  | index: "retake page 3" (camera with the retake label) |
| Discard dialog | `10-scanner/scanner-review-discard.html` | yes | yes | n/a |  |  |
| Save sheet | `10-scanner/scanner-review-save.html` | yes | yes | yes |  |  |
| Scan result | `10-scanner/scanner-review-result.html` | yes | yes | n/a |  |  |

## Photo finder

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| Intro sheet | `11-photo-finder/photo-finder-intro.html` | yes | yes | yes |  |  |
| Scanning card | `11-photo-finder/photo-finder-scanning.html` | yes | yes | n/a |  |  |
| Results grid with selection | `11-photo-finder/photo-finder-results.html` | yes | yes | n/a |  |  |
| Convert sheet | `11-photo-finder/photo-finder-convert.html` | yes | yes | n/a |  |  |
| Empty | `11-photo-finder/photo-finder-empty.html` | yes | yes | n/a |  | index: "no documents found" |

## Tool shell

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| T2 empty input | `12-tool-shell/tool-shell-t2empty.html` | yes | yes | n/a |  |  |
| T2 Compress (options) | `12-tool-shell/tool-shell-compress.html` | yes | yes | yes | 200 % "T2 Compress – options – 200 %": light+dark |  |
| T2 Merge (4 files) | `12-tool-shell/tool-shell-merge.html` | yes | yes | n/a |  |  |
| T2 Pro first-try caption | `12-tool-shell/tool-shell-protry.html` | yes | yes | n/a |  |  |
| T2 locked input row | `12-tool-shell/tool-shell-lockedrow.html` | yes | yes | n/a |  |  |
| Progress button state | `12-tool-shell/tool-shell-btnloading.html` | yes | yes | n/a |  | index: "X2 · button loading (2–10 s)" |
| Progress sheet | `12-tool-shell/tool-shell-progress.html` | yes | yes | n/a |  |  |
| Mini bar | `12-tool-shell/tool-shell-minibar.html` | yes | yes | n/a |  |  |
| Cancel dialog | `12-tool-shell/tool-shell-canceldlg.html` | yes | yes | n/a |  |  |
| Failure state | `12-tool-shell/tool-shell-failure.html` | yes | yes | n/a |  |  |
| X1 picker (single PDF) | `12-tool-shell/tool-shell-x1single.html` | yes | yes | n/a |  |  |
| X1 picker (4 files) | `12-tool-shell/tool-shell-x1multi.html` | yes | yes | n/a |  |  |
| T3 Compress result | `12-tool-shell/tool-shell-result.html` | yes | yes | yes | 200 % "T3 Compress – result – 200 %": light+dark |  |
| T3 multi-file result (Split) | `12-tool-shell/tool-shell-split.html` | yes | yes | n/a |  |  |
| T3 partial (OCR) | `12-tool-shell/tool-shell-partial.html` | yes | yes | n/a |  |  |
| Save menu | `12-tool-shell/tool-shell-savemenu.html` | yes | yes | n/a |  |  |
| Replace dialog | `12-tool-shell/tool-shell-replace.html` | yes | yes | n/a |  |  |
| Discard dialog | `12-tool-shell/tool-shell-discard.html` | yes | yes | n/a |  |  |

## Tools (dedicated)

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| Split (ranges + visual markers) | `13-tools-organize/tools-organize-split.html` | yes | yes | n/a |  |  |
| Extract (grid) | `13-tools-organize/tools-organize-extract.html` | yes | yes | n/a |  |  |
| Rotate (grid + banner) | `13-tools-organize/tools-organize-rotate.html` | yes | yes | n/a |  |  |
| Smart Split review | `13-tools-organize/tools-organize-smartsplit.html` | yes | yes | n/a |  |  |
| Image to PDF | `14-tools-convert/tools-convert-img2pdf.html` | yes | yes | n/a |  |  |
| PDF to images | `14-tools-convert/tools-convert-pdf2img.html` | yes | yes | n/a |  |  |
| Web to PDF (preview) | `14-tools-convert/tools-convert-web.html` | yes | yes | n/a |  |  |
| Web to PDF (offline) | `14-tools-convert/tools-convert-weboffline.html` | yes | yes | n/a |  |  |
| PDF/A result with warning | `14-tools-convert/tools-convert-pdfa.html` | yes | yes | n/a |  |  |
| PDF to text result | `14-tools-convert/tools-convert-text.html` | yes | yes | n/a |  |  |
| Compress edge state: already small | `15-tools-optimize/tools-optimize-small.html` | yes | yes | yes (DK-1010) |  | DE "Compress" |
| Compress edge state: target dialog | `15-tools-optimize/tools-optimize-target.html` | yes | yes | yes (DK-1010) |  | DE "Compress"; index: "target unreachable" |
| OCR result | `15-tools-optimize/tools-optimize-ocr.html` | yes | yes | n/a |  |  |
| Page numbers | `17-tools-edit/tools-edit-pagenum.html` | yes | yes | n/a |  |  |
| Watermark | `17-tools-edit/tools-edit-watermark.html` | yes | yes | n/a |  |  |
| Crop | `17-tools-edit/tools-edit-crop.html` | yes | yes | n/a |  |  |
| Fill form dialogs | `17-tools-edit/tools-edit-formlock.html`<br>`17-tools-edit/tools-edit-noform.html` | yes | yes | n/a |  | lock values + no fields dialogs |
| Add password | `16-tools-security/tools-security-addpw.html` | yes | yes | n/a |  | index: "mismatch error" (only state exported) |
| Remove password | `16-tools-security/tools-security-removepw.html` | yes | yes | n/a |  | index: "wrong password" (only state exported) |
| Black out: find | `18-black-out/black-out-find.html` | yes | yes | yes |  |  |
| Black out: review | `18-black-out/black-out-review.html` | yes | yes | yes |  |  |
| Black out: confirm | `18-black-out/black-out-confirm.html` | yes | yes | yes |  |  |
| Black out: result | `18-black-out/black-out-result.html` | yes | yes | yes |  |  |
| Black out: failed | `18-black-out/black-out-failed.html` | yes | yes | yes |  |  |
| Compare: setup | `19-compare/compare-setup.html` | yes | yes | n/a |  |  |
| Compare: single view | `19-compare/compare-single.html` | yes | yes | n/a |  |  |
| Compare: side-by-side landscape | `19-compare/compare-side-by-side.html` | yes | yes | n/a |  | 852×393 |
| Compare: change list | `19-compare/compare-list.html` | yes | yes | n/a |  |  |
| Extract assets result | `20-automation/automation-assets.html` | yes | yes | n/a |  |  |
| Batch: tool choice | `20-automation/automation-batchtool.html` | yes | yes | n/a |  |  |
| Batch: queue | `20-automation/automation-queue.html` | yes | yes | n/a |  |  |
| Batch: result | `20-automation/automation-batchresult.html` | yes | yes | n/a |  |  |
| Workflows: list | `20-automation/automation-wflist.html` | yes | yes | n/a |  |  |
| Workflows: builder | `20-automation/automation-builder.html` | yes | yes | n/a |  |  |
| Workflows: run | `20-automation/automation-wfrun.html` | yes | yes | n/a |  |  |

## AI

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| Not eligible | `21-ai/ai-noteligible.html` | yes | yes | n/a |  |  |
| Model download | `21-ai/ai-download.html` | yes | yes | n/a |  |  |
| Downloading | `21-ai/ai-downloading.html` | yes | yes | n/a |  |  |
| First-use notice | `21-ai/ai-firstuse.html` | yes | yes | n/a |  |  |
| Summary streaming | `21-ai/ai-streaming.html` | yes | yes | yes |  | DE "Summary" |
| Summary done | `21-ai/ai-done.html` | yes | yes | yes | 200 % "A1 Summary – 200 %": light+dark | DE "Summary" |
| Detailed | `21-ai/ai-detailed.html` | yes | yes | yes |  | DE "Summary" |
| Ask empty | `21-ai/ai-askempty.html` | yes | yes | yes |  | DE "Ask" |
| Ask thread | `21-ai/ai-ask.html` | yes | yes | yes |  | DE "Ask" |
| Ask not found | `21-ai/ai-notfound.html` | yes | yes | yes |  | DE "Ask" |
| Translate options | `21-ai/ai-tropts.html` | yes | yes | n/a |  |  |
| Translate both view | `21-ai/ai-trboth.html` | yes | yes | n/a |  |  |
| Engine sheet | `21-ai/ai-engine.html` | yes | yes | n/a |  |  |
| Language sheet | `21-ai/ai-lang.html` | yes | yes | n/a |  |  |
| No-text banner | `21-ai/ai-notext.html` | yes | yes | n/a |  |  |
| Low-memory banner | `21-ai/ai-lowmem.html` | yes | yes | n/a |  |  |

## Me & settings

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| Me (free) | `22-me-settings/me-me.html` | yes | yes | yes |  |  |
| Me (Pro) | `22-me-settings/me-mepro.html` | yes | yes | yes |  |  |
| AI models | `22-me-settings/me-models.html` | yes | yes | n/a |  |  |
| Model detail | `22-me-settings/me-modeldetail.html` | yes | yes | n/a |  |  |
| Scanning | `22-me-settings/me-scanning.html` | yes | yes | n/a |  |  |
| Files & storage | `22-me-settings/me-files.html` | yes | yes | n/a |  |  |
| Security | `22-me-settings/me-security.html` | yes | yes | n/a |  |  |
| Appearance | `22-me-settings/me-appearance.html` | yes | yes | n/a |  |  |
| Language | `22-me-settings/me-language.html` | yes | yes | n/a |  |  |
| Privacy | `22-me-settings/me-privacy.html` | yes | yes | n/a |  |  |
| Licences list | `22-me-settings/me-licences.html` | yes | yes | n/a |  |  |
| Licence detail | `22-me-settings/me-licence.html` | yes | yes | n/a |  |  |

## Paywall

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| Default (from tool) | `23-paywall/paywall-tool.html` | yes | yes | yes | SE `23-paywall/paywall-tool-iphone-se.html`: light+dark; DE yes | index state label is "se"; page says "Black out is part of Pro." |
| Default 200 % | — | — | — | n/a | 200 % "X3 Paywall – 200 %": light+dark | only in the 200 % board |
| Default (from Me) | `23-paywall/paywall-me.html` | yes | yes | n/a |  |  |
| Purchasing | `23-paywall/paywall-purchasing.html` | yes | yes | n/a |  |  |
| Success | `23-paywall/paywall-success.html` | yes | yes | n/a |  |  |
| Error | `23-paywall/paywall-error.html` | yes | yes | n/a |  |  |
| Restore none found | `23-paywall/paywall-restore.html` | yes | yes | n/a |  | page: "No purchase found for this account." |

## System

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| Notifications (5) | `25-system-surfaces/system-surfaces.html` | yes | yes | yes |  | section of the system-surfaces board: 5 notifications |
| Android progress notification | `25-system-surfaces/system-surfaces.html` | yes | yes | n/a |  | board section |
| Widgets (3 × light/dark) | `25-system-surfaces/system-surfaces.html` | yes | yes | n/a |  | board section, 3 widgets; light/dark via light/ and dark/ copies of the board |
| Shortcuts | `25-system-surfaces/system-surfaces.html` | yes | yes | n/a |  | board section "App-icon shortcuts" |
| iOS share extension | `25-system-surfaces/system-surfaces.html` | yes | yes | n/a |  | board section |

## Global

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| Toast (with action) | `26-global-states/global-states.html` | yes | yes | n/a |  | global-states board, "Toasts and banners" |
| Banners (info/warning/error/Pro) | `26-global-states/global-states.html` | yes | yes | n/a |  | global-states board: OCR info, camera warning, purchase error, Pro |
| Empty states (8) | `26-global-states/global-states.html` | yes | yes | n/a |  | global-states board: 8 empty states (ILL-04..08, 15, 16, 17) |
| Error catalogue examples | `26-global-states/global-states.html` | yes | yes | n/a |  | global-states board, "Error catalogue" |

## Tablet (§32.3)

| Frame | Export file | Light | Dark | DE | SE/200 % | Note |
|---|---|---|---|---|---|---|
| Home (portrait) | `24-tablet/tablet-home-portrait.html` | yes | yes | n/a | — | |
| Home (landscape) | `24-tablet/tablet-home-landscape.html` | yes | yes | n/a | — | |
| Tools (portrait) | `24-tablet/tablet-tools-portrait.html` | yes | yes | n/a | — | |
| Tools (landscape) | `24-tablet/tablet-tools-landscape.html` | yes | yes | n/a | — | |
| Files two-pane (portrait) | `24-tablet/tablet-files-portrait.html` | yes | yes | n/a | — | |
| Files two-pane (landscape) | `24-tablet/tablet-files-landscape.html` | yes | yes | n/a | — | |
| Viewer with AI pane (portrait) | `24-tablet/tablet-viewer-portrait.html` | yes | yes | n/a | — | |
| Viewer with AI pane (landscape) | `24-tablet/tablet-viewer-landscape.html` | yes | yes | n/a | — | |
| Organize (portrait) | `24-tablet/tablet-organize-portrait.html` | yes | yes | n/a | — | |
| Organize (landscape) | `24-tablet/tablet-organize-landscape.html` | yes | yes | n/a | — | |
| T2 Compress with live preview (portrait) | `24-tablet/tablet-compress-options-portrait.html` | yes | yes | n/a | — | |
| T2 Compress with live preview (landscape) | `24-tablet/tablet-compress-options-landscape.html` | yes | yes | n/a | — | |
| T3 Compress with live preview (portrait) | `24-tablet/tablet-compress-result-portrait.html` | yes | yes | n/a | — | |
| T3 Compress with live preview (landscape) | `24-tablet/tablet-compress-result-landscape.html` | yes | yes | n/a | — | |
| Compare side by side (portrait) | `24-tablet/tablet-compare-portrait.html` | yes | yes | n/a | — | |
| Compare side by side (landscape) | `24-tablet/tablet-compare-landscape.html` | yes | yes | n/a | — | |
| Paywall dialog (portrait) | `24-tablet/tablet-paywall-portrait.html` | yes | yes | n/a | — | |
| Paywall dialog (landscape) | `24-tablet/tablet-paywall-landscape.html` | yes | yes | n/a | — | |
| Scanner landscape (portrait) | `24-tablet/tablet-scanner-portrait.html` | yes | yes | n/a | — | |
| Scanner landscape (landscape) | `24-tablet/tablet-scanner-landscape.html` | yes | yes | n/a | — | |

## Gaps

Every §32.2 / §32.3 frame has a light and a dark export file, and every SE and 200 % frame the inventory marks is there in both themes.

1. **Filled: Tools (dedicated), DE "Compress".** The row's only Compress frames are the edge states, so its DE mark asks for them. `deutsch/15-tools-optimize/tools-optimize-small.html` ("already small") and `tools-optimize-target.html` ("target unreachable") were added in DK-1010, translated from light/ with the ARB's German (`compress_*`) and the spec's "Kleinstmöglich: 2,4 MB"; `deutsch/index.html` lists them. The edge-state copy ("schon klein", "Original behalten", the dialog body) is not in the ARBs yet; the task that builds these states adds it in these words.
2. **Judgement notes (not file gaps):**
   - Edit mode DE "Default" was taken to mean `07-edit/edit-pen.html`. All 13 `07-edit/` files are in `deutsch/`, so the reading doesn't change the result.
   - Paywall "Default 200 %" exists only as the "X3 Paywall – 200 %" section of `27-accessibility/text-200-percent.html`. The same goes for the other 200 % frames: H1 Home, T1 Tools, T2 Compress, T3 Compress, A1 Summary, and an extra S2 Review. That board is in light/ and dark/ but not in `deutsch/`; the inventory doesn't ask for it there.
   - System and Global frames are sections of one board each: `25-system-surfaces/system-surfaces.html` and `26-global-states/global-states.html`. The system board has 5 notifications, the Android progress notification, 3 widgets, app-icon shortcuts and the iOS share extension. "Widgets 3 × light/dark" is met by the light/ and dark/ copies of that board, not by separate frames. Notifications DE: `deutsch/25-system-surfaces/system-surfaces.html` exists.
   - Add password and Remove password are exported only in an error state: `tools-security-addpw.html` (index title "mismatch error") and `tools-security-removepw.html` ("wrong password"). The inventory names only the tools, not their states.
   - Scanner "retake label" was matched to `10-scanner/scanner-camera-retake.html` (index title "retake page 3"). Paywall "Default (from tool)" was matched to `23-paywall/paywall-tool.html` (the page reads "Black out is part of Pro."); its state label was "se", an export typo, now "from a tool" in its `<title>` and the three indexes.
   - Tablet: the inventory names the frames, and each one has a portrait and a landscape file. Portrait frames render at 820 px, although `light/index.html` lists every tablet file as 1366×1024. The text "Live preview" appears only in `tablet-compress-options-landscape.html`; the portrait options frame and both result frames don't carry that label.


## Extra frames (in light/, not matched to an inventory entry)

- `02-home/home-jobs3.html`
- `02-home/home-rating.html`
- `02-home/home-scanmenu.html`
- `02-home/home-tilemenu.html`
- `04-files/files-dragfolder.html`
- `04-files/files-foldermenu.html`
- `04-files/files-loading.html`
- `04-files/files-selmore.html`
- `04-files/files-swipe.html`
- `04-files/files-trashaction.html`
- `06-viewer/viewer-unlocked.html`
- `07-edit/edit-eraser.html`
- `07-edit/edit-hiopts.html`
- `07-edit/edit-shapesopts.html`
- `07-edit/edit-textopts.html`
- `09-organize-pages/organize-large.html`
- `09-organize-pages/organize-pinch.html`
- `09-organize-pages/organize-savemenu.html`
- `10-scanner/scanner-camera-cutoff.html`
- `10-scanner/scanner-camera-dark.html`
- `10-scanner/scanner-camera-far.html`
- `10-scanner/scanner-review-book.html`
- `10-scanner/scanner-review-deleted.html`
- `10-scanner/scanner-review-jpg.html`
- `10-scanner/scanner-review-reorder.html`
- `11-photo-finder/photo-finder-notdoc.html`
- `12-tool-shell/tool-shell-aftersave.html`
- `12-tool-shell/tool-shell-mergefew.html`
- `12-tool-shell/tool-shell-mergerange.html`
- `12-tool-shell/tool-shell-moreopts.html`
- `12-tool-shell/tool-shell-notifprompt.html`
- `12-tool-shell/tool-shell-prosecond.html`
- `12-tool-shell/tool-shell-replaced.html`
- `13-tools-organize/tools-organize-smartinput.html`
- `13-tools-organize/tools-organize-smartprogress.html`
- `13-tools-organize/tools-organize-splitinvalid.html`
- `13-tools-organize/tools-organize-splitn.html`
- `14-tools-convert/tools-convert-pdfaopts.html`
- `14-tools-convert/tools-convert-textnotext.html`
- `14-tools-convert/tools-convert-textopts.html`
- `15-tools-optimize/tools-optimize-repair.html`
- `15-tools-optimize/tools-optimize-repaired.html`
- `15-tools-optimize/tools-optimize-repairfail.html`
- `16-tools-security/tools-security-nopw.html`
- `17-tools-edit/tools-edit-xfa.html`
- `18-black-out/black-out-ocrstep.html`
- `19-compare/compare-scans.html`
- `20-automation/automation-batchfiles.html`
- `20-automation/automation-batchopts.html`
- `20-automation/automation-extractopts.html`
- `20-automation/automation-noimages.html`
- `20-automation/automation-wfpick.html`
- `21-ai/ai-askselection.html`
- `21-ai/ai-dlbar.html`
- `22-me-settings/me-filename.html`
- `22-me-settings/me-filter.html`
- `22-me-settings/me-signatures.html`
- `23-paywall/paywall-restored.html`
- `28-store-assets/app-icon-and-store-assets.html`

Plus 25 design-system pages under `00-design-system/` (not screen frames). Files in light/ only (no dark copy, not inventory frames): `00-design-system/motion.html`, `28-store-assets/app-icon-and-store-assets.html`.

## Not in the export

- **Android 412 × 915 spot checks** (§32.1): the export has phone frames at 393 × 852 and 375 × 667 only. The 412 × 915 check is done on the app instead: the emulator runs (`emulator-5554`, Android x86_64) and the widget goldens.
