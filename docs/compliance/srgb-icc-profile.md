# sRGB ICC profile for PDF/A (DK-0678)

**Decision:** the PDF/A OutputIntent (`pdfa_writer`, DK-0395) embeds the
International Color Consortium's **`sRGB2014.icc`**, unmodified. It is the
ICC's own sRGB IEC 61966-2.1 profile, in ICC version 2, so it is valid in
PDF/A-1 as well as PDF/A-2 and PDF/A-3. Checked 2026-10-07.

| | |
| --- | --- |
| Source | <https://registry.color.org/rgb-registry/profiles/sRGB2014.icc> (listed on <https://registry.color.org/rgb-registry/srgbprofiles>) |
| Size | 3,024 bytes |
| SHA-256 | `384b832de3412066743b52a75ee906b6fb9fb8d9e09e936fc2c43223815c6e0a` |
| Header | version 2.0.0, class `mntr` (display), colour space `RGB `, PCS `XYZ ` |
| `desc` tag | `sRGB2014` |
| `cprt` tag | `Copyright International Color Consortium, 2015` |

## Licence

The registry page says the v2 profile "is subject to the general licensing
terms for ICC profiles". Those terms (<https://registry.color.org/profile-library/#license>) are:

> This profile is made available by the International Color Consortium, and
> may be copied, distributed, embedded, made, used, and sold without
> restriction. Altered versions of this profile shall have the original
> identification and copyright information removed and shall not be
> misrepresented as the original profile.

So we may bundle it in the app and embed it in every PDF/A we write, with no
notice duty. We never alter it: DK-0395 checks the SHA-256 above in a test.
We credit it in the licence screen anyway (licence register → Colour profiles).

## How DK-0395 uses it

- Embedded unchanged in `doc_core` (`lib/src/pdf/srgb2014_icc.dart`, base64), its SHA-256 tested (DK-0395).
- Write the OutputIntent as `/Type /OutputIntent /S /GTS_PDFA1
  /OutputConditionIdentifier (sRGB IEC61966-2.1) /Info (sRGB IEC61966-2.1)
  /DestOutputProfile <stream with /N 3>`.
- veraPDF validates the output as PDF/A-2b in the local gate (a test tool, never shipped).

## Alternatives considered

| Profile | Licence | Why not first |
| --- | --- | --- |
| ICC `sRGB_v4_ICC_preference.icc` | ICC: use, copy and distribute for any purpose, unchanged, keeping the copyright tag | ICC v4 is not allowed in PDF/A-1, and v2 has wider reader support. A fine choice if we only ever write PDF/A-2/3. |
| `sRGB-v2-micro.icc` (Compact ICC Profiles, saucecontrol) | CC0 (public domain) | 456 bytes, `desc` "uRGB": a 42-point approximation of the sRGB curve. It's the fallback if the ICC terms ever change. The SHA-256 of the copy checked today is `0a8a33aea66a6f154a5642ebe168ef287e73265d9f7b51c42a45e6eedbacda7a`. |
| Ghostscript's `srgb.icc`, Adobe's sRGB profiles | AGPL / Adobe's own terms | Excluded (AGPL), or their terms are more restrictive than the ICC's |
| A profile generated at run time (Little CMS) | MIT | It adds a native library to produce 3 KB we can ship as a file |
