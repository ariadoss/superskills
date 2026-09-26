"""Comprehensive DETERMINISTIC AI-slop / tell reporter, with line numbers, to guide surgical editing.

Consolidates every mechanically-checkable rule from Danilo Stern-Sapad's AI-slop checklists
(26 prose tells, 7 slop layers, H1-H11) that `construction_scanner.py` did NOT
already cover, and reuses the tools that do:
  - construction_scanner.py  — its 16 calibrated signals (way-X, aphorism, magic-adverb, ...)
  - eq_bench_slop_index.py    — the EQ-bench slop_index number
This file adds: em-dash density (A9), EQ-bench slop word/bigram hits WITH line numbers (A16/A17),
the AI verb-phrase blocklist (A26), marketing/corporate lists (A19/A20), extended intensifiers
(A1), authority tropes (A10), body-as-meter (A3), cliché similes (A4), mythic-ese (A5), rule-of-
three (A6), hedging (A11), declaration chains (A13/A14), participial chains (A21), personification
(A22), dialogue-attribution patterns (A25), vague gestures (A27/A28/A29), short-paragraph overuse
(A8), sentence-length burstiness (A23), and windowed opener-monotony (A12).

NOT rewriting — a whole-text LLM rewrite re-adds a detectable fingerprint. Read-only checklist
that guides surgical, span-level edits. These are QUALITY signals; they do NOT predict what an AI
detector will say. Judgment-only rules (polite behavior, clean resolution, metaphor
originality, etc.) are intentionally NOT here — they need a careful read.

Usage: python3 slop_report.py FILE [--exempt terms.txt]
"""
from __future__ import annotations

import json
import re
import statistics
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

# Sibling imports resolve against this file's real directory, so they work when it
# runs as a script, via runpy, as part of a package, or through a symlink; and they
# never write __pycache__ into the installed skill directory.
sys.dont_write_bytecode = True
if str(Path(__file__).resolve().parent) not in sys.path:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
from eq_bench_slop_index import SLOP_BIGRAMS, SLOP_TRIGRAMS, SLOP_UNIGRAMS, load_slop_set
from textio import read_prose

HERE = Path(__file__).resolve().parent

# ---- word / phrase lists (from the command blocklists; A-numbers map to the gap analysis) ----
INTENSIFIERS = [  # A1 (H4/H11)
    "particularly", "somehow", "perfectly", "almost imperceptibly", "inevitably", "precisely",
    "impossibly", "simply", "merely", "utterly", "remarkably", "fundamentally"]
BODY_METER = [  # A3 (humanize #1)
    r"heart\s+pound(?:ing|ed)", r"breath\s+caught", r"throat\s+tighten(?:ed|ing)",
    r"stomach\s+dropp?ed", r"hair\s+(?:stood|raised)", r"knees?\s+weaken(?:ed|ing)",
    r"blood\s+ran\s+cold", r"skin\s+crawl(?:ed|ing)", r"voice\s+barely\s+(?:a\s+)?whisper",
    r"chill\s+ran\s+(?:up|down)", r"shiver\s+ran"]
CLICHE_SIMILE = [r"\blike\s+(?:a|an|the)\s+(?:knife|stone|sea|wave|dream|shadow|ghost|silk|fire|storm)\b"]  # A4
MYTHIC_ESE = ["ancient", "primordial", "eternal", "timeless", "primal", "elemental", "sacred", "profound"]  # A5
AUTHORITY_TROPES = [  # A10 (humanize #15)
    "the real question is", "at its core", "in reality", "what really matters",
    "the deeper issue", "the heart of the matter"]
VERB_PHRASES = [  # A26 (H11)
    r"couldn't help but", r"found (?:her|him|my)self\s+\w+ing", r"made (?:her|his|my) way",
    r"let out a (?:breath|sigh)", r"released a breath", r"holding (?:her|his|my) breath",
    r"managed to", r"couldn't quite", r"threatened to", r"washed over", r"settled over",
    r"filled the (?:space|room|air)", r"hung in the air", r"cut through",
    r"sent a (?:chill|shiver)"]
