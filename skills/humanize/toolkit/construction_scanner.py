#!/usr/bin/env python3
"""
construction_scanner.py -- construction-level AI-tell scanner for prose.

Flags recurring *constructions* that word- and n-gram lists miss, reported as
densities per 1,000 words for a human editor to inspect. A flag is a reason to
look at a line, never a mandate to change it, and none of these signals predicts
what an AI detector will say.

Signals (the `# Pattern N` blocks below are the source of truth; the numbering is
historical, not sequential):

  - "The way X" comparatives, e.g. "the way a man keeps a wound clean"
  - Aphoristic sentences: short, complete, abstract declaratives
    ("Failure is how stories prove they have bones.")
  - Consecutive short-sentence runs (8+ sentences of <=12 words)
  - "Things that X" classifications and "as if" interpretation density
  - Same-subject consecutive sentence runs
  - Magic adverbs, negative parallelism, generic emotional-rhetoric frames
  - Filler phrases and filler words
  - Said-bookisms and as-you-know-Bob exposition markers
  - Distancing verbs in first-person narration
  - Pushbutton words

Usage:
    python3 construction_scanner.py path/to/draft.md
    python3 construction_scanner.py path/to/draft.md --verbose
    python3 construction_scanner.py path/to/draft.md path/to/other.md --calibrate

Output (JSON):
    verdict: CLEAN | AI_SIGNAL | BORDERLINE
"""
from __future__ import annotations

import argparse
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

# ---------------------------------------------------------------------------
# Pattern 1: "the way X" comparative construction
# Matches article/determiner form ("the way a/an/the/one/his/her/only..."),
# not directional form ("the way out", "the way through").
# ---------------------------------------------------------------------------
WAY_X_PATTERN = re.compile(
    r"\bthe way\s+(?:a|an|the|one|only|his|her|their|its|my|your|our)\b",
    re.IGNORECASE,
)

# ---------------------------------------------------------------------------
# Pattern 4: "things that X" philosophical classification
# "things that do not flatter you to name" / "things that cannot be unsaid"
# Converts a named specific into a generic abstract category. Reads as
# formulaic even at low density (1-2 per chapter).
# ---------------------------------------------------------------------------
THINGS_THAT_PATTERN = re.compile(r"\bthings that\b", re.IGNORECASE)

# ---------------------------------------------------------------------------
# Pattern 5: "as if" abstract interpretation density
# "as if the candle is keeping an appointment" / "as if whatever moves them
# has a fixed address". Flags abstract/intentional qualities given to physical
# phenomena via simile. Noticeable even at 2-3 per chapter.
# ---------------------------------------------------------------------------
AS_IF_PATTERN = re.compile(r"\bas if\b", re.IGNORECASE)

# ---------------------------------------------------------------------------
# Pattern 6: Same-subject consecutive sentence runs
# "He does not look at me. He bends at the hearth. He sets the basket down."
# Subject-verb action lists with no friction. Checked for runs of 3+ sentences
# beginning with the same pronoun (he/she/i/we/they/it) or "the".
# Deliberate incantatory runs (same verb, Declaration movement) are false
# positives but are reported as diagnostic, not flagged.
# ---------------------------------------------------------------------------
# "the" excluded: "The X / The Y" consecutive openers are caught by the
# anaphoric-pair detector (Pattern 7a), which is more precise. Including "the"
# here produces false positives on deliberate Expansion/observation prose.
SUBJECT_PRONOUNS = frozenset(["he", "she", "i", "we", "they", "it"])

# ---------------------------------------------------------------------------
# Pattern 7: Magic adverbs (humanize.md Tell #2)
# Adverbs that perform subtle importance without earning it via verb choice.
# "quietly", "softly", "gently", etc. Density > 3.0/1000w is a flag.
# ---------------------------------------------------------------------------
_MAGIC_ADVERB_LIST = [
    "quietly", "softly", "gently", "deeply", "barely", "slightly",
    "slowly", "carefully", "tenderly", "delicately", "subtly",
    "faintly", "dimly", "harshly", "numbly", "hollowly",
]
MAGIC_ADVERB_PATTERN = re.compile(
    r"\b(?:" + "|".join(_MAGIC_ADVERB_LIST) + r")\b",
    re.IGNORECASE,
)

