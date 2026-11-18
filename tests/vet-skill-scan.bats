#!/usr/bin/env bats
setup() {
  T="$BATS_TEST_DIRNAME/../skills/vet-skill/tools/vet_scan.py"
  D="$BATS_TEST_TMPDIR/target"; mkdir -p "$D"
}
scan() { python3 -I "$T" "$D"; }

@test "an empty directory scans clean with exit 0" {
  run scan
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.findings | length')" = "0" ]
}
@test "bad input is exit 2" {
  run python3 -I "$T" "$BATS_TEST_TMPDIR/nope"
  [ "$status" -eq 2 ]
  run python3 -I "$T"
  [ "$status" -eq 2 ]
}
@test "target python is never executed" {
  printf 'open("%s/MARK","w").write("ran")\n' "$BATS_TEST_TMPDIR" > "$D/boom.py"
  printf 'open("%s/MARK2","w").write("ran")\n' "$BATS_TEST_TMPDIR" > "$D/setup.py"
  run scan
  [ ! -e "$BATS_TEST_TMPDIR/MARK" ] || false
  [ ! -e "$BATS_TEST_TMPDIR/MARK2" ] || false
}
@test "a symlink is skipped and reported, never followed" {
  ln -s /etc/hosts "$D/link.txt"
  run scan
  echo "$output" | jq -e '.skipped[] | select(.path=="link.txt" and .reason=="symlink")' >/dev/null
}
@test "a file over the size cap is skipped and reported" {
  head -c 1100000 /dev/zero | tr '\0' 'a' > "$D/big.txt"
  run scan
  echo "$output" | jq -e '.skipped[] | select(.path=="big.txt" and .reason=="too large")' >/dev/null
  [ "$status" -eq 3 ]
}
@test "a FIFO is skipped, never opened (opening one would hang the scan)" {
  mkfifo "$D/pipe.txt"
  run timeout 10 python3 -I "$T" "$D"
  [ "$status" -eq 3 ]
  echo "$output" | jq -e '.skipped[] | select(.path=="pipe.txt" and .reason=="special file")' >/dev/null
}
@test "a symlinked directory is skipped and reported, not descended" {
  mkdir -p "$BATS_TEST_TMPDIR/outside"; echo "x" > "$BATS_TEST_TMPDIR/outside/a.txt"
  ln -s "$BATS_TEST_TMPDIR/outside" "$D/linkdir"
  run scan
  echo "$output" | jq -e '.skipped[] | select(.path=="linkdir" and .reason=="symlink")' >/dev/null
}
@test "a binary file is skipped and reported, never read as text" {
  printf '\x00\x01\x02\x03' > "$D/blob.bin"
  run scan
  echo "$output" | jq -e '.skipped[] | select(.path=="blob.bin" and .reason=="binary")' >/dev/null
}
@test "an archive is listed as unreviewable" {
  printf 'PK\x03\x04junk' > "$D/pack.zip"
  run scan
  echo "$output" | jq -e '.skipped[] | select(.path=="pack.zip")' >/dev/null
}
@test "a tree over the file cap stops cleanly and says so" {
  for i in $(seq 1 5100); do : > "$D/f$i.txt"; done
  run scan
  echo "$output" | jq -e '.truncated == true' >/dev/null
}
@test "the .git directory is not scanned" {
  mkdir -p "$D/.git"; echo "x" > "$D/.git/config"
  run scan
  [ "$(echo "$output" | jq -r '[.skipped[].path] | map(select(startswith(".git/"))) | length')" = "0" ]
}
@test "snippets are escaped: no ANSI, bidi or zero-width in the output" {
  python3 -I -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME/../skills/vet-skill/tools')
import vet_scan
s = vet_scan.clean('a\x1b[31mb‮c​d')
assert '\x1b' not in s and '‮' not in s and '​' not in s, s
"
}
@test "clean() escapes C1, invisible format, variation-selector and line-separator characters" {
  run python3 -I -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME/../skills/vet-skill/tools')
import vet_scan
bad = ['\u009b', '\u0085', '⁠', '⁤', '⁪', '⁯', '؜', '­', '᠎',
       '︀', '️', '\U000e0100', '\U000e01ef', ' ', ' ']
for ch in bad:
    s = vet_scan.clean('a' + ch + 'b')
    assert ch not in s, repr(ch)
    assert '\\\\u' in s, repr(ch)
"
  [ "$status" -eq 0 ]
}
@test "clean() truncates to 160 characters" {
  run python3 -I -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME/../skills/vet-skill/tools')
import vet_scan
assert len(vet_scan.clean('x' * 1000)) == 160
"
  [ "$status" -eq 0 ]
}
@test "the skipped list is bounded and the overflow is counted" {
  for i in $(seq 1 300); do : > "$D/a$i.zip"; done
  run scan
  [ "$status" -eq 3 ]
  [ "$(echo "$output" | jq -r '.skipped | length')" = "200" ]
  [ "$(echo "$output" | jq -r '.skipped_overflow')" = "100" ]
}
@test "the walk stops at the file cap instead of visiting the whole tree" {
  for i in $(seq 1 5100); do : > "$D/f$i.txt"; done
  run scan
  [ "$(echo "$output" | jq -r '.truncated')" = "true" ]
  [ "$(echo "$output" | jq -r '.skipped_overflow')" = "0" ]
}
@test "a file that cannot be lstat'd is skipped as unreadable, not a crash" {
  : > "$D/a.txt"
  run python3 -I -c "
import sys; sys.path.insert(0, '$BATS_TEST_DIRNAME/../skills/vet-skill/tools')
import vet_scan
from pathlib import Path
orig = Path.lstat
def boom(self):
    if self.name == 'a.txt':
        raise PermissionError('x')
    return orig(self)
Path.lstat = boom
files, skipped, truncated, overflow = vet_scan.walk(Path('$D').resolve())
assert files == [] and skipped == [{'path': 'a.txt', 'reason': 'unreadable'}], (files, skipped)
"
  [ "$status" -eq 0 ]
}
