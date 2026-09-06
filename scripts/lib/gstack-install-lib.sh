#!/usr/bin/env bash
# gstack install state machine, used by ./setup.
#
# Goal: a REAL clone of github.com/garrytan/gstack ends up at $GSTACK_DIR, and
# the markdown-only vendor snapshot (vendor/gstack) is only ever a stopgap.
#
#   state     meaning                                   what ensure() does
#   -------   ---------------------------------------   ------------------------------
#   real      .git present, VERSION present             leave it alone
#   vendor    installed from vendor/gstack (marker)     retry the real clone; promote
#   partial   directory exists but no VERSION           move it aside, clone fresh
#   absent    nothing there                             clone; else vendor copy
#
# Clones go into a sibling temp dir and are moved into place only on success,
# so a failed or interrupted clone never leaves a half-populated $GSTACK_DIR
# that would make every later run think gstack is installed.
#
# Pure-ish: everything is parameterised (dirs, URL, attempts, backoff, the
# `log` sink) so bats can drive it against a local bare repo with no network.

GSTACK_UPSTREAM_URL_DEFAULT="https://github.com/garrytan/gstack.git"
GSTACK_VENDOR_MARKER=".superskills-vendor-copy"

# Callers may define log(); default to stdout so the library works standalone.
if ! declare -F log >/dev/null 2>&1; then
    log() { echo "$@"; }
fi

# gstack_install_state <dir> → real | vendor | partial | absent
gstack_install_state() {
    local dir="$1"
    if [ ! -e "$dir" ]; then echo absent; return 0; fi
    if [ -f "$dir/VERSION" ]; then
        if [ -f "$dir/$GSTACK_VENDOR_MARKER" ] && [ ! -d "$dir/.git" ]; then echo vendor; else echo real; fi
        return 0
    fi
    echo partial
}

# gstack_run_own_setup <dir> — run gstack's bundled setup if present (never fatal).
gstack_run_own_setup() {
    local dir="$1"
    [ -x "$dir/setup" ] || return 0
    (cd "$dir" && ./setup -q --no-prefix >/dev/null 2>&1) || {
        log "  [warn] gstack's own setup failed — skills may need manual activation"
    }
    return 0
}

# gstack_clone <dir> <url> — shallow clone into a sibling temp dir, then move
# into place. Retries GSTACK_CLONE_ATTEMPTS times (default 3) with
# GSTACK_CLONE_BACKOFF seconds between tries (default 2). Returns 1 on failure
# with nothing left behind.
gstack_clone() {
    local dir="$1" url="$2"
    local attempts="${GSTACK_CLONE_ATTEMPTS:-3}" backoff="${GSTACK_CLONE_BACKOFF:-2}"
    local tmp="${dir}.clone-$$" i
    mkdir -p "$(dirname "$dir")"
    for ((i = 1; i <= attempts; i++)); do
        rm -rf "$tmp"
        if git clone --single-branch --depth 1 --quiet "$url" "$tmp" 2>/dev/null; then
            mv "$tmp" "$dir"
            return 0
        fi
        log "  [warn] gstack clone failed (attempt $i/$attempts)"
        [ "$i" -lt "$attempts" ] && sleep "$backoff"
    done
    rm -rf "$tmp"
    return 1
}

# gstack_install_from_vendor <vendor_dir> <dir> — copy the snapshot into place
# and mark it so the next run knows to try the real clone again.
gstack_install_from_vendor() {
    local vendor="$1" dir="$2"
    [ -d "$vendor" ] || return 1
    mkdir -p "$(dirname "$dir")"
    rm -rf "$dir"
    cp -R "$vendor" "$dir"
    touch "$dir/$GSTACK_VENDOR_MARKER"
    return 0
}

# gstack_ensure <dir> <vendor_dir> [url] — drive the state machine. Exit 0 when
# gstack is usable (real or vendor), 1 when nothing could be installed.
gstack_ensure() {
    local dir="$1" vendor="$2" url="${3:-$GSTACK_UPSTREAM_URL_DEFAULT}"
    local state
    state="$(gstack_install_state "$dir")"

    case "$state" in
        real)
            log "  [ok] gstack already installed ($(cat "$dir/VERSION" 2>/dev/null))"
            return 0 ;;
        partial)
            local aside="${dir}.broken-$(date +%Y%m%d%H%M%S)"
            mv "$dir" "$aside"
            log "  [warn] gstack dir had no VERSION — moved aside to $aside" ;;
        vendor)
            log "  [install] gstack is on the vendor copy ($(cat "$dir/VERSION" 2>/dev/null)) — trying the real clone again" ;;
        absent)
            log "  [install] gstack (Garry Tan) — virtual engineering team skills" ;;
    esac

    local staging="${dir}.clone-target"
    rm -rf "$staging"
    if gstack_clone "$staging" "$url"; then
        if [ "$state" = "vendor" ]; then
            rm -rf "$dir"
            log "  [ok] gstack cloned — promoted from vendor copy to a real install"
        else
            log "  [ok] gstack cloned"
        fi
        mv "$staging" "$dir"
        gstack_run_own_setup "$dir"
        log "  [ok] gstack installed ($(cat "$dir/VERSION" 2>/dev/null))"
        return 0
    fi

    rm -rf "$staging"
    if [ "$state" = "vendor" ]; then
        log "  [warn] gstack clone still failing — still on the vendor copy; browser skills (/qa, /browse) need the real clone. Re-run ./setup when online."
        return 0
    fi
    if gstack_install_from_vendor "$vendor" "$dir"; then
        gstack_run_own_setup "$dir"
        log "  [warn] gstack clone failed — installed the vendor copy ($(cat "$dir/VERSION" 2>/dev/null)) as a stopgap."
        log "         Browser skills (/qa, /browse) need the real clone; ./setup retries it on every run."
        return 0
    fi
    log "  [error] gstack not installed — clone failed and no vendor copy at $vendor"
    log "          Manual install: git clone $url $dir && cd $dir && ./setup"
    return 1
}
