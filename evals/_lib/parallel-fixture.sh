#!/bin/bash
# parallel-fixture.sh <dir>: builds the plain-Node repo used by
# evals/reports/2026-10-29-parallel-bound.md. One clean main branch; agents
# running the case prompts set up their own branches/worktrees on top.
set -e
D="$1"; rm -rf "$D"; mkdir -p "$D"; cd "$D"
git init -q -b main; git config user.email eval@example.test; git config user.name "Parallel Fixture"
mkdir -p src tests
cat > package.json <<'J'
{ "name": "notewell", "version": "0.3.0", "private": true, "type": "commonjs",
  "scripts": { "test": "node --test" } }
J
cat > CLAUDE.md <<'M'
# notewell

Plain Node (no dependencies, no build step, no database — notes are stored
in a JSON file). Tests use the built-in runner.

- Test command: `npm test`
- No dev server.
M
cat > src/notes.js <<'J'
const fs = require('fs');
function loadNotes(file) {
  if (!fs.existsSync(file)) return [];
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}
function saveNote(file, note) {
  const notes = loadNotes(file);
  notes.push(note);
  fs.writeFileSync(file, JSON.stringify(notes, null, 2));
  return note;
}
module.exports = { loadNotes, saveNote };
J
cat > tests/notes.test.js <<'J'
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { loadNotes, saveNote } = require('../src/notes');
test('saves and reloads a note', () => {
  const f = path.join(os.tmpdir(), `notes-${Date.now()}.json`);
  saveNote(f, { id: 1, body: 'hello' });
  assert.strictEqual(loadNotes(f).length, 1);
  fs.unlinkSync(f);
});
J
printf 'node_modules\nnotes-data.json\n' > .gitignore
git add -A; git commit -qm "base: note storage"
echo "fixture ready: $D"