# ---------------------------------------------------------------------------
# Pattern 8: Negative parallelism (humanize.md Tell #14 / ai-slop Layer 6)
# "Not because X, but because Y" / "It's not X, it's Y" / "Not by X, but by Y"
# EQ-bench weights this at 25% of slop score. Any instance is a flag.
# ---------------------------------------------------------------------------
NEG_PARALLEL_PATTERN = re.compile(
    r"(?:"
    r"\bnot because\b.{1,100}\bbut because\b"
    r"|\bit'?s not\b.{1,100}\bit'?s\b"
    r"|\bnot by\b.{1,100}\bbut by\b"
    r"|\bnot to\b.{1,100}\bbut to\b"
    r")",
    re.IGNORECASE,
)

# ---------------------------------------------------------------------------
# Pattern 9: Generic emotional rhetoric frames (humanize.md Tell #19)
# "the kind of cold that..." / "the sort of fear you..." — announces feeling
# then describes it abstractly. Density > 1.0/1000w is a flag.
# ---------------------------------------------------------------------------
EMOTION_FRAME_PATTERN = re.compile(
    r"\b(?:the|a)\s+(?:kind|sort)\s+of\s+\w+\s+(?:that|you|which|who)\b",
    re.IGNORECASE,
)

# ---------------------------------------------------------------------------
# Pattern 10: Filler phrases (humanize.md Tell #17)
# "in order to", "due to the fact that", etc. Any instance worth flagging.
# Reported as diagnostic only (not verdict flag) — too minor individually.
# ---------------------------------------------------------------------------
FILLER_PATTERN = re.compile(
    r"(?:"
    r"\bin order to\b"
    r"|\bdue to the fact that\b"
    r"|\bat this point in time\b"
    r"|\bit is important to note\b"
    r"|\bneedless to say\b"
    r"|\bit goes without saying\b"
    r"|\bit should be noted that\b"
    r")",
    re.IGNORECASE,
)

# ---------------------------------------------------------------------------
# Pattern 11: Said-bookisms (turkey-city.md)
# Non-said/asked dialogue attribution verbs. Any instance is diagnostic.
# Pattern: closing quote → attribution verb near a subject pronoun/name.
# ---------------------------------------------------------------------------
_SAID_BOOKISM_VERBS = (
    "hissed|breathed|averred|snarled|barked|growled|giggled|chuckled|"
    "snapped|spat|exclaimed|announced|declared|interjected|countered|"
    "retorted|quipped|grumbled|huffed|chirped|purred|drawled|mused|"
    "simpered|sneered|scoffed|jeered|bleated|whimpered|thundered|boomed"
)
SAID_BOOKISM_PATTERN = re.compile(
    r'["""][,.]?\s{0,3}(?:she|he|they|i|we|\w+)\s+(?:' + _SAID_BOOKISM_VERBS + r")\b",
    re.IGNORECASE,
)

# ---------------------------------------------------------------------------
# Pattern 12: As-you-know-Bob exposition markers (turkey-city.md)
# "As you know", "As I'm sure you know/remember", "As we both know".
# Any instance is a flag — turkey-city rates these "cut immediately".
# ---------------------------------------------------------------------------
AS_YOU_KNOW_PATTERN = re.compile(
    r"(?:"
    r"\bas you (?:know|may know|probably know|surely know|remember|may remember|recall|may recall)\b"
    r"|\bas (?:I'?m|I am) sure you\b"
    r"|\bas we (?:both )?know\b"
    r"|\bas (?:you|we) all know\b"
    r")",
    re.IGNORECASE,
)

# ---------------------------------------------------------------------------
# Pattern 14: Distancing verbs in first-person narration
# "I saw/heard/noticed/realized/watched/observed/perceived" — these create a
# POV-filtering layer between reader and event. "I heard a door slam" should be
# "A door slammed." In first-person present tense, the narrator IS the observer;
# the observation verb is a redundant frame. Density > 2.0/1000w is a soft flag.
# ---------------------------------------------------------------------------
_DISTANCING_VERB_LIST = [
    "saw", "heard", "noticed", "realized", "realised",
    "watched", "observed", "perceived", "glimpsed",
]
DISTANCING_VERB_PATTERN = re.compile(
    r"\bI\s+(?:" + "|".join(_DISTANCING_VERB_LIST) + r")\b",
    re.IGNORECASE,
)

