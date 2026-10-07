# export-lib.sh — the shared source-overlap guard for the pure-copy export
# scripts (export-humanize.sh, export-eval.sh, export-dbmap.sh).
#
# Sourced, never executed. The caller sets SRC_ROOT (repo root) and OUT
# (already resolved to an absolute physical path, and already created) and
# then calls export_refuse_source_overlap, which exits 1 with a refusal
# message when OUT overlaps the source tree in either direction.

export_refuse_source_overlap() {
  # The export deletes and rewrites its owned paths under OUT, so OUT must
  # not overlap the source: not the repo itself, not a directory that
  # contains it, and not anywhere inside it except under dist/.
  local root
  root="$(cd "$SRC_ROOT" && pwd -P)"
  case "$OUT/" in
    "$root/dist/"*) ;;
    "$root/"*) echo "refusing to export into the source tree: $OUT (use a path under $root/dist/ or outside the repo)" >&2; return 1 ;;
  esac
  case "$root/" in
    "${OUT%/}/"*) echo "refusing to export into $OUT: it contains the source tree" >&2; return 1 ;;
  esac
}
