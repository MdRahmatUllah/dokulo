# 04 — Offline PDF Toolkit (iLovePDF-style mobile app)

Oct 6, 2026 · @Rahmat Ullah

## Overview

A mobile PDF suite with the iLovePDF tool set plus a full document scanner, running 100% on the phone: no uploads, no account, no watermark, no file-size or daily limits, one-time price.

| Field | Value |
| --- | --- |
| Type | New standalone app (Flutter, iOS + Android) |
| Replaces | The "module only" plan in the original doc 04; the scan/OCR/export code (doc-core) is reused later by the letter assistant (doc 03) |
| Status | Scope decided, Oct 2026; name not chosen yet |
| Data | 100% on device; nothing uploaded |
| First release scope | All planned tools except PDF↔Office conversion, full text editing and certificate signatures |
| Target markets | US, UK, EU (DACH first for German keywords) |
| Estimated build | About 17–20 weeks solo to first store release |

**One-line pitch:** All your PDF tools and a full scanner. Nothing uploaded. No watermark. Pay once.

## Problem and positioning

On phones, every major PDF tool either uploads your files or locks basic tasks behind a subscription. We win on the gap all three leaders leave open: a full tool set that never leaves the device, at a one-time price.

|  | iLovePDF | Adobe Scan | CamScanner | **This app** |
| --- | --- | --- | --- | --- |
| Where files are processed (mobile) | Their cloud | Adobe Document Cloud | Account + cloud sync | **On the phone only** |
| Account needed | For Premium | Yes (Adobe ID) | For most features | **Never** |
| Watermark on free exports | No | No | Yes (removable in the US) | **Never** |
| Free-tier limits | Batch and file-size caps; OCR conversions, PDF/A, AI locked | OCR 5 pages; combine, extract, eraser locked | Cloud OCR 3 tries; watermark | **No limits on free tools** |
| Paid model | Subscription | Subscription | Subscription | **One-time unlock** |
| AI summary / translate | Cloud, AI credits | Cloud AI Assistant | Cloud translate | **On-device** |

**Who it's for:** people who handle sensitive documents on their phone (tenants, job seekers, visa applicants, freelancers, lawyers, tax advisors), and anyone tired of subscriptions for simple PDF jobs.

**Store message:** "No uploads. No watermark. No subscription."

## Competitor research

All three are strong on features; their weak points are cloud processing, subscriptions and free-tier limits.