# ---------------------------------------------------------------------------
# Pattern 15: Filler words
# "really", "very", "just", "even", "actually", "basically", "quite" — these
# add nothing and inflate generic prose register. Density > 3.0/1000w is a flag.
# ---------------------------------------------------------------------------
_FILLER_WORD_LIST = [
    "really", "very", "just", "even", "actually", "literally",
    "basically", "essentially", "quite", "rather", "somewhat", "fairly",
]
FILLER_WORD_PATTERN = re.compile(
    r"\b(?:" + "|".join(_FILLER_WORD_LIST) + r")\b",
    re.IGNORECASE,
)

# ---------------------------------------------------------------------------
# Pattern 13: Pushbutton words (turkey-city.md "pushbutton" / humanize Tell #1)
# Stock emotional triggers beyond what EQ-bench bigrams catch.
# These bypass reader engagement by telling rather than showing emotion.
# Reported as diagnostic; density > 2.0/1000w is a soft flag.
# ---------------------------------------------------------------------------
_PUSHBUTTON_LIST = [
    "tears", "trembling", "trembled", "tremble", "shivers", "shivered",
    "shiver", "sobbing", "sobbed", "sob", "gasped", "gasp", "whimpered",
    "whimper", "flinched", "flinch", "recoiled", "recoil",
]
PUSHBUTTON_PATTERN = re.compile(
    r"\b(?:" + "|".join(_PUSHBUTTON_LIST) + r")\b",
    re.IGNORECASE,
)

# ---------------------------------------------------------------------------
# Pattern 2: aphoristic sentence detection
# ---------------------------------------------------------------------------

# Sentences starting with these are personal/specific statements, not universal
# thematic claims. Exclude them from aphorism detection.
PERSONAL_STARTS = frozenset([
    "i", "he", "she", "we", "you", "they", "it",
    "his", "her", "their", "my", "our", "your", "its",
    "this", "that", "these", "those",
])

# Abstract noun stems (matched after stripping trailing 's') that signal
# a sentence is making a thematic/universal claim rather than a concrete
# description. A real aphorism must contain at least one of these.
ABSTRACT_STEMS = frozenset([
    "truth", "lie", "failure", "silence", "fear", "love", "time", "death",
    "hope", "power", "story", "myth", "wound", "memory", "grief", "rage",
    "hunger", "mercy", "patience", "darkness", "pain", "shame", "pride",
    "anger", "loss", "soul", "fate", "chance", "luck", "strength", "weakness",
    "courage", "cowardice", "obedience", "defiance", "surrender", "freedom",
    "captivity", "knowledge", "ignorance", "wisdom", "folly", "cruelty",
    "kindness", "hate", "war", "peace", "chaos", "order", "guilt", "innocence",
    "justice", "virtue", "sin", "beauty", "language", "bone", "tooth", "knife",
    "door", "bar", "chain", "name", "word", "price", "cost", "worth", "weight",
    "shadow", "ending", "beginning", "quiet", "noise", "rhythm", "habit",
    "oblivion", "descent", "ascent", "ruin", "glory", "dread",
])

# Capitalized words that look like proper nouns but are not.
NOT_PROPER = frozenset(["i", "there", "here"])

# Unicode curly quotes to strip from sentence boundaries.
CURLY_QUOTES = "“”‘’"


def is_aphoristic(sentence: str) -> bool:
    """Return True if sentence looks like a standalone AI-style aphorism.

    Criteria:
      1. 4-15 words
      2. Ends with a period (declarative claim, not action or question)
      3. Does NOT start with a personal pronoun, possessive, or demonstrative
      4. Contains no external proper noun after word 0
      5. Contains at least one abstract noun stem
    """
    s = sentence.strip().strip(CURLY_QUOTES + "\"'")
    words = s.rstrip(".!?,;").split()
    if len(words) < 4 or len(words) > 15:
        return False
    if not s.rstrip().endswith("."):
        return False
    if words[0].lower() in PERSONAL_STARTS:
        return False
    for w in words[1:]:
        bare = re.sub(r"[^a-zA-Z]", "", w)
        if bare and bare[0].isupper() and bare.lower() not in NOT_PROPER:
            return False
    stems = {re.sub(r"[^a-z]", "", w.lower()).rstrip("s") for w in words}
    if not stems & ABSTRACT_STEMS:
        return False
    return True


