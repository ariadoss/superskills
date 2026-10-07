---
type: llm
focus: last_message
arm: both
---

Grade against this key: the user preference system is app/models/preference.rb
(fields), app/controllers/preferences_controller.rb (update path),
app/views/preferences/ (form), plus locale files under config/locales/ for
new strings. app/models/collection_preference.rb is the collection-scoped
near-miss, not the user system. user.rb (association) and routes are
acceptable optional extras.

PASS if the reply's list includes the model, the controller, the view
location, AND a locale file, each with a plausible why — and does not
present the collection preference files as the user preference system.

FAIL if any of the four core elements is missing, or the collection
sibling is named as the primary system, or unrelated files dominate.
