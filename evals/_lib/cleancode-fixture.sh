#!/usr/bin/env bash
# cleancode_fixture <dir>: builds the exporters repo for the clean-code judo
# eval. Base: three near-identical export functions (csv/json/xml) each
# re-implementing row handling, behind a one-method Dispatcher. Diff: adds
# export_yaml as a fourth copy wired into the Dispatcher. The judo move: one
# spec-driven exporter replacing all four (a per-format table deletes the
# duplication category); the smallest-fix is only extracting a shared helper.
# Tests pin behavior for all formats + the unknown-format error.
cleancode_fixture() {
  local dir="$1"
  [ -n "$dir" ] || { echo "usage: cleancode_fixture <dir>" >&2; return 2; }
  (
  rm -rf "$dir"
  mkdir -p "$dir"
  cd "$dir" || exit 1
  git init -q
  git config user.email fixture@example.com
  git config user.name fixture
  cat > exporters.py <<'EOF'
def _validate(rows):
    out = []
    for row in rows:
        if not isinstance(row, dict):
            raise TypeError("rows must be dicts")
        out.append({str(k): "" if v is None else str(v) for k, v in row.items()})
    return out


def _esc_csv(value):
    value = str(value)
    if any(c in value for c in ",\"\n"):
        return '"' + value.replace('"', '""') + '"'
    return value


def _esc_xml(value):
    return (str(value).replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;"))


def export_csv(rows):
    rows = _validate(rows)
    if not rows:
        return ""
    headers = list(rows[0].keys())
    lines = [",".join(_esc_csv(h) for h in headers)]
    for row in rows:
        lines.append(",".join(_esc_csv(row.get(h, "")) for h in headers))
    return "\n".join(lines)


def export_json(rows):
    rows = _validate(rows)
    import json as _json
    return _json.dumps(
        [{h: row.get(h, "") for h in (list(rows[0].keys()) if rows else [])}
         for row in rows] if rows else [])


def export_xml(rows):
    rows = _validate(rows)
    lines = ["<rows>"]
    for row in rows:
        lines.append("  <row>")
        for h in (list(rows[0].keys()) if rows else []):
            lines.append(f"    <{h}>{_esc_xml(row.get(h, ''))}</{h}>")
        lines.append("  </row>")
    lines.append("</rows>")
    return "\n".join(lines)


class Dispatcher:
    """Routes a format name to its export function."""

    def export(self, fmt, rows):
        if fmt == "csv":
            return export_csv(rows)
        if fmt == "json":
            return export_json(rows)
        if fmt == "xml":
            return export_xml(rows)
        raise ValueError(f"unknown format: {fmt}")
EOF
  cat > test_exporters.py <<'EOF'
import pytest
from exporters import Dispatcher

ROWS = [{"id": 1, "name": 'Ann, "A"'}, {"id": 2, "name": "Bob"}]

@pytest.mark.parametrize("fmt", ["csv", "json", "xml"])
def test_roundtrip_fields(fmt):
    out = Dispatcher().export(fmt, ROWS)
    assert "Ann" in out and "Bob" in out

def test_unknown_format_raises():
    with pytest.raises(ValueError):
        Dispatcher().export("parquet", ROWS)
EOF
  git add -A && git commit -qm "base: csv/json/xml exporters"
  git switch -qc feature/export-yaml
  # --- the diff under review: a fourth format as a fourth copy (committed on
  # the feature branch so clean-code's Step 1.4 clean-tree precondition holds
  # without a user to ask) ---
  cat > exporters.py <<'EOF'
def _validate(rows):
    out = []
    for row in rows:
        if not isinstance(row, dict):
            raise TypeError("rows must be dicts")
        out.append({str(k): "" if v is None else str(v) for k, v in row.items()})
    return out


def _esc_csv(value):
    value = str(value)
    if any(c in value for c in ",\"\n"):
        return '"' + value.replace('"', '""') + '"'
    return value


def _esc_xml(value):
    return (str(value).replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;"))


def _esc_yaml(value):
    value = str(value)
    return '"' + value.replace('"', '\\"') + '"' if any(
        c in value for c in ':,"\n') else value


def export_csv(rows):
    rows = _validate(rows)
    if not rows:
        return ""
    headers = list(rows[0].keys())
    lines = [",".join(_esc_csv(h) for h in headers)]
    for row in rows:
        lines.append(",".join(_esc_csv(row.get(h, "")) for h in headers))
    return "\n".join(lines)


def export_json(rows):
    rows = _validate(rows)
    import json as _json
    return _json.dumps(
        [{h: row.get(h, "") for h in (list(rows[0].keys()) if rows else [])}
         for row in rows] if rows else [])


def export_xml(rows):
    rows = _validate(rows)
    lines = ["<rows>"]
    for row in rows:
        lines.append("  <row>")
        for h in (list(rows[0].keys()) if rows else []):
            lines.append(f"    <{h}>{_esc_xml(row.get(h, ''))}</{h}>")
        lines.append("  </row>")
    lines.append("</rows>")
    return "\n".join(lines)


def export_yaml(rows):
    rows = _validate(rows)
    lines = ["---"]
    for row in rows:
        lines.append("- " + ", ".join(
            f"{h}: {_esc_yaml(row.get(h, ''))}"
            for h in (list(rows[0].keys()) if rows else [])))
    return "\n".join(lines)


class Dispatcher:
    """Routes a format name to its export function."""

    def export(self, fmt, rows):
        if fmt == "csv":
            return export_csv(rows)
        if fmt == "json":
            return export_json(rows)
        if fmt == "xml":
            return export_xml(rows)
        if fmt == "yaml":
            return export_yaml(rows)
        raise ValueError(f"unknown format: {fmt}")
EOF
  cat >> test_exporters.py <<'EOF'

def test_yaml_roundtrip_fields():
    out = Dispatcher().export("yaml", ROWS)
    assert "Ann" in out and "Bob" in out

def test_yaml_dispatcher():
    out = Dispatcher().export("yaml", [{"id": 1, "name": "Ann"}])
    assert out.startswith("---")
EOF
  git add -A && git commit -qm "feature: add yaml exporter as a fourth copy"
  )
}