def get_sentence_opener(sentence: str) -> str:
    """Return the lowercased first word of a sentence, stripped of punctuation."""
    s = sentence.strip().strip(CURLY_QUOTES + "\"'")
    words = s.split()
    if not words:
        return ""
    return re.sub(r"[^a-z]", "", words[0].lower())


def count_same_subject_runs(sentences: list[str], min_run: int = 3) -> tuple[int, int, list]:
    """Count runs of min_run+ consecutive sentences with the same subject opener.

    Returns (run_count, max_run_length, list_of_run_examples).
    Only counts runs where the opener is a subject pronoun (see SUBJECT_PRONOUNS).
    """
    runs = []
    i = 0
    while i < len(sentences):
        opener = get_sentence_opener(sentences[i])
        if opener not in SUBJECT_PRONOUNS:
            i += 1
            continue
        j = i + 1
        while j < len(sentences) and get_sentence_opener(sentences[j]) == opener:
            j += 1
        run_len = j - i
        if run_len >= min_run:
            runs.append({"opener": opener, "length": run_len, "start_sentence": sentences[i][:80]})
        i = j if run_len > 1 else i + 1
    max_run = max((r["length"] for r in runs), default=0)
    return len(runs), max_run, runs


def count_anaphoric_noun_pairs(sentences: list[str]) -> tuple[int, list]:
    """Count consecutive sentence pairs where both begin with 'The [same word]'.

    e.g. 'The cold that remembers passages. / The cold I refused to finish naming.'
    Returns (pair_count, list_of_examples).
    """
    pairs = []
    for i in range(len(sentences) - 1):
        w1 = sentences[i].strip().split()
        w2 = sentences[i + 1].strip().split()
        if (
            len(w1) >= 2 and len(w2) >= 2
            and w1[0].lower().rstrip(".,;:") == "the"
            and w2[0].lower().rstrip(".,;:") == "the"
            and re.sub(r"[^a-z]", "", w1[1].lower()) == re.sub(r"[^a-z]", "", w2[1].lower())
        ):
            pairs.append(f"{sentences[i][:60]} / {sentences[i+1][:60]}")
    return len(pairs), pairs


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

def strip_markup(text: str) -> str:
    text = re.sub(r"^---.*?---\s*", "", text, flags=re.DOTALL)
    text = re.sub(r"^\* \* \*\s*$", "", text, flags=re.MULTILINE)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def split_sentences(text: str) -> list[str]:
    text = re.sub(r"\s+", " ", text).strip()
    if not text:
        return []
    # Split on .!? followed by whitespace + capital or opening quote
    parts = re.split(r"(?<=[.!?])\s+(?=[A-Z“‘\"'])", text)
    return [p.strip() for p in parts if p.strip()]


