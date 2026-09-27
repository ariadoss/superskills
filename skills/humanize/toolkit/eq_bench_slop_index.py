#!/usr/bin/env python3
"""
eq_bench_slop_index.py — exact local replication of EQ-bench creative-writing-bench
slop scoring (calculate_slop_index_new and the legacy calculate_slop_index).

Source: https://github.com/EQ-bench/creative-writing-bench/blob/main/core/metrics.py
This file copies the algorithms verbatim so local audits use the same formulas
as the public leaderboard.

Usage:
    python3 eq_bench_slop_index.py <file.md> [--legacy]

Outputs JSON with:
    slop_index           — current EQ-bench formula (word + 2*bigram + 8*trigram, /1000 words)
    word_hits, bigram_hits, trigram_hits
    total_words
    legacy_slop_index    — only when --legacy is passed
    flesch_kincaid_grade — raw grade (the complexity index uses it capped at 14)
    complexity_index     — 0-100 (FK + % polysyllabic average)

Dependencies: stdlib only for slop scoring. NLTK and wordfreq only for the
optional complexity/repetition metrics; the slop scoring degrades gracefully.
"""
from __future__ import annotations

import functools
import json
import re
import sys
from pathlib import Path

# Sibling imports resolve against this file's real directory, so they work when it
# runs as a script, via runpy, as part of a package, or through a symlink; and they
# never write __pycache__ into the installed skill directory.
sys.dont_write_bytecode = True
if str(Path(__file__).resolve().parent) not in sys.path:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
from textio import read_prose

DATA_DIR = Path(__file__).parent

SLOP_UNIGRAMS = DATA_DIR / "eq_bench_slop_list.json"
SLOP_BIGRAMS = DATA_DIR / "eq_bench_slop_list_bigrams.json"
SLOP_TRIGRAMS = DATA_DIR / "eq_bench_slop_list_trigrams.json"
SLOP_PHRASE_PROBS = DATA_DIR / "eq_bench_slop_phrase_prob_adjustments.json"


def load_slop_set(path: Path) -> set[str]:
    """Load JSON shaped as [["item"], ...] or ["item", ...] -> set of lowercased items."""
    if not path.exists():
        return set()
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    return {(item[0] if isinstance(item, (list, tuple)) else item).lower() for item in data if item}


def tokenize(text: str) -> list[str]:
    """Lowercase, alnum-only token list. NLTK if available, else regex."""
    lower = text.lower()
    try:  # pragma: no cover - optional
        import nltk
        from nltk.tokenize import word_tokenize

        try:
            nltk.data.find("tokenizers/punkt")
        except LookupError:
            nltk.download("punkt", quiet=True)
        return [tok for tok in word_tokenize(lower) if tok.isalnum()]
    except Exception:
        return re.findall(r"\b\w+\b", lower)


def slop_index_new(text: str) -> dict:
    """Replication of core.metrics.calculate_slop_index_new (current EQ-bench formula)."""
    words = load_slop_set(SLOP_UNIGRAMS)
    bigrams = load_slop_set(SLOP_BIGRAMS)
    trigrams = load_slop_set(SLOP_TRIGRAMS)

    tokens = tokenize(text)
    total = len(tokens)
    if total == 0:
        return {
            "slop_index": 0.0,
            "word_hits": 0,
            "bigram_hits": 0,
            "trigram_hits": 0,
            "total_words": 0,
        }

    word_hits = sum(1 for t in tokens if t in words)

    bigram_hits = 0
    if bigrams and len(tokens) >= 2:
        for a, b in zip(tokens, tokens[1:]):
            if f"{a} {b}" in bigrams:
                bigram_hits += 1

    trigram_hits = 0
    if trigrams and len(tokens) >= 3:
        for a, b, c in zip(tokens, tokens[1:], tokens[2:]):
            if f"{a} {b} {c}" in trigrams:
                trigram_hits += 1

    score = word_hits + 2 * bigram_hits + 8 * trigram_hits
    return {
        "slop_index": round(score / total * 1000, 4),
        "word_hits": word_hits,
        "bigram_hits": bigram_hits,
        "trigram_hits": trigram_hits,
        "total_words": total,
    }


