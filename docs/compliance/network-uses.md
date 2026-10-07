# What uses the internet (DK-0012)

Dokulo works in airplane mode. Only three things use the internet, the same
three the Privacy page lists under "What uses the internet" (UI spec §23.3):

| Use | Where | What it reaches | Rule |
|---|---|---|---|
| Model downloads | `ai_core` `Network.downloadModel` | the hosts of the model catalogue | https only; any other host is refused; the user starts it; the hash is checked after download |
| Web page to PDF | the WebView of the `web` tool (`Network.webPage` checks the address) | the address the user typed | http or https only (`https://` is added when missing) |
| Purchases | `in_app_purchase` (StoreKit 2, Play Billing) | the App Store or Google Play | only when the user buys or restores Pro |

Nothing else: no analytics, no ads, no account, no crash upload (crash reports
are sent by the user by email, DK-0011), no update checks.

## How it is enforced

- **No tool run can reach the network.** Every job runs inside `offline()`
  (`ai_core`, `IsolatePool`), on every lane: creating an `HttpClient` or
  connecting a socket fails with `SocketException('No network during a tool
  run (DK-0012)')`, in release builds too. Native engines (PDFium, qpdf,
  OpenCV, ONNX Runtime, llama.cpp) make no network calls. Web page to PDF's
  WebView is the one exception, and it loads only the user's address.
- **One client.** `tools/check_layers.py` fails on an HTTP client, a socket or
  an HTTP package anywhere in `packages/*/lib` outside
  `packages/ai_core/lib/src/network.dart`. A new network use is an owner's
  decision first (`team.py decision`), then a row in the table above, the
  Privacy page and the privacy policy, in the same PR.
- **No CI proxy.** The plan asked for a CI proxy check; there is no CI/CD (the
  owner, 2026-10-07). The in-process guard above replaces it: it blocks the
  request instead of watching for it, and the golden-PDF suite runs every tool
  under it in `python tools/check.py`.

## Airplane-mode test (manual, every release)

Recorded by SQA in the release checklist (DK-0664).

1. Install the release build; turn on airplane mode (Wi-Fi and mobile data off).
2. Scan a two-page document and save it.
3. Run every tool in the catalogue once on a sample file
   (`test/fixtures/`), except Web page to PDF: each finishes and its result
   opens.
4. Open AI features with an installed model: they work. Without a model: the
   download offers itself and says it needs the internet; nothing else does.
5. Web page to PDF: shows "No internet connection" and nothing else.
6. Turn airplane mode off; download a model; buy and restore Pro on a test
   account: these three are the only network uses.

Pass: steps 2–5 work fully offline and no screen asks for the internet except
the model download, Web page to PDF and the paywall.
