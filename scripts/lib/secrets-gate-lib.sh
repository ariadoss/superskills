#!/usr/bin/env bash
# secrets-gate-lib.sh: scan unpushed commits for secrets with gitleaks.
sg_available() { command -v gitleaks >/dev/null 2>&1; }

# sg_target_dir <command> <cwd>: the directory a push command acts on.
sg_target_dir() {
  local cmd="$1" cwd="$2" dir="$2"
  if [[ "$cmd" =~ (^|[\;\&\|[:space:]])cd[[:space:]]+([^\;\&\|[:space:]]+) ]]; then dir="${BASH_REMATCH[2]}"; fi
  if [[ "$cmd" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then dir="${BASH_REMATCH[1]}"; fi
  dir="${dir//\"/}"; dir="${dir//\'/}"; dir="${dir/#\~/$HOME}"
  [[ "$dir" = /* ]] || dir="$cwd/$dir"
  printf '%s\n' "$dir"
}

# sg_scan_unpushed <config>: scan every local branch and tag no remote holds.
# Prints "file:line rule" per leak (values redacted). Returns 0 clean, 1 leaks,
# 2 scanner error (a broken scanner never reads as clean).
sg_scan_unpushed() {
  local cfg="$1" out rc
  out="$(mktemp)" || return 2
  gitleaks git --no-banner --redact --exit-code 42 --config "$cfg" \
    --ignore-gitleaks-allow --gitleaks-ignore-path /dev/null \
    --log-opts="--branches --tags --not --remotes" \
    -r "$out" --report-format json . >/dev/null 2>"$out.err"
  rc=$?
  case "$rc" in
    0)  rm -f "$out" "$out.err"; return 0 ;;
    42) jq -r '.[] | "\(.File):\(.StartLine) \(.RuleID)"' "$out" 2>/dev/null
        rm -f "$out" "$out.err"; return 1 ;;
    *)  head -c 400 "$out.err"; rm -f "$out" "$out.err"; return 2 ;;
  esac
}