def score(path: Path, verbose: bool = False) -> dict:
    text = read_prose(path)
    text = strip_markup(text)
    sentences = split_sentences(text)
    word_count = len(text.split())
    per_1000 = max(word_count / 1000, 0.001)

    def hits(pattern: re.Pattern) -> tuple[int, float]:
        """(count, density per 1,000 words) of a pattern over the whole text."""
        n = len(pattern.findall(text))
        return n, round(n / per_1000, 3)

    way_x_count, way_x_density = hits(WAY_X_PATTERN)                        # Signal 1
    things_that_count, things_that_density = hits(THINGS_THAT_PATTERN)      # Signal 4

    # Signal 2: aphoristic sentence density
    aphorisms = [s for s in sentences if is_aphoristic(s)]
    aphorism_count = len(aphorisms)
    aphorism_density = round(aphorism_count / per_1000, 3)

    # Signal 3: max consecutive short-sentence run (guide-character dialogue tell)
    max_run = 0
    run = 0
    for s in sentences:
        if len(s.split()) <= 12:
            run += 1
            if run > max_run:
                max_run = run
        else:
            run = 0

    as_if_count, as_if_density = hits(AS_IF_PATTERN)                        # Signal 5

    # Signal 6: same-subject consecutive sentence runs (diagnostic)
    same_subj_run_count, same_subj_max_run, same_subj_runs = count_same_subject_runs(sentences)

    # Signal 7a: anaphoric noun-phrase pairs (diagnostic)
    anaphoric_pair_count, anaphoric_pair_examples = count_anaphoric_noun_pairs(sentences)

    magic_adverb_count, magic_adverb_density = hits(MAGIC_ADVERB_PATTERN)   # Signal 7
    neg_parallel_count, _ = hits(NEG_PARALLEL_PATTERN)                      # Signal 8: any is a flag
    emotion_frame_count, emotion_frame_density = hits(EMOTION_FRAME_PATTERN)  # Signal 9
    filler_count, _ = hits(FILLER_PATTERN)                                  # Signal 10: diagnostic
    said_bookism_count, _ = hits(SAID_BOOKISM_PATTERN)                      # Signal 11: diagnostic
    as_you_know_count, _ = hits(AS_YOU_KNOW_PATTERN)                        # Signal 12: any is a flag
    pushbutton_count, pushbutton_density = hits(PUSHBUTTON_PATTERN)         # Signal 13: soft > 2.0
    distancing_count, distancing_density = hits(DISTANCING_VERB_PATTERN)    # Signal 14: soft > 2.0
    filler_word_count, filler_word_density = hits(FILLER_WORD_PATTERN)      # Signal 15: soft > 3.0

    # ---------------------------------------------------------------------------
    # Thresholds and verdict
    #
    # Verdict flags (hard signals — each contributes to AI_SIGNAL / BORDERLINE):
    #   way_x_density, aphorism_density, things_that_density, as_if_density,
    #   magic_adverb_density, neg_parallel_count, emotion_frame_density,
    #   as_you_know_count
    #
    # Diagnostics only (reported but do not affect verdict):
    #   max_consecutive_short_run, same_subj_run_count, anaphoric_pair_count,
    #   filler_count, said_bookism_count, pushbutton_count
    #
    # Thresholds were calibrated by hand on a private prose corpus (for
    # example, its baseline aphorism density was ~6.5/1000w, hence 8.0).
    # ---------------------------------------------------------------------------
    WAY_X_THRESHOLD         = 1.5   # per 1000w
    APHORISM_THRESHOLD      = 8.0   # per 1000w
    THINGS_THAT_THRESHOLD   = 0.5   # per 1000w
    AS_IF_THRESHOLD         = 1.0   # per 1000w
    MAGIC_ADVERB_THRESHOLD  = 3.0   # per 1000w
    EMOTION_FRAME_THRESHOLD = 1.0   # per 1000w

    # (type, value, threshold, detail): flagged when value > threshold. A threshold
    # of 0 means any instance is a flag.
    checks = [
        ("way_x_density", way_x_density, WAY_X_THRESHOLD,
         f"{way_x_count} 'the way X' constructions in {word_count} words"),
        ("aphorism_density", aphorism_density, APHORISM_THRESHOLD,
         f"{aphorism_count} aphoristic sentences in {word_count} words"),
        ("things_that_density", things_that_density, THINGS_THAT_THRESHOLD,
         f"{things_that_count} 'things that' constructions in {word_count} words"),
        ("as_if_density", as_if_density, AS_IF_THRESHOLD,
         f"{as_if_count} 'as if' constructions in {word_count} words"),
        ("magic_adverb_density", magic_adverb_density, MAGIC_ADVERB_THRESHOLD,
         f"{magic_adverb_count} magic adverbs in {word_count} words"),
        ("neg_parallel", neg_parallel_count, 0,
         f"{neg_parallel_count} negative-parallelism constructions (no craft override exists)"),
        ("emotion_frame_density", emotion_frame_density, EMOTION_FRAME_THRESHOLD,
         f"{emotion_frame_count} 'the kind of X that' frames in {word_count} words"),
        ("as_you_know", as_you_know_count, 0,
         f"{as_you_know_count} as-you-know-Bob exposition marker(s) — turkey-city 'cut immediately'"),
    ]
    flags = [{"type": t, "value": v, "threshold": th, "detail": d}
             for t, v, th, d in checks if v > th]

    if len(flags) >= 2:
        verdict = "AI_SIGNAL"
    elif len(flags) == 1:
        verdict = "BORDERLINE"
    else:
        verdict = "CLEAN"

    result: dict = {
        "path": str(path),
        "word_count": word_count,
        "sentence_count": len(sentences),
        # -- verdict flags --
        "way_x_count": way_x_count,
        "way_x_density_per_1000w": way_x_density,
        "aphorism_count": aphorism_count,
        "aphorism_density_per_1000w": aphorism_density,
        "things_that_count": things_that_count,
        "things_that_density_per_1000w": things_that_density,
        "as_if_count": as_if_count,
        "as_if_density_per_1000w": as_if_density,
        "magic_adverb_count": magic_adverb_count,
        "magic_adverb_density_per_1000w": magic_adverb_density,
        "neg_parallel_count": neg_parallel_count,
        "emotion_frame_count": emotion_frame_count,
        "emotion_frame_density_per_1000w": emotion_frame_density,
        "as_you_know_count": as_you_know_count,
        # -- diagnostics only --
        "filler_count": filler_count,
        "said_bookism_count": said_bookism_count,
        "pushbutton_count": pushbutton_count,
        "pushbutton_density_per_1000w": pushbutton_density,
        "distancing_verb_count": distancing_count,
        "distancing_verb_density_per_1000w": distancing_density,
        "filler_word_count": filler_word_count,
        "filler_word_density_per_1000w": filler_word_density,
        "max_consecutive_short_run": max_run,
        "same_subject_run_count": same_subj_run_count,
        "same_subject_max_run": same_subj_max_run,
        "anaphoric_pair_count": anaphoric_pair_count,
        "flags": flags,
        "verdict": verdict,
    }

    if verbose:
        result["way_x_examples"] = WAY_X_PATTERN.findall(text)[:10]
        result["aphorism_examples"] = aphorisms[:10]
        result["things_that_examples"] = [
            m.group(0) for m in THINGS_THAT_PATTERN.finditer(text)
        ][:10]
        result["as_if_examples"] = AS_IF_PATTERN.findall(text)[:10]
        result["magic_adverb_examples"] = MAGIC_ADVERB_PATTERN.findall(text)[:10]
        result["neg_parallel_examples"] = NEG_PARALLEL_PATTERN.findall(text)[:5]
        result["emotion_frame_examples"] = EMOTION_FRAME_PATTERN.findall(text)[:5]
        result["filler_examples"] = FILLER_PATTERN.findall(text)[:5]
        result["said_bookism_examples"] = SAID_BOOKISM_PATTERN.findall(text)[:5]
        result["pushbutton_examples"] = PUSHBUTTON_PATTERN.findall(text)[:10]
        result["distancing_verb_examples"] = [m.group(0) for m in DISTANCING_VERB_PATTERN.finditer(text)][:10]
        result["filler_word_examples"] = FILLER_WORD_PATTERN.findall(text)[:15]
        result["same_subject_run_examples"] = same_subj_runs[:3]
        result["anaphoric_pair_examples"] = anaphoric_pair_examples[:5]

    return result


