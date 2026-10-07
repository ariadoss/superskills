---
max_turns: 30
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Bash, Skill]
tags: [graphify, corpus, maintainer]
---

The folder ./fixture-repo is a song corpus (lyrics, style notes, mapping
notes across pop/, rap/ and other dirs). Answer these questions from the
corpus, with evidence (file names / quoted lines):
1. List every band, its genre, and where its songs live in the folder
   structure.
2. Which tracks are the breakouts, for which bands, and what are their play
   counts? Which bands have NO hit yet, and what range do their tracks sit in?
3. In pop/, which songs exist in both a _style and a _suno variant? Which
   song has Russian-language variants, and what are they?
