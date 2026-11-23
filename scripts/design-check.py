#!/usr/bin/env python3
"""Score an HTML file on binary design-quality checks.

usage: design-check.py FILE [--build] [--json]
Prints "passed/applicable" and the failed check names. --build adds the
documented-direction check. Deterministic: same file, same score.
"""
import json
import re
import sys

EMOJI = re.compile("[\U0001F300-\U0001FAFF☀-➿⭐✅❌]")
DEFAULT_FONTS = ("inter", "roboto", "arial", "fraunces", "playfair display", "helvetica", "system-ui")
SERIF = ("georgia", "playfair", "fraunces", "serif")


def hex_colors(css):
    out = []
    for h in re.findall(r"#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b", css):
        if len(h) == 3:
            h = "".join(c * 2 for c in h)
        out.append(tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)))
    return out


def is_cream(c):
    r, g, b = c
    return r >= 0xF0 and g >= 0xE8 and 0xD0 <= b <= 0xEC and r - b >= 16


def is_terracotta(c):
    r, g, b = c
    return r >= 0xC0 and 0x50 <= g <= 0xA8 and b <= 0x78 and r - g >= 40


def first_fonts(css):
    return [m.split(",")[0].strip().strip("'\"").lower()
            for m in re.findall(r"font-family\s*:\s*([^;}]+)", css, re.I)]


def spacing_values(css):
    vals = []
    for prop in re.findall(r"(?:^|[;{\s])(?:padding|margin|gap|row-gap|column-gap)(?:-[a-z]+)?\s*:\s*([^;}]+)", css, re.I):
        vals += [int(float(v)) for v in re.findall(r"(-?\d+(?:\.\d+)?)px", prop)]
    return vals


def checks(html, build):
    low = html.lower()
    css = " ".join(re.findall(r"<style[^>]*>(.*?)</style>", html, re.S | re.I)) + " " + \
        " ".join(re.findall(r'style="([^"]*)"', html, re.I))
    lcss = css.lower()
    grads = re.findall(r"(?:linear|radial|conic)-gradient\(([^;]*)\)", lcss)
    bad_grad = any(
        len(re.findall(r"#[0-9a-f]{3,6}\b|rgba?\(|hsla?\(|oklch\(", g)) > 2
        or re.search(r"purple|violet|pink|magenta|#(?:8b5cf6|a855f7|ec4899|7c3aed|c026d3|9333ea)", g)
        for g in grads)
    white_bg = re.search(r"background(?:-color)?\s*:\s*(?:#fff\b|#ffffff\b|white\b)", lcss)
    black_fg = re.search(r"(?<![-\w])color\s*:\s*(?:#000\b|#000000\b|black\b)", lcss)
    fonts = first_fonts(lcss)
    colors = hex_colors(css)
    has_serif_display = any(any(s in f for s in SERIF) for f in fonts)
    off = [v for v in spacing_values(lcss) if v % 4 != 0 and abs(v) > 2]
    animated = re.search(r"transition|animation|@keyframes", lcss)
    result = {
        "no-bad-gradient": not bad_grad,
        "no-emoji": not EMOJI.search(html),
        "no-left-border-card": not re.search(r"border-left\s*:\s*[3-9]px\s+solid", lcss),
        "no-pure-white-on-black": not (white_bg and black_fg),
        "spacing-on-scale": not off,
        "no-default-font": not any(f in DEFAULT_FONTS for f in fonts),
        "no-cream-serif-terracotta": not (any(map(is_cream, colors)) and has_serif_display
                                          and any(map(is_terracotta, colors))),
        "has-hover": ":hover" in lcss,
        "has-focus-visible": ":focus-visible" in lcss and not re.search(r"outline\s*:\s*(?:none|0)\b(?![^}]*(?:box-shadow|border))", lcss),
        "has-disabled-state": ":disabled" in lcss or "[disabled]" in lcss or "aria-disabled" in lcss,
        "reduced-motion": (not animated) or "prefers-reduced-motion" in lcss,
        "semantic-and-lang": bool(re.search(r"<html[^>]*\blang=", low)) and not re.search(r"<div[^>]*onclick", low)
        and not re.search(r"<img(?![^>]*\balt=)", low),
    }
    if build:
        result["documents-direction"] = bool(re.search(r"<!--[^>]*(direction|palette|tokens)|/\*[^*]*(direction|palette|tokens)", low))
    return result


def main(argv):
    path = next((a for a in argv[1:] if not a.startswith("--")), None)
    if not path:
        print(__doc__)
        return 2
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            html = fh.read()
    except OSError as err:
        print(f"design-check: cannot read {path}: {err.strerror}", file=sys.stderr)
        return 2
    res = checks(html, "--build" in argv)
    passed = sum(res.values())
    if "--json" in argv:
        print(json.dumps({"passed": passed, "total": len(res), "checks": res}))
    else:
        print(f"{passed}/{len(res)}")
        for k, v in res.items():
            if not v:
                print(f"FAIL {k}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
