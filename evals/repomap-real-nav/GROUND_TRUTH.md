# otwarchive navigation ground truth (derived by grep, 2026-10-07)

Question: "add a user preference controlling email timing — which files change?"

## Core answer set (all three required for a PASS)
1. app/models/preference.rb — the preference fields live here (email prefs
   are columns on this model; collection_preference.rb is the COLLECTION
   sibling, a near-miss).
2. app/controllers/preferences_controller.rb — the update path.
3. app/views/preferences/ — the preference form/partials the user edits.
4. Locale files under config/locales/ (at minimum the English controllers/
   views yml) for the new label strings.

## Near-miss distractors (a WRONG answer leans on these)
- app/models/collection_preference.rb + collections controllers — the
  collection-scoped preference system, NOT user email prefs.

## A correct answer
names the core set with one-line reasons; may mention user.rb (owner
association) and routing as optional extras.

## WRONG if
- the collection preference files are presented as THE user preference
  system,
- no view or no locale file is identified,
- files are named that have nothing to do with preferences.