VAGUE_GESTURES = [r"something about", r"there was something", r"for a long moment", r"it occurred to me"]  # A27-A29
def _load_ai_slop_lists():
    """Full Layer-5 marketing/workslop (139) + Layer-7 corporate (19) lists, extracted from
    ai-slop.md into ai_slop_wordlist.json. Strip '(verb sense)'-style parentheticals so the
    words match. Falls back to a small subset if the file is absent."""
    try:
        d = json.loads((HERE / "ai_slop_wordlist.json").read_text())
        clean = lambda xs: sorted({re.sub(r"\s*\(.*?\)", "", w).strip() for w in xs if w.strip()})
        return clean(d.get("marketing_workslop", [])), clean(d.get("corporate", []))
    except Exception:
        return (["leverage", "delve", "tapestry", "unlock", "harness", "elevate", "resonate"],
                ["continuous improvement", "deliver value", "best-in-class", "deep dive"])


MARKETING, CORPORATE = _load_ai_slop_lists()  # A19 (ai-slop L5) / A20 (ai-slop L7)


def _load_research_overused():
    """Academic AI-'excess vocabulary' words (Kobak/Liang/Reinhart/Juzek). QUALITY signal for
    manual review; over-flags some common words, so pair with --exempt + judgment."""
    try:
        d = json.loads((HERE / "ai_overused_research.json").read_text())
        return set(d.get("words", [])), set(d.get("high_confidence_core", []))
    except Exception:
        return set(), set()


RESEARCH_OVERUSED, RESEARCH_CORE = _load_research_overused()


def _load_llm_slop():
    """Words and literal phrase clichés over-represented in LLM output (Sam Paech
    slop-forensics/antislop, Reinhart, Novelcrafter). Words = density/overuse signal; phrases =
    high-precision line-numbered clichés."""
    try:
        d = json.loads((HERE / "llm_slop.json").read_text())
        return set(d.get("words", [])), d.get("phrases", [])
    except Exception:
        return set(), []


LLM_SLOP_WORDS, LLM_SLOP_PHRASES = _load_llm_slop()
_FIC_PHRASE_RE = re.compile("|".join(re.escape(p) for p in LLM_SLOP_PHRASES), re.I) if LLM_SLOP_PHRASES else None
HEDGES = ["potentially", "possibly", "somewhat", "perhaps", "maybe", "arguably"]  # A11


def prose_lines(raw: str):
    """(1-based lineno, text) for prose lines (skip md header + scene breaks + blanks)."""
    return [(i + 1, l) for i, l in enumerate(raw.splitlines())
            if not l.startswith("#") and l.strip() not in ("* * *", "")]


def load_slop():
    return tuple(load_slop_set(p) for p in (SLOP_UNIGRAMS, SLOP_BIGRAMS, SLOP_TRIGRAMS))


def scan_lines(lines, patterns, flags=re.I):
    """Return [(lineno, matched_str, linetext)] for any regex in `patterns`."""
    hits = []
    compiled = [re.compile(p, flags) for p in patterns]
    for ln, text in lines:
        for c in compiled:
            for m in c.finditer(text):
                hits.append((ln, m.group(0).strip(), text.strip()))
    return hits


_EXEMPT: set = set()  # set in main() from --exempt; tokens here are skipped from all checks


def report_group(label, hits, thr_note=""):
    if _EXEMPT:
        hits = [h for h in hits if not (set(h[1].lower().split()) & _EXEMPT)]
    if not hits:
        print(f"— {label}: none")
        return 0
    cnt = Counter(h[1].lower() for h in hits)
    top = ", ".join(f"{w}×{c}" for w, c in cnt.most_common(8))
    print(f"— {label}: {len(hits)}{thr_note}  ({top})")
    for ln, tok, txt in hits[:15]:
        s = txt if len(txt) <= 100 else txt[:97] + "..."
        print(f"    L{ln}: [{tok}]  {s}")
    if len(hits) > 15:
        print(f"    ... and {len(hits)-15} more")
    return len(hits)