|  | [iLovePDF](https://www.ilovepdf.com/pricing) | [Adobe Scan](https://apps.apple.com/us/app/adobe-scan-pdf-doc-scanner/id1199564834) | [CamScanner](https://apps.apple.com/us/app/camscanner-pdf-scanner-app/id388627783) |
| --- | --- | --- | --- |
| Focus | 38-tool PDF suite (web first) | Scanner + OCR, feeds Acrobat | Scanner + document manager |
| Scale | \~217M web visits/month (Dec 2025, Semrush); 16.5M docs/day claimed | 4.9 stars, 1.6M ratings (US App Store) | 4.8 stars, 1.9M ratings (US App Store) |
| Price (US) | $5/mo yearly ($60) or $9 monthly | Plus $4.99/mo; Premium $9.99/mo, up to $69.99/yr | $9.99/mo; $49.99–69.99/yr; $6.99/week |
| Standout features | Full PDF tool set, AI summarize/translate, workflows, iLoveSign | Straighten curved pages, Magic eraser, high-speed scan, photo-library detection, AI Assistant | ID/passport mode, Smart Erase, mosaic/auto-mask, scan-to-translate, Mega Scan, fax |
| Privacy notes | Mobile processing goes through their cloud; offline only on desktop | Scans auto-saved to Document Cloud; PDFs opened in the app are uploaded | App Store label lists tracking identifiers and third-party advertising |
| Main user complaints | Price; slow uploads on large files | Subscription cost; trial auto-charges | Watermark, aggressive paywall, 2019 malware SDK incident |

iLovePDF's own blog says offline processing is a desktop feature and the mobile app uses cloud processing ([source](https://www.ilovepdf.com/pl/blog/pdf-web-or-desktop)). Privacy-first PDF tools already exist on the web (e.g. BentoPDF, CoolPDF), which is why this app competes on mobile instead.

## First-release feature list

The first release ships 44 features: 30 PDF tools, 8 scanner features and 6 app features. Free tools have no limits; Pro is the one-time unlock (tier split is a proposal, see Monetization).

### PDF tools

| Category | Feature | What it does | Tier |
| --- | --- | --- | --- |
| Organize | Merge PDF | Combine PDFs in any order | Free |
| Organize | Split PDF | By range, every N pages, or into single pages | Free |
| Organize | Extract pages | Save chosen pages as a new PDF | Free |
| Organize | Organize pages | Reorder, delete, duplicate, insert blank pages in one screen | Free |
| Organize | Rotate PDF | Single pages or whole document | Free |
| Organize | Smart Split | Split a scan bundle into separate documents by detected sections (on-device AI) | Pro |
| Convert | Image to PDF | JPG, PNG, HEIC, WebP to PDF | Free |
| Convert | PDF to images | Export pages as JPG or PNG | Free |
| Convert | Web/HTML to PDF | Save a web page or HTML file as PDF | Free |
| Convert | PDF to PDF/A | Archive format for authorities and courts | Pro |
| Convert | PDF to Markdown / text | Extract structured text | Pro |
| Optimize | Compress PDF | Quality presets plus "under 1 / 2 / 5 MB" targets for upload portals | Free |
| Optimize | Repair PDF | Fix damaged or broken files | Free |
| Optimize | OCR PDF | Make scanned PDFs searchable (invisible text layer) | Pro |
| Edit | Add page numbers | Position, format, start number | Free |
| Edit | Add watermark | Text or image, opacity, angle | Free |
| Edit | Crop PDF | Crop margins, single page or all | Free |
| Edit | Annotate & add text | Highlight, comments, text boxes, shapes, freehand | Free |
| Edit | Fill forms | Fill and flatten PDF forms | Pro |
| Security | Sign PDF | Drawn or saved signature, initials, date | Free |
| Security | Protect PDF | Password (AES-256) | Free |
| Security | Unlock PDF | Remove a password you know | Free |
| Security | Redact PDF | True redaction with auto-detection of IBAN, tax IDs, emails, phone numbers | Pro |
| Security | Compare PDF | Highlight text differences between two versions | Pro |
| Extract | PDF extract | Pull out embedded images and text | Free |
| Intelligence | AI Summarizer | On-device summary (Gemma, optional download) | Pro |
| Intelligence | Ask your PDF | Questions answered from the document, on-device | Pro |
| Intelligence | Translate PDF | On-device translation, side-by-side view and export | Pro |
| Automation | Workflows | Chain tools, e.g. scan → OCR → compress → protect | Pro |
| Automation | Batch processing | Run a tool on many files at once | Free |

### Scanner

| Feature | What it does | Tier |
| --- | --- | --- |
| Document scan | Auto edge detection, auto-capture, perspective correction | Free |
| Multi-page batch scan | Continuous capture into one document | Free |
| Filters & adjust | B/W, greyscale, colour, shadow removal, brightness/contrast | Free |
| ID card mode | Front and back placed on one page | Free |
| Book mode | Split a two-page spread into two pages | Free |
| Find documents in photos | On-device detection of documents and receipts in the photo library | Pro |
| Import from gallery/files | Turn existing photos into clean scans | Free |
| Scan to PDF/JPG | Export with page size presets (A4, Letter, auto) | Free |

### App features

| Feature | What it does | Tier |
| --- | --- | --- |
| PDF viewer | Fast viewer with search, thumbnails, night mode | Free |
| File manager | Recents, folders, favourites, search by name and OCR text | Free |
| Locked folders / app lock | Biometric or PIN lock, encrypted local storage | Pro |
| Share-sheet integration | "Open with" on Android, share extension and Files action on iOS | Free |
| Tool grid home | iLovePDF-style grid so every tool is one tap away | Free |
| Languages | English and German at launch | Free |

## Later and not planned

Office conversion and full text editing are the main gaps against iLovePDF; everything below is deliberately left out of the first release.

| Feature | Decision | Reason |
| --- | --- | --- |
| PDF → Word / Excel / PowerPoint (incl. OCR versions) | Later | Hard to do with good fidelity on-device |
| Word / Excel / PowerPoint → PDF | Later | Needs a heavy rendering engine or paid SDK |
| Full editing of existing PDF text | Later | Changing original text while keeping layout is very hard; annotations cover most needs |
| Certificate-based (advanced) e-signature | Later | Needs certificate handling and trust services |
| Curved-page straighten (dewarping) | Later | Needs an on-device dewarping model |
| Magic eraser (fingers, stains, handwriting) | Later | Needs an on-device inpainting model |
| Business card → contacts | Later | Small, outside the PDF core |
| Desktop version (Mac/Windows) | Later | Same Flutter code, after mobile proves out |
| QR scanning | Not planned | Phone cameras already do it |
| Fax, cloud collaboration, comment sharing | Not planned | Needs servers; breaks the no-upload promise |
| ID photo maker, maths solver, practice tests | Not planned | Off-topic |
| Copy PDF | Not planned | Unclear user value |

## Technical architecture

Flutter app on top of a shared `doc-core` package; every engine is permissively licensed so the app can be sold closed-source.

| Layer | Choice | Licence | Used for |
| --- | --- | --- | --- |
| PDF engine | PDFium via FFI (or pdfrx) | BSD-3 / Apache-2.0 | Render, merge/split/rotate (import pages), text extraction, forms, save |
| PDF structure | qpdf via FFI | Apache-2.0 | Encrypt/decrypt, repair, linearize, structural compression |
| PDF creation | Dart `pdf` package | Apache-2.0 | New PDFs, page numbers, watermarks, invisible OCR text layer |
| Scanning | Own CameraX + OpenCV scanner (Android), VisionKit (iOS) | Platform | Edge detection, auto-capture, cleanup |
| OCR | PP-OCRv5 on ONNX Runtime / Apple Vision | Platform | Searchable PDFs, redaction detection, Ask your PDF |
| Image processing | Dart `image`; OpenCV via FFI only if needed | MIT / Apache-2.0 | Filters, compression, book mode split |
| Translation | Sogda's on-device translation models | Per model | Translate PDF |
| LLM | Gemma 4 E2B (optional download, reuse Sogda's model manager) | Gemma terms | Summarize, Ask, Smart Split |
| HTML to PDF | Platform WebView print | Platform | Web/HTML to PDF |
| Storage | Local, encrypted (shared with doc 03) | — | Files, folders, locked folders |

**Rules**

- No AGPL code (MuPDF, PyMuPDF, Ghostscript, BentoPDF) unless a commercial licence is bought.
- Redaction rasterises affected pages; test every build by extracting text from redacted output.
- AI and translation models are optional downloads; the app works fully without them.
- No analytics SDK that sends document content; crash reports only, opt-in.

## Monetization

Free core tools with no limits, plus a one-time Pro unlock at €9.99–14.99; no subscription.

| Tier | Includes | Price |
| --- | --- | --- |
| Free | All tools marked Free: organize, convert images, compress, sign, protect, annotate, scanner, viewer. No watermark, no size or daily limits | €0 |
| Pro (one-time) | OCR, redaction, AI summarize/ask, translate, compare, forms, PDF/A, workflows, Smart Split, photo-library detection, locked folders | €9.99–14.99 (test both) |

- **Ads:** none, or at most one small banner on the free tier; decide after the first month of data.
- **Trial:** let users run each Pro tool once for free on a real file, so they see the result before paying.
- **Price comparison for the store page:** one year of iLovePDF Premium is $60, Adobe Scan Premium up to $69.99, CamScanner $49.99–69.99; Pro costs about one month of these, once.
- **Family Sharing (iOS) on** for the Pro unlock.

## Distribution and ASO

Users must find the app at the moment they hold a PDF, so system integration and per-tool keywords matter more than the brand.

1. **Be in the share sheet.** "Open with" on Android; share extension and Files action on iOS. A user holding a PDF picks a tool without opening the app first.
2. **One keyword per tool.** Long-tail terms, not "pdf scanner": "merge pdf offline", "compress pdf without upload", "pdf scanner no watermark", "redact pdf", "PDF zusammenfügen offline", "PDF verkleinern ohne Upload", "Dokumente scannen ohne Abo".
3. **Store screenshots lead with the promise:** no uploads, no watermark, no subscription; then the tool grid; then redaction and offline translate.
4. **Proof of offline:** a screenshot of the app working in airplane mode.
5. **Launch channels:** r/privacy, r/degoogle, Product Hunt, German expat groups, and cross-promotion from Sogda and later the letter assistant.
6. **Localise listings** in English and German at launch; add Spanish, French, Portuguese next (store text only).

## Build plan

About 19 weeks solo from start to store release, in seven phases; each phase ends with a usable internal build.

| Phase | Scope | Weeks | Cumulative |
| --- | --- | --- | --- |
| 1. Foundations | doc-core package, PDFium + qpdf bindings, viewer, file manager, share-sheet integration, tool grid | 3 | 3 |
| 2. Scanner | Document scan, batch scan, filters, ID mode, book mode, gallery import | 2 | 5 |
| 3. Core tools | Merge, split, extract, organize, rotate, image↔PDF, web to PDF, compress, repair, page numbers, watermark, crop, PDF extract | 3 | 8 |
| 4. Edit & security | Annotate, sign, forms, protect/unlock, redaction with auto-detect, compare | 4 | 12 |
| 5. OCR & automation | OCR text layer, PDF/A, PDF to Markdown, batch processing, workflows | 2 | 14 |
| 6. Intelligence | Model manager reuse, summarize, ask, translate, Smart Split, photo-library detection, locked folders | 3 | 17 |
| 7. Launch | Paywall, store listings EN/DE, screenshots, closed testing, fixes, release | 2 | 19 |

The estimate assumes full-time focus; at side-project pace (evenings and weekends), expect roughly double. If time runs short, phase 6 can ship as a free update one month after launch.

## Risks

The biggest risk is discovery, not technology: the category is crowded and the leaders have huge brands.

| Risk | Mitigation |
| --- | --- |
| Hard to get discovered against apps with 100M+ installs | Long-tail keywords per tool, share-sheet presence, privacy communities, cross-promotion |
| Free OS scanners (iOS Notes/Files, Google Drive) are "good enough" for many | Lead with what they lack: redaction, compress-to-size, merge, translate, AI |
| Scope is large for one person (44 features) | Phase plan with usable builds; phase 6 can slip to a post-launch update |
| Fake redaction leaks data | Rasterise redacted pages; automated test extracts text from every redacted output |
| AI models are large and need recent phones | Optional downloads; app fully works without them; clear device requirements |
| Licence trap with AGPL PDF engines | Permissive-only rule in the architecture section; check every new dependency |
| One-time price limits long-term revenue | Large user base via free tier; later paid add-ons (desktop, Office conversion pack) |

## Name options

Top pick: **Hush PDF**. It says "private" in one word, works in English and German, and leaves room for the keyword part of the store title. Availability (stores, domains, EUIPO/USPTO trademarks) has not been checked yet.

| Name | Idea behind it | Example store title (≤ 30 chars) |
| --- | --- | --- |
| **Hush PDF** | Your documents stay quiet, nothing leaves the phone | Hush PDF – Offline PDF Editor |
| **Quire** | A quire is a bundle of pages; short, distinctive, ownable | Quire: PDF Tools & Scanner |
| **Lokal PDF** | German "lokal" = local; reads naturally in English too; strong DACH fit | Lokal PDF – Scan & Edit Offline |
| **Sheaf** | A sheaf of papers; calm, simple brand | Sheaf – Private PDF Toolkit |
| **OwnPDF** | Your files stay yours; clear promise | OwnPDF: No-Upload PDF Tools |
| **Pagekeep** | Keeps your pages on your device | Pagekeep – PDF Scanner & Tools |
| **Paperlock** | Privacy and security first; fits redaction and locked folders | Paperlock: Private PDF Scanner |
| **Offpaper** | Offline + paper; hints at working without internet | Offpaper – Offline PDF Toolkit |

Avoid names close to iLovePDF, CamScanner or Adobe, and avoid "Vault" (keep it for the warranty vault in doc 05).

## Open decisions

- [ ] Pick the app name and check store, domain and trademark availability
- [ ] Confirm the Free / Pro split and the price (€9.99 vs €14.99)
- [ ] Decide on a free-tier banner ad or no ads at all
- [ ] Confirm the order against the letter assistant (doc 03), which now starts after this app
- [ ] Choose launch languages beyond English and German

## Sources

- [iLovePDF pricing and full tool list](https://www.ilovepdf.com/pricing)
- [iLovePDF mobile app page](https://www.ilovepdf.com/mobile)
- [iLovePDF blog: web, desktop or mobile](https://www.ilovepdf.com/pl/blog/pdf-web-or-desktop)
- [iLovePDF traffic, Semrush](https://www.semrush.com/website/ilovepdf.com/overview/)
- [Adobe Scan, US App Store](https://apps.apple.com/us/app/adobe-scan-pdf-doc-scanner/id1199564834)
- [Adobe Scan subscription features](https://www.adobe.com/devnet-docs/adobescan/ios/en/subscriptions.html)
- [CamScanner, US App Store](https://apps.apple.com/us/app/camscanner-pdf-scanner-app/id388627783)
- [CamScanner watermark change, CamScanner blog](https://blog.camscanner.com/2022/11/22/camscanner-unlocks-an-advanced-feature-to-american-ios-and-android-users/)
- [BentoPDF (client-side web PDF tools)](https://railway.com/deploy/bentopdf--bento-pdf.md)