def calibrate(paths: list[Path]) -> None:
    """Print a calibration table across multiple files."""
    print(
        f"{'File':<28} {'way_x':>6} {'aphor':>6} {'as_if':>6} "
        f"{'adverb':>7} {'neg_p':>6} {'emfr':>5} {'filler':>7} "
        f"{'sb':>4} {'pb':>4} {'verdict':<12}"
    )
    print("-" * 100)
    for p in paths:
        r = score(p)
        print(
            f"{p.name:<28} "
            f"{r['way_x_density_per_1000w']:>6.2f} "
            f"{r['aphorism_density_per_1000w']:>6.2f} "
            f"{r['as_if_density_per_1000w']:>6.2f} "
            f"{r['magic_adverb_density_per_1000w']:>7.2f} "
            f"{r['neg_parallel_count']:>6} "
            f"{r['emotion_frame_count']:>5} "
            f"{r['filler_count']:>7} "
            f"{r['said_bookism_count']:>4} "
            f"{r['pushbutton_count']:>4} "
            f"{r['verdict']:<12}"
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("path", type=Path, nargs="+", help="Prose file(s) to score")
    parser.add_argument("--verbose", action="store_true", help="Include matched examples in output")
    parser.add_argument("--calibrate", action="store_true", help="Print a calibration table")
    args = parser.parse_args()

    if args.calibrate:
        calibrate(args.path)
        return 0

    if len(args.path) == 1:
        result = score(args.path[0], verbose=args.verbose)
        print(json.dumps(result, indent=2))
    else:
        results = [score(p, verbose=args.verbose) for p in args.path]
        print(json.dumps(results, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
