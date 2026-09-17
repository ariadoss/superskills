#!/usr/bin/env bats
# Guard for a bats/bash-3.2 pitfall that silently disabled assertions: macOS
# ships bash 3.2, where a failing `[[ … ]]`, a `! cmd`, or a failing non-final
# part of `a && b` does NOT stop a bats test (errexit ignores them) unless it is
# the test's last line. Every such assertion line must end in `|| false`.

@test "no bats assertion line relies on errexit for [[ ]], ! or &&" {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  offenders="$(awk '
    FNR == 1 { intest = 0 }
    /^@test / { intest = 1; next }
    /^}/ { intest = 0; next }
    intest {
      t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t)
      if (t ~ /\|\|/ || t ~ /^(#|for |if |while |case )/ || t ~ /(\{|\\|do|then)$/) next
      if (t ~ /^\[\[ / || t ~ /^! / || (t ~ /^\[ / && t ~ / && /)) print FILENAME ":" FNR ": " t
    }' "$REPO_ROOT"/tests/*.bats)"
  [ -z "$offenders" ] || { echo "$offenders"; return 1; }
}

@test "the guard itself catches a bare [[ ]] (self-test)" {
  f="$BATS_TEST_TMPDIR/x.bats"
  printf '@test "t" {\n  [[ a == b ]]\n  true\n}\n' > "$f"
  run awk '/^@test /{i=1;next} /^}/{i=0;next} i { t=$0; sub(/^[ \t]+/,"",t); if (t ~ /^\[\[ / && t !~ /\|\|/) print }' "$f"
  [ -n "$output" ]
}