def slop_index_legacy(text: str, n_slop_words: int = 600) -> float:
    """Replication of core.metrics.calculate_slop_index (legacy formula)."""
    if not SLOP_PHRASE_PROBS.exists():
        return 0.0
    with SLOP_PHRASE_PROBS.open("r", encoding="utf-8") as f:
        slop_phrases = json.load(f)
    weights_raw = [1.0 - prob for _, prob in slop_phrases]
    if not weights_raw:
        return 0.0
    max_score = max(weights_raw) or 1.0
    weights = [w / max_score for w in weights_raw]
    selected = {
        word.lower(): score
        for (word, _), score in zip(slop_phrases[:n_slop_words], weights[:n_slop_words])
    }

    total_words = len(text.split())
    if total_words == 0:
        return 0.0
    score = 0.0
    for word, weight in selected.items():
        score += weight * len(re.findall(r"\b" + re.escape(word) + r"\b", text))
    return round(score / total_words * 1000, 4)


# cmudict.dict() rebuilds the whole ~130k-entry pronunciation dictionary on each
# call, and complexity_index calls syllable_count twice per token: a 1,000-word
# document meant ~2,000 rebuilds, enough to hit slop_report.py's 60 s scorer
# timeout and drop both headline metrics. Cached once, including a failed load
# (None), so a missing corpus is not re-attempted per word either.
@functools.lru_cache(maxsize=None)
def _cmu():
    try:  # pragma: no cover - optional
        from nltk.corpus import cmudict

        return cmudict.dict()
    except Exception:
        return None


def syllable_count(word: str) -> int:
    """Approximate syllable count (CMU dict if available, else heuristic)."""
    word = word.lower()
    d = _cmu()
    if d is not None and word in d:
        return max(len([p for p in pron if p[-1].isdigit()]) for pron in d[word])
    # heuristic fallback: count vowel groups
    vowels = "aeiouy"
    count = 0
    prev = False
    for ch in word:
        is_v = ch in vowels
        if is_v and not prev:
            count += 1
        prev = is_v
    return max(count, 1)


def complexity_index(text: str) -> dict:
    """Replication of core.metrics.calculate_complexity_index."""
    sentences = re.split(r"(?<=[.!?])\s+", text.strip())
    sentences = [s for s in sentences if s]
    tokens = re.findall(r"\b\w+\b", text)
    sentence_count = max(1, len(sentences))
    word_count = max(1, len(tokens))
    total_syllables = sum(syllable_count(t) for t in tokens)
    fk = (
        0.39 * (word_count / sentence_count)
        + 11.8 * (total_syllables / word_count)
        - 15.59
    )
    fk_capped = min(fk, 14)
    polysyllabic = sum(1 for t in tokens if syllable_count(t) >= 3)
    pct_complex = min((polysyllabic / word_count) * 100, 20)
    fk_norm = fk_capped / 14 * 100
    complex_norm = pct_complex / 20 * 100
    composite = round((fk_norm + complex_norm) / 2, 2)
    return {
        "flesch_kincaid_grade": round(fk, 2),
        "percent_complex_words": round(pct_complex, 2),
        "complexity_index": composite,
    }


def main(argv: list[str]) -> int:
    legacy = "--legacy" in argv
    paths = [a for a in argv[1:] if not a.startswith("--")]
    if not paths:
        print(__doc__)
        return 1
    for p in paths:
        text = read_prose(p)
        result = {"path": p}
        result.update(slop_index_new(text))
        if legacy:
            result["legacy_slop_index"] = slop_index_legacy(text)
        result.update(complexity_index(text))
        print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
