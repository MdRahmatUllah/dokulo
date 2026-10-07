# AI models: policy, intake checklist and licence checks

Covers DK-0683 (the inference-only policy and the model intake checklist),
DK-0674 (Gemma 4 E2B), DK-0675 (Bergamot) and DK-0676 (Hy-MT). Checked
2026-10-07 against the model cards, licence files and registries listed under
each model. Re-check every model at release (DK-0695) and whenever its pinned
revision changes.

## Policy: inference only

- **No training and no fine-tuning** of any LLM or other model, by us or on
  the phone. That includes LoRA, adapters and distillation.
- **Allowed:** prompting, retrieval (RAG: BM25 or embeddings over the user's
  own document), rule-based pre- and post-processing, and ready-made
  embedding, OCR and layout models used as published.
- **Small classic models** (a classifier, a detector) only if a ready-made
  model with a permissive licence exists. We don't train one ourselves.
- Converting a model's format (ONNX export, GGUF quantisation) is allowed. The
  NOTICE says the file is converted, not modified.

## The intake checklist

No model enters the catalogue (`ai_core`'s model manifest, DK-0546) until a
filled-in copy of this checklist is in this file and has been through a PR
review.

| # | Item | What to record |
|---|---|---|
| 1 | Licence | SPDX id or licence name, with a link to the licence **file in the pinned revision** (not a third-party listing) |
| 2 | Territory | Any region the licence excludes. Any exclusion of the EU, the UK or Germany is a **No** |
| 3 | Use restrictions | Acceptable-use or prohibited-use policy; whether it has to be passed on in the app terms |
| 4 | Attribution | NOTICE text, the licence text to ship, and the "converted, not modified" note |
| 5 | Source | Official publisher repo, plus the converter repo if a third party made the GGUF or ONNX file |
| 6 | Pinned revision | Commit sha of the repo the download URL points at |
| 7 | File and hash | File name, size in bytes, sha256 (checked by the download manager) |
| 8 | RAM | Working set on the phone; the RAM floor for offering the download |
| 9 | Size | Disk size; bundled or download |
| 10 | Card link | Model card URL |
| 11 | Policy fit | Used by inference only (above); no training or fine-tuning needed |

Items 6 and 7 are filled in when DK-0546 pins the files. Until then a model
is **licence-cleared**, not catalogued.

## The models

| Model | Licence | Territory | Verdict |
|---|---|---|---|
| Gemma 4 E2B (it) | Apache-2.0 | None | **Use** (download) |
| Bergamot engine + Firefox Translations models | MPL-2.0 | None | **Use** (engine bundled, models downloaded) |
| PP-OCRv5 (det, Latin rec, cls, multilingual rec), ONNX | Apache-2.0 | None | **Use** (bundled / download) |
| EuroLLM-1.7B-Instruct | Apache-2.0 | None | **Licence-cleared**; the product use is still open (below) |
| Hy-MT2 (1.8B) | Apache-2.0 | None | **Licence-cleared** (see "Hy-MT", below) |
| HY-MT1.5 / Hunyuan-MT 1.x | Tencent HY Community Licence | Excludes EU, UK, South Korea | **No** |

### Gemma 4 E2B (DK-0674)

1. Licence: **Apache-2.0**. Google's Gemma 4 licence page
   (<https://ai.google.dev/gemma/docs/gemma_4_license>) is the plain Apache 2.0
   text, and the model card <https://huggingface.co/google/gemma-4-E2B-it> is
   tagged `apache-2.0`. That replaces the older "Gemma Terms of Use" the plan
   mentions.
2. Territory: none.
3. Use restrictions: Google also publishes a Gemma Prohibited Use Policy
   (<https://ai.google.dev/gemma/prohibited_use_policy>). Its page doesn't say
   whether it binds models under Apache-2.0. **We follow it anyway** and link
   it from the app terms (DK-0695). It costs nothing and rules out nothing
   Dokulo does.
4. Attribution: ship the Apache-2.0 text, keep the copyright notices, and
   note "converted to GGUF, not modified" if we quantise it ourselves.
5. Source: official `google/gemma-4-E2B-it`. GGUF from `ggml-org/gemma-4-E2B-it-GGUF`
   (Apache-2.0; Q4_0 and Q8_0, no Q4_K_M), or a Q4_K_M from another converter.
   DK-0546 picks one, pins it, and records the sha and hash here.
8–9. Sogda's figures: about 1.3 GB on disk at Q4_K_M, 2–3 GB working RAM.
11. Policy fit: prompting and RAG only.

### Bergamot / Firefox Translations models (DK-0675)

1. Licence: **MPL-2.0**, for the engine (`bergamot-translator`) and for the
   models. Mozilla's `translations` README: "The model files are distributed
   under the MPL 2.0 license." The archived `firefox-translations-models` repo
   carries the same MPL-2.0 LICENSE. The live registry JSON has no per-model
   licence field, so the README statement is the source.
2. Territory: none.
3. Use restrictions: none beyond MPL-2.0.
4. Attribution: MPL notice; the model files ship unmodified (file-level
   copyleft: any change to them would have to be published).
5. Source: Mozilla's model registry
   <https://storage.googleapis.com/moz-fx-translations-data--303e-prod-translations-data/db/models.json>
   (UI: <https://mozilla.github.io/translations/model-registry/>). The old
   GitHub repo is archived ("not maintained anymore").
- **Language pairs** (registry generated 2026-10-07): 112 released model
  entries, almost all to or from English. **de→en and en→de are both
  released** (architecture `base-memory`, model file 31,561,787 bytes
  uncompressed, plus vocab and lexical shortlist). Pairs that don't touch
  English (e.g. de→fr) have no direct model: translate through English, two
  hops, at lower quality. The UI's "installed languages first, others with
  size tags" fits. A language pack is one direction: the model is about 32 MB uncompressed, plus its vocab and shortlist.
11. Policy fit: inference only.

### PP-OCRv5 (applied for DK-0683)

1. Licence: **Apache-2.0** (PaddleOCR upstream). The ONNX conversions
   (<https://github.com/gitakoos/ocr-models>) are Apache-2.0 too.
2. Territory: none. 3. None. 4. NOTICE: "ONNX files converted from PaddleOCR,
   not modified".
9. det about 4.8 MB, Latin rec about 8 MB, cls about 0.6 MB (bundled);
   multilingual rec about 16.5 MB (download), per the Technology plan.

### EuroLLM-1.7B-Instruct (applied for DK-0683)

1. Licence: **Apache-2.0** (<https://huggingface.co/utter-project/EuroLLM-1.7B-Instruct>).
   Covers 35 languages, German and English among them.
2. Territory: none. 3. None in the licence. The card warns the model "has not
   been aligned to human preferences, so the model may generate problematic
   outputs". That suits translation only, never open chat.
5. Only third-party GGUF builds exist. DK-0546 names and pins one if EuroLLM
   ships.
- **Open:** whether Dokulo offers EuroLLM at all once Hy-MT2 is cleared
  (below). That is the Translate engine sheet's call (DK-0566), not a licence
  question.

### Hy-MT (DK-0676)

The plan's premise needs a correction:

- **HY-MT1.5** (and Hunyuan-MT 1.x) is under the **Tencent HY Community
  Licence**. Its `License.txt` in `tencent/HY-MT1.5-1.8B` begins "THIS LICENSE
  AGREEMENT DOES NOT APPLY IN THE EUROPEAN UNION, UNITED KINGDOM AND SOUTH
  KOREA". So it is **excluded**, as the plan says.
- **Hy-MT2** (`tencent/Hy-MT2-1.8B`, `-7B` and their GGUF builds) is
  **Apache-2.0**. The official `tencent/Hy-MT2-1.8B-GGUF` repo's `LICENSE.txt`
  (revision `a0c709d9fac510f2c807aa3af52872340dc37a4a`) reads "Hy-MT2-1.8B-GGUF
  is licensed under the Apache License, Version 2.0", followed by the standard
  text, with no territory clause. Some third-party repackages (e.g. on Ollama)
  attach a Tencent community licence to Hy-MT2 files. Only Tencent's own repo
  counts (checklist item 1).
- **Sogda already ships it on this basis:** `Hy-MT2-1.8B-Q4_K_M.gguf`,
  1,133,080,448 bytes, sha256
  `dc5f44fcf1fa496ee7ad725982c0c8c553a4de00259b53af84c4b89fb0c06699`, pinned at
  the revision above, no region gate, RAM floor 3.5 GiB total memory (the
  owner's decision there, 2026-09-30; DeutschPlan ADR 30).

So the UI spec's "Hy-MT2 (best quality)" engine is **licence-cleared**, and
nothing has to be removed from the Translate engine sheet or from M2. The
Technology plan's "Hy-MT cannot be used" now names HY-MT1.5 only. Its size row
is corrected: about 1.1 GB, not 440 MB. Hy-MT2 needs a 3.5 GiB device floor.
That is close to Gemma's floor, so on low-RAM phones Bergamot stays the only
engine. Whether Dokulo offers Hy-MT2 alongside or instead of EuroLLM is
DK-0566's call.
