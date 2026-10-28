#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  CHECKER="$REPO_ROOT/tests/plugin-validation-report.py"
}

@test "validator policy accepts informational notes and the established warning exceptions" {
  python3 - "$CHECKER" <<'PY'
import json
import subprocess
import sys

report = {
    "success": True,
    "manifest": {"errors": [], "warnings": []},
    "contents": [{"errors": [], "warnings": [{"message": "CLAUDE.md at the plugin root is not loaded as project context."}]}],
    "directory": {
        "findings": [{"code": "ICON_MISSING", "severity": "warning"}],
        "notes": ["README.md was taken from the repository root."],
        "incomplete": False,
        "failure": None,
    },
}
result = subprocess.run([sys.executable, sys.argv[1]], input=json.dumps(report), text=True, capture_output=True)
assert result.returncode == 0, result.stderr or result.stdout
assert not result.stdout, result.stdout
PY
}

@test "validator policy still rejects errors new warnings and incomplete checks" {
  python3 - "$CHECKER" <<'PY'
import json
import subprocess
import sys

cases = [
    {"success": False},
    {"manifest": {"errors": [{"message": "invalid version"}], "warnings": []}},
    {"manifest": {"errors": [], "warnings": [{"message": "unknown manifest field"}]}},
    {"contents": [{"errors": [{"message": "invalid skill"}], "warnings": []}]},
    {"contents": [{"errors": [], "warnings": [{"message": "unknown skill field"}]}]},
    {"directory": {"findings": [{"code": "NEW_WARNING", "severity": "warning"}]}},
    {"directory": {"findings": [{"code": "ICON_MISSING", "severity": "error"}]}},
    {"directory": {"incomplete": True}},
    {"directory": {"failure": "could not read plugin"}},
]
for patch in cases:
    report = {"success": True, "manifest": {"errors": [], "warnings": []}, "contents": [], "directory": {}}
    report.update(patch)
    result = subprocess.run([sys.executable, sys.argv[1]], input=json.dumps(report), text=True, capture_output=True)
    assert result.returncode == 1, (patch, result.stderr)
    assert result.stdout, patch
PY
}

@test "validator policy rejects malformed JSON" {
  run bash -c 'printf "%s" "{broken" | python3 "$1"' _ "$CHECKER"
  [ "$status" -eq 1 ] || false
  [[ "$output" == *"invalid validation report"* ]] || false
}
