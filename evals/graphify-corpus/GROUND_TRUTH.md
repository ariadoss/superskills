# songs corpus relational ground truth (derived from mapping.md + corpus listing, 2026-10-07)

## Bands and their genres (from mapping.md)
- Twilight Syndicate — Pop; Da-Nilo — Hip Hop; Velvet Embassy — Alt Rock;
  Phantom Reverie — Symphonic Metal (incl. Comrades of the Sword / Ariadoss book tie-ins);
  an unnamed devotional band (Baha'i-inspired); Nilorhythms — umbrella label over all.

## Breakout facts (mapping.md "Key findings")
1. "I'll Carry On" is the #1 asset: 5,667 plays vs 2,144 for #2 — 20-30x the
   150-300 baseline; Pop / Twilight Syndicate.
2. Breakouts cluster in exactly two bands: pop (I'll Carry On, Light of Day,
   Nanay, Nanay Bayani Ko) and symphonic-metal (Ode on a Book, Fire and Ice).
   Hip-hop and alt-rock tracks all sit in the flat 147-299 range — no hit yet.

## Corpus file facts (mechanical)
- pop/ files come in _style and _suno variants (e.g. AYUN_style.txt,
  AYUN_suno.txt); at least one song (GOODNIGHT_SLEEP_TIGHT) has _russian and
  _russian_latin variants. Exact per-song variant lists are checkable by
  listing pop/.

## A correct answer must
- name the two breakout bands and at least 3 of the 4 named pop breakouts and
  both symphonic-metal breakouts with the #1 track's play count (5,667) and
  the flat-band play range (147-299),
- place each band in its genre directory correctly,
- get variant structure right when asked (style+suno pairs; russian variants).

## WRONG if
- bands are swapped across genres, play counts are invented, or the devotional
  band / umbrella label is omitted when asked for the full band list.