def sentences(text):
    return [s.strip() for s in re.split(r"(?<=[.!?])\s+", text) if s.strip()]


def load_exempt(argv):
    """--exempt FILE : one token/name per line, case-insensitive, skipped from all word checks.
    Use it for product and people names + words with a literal sense in your field
    (e.g. 'leverage' in finance, 'robust' in statistics). See exempt_example.txt."""
    ex = set()
    if "--exempt" in argv:
        i = argv.index("--exempt") + 1
        if i >= len(argv):
            print("usage: python3 slop_report.py FILE [--exempt terms.txt]", file=sys.stderr)
            sys.exit(1)
        p = Path(argv[i])
        # A mistyped path used to exempt nothing, silently: every exempt term then
        # showed up as slop with no hint why.
        if not p.exists():
            print(f"slop_report: exempt file not found: {p} (continuing with no exemptions)", file=sys.stderr)
        else:
            ex |= {w.strip().lower() for w in read_prose(p).splitlines() if w.strip()}
    return ex


def main():
    if len(sys.argv) < 2:
        print("usage: python3 slop_report.py FILE [--exempt terms.txt]"); sys.exit(1)
    path = Path(sys.argv[1])
    global _EXEMPT
    _EXEMPT = load_exempt(sys.argv)
    raw = read_prose(path)
    lines = prose_lines(raw)
    prose = "\n".join(l for _, l in lines)
    sents = sentences(prose)
    # Paragraphs: split the RAW text on blank lines (prose_lines drops blanks), minus
    # the md header and scene-break blocks.
    paras = [p.strip() for p in re.split(r"\n\s*\n", raw)
             if p.strip() and not p.strip().startswith("#") and p.strip() != "* * *"]
    words = re.findall(r"\b\w+\b", prose)
    nwords = max(len(words), 1)
    def per1k(n): return n / nwords * 1000

    print(f"\n{'='*72}\nDETERMINISTIC SLOP / AI-TELL REPORT — {path.name}  ({nwords} words)\n{'='*72}")
    print("QUALITY signals only — they do NOT predict AI detectors. Edit flagged spans surgically;")
    print("a whole-text LLM rewrite re-adds the detectable fingerprint. Line numbers below.\n")

    # ---- EQ-bench slop_index (reuse the EQ-bench scorer) ----
    try:
        r = subprocess.run([sys.executable, str(HERE / "eq_bench_slop_index.py"), str(path), "--legacy"],
                           capture_output=True, text=True, timeout=60)
        d = json.loads(r.stdout)
        print(f"slop_index = {d['slop_index']:.1f}  [word {d['word_hits']}, bigram {d['bigram_hits']}, trigram {d['trigram_hits']}]"
              f"   |   legacy_slop_index = {d.get('legacy_slop_index', float('nan')):.1f}  (phrase-probability formula)")
        print(f"complexity_index = {d.get('complexity_index', float('nan')):.1f}  (FK grade {d.get('flesch_kincaid_grade', float('nan')):.1f}; vocab-maxxing if high)")
    except Exception as e:
        print(f"slop_index: (scorer unavailable: {e})")

    # ---- EQ-bench slop words/bigrams WITH line numbers (A16/A17) ----
    uni, big, tri = load_slop()
    uni_hits = [(ln, w, txt) for ln, txt in lines for w in re.findall(r"\b[a-zA-Z']+\b", txt) if w.lower() in uni]
    print()
    report_group("EQ-BENCH SLOP WORDS", uni_hits)
    def bigram_scan(t):
        toks = re.findall(r"\b\w+\b", t.lower()); return [f"{toks[i]} {toks[i+1]}" for i in range(len(toks)-1) if f"{toks[i]} {toks[i+1]}" in big]
    report_group("EQ-BENCH SLOP BIGRAMS", [(ln, b, txt) for ln, txt in lines for b in bigram_scan(txt)])

    # ---- em dashes (A9) — the highest-value missing check ----
    em = [(ln, "—", txt) for ln, txt in lines for _ in range(txt.count("—"))]
    em += [(ln, " - ", txt) for ln, txt in lines for _ in range(len(re.findall(r"\s-\s", txt)))]
    d_em = per1k(len(em))
    report_group(f"EM DASHES / SPACED HYPHENS  [density {d_em:.1f}/1k; flag>5]", em)

    # ---- phrase/word-list checks ----
    report_group("AI VERB-PHRASES (washed over, couldn't help but…)", scan_lines(lines, VERB_PHRASES))
    report_group("VAGUE GESTURES (something about, for a long moment…)", scan_lines(lines, VAGUE_GESTURES))
    report_group("AUTHORITY TROPES (the real question is, at its core…)", scan_lines(lines, [re.escape(p) for p in AUTHORITY_TROPES]))
    report_group("EXTENDED INTENSIFIERS (somehow, perfectly, merely…)", scan_lines(lines, [rf"\b{re.escape(w)}\b" for w in INTENSIFIERS]))
    report_group("BODY-AS-EMOTION-METER (heart pounding, breath caught…)", scan_lines(lines, BODY_METER))
    report_group("CLICHÉ SIMILES (like a knife/stone/sea…)", scan_lines(lines, CLICHE_SIMILE))
    report_group("MYTHIC-ESE (ancient, eternal, primordial…)", scan_lines(lines, [rf"\b{w}\b" for w in MYTHIC_ESE]))
    # AI-overused vocabulary = curated marketing/workslop (ai-slop L5) MERGED with academic
    # research 'excess vocabulary' (Kobak/Liang/Reinhart/Juzek), minus EQ-slop words already
    # reported above (dedupe) and minus common function words. Core = multi-source high-confidence.
    ai_overused = (set(MARKETING) | RESEARCH_OVERUSED) - uni
    ov_hits = [(ln, w, txt) for ln, txt in lines
               for w in re.findall(r"\b[a-zA-Z']+\b", txt) if w.lower() in ai_overused]
    report_group("AI-OVERUSED VOCAB (delve, intricate, underscore…; curated + research)", ov_hits)
    if ov_hits:
        core_hit = sorted({w.lower() for _, w, _ in ov_hits if w.lower() in RESEARCH_CORE})
        if core_hit:
            print(f"      high-confidence core among them: {', '.join(core_hit)}")
    report_group("CORPORATE PHRASES", scan_lines(lines, [re.escape(p) for p in CORPORATE]))
    report_group("DIALOGUE ATTRIBUTION (\"...\" she says quietly)", scan_lines(lines, [r'["”][,.]?\s{0,3}(?:she|he|they|I|we|\w+)\s+(?:says?|said)\s+(?:quietly|carefully|slowly|softly|gently)\b']))
    report_group('PERSONIFICATION ([thing] waits/breathes/watches)', scan_lines(lines, [r"\b(?!He|She|It|I|We|They)[A-Z][\w'-]+\s+(?:waits|breathes|watches|hums)\b"], flags=0))

    # ---- hedging: 2+ hedge words in a clause (A11) ----
    hedge_hits = []
    for ln, text in lines:
        for clause in re.split(r"[,.;]", text):
            if sum(1 for h in HEDGES if re.search(rf"\b{h}\b", clause, re.I)) >= 2:
                hedge_hits.append((ln, clause.strip()[:40], text.strip()))
    report_group("STACKED HEDGING (2+ qualifiers in a clause)", hedge_hits)

    # ---- rule-of-three: adjective/short triplets "X, Y, and Z" (A6) ----
    tri3 = [(ln, m.group(0).strip(), txt) for ln, txt in lines
            for m in re.finditer(r"\b\w+,\s+\w+,\s+(?:and\s+)?\w+\b", txt)]
    report_group("RULE-OF-THREE triplets (flag if 6+ total)", tri3)

    # ---- extra AI sentence-patterns (A2 + Layer 6 additions) ----
    report_group("AI SENTENCE-PATTERNS (it's not just X it's Y; Not because…; The result?)", scan_lines(lines, [
        r"\bit'?s not just\b.{1,80}?\bit'?s\b", r"\bthat'?s not\b.{0,40}?\bthat'?s\b",
        r"\bnot because\b.{0,60}?[.]\s*but because\b", r"\bnot by\b.{0,40}?\bbut by\b",
        r"\bthe (?:result|outcome|answer|truth|question|point)\?\s", r"\band the \w+\?\s"]))
    # ---- frame-break / meta-reference (frame-check §1,§4) ----
    report_group("FRAME-BREAK / META-REFERENCE (the prologue, as I mentioned…)", scan_lines(lines, [
        r"\bthe (?:prologue|story|last scene|previous chapter)\b", r"\bchapter (?:one|two|three|\d+)\b",
        r"\bas I (?:mentioned|said|explained)\b", r"\byou must understand\b",
        r"\bthe reader (?:should|will)\b", r"\blooking back now\b", r"\bearlier in this account\b"]))
    # ---- hindsight / telegraphing (frame-check §5) ----
    report_group("HINDSIGHT / TELEGRAPHING (would later learn; did not know then)", scan_lines(lines, [
        r"\bwould\s+(?:later\s+)?(?:learn|discover|realize|realise|understand|see|know)\b",
        r"\bdid not know then\b", r"\bit would (?:later )?turn out\b",
        r"\bthat was the (?:last|first) time\b.{0,40}\bwould\b"]))
    # ---- generic filler names (A7) — case-sensitive ----
    report_group("FILLER NAMES (Ael-/Aeth-)", scan_lines(lines, [r"\bAe(?:l|th)\w{2,}\b"], flags=0))
    # ---- scaffolding / meta-text artifacts (A24) ----
    report_group("SCAFFOLDING ARTIFACTS (this is where…, [note])", scan_lines(lines, [
        r"\bthis is where\b", r"^\s*(?:note|todo)\s*:", r"\[[^\]]{3,}\]"]))
    # ---- participle-after dialogue attribution (A25b) ----
    report_group('PARTICIPLE-AFTER ATTRIBUTION ("…" he says it looking…)', scan_lines(lines, [
        r'["”]\s*(?:he|she|they|I)\s+says?\s+it\s+\w+ing\b']))
    # ---- trailing participial chains (A21): 2+ ", <word>ing" tails in one line ----
    part_hits = [(ln, "…,-ing,-ing", txt) for ln, txt in lines
                 if len(re.findall(r",\s+\w+ing\b", txt)) >= 2]
    report_group("TRAILING PARTICIPIAL CHAINS (2+ ,-ing tails)", part_hits)

    # ---- declaration / thematic-weight chains (A13/A14): 3+ consecutive matching openers ----
    def opener_run(sents, pat):
        runs, cur = [], 0
        for s in sents:
            if re.match(pat, s, re.I):
                cur += 1
                if cur >= 3: runs.append(s[:60])
            else:
                cur = 0
        return runs
    decl = opener_run(sents, r"\bI (?:am not|am|have|will)\b")
    them = opener_run(sents, r"\bit is (?:\w+ than|the same)\b")
    if decl: print(f"— DECLARATION-ANAPHORA CHAIN (I am/I have… 3+): {len(decl)}  e.g. {decl[0]}")
    else: print("— DECLARATION-ANAPHORA CHAIN (I am/I have… 3+): none")
    if them: print(f"— THEMATIC-WEIGHT CHAIN (It is X than / the same… 3+): {len(them)}  e.g. {them[0]}")
    else: print("— THEMATIC-WEIGHT CHAIN (It is X than / the same… 3+): none")

    # ---- passive constructions (style/voice/agency-check) ----
    report_group("PASSIVE CONSTRUCTIONS (was taken; found herself; it occurred to)", scan_lines(lines, [
        r"\b(?:was|were|is|are|been|being)\s+\w+(?:ed|en)\b",
        r"\bfound (?:her|him|my)self\b", r"\bit happened that\b", r"\bit occurred to (?:her|him|me)\b"]))
    # ---- scene opener/closer patterns (style-check) ----
    report_group("SCENE-OPENER PATTERN (The room was…; Name had…)", scan_lines(lines, [
        r"^The \w+ (?:was|is|were)\b", r"^[A-Z][a-z]+ (?:had|was)\b"], flags=0))
    report_group("SCENE-CLOSER TRANSITION (The next morning…; That night…)", scan_lines(lines, [
        r"^(?:The next|Later that|That night|By morning|Afterward|The following)\b"], flags=0))
    # ---- source-attribution scaffolding (style-check) ----
    report_group("SOURCE-ATTRIBUTION SCAFFOLDING (the chapter says…, in X's telling)", scan_lines(lines, [
        r"\bthe (?:introduction|chapter|source|account) (?:says|opens|remembers|tells|notes)\b",
        r"\bin \w+'?s telling\b", r"\bthe chapter'?s pressure\b"]))

    # ---- dialogue: over-long speeches + beat-less runs (dialogue-check) ----
    long_speech = [(ln, f"{len(sentences(m.group(1)))} sents", txt) for ln, txt in lines
                   for m in re.finditer(r'"([^"]{40,})"', txt) if len(sentences(m.group(1))) > 5]
    report_group("OVER-LONG SPEECHES (>5 sentences in one quote)", long_speech)
    # beat-less dialogue: consecutive paragraphs that start with a quote, no narration between
    run = maxrun = 0
    for p in paras:
        if p.lstrip().startswith(('"', '“')):
            run += 1; maxrun = max(maxrun, run)
        else:
            run = 0
    print(f"— BEAT-LESS DIALOGUE: longest run of consecutive quote-only paragraphs = {maxrun} (flag ≥6)")

    # ---- same-length sentence run (style/voice rhythm) ----
    slen_seq = [len(s.split()) for s in sents]
    runs, cur = 0, 1
    for i in range(1, len(slen_seq)):
        if abs(slen_seq[i] - slen_seq[i-1]) <= 2:
            cur += 1
            if cur >= 3: runs += 1
        else:
            cur = 1
    print(f"— SAME-LENGTH SENTENCE RUNS (3+ within ±2 words): {runs} (rhythm monotony)")

    # ---- construction_scanner (calibrated construction signals) ----
    print("\n— CONSTRUCTION SCANNER (calibrated densities):")
    try:
        r = subprocess.run([sys.executable, str(HERE / "construction_scanner.py"), str(path)],
                           capture_output=True, text=True, timeout=60)
        cs = json.loads(r.stdout)
        for k in ("way_x_density_per_1000w", "aphorism_density_per_1000w", "as_if_density_per_1000w",
                  "magic_adverb_density_per_1000w", "pushbutton_density_per_1000w",
                  "distancing_verb_density_per_1000w", "filler_word_density_per_1000w"):
            if k in cs:
                print(f"    {k.replace('_density_per_1000w',''):<18} {cs[k]:.2f}/1k")
        if cs.get("max_consecutive_short_run"):
            print(f"    max consecutive short-sentence run: {cs['max_consecutive_short_run']}")
    except Exception as e:
        print(f"    (construction_scanner unavailable: {e})")

    # ---- poor-diction: distinctive-word overuse + close echoes (ai-slop Layer 1) ----
    try:
        top2000 = set(json.loads((HERE / "top2000_en.json").read_text()))
    except Exception:
        top2000 = set()
    # token stream with line numbers; a word is "distinctive" if uncommon (>4 chars, not top-2000,
    # not exempt) — repeating one is a diction weakness / word echo.
    stream = []  # (idx, word_lower, lineno)
    idx = 0
    for ln, text in lines:
        for w in re.findall(r"\b[a-zA-Z']+\b", text):
            wl = w.lower()
            if len(wl) > 4 and wl not in top2000 and wl not in _EXEMPT:
                stream.append((idx, wl, ln))
            idx += 1
    occ = defaultdict(list)
    for i, wl, ln in stream:
        occ[wl].append((i, ln))
    overused = sorted(((w, v) for w, v in occ.items() if len(v) >= 3), key=lambda t: -len(t[1]))
    print(f"\n— DISTINCTIVE-WORD OVERUSE (uncommon word used 3+ times): {len(overused)}")
    for w, v in overused[:15]:
        print(f"    {w} ×{len(v)}  (lines {', '.join(str(l) for _, l in v[:8])})")
    # close echoes: same distinctive word twice within ~150 tokens
    echoes = []
    for w, v in occ.items():
        for a, b in zip(v, v[1:]):
            if b[0] - a[0] <= 150:
                echoes.append((w, a[1], b[1]))
    print(f"— CLOSE WORD ECHOES (same uncommon word within ~150 words): {len(echoes)}")
    for w, l1, l2 in echoes[:12]:
        print(f"    {w}  (L{l1} → L{l2})")

    # ---- over-represented LLM vocabulary: density + overuse + phrase clichés ----
    if LLM_SLOP_WORDS:
        toks_l = [w.lower() for w in words]
        fic_tokens = [w for w in toks_l if w in LLM_SLOP_WORDS and w not in _EXEMPT]
        dens = len(fic_tokens) / nwords * 100
        print(f"\n— LLM-SLOP VOCAB DENSITY: {dens:.1f}%  ({len(fic_tokens)} words on the over-represented list; higher = more LLM register)")
        fic_counts = Counter(fic_tokens)
        overused_fic = [(w, c) for w, c in fic_counts.most_common() if c >= 2][:20]
        if overused_fic:
            print(f"  overused LLM-slop words (2+×): " + ", ".join(f"{w}×{c}" for w, c in overused_fic))
    if _FIC_PHRASE_RE is not None:
        ph_hits = [(ln, m.group(0), txt) for ln, txt in lines for m in _FIC_PHRASE_RE.finditer(txt)]
        report_group("SLOP PHRASE CLICHÉS (took a deep breath; ghost of a smile…)", ph_hits)

    # ---- paragraph-level: short-paragraph overuse (A8) + burstiness (A23) ----
    short_paras = [p for p in paras if len(sentences(p)) == 1 and len(p.split()) <= 5]
    if paras:
        pct = 100 * len(short_paras) // len(paras)
        print(f"\n— SHORT PARAGRAPHS (1 sentence, ≤5 words): {len(short_paras)}/{len(paras)} ({pct}%; flag>30%)")
    slens = slen_seq
    if len(slens) > 3:
        print(f"— SENTENCE LENGTH: mean {statistics.mean(slens):.1f}, stdev {statistics.pstdev(slens):.1f} "
              f"(burstiness; low stdev + all 12-20w = AI-flat)")
    shorts = [s for s in sents if 0 < len(s.split()) <= 4]
    print(f"— VERY SHORT SENTENCES (≤4 words): {len(shorts)}")

    # ---- windowed opener monotony (A12) ----
    mono = []
    for i in range(0, max(1, len(sents) - 9)):
        window = sents[i:i+10]
        openers = [" ".join(s.split()[:2]).lower() for s in window if s.split()]
        c = Counter(openers)
        rep = [(o, n) for o, n in c.items() if n >= 3]
        if rep or len(set(openers)) < 5:
            mono.append((i + 1, rep))
    if mono:
        print(f"— OPENER MONOTONY: {len(mono)} 10-sentence window(s) with a repeated/low-variety opener")
        for start, rep in mono[:4]:
            print(f"    window@sent {start}: {rep if rep else '<5 distinct openers'}")
    print()


if __name__ == "__main__":
    main()
