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
