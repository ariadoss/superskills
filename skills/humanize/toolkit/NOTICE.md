# NOTICE — third-party data redistributed in this toolkit

The scripts here are original work released under this repository's MIT license.
The data files below are third-party and redistributed under their own terms.

## Sam Paech — EQ-Bench, slop-forensics, antislop-sampler

- `eq_bench_slop_list.json`, `eq_bench_slop_list_bigrams.json`,
  `eq_bench_slop_list_trigrams.json`, `eq_bench_slop_phrase_prob_adjustments.json`
- `llm_slop.json` (mined over-representation data)
- The slop-index formulas in `eq_bench_slop_index.py` replicate EQ-Bench's
  `core.metrics.calculate_slop_index` (new and legacy forms).

Sources: <https://github.com/EQ-bench/EQ-Bench> (MIT),
<https://github.com/sam-paech/slop-forensics> (MIT),
<https://github.com/sam-paech/antislop-sampler> (Apache-2.0).

## Academic AI-overused vocabulary

- `ai_overused_research.json` — word lists reported in:
  - Reinhart et al., "Do LLMs write like humans?", PNAS 2025, arXiv:2410.16107
  - Juzek & Ward, COLING 2025

Used as a quality signal for manual review, not as an evasion predictor.

## Common-word frequency list

- `top2000_en.json` — top-2000 English frequency list derived from `wordfreq`
  (<https://github.com/rspeer/wordfreq>, Apache-2.0).

## Curated

- `ai_slop_wordlist.json` — marketing/corporate AI-slop vocabulary curated by
  [Danilo Stern-Sapad](https://danilosapad.com).

Apache-2.0 requires that its attribution notices travel with redistribution; this
file serves that purpose. If you redistribute this toolkit, keep it.

## Siqi Chen — humanizer editorial patterns

Selected stock transitions, contrast frames, and chatbot-wrapper patterns in
`slop_report.py` are adapted from
[blader/humanizer](https://github.com/blader/humanizer), version 3.1.0, revision
`8c307f367c91bd974002f10f2be2965d642c13df` (retrieved 2026-10-27).
The Python implementation is local and has no upstream runtime dependency.
These are context-dependent review signals, not automatic rewrites or evidence
of AI authorship. The complete upstream license follows.

MIT License

Copyright (c) 2025 Siqi Chen

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
