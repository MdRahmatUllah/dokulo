# German layout at 100 % and 200 % text

DK-0635: German runs about 30 % longer than English. Board:
`packages/app_pdf/test/qa/german_layout_qa_test.dart`, in the gate. It opens
every DE-marked screen the router reaches, in German, at 100 % text on the
phone frame (393 × 852) and at 200 % on the smallest (375 × 667), and fails
on any overflow (an exception in a test) and on any button, chip, Next chip,
segment, text action or tool name whose text is cut (past its line limit,
or wider than its box on a line that can't wrap). It draws with Roboto, the
SDK's copy (what Android shows): the test font's square glyphs make every
German word far too wide to judge a line break.

Screens (×2 sizes, 48 runs): onboarding (O1), Home, Tools, Files, Recently
deleted, the locked folder (L1), Me, AI models, Signatures, M3 Scanning,
Security, Files & storage, Language and Appearance, S1, the photo finder,
T2 of Compress, Image to PDF, Merge, Black out and Make text searchable, and
V1, V2 and P1 on the invoice sample.

The DE-marked sheets and states the router doesn't open have German goldens
on their own boards: the onboarding pages (`onboarding_o1..o3_light_de`), S1
(`qa_scanner_*_deutsch`, `s1_quad_de`, `s1_quick_settings_de`), S2 and its
Save sheet (`s2_*_de`, `s2_save_de`), the scan result, V1's states
(`qa_viewer_*_deutsch`, `viewer_*_de`), the signatures sheet and the pad,
the photo finder (`pf_qa_*_de`, `photo_finder_results_de`), Compress's More
options (`qa_compress_moreopts_deutsch`), the X1 picker
(`tool_shell_x1*_deutsch`), Home at 200 % (`home_200_de`), empty states and
global banners. Paywall, notifications and AI Summary/Ask aren't built yet:
their tasks (DK-0586, DK-0587..0592, the A1 tasks) carry the German check.

| Finding | Result |
| --- | --- |
| S1 at 200 %: the mode bar (Document · ID card · Book · Batch) was 44 high, so its labels overflowed by 2 px | Fixed here: at least 44, taller with the text |
| Home at 100 %: the tile "Text durchsuchbar machen" ends "Text durchsuchb…" | As the frame (deutsch/02-home/home-default); **DK-1139** asks the lead whether tool names get a third line |

Everything else fits: on all 48 runs no control's text is cut and nothing
overflows; T1 shows every tool name in full at both sizes.
