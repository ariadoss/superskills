"""Rule table for vet_scan. Each rule is a function: {relative path: text} -> list of findings.
A finding is {"rule", "severity", "path", "line", "snippet", "note"}.
Rules only inspect text; they never execute or import it."""
import json
import re

MAX_LINE = 4_096
_EOL = re.compile(r"\r\n|\r|\n")

# Invisible characters, as a regex character-class body (zero-width joiner U+200D handled apart).
# vet_scan.py reuses this to escape the same characters in quoted snippets.
INVISIBLE = (
    "\u00ad\u034f\u061c\u180e\u200b\u200c\u200e\u200f\u202a-\u202e\u2060-\u2064\u2066-\u206f"
    "\u2800\u3164\ufe00-\ufe0f\ufeff\U000e0000-\U000e007f\U000e0100-\U000e01ef"
)


# Characters str.splitlines treats as breaks but an editor and a reader treat as plain whitespace.
_SEPARATORS = re.compile("[\x0b\x0c\x1c-\x1e\x85\u2028\u2029]")


def variants(line):
    """The line as written, with separators read as spaces, and with them deleted (a word split by one)."""
    if not _SEPARATORS.search(line):
        return (line,)
    return (line, _SEPARATORS.sub(" ", line), _SEPARATORS.sub("", line))


def split_lines(text):
    """Split on LF, CRLF or CR only, as an editor numbers lines. str.splitlines also splits on
    \\x0b, \\x0c, \\x1c-\\x1e, \\x85, U+2028 and U+2029, which a reader treats as plain spaces."""
    return _EOL.split(text)


def iter_lines(texts, globs=None):
    """Yield (path, line number, line) for each line to examine; lines over MAX_LINE are left to VS010."""
    for path, text in texts.items():
        if globs and not any(path.endswith(g) for g in globs):
            continue
        for n, line in enumerate(split_lines(text), 1):
            if len(line) <= MAX_LINE:
                yield path, n, line


def _finding(rule_id, severity, path, n, line, note):
    return {"rule": rule_id, "severity": severity, "path": path, "line": n,
            "snippet": line.strip(), "note": note}


def line_rule(rule_id, severity, pattern, note, globs=None):
    """Build a rule that flags each line matching `pattern` (case-insensitive) in files matching `globs`."""
    rx = re.compile(pattern, re.I)

    def run(texts):
        return [_finding(rule_id, severity, path, n, line, note)
                for path, n, line in iter_lines(texts, globs)
                if any(rx.search(v) for v in variants(line))]
    return run


def long_line_rule(texts):
    """VS010: a line over 4 KB is not examined by the line rules, so a payload can hide there. Say so."""
    return [{"rule": "VS010", "severity": "medium", "path": p, "line": n, "snippet": l[:160],
             "note": "line over 4096 characters: not examined by the other rules, read it by hand"}
            for p, t in texts.items() for n, l in enumerate(split_lines(t), 1) if len(l) > MAX_LINE]


steering_rule = line_rule(
    "VS001", "high",
    r"(ignore|disregard|forget).{0,30}(previous|prior|above).{0,20}(instruction|rule)"
    r"|\b(ai|llm|claude|model|agent|assistant)\s+(reviewer|scanner|auditor)\b"
    r"|(do not|don't|never)\s+(tell|mention|report|reveal|disclose).{0,30}(user|reviewer|this)"
    r"|report that (this|it) (is|has)\b.{0,30}(safe|no (issues|vulnerabilit))"
    r"|<IMPORTANT>|<system>|\[SYSTEM\]",
    "text that addresses the reviewer or hides instructions from the user")

_invisible = line_rule(
    "VS002", "high",
    "[" + INVISIBLE.replace("\ufe00-\ufe0f", "\ufe00-\ufe0e") + "]"
    "|(?<![^\\x00-\\x7f])\u200d|\u200d(?![^\\x00-\\x7f])"
    # One emoji variation selector (U+FE0F) is fine after a visible non-ASCII symbol.
    "|(?<![^\\x00-\\x7f\u200d" + INVISIBLE + "])\ufe0f|\ufe0f(?=[\ufe00-\ufe0f\U000e0100-\U000e01ef])",
    "invisible or bidirectional-control character: the text a reviewer sees is not the text that runs")


def invisible_rule(texts):
    """VS002, ignoring a single byte-order mark at the very start of a file."""
    return _invisible({p: (t[1:] if t.startswith("﻿") else t) for p, t in texts.items()})


obfuscation_rule = line_rule(
    "VS003", "medium",
    r"[A-Za-z0-9+/=]{200,}"
    r"|\b(eval|exec)\s*\(.{0,40}(b64decode|decode|fromhex|atob|decompress)"
    r"|String\.fromCharCode\(([^)]*,){8,}"
    r"|\\x[0-9a-f]{2}(\\x[0-9a-f]{2}){20,}",
    "encoded or obfuscated payload")

pipe_to_shell_rule = line_rule(
    "VS004", "high",
    r"\b(curl|wget|fetch)\b[^|\n]*\|\s*(sudo\s+)?(ba|z|da)?sh\b|\|\s*python3?\b"
    r"|\b(iex|Invoke-Expression)\b.{0,40}(iwr|Invoke-WebRequest|DownloadString)",
    "downloads code and runs it unread")


# --- VS005: install-time and session-start execution, judged from the file's structure ---

_LIFECYCLE = {"preinstall", "install", "postinstall", "prepare"}
_LIFECYCLE_LINE = re.compile(r'"(preinstall|install|postinstall|prepare)"\s*:', re.I)
_HOOK_LINE = re.compile(r'"type"\s*:\s*"command"', re.I)
_HOOK_FILES = {"hooks.json", "settings.json", "plugin.json"}


class _Pairs(list):
    """A JSON object kept as (key, value) pairs, so a duplicated key cannot hide the first one."""


def _parse_json(text):
    try:
        return json.loads(text.lstrip("\ufeff"), object_pairs_hook=_Pairs)
    except (ValueError, RecursionError):
        return None


def _json_pairs(root):
    """Yield (parent key, key, value) for every object member, without recursion."""
    stack = [(root, None)]
    while stack:
        node, parent = stack.pop()
        if isinstance(node, _Pairs):
            for key, value in node:
                yield parent, key, value
                stack.append((value, key))
        elif isinstance(node, list):
            stack.extend((item, parent) for item in node)


def _install_hits(name, text):
    """Count of structural hits when `text` parses as JSON, else None."""
    root = _parse_json(text)
    if root is None:
        return None
    hits = 0
    for parent, key, value in _json_pairs(root):
        k = str(key).lower()
        if name == "package.json":
            hits += parent is not None and parent.lower() == "scripts" and k in _LIFECYCLE
        else:
            hits += k == "type" and isinstance(value, str) and value.lower() == "command"
    return hits


def install_hook_rule(texts):
    """VS005: npm lifecycle scripts in package.json, command hooks in hooks/settings/plugin json.
    Parsed as text (never executed); a file that is not valid JSON falls back to a line match."""
    out = []
    for path, text in texts.items():
        name = path.rsplit("/", 1)[-1].lower()
        if name == "package.json":
            rx, note = _LIFECYCLE_LINE, "npm lifecycle script: runs code when the package is installed"
        elif name in _HOOK_FILES:
            rx, note = _HOOK_LINE, "command hook: runs a shell command on a session or tool event"
        else:
            continue
        lines = split_lines(text)
        candidates = [(n, l) for n, l in enumerate(lines, 1) if any(rx.search(v) for v in variants(l))]
        hits = _install_hits(name, text)
        if hits is None:  # malformed JSON: judge by line, long lines are VS010's
            found = [(n, l) for n, l in candidates if len(l) <= MAX_LINE]
        else:
            found = [candidates[min(i, len(candidates) - 1)] if candidates else (1, lines[0])
                     for i in range(hits)]
        out += [_finding("VS005", "medium", path, n, l, note) for n, l in found]
    return out


# --- VS006: launchers and dependencies that fetch whatever is newest ---

_LAUNCHER = re.compile(r"\b(npx|uvx|pipx\s+run|bunx)\b", re.I)
_JSON_KEY = re.compile(r'"[^"\\]{0,60}"\s*:')
_TOKEN_SPLIT = re.compile(r"""[\s",\[\]'`]+""")
_PINNED = re.compile(r".@v?\d|===?\d")
_GIT_URL = re.compile(r"git\+https?://[^\s\"'<>,)]+", re.I)
_GIT_PINNED = re.compile(r"@\S|#(?!egg=|subdirectory=)\S")


def _unpinned_launcher(line):
    """True when a launcher on the line is followed by a package without a version pin."""
    for m in _LAUNCHER.finditer(line):
        rest = _JSON_KEY.sub(" ", line[m.end():m.end() + 400])
        for tok in _TOKEN_SPLIT.split(rest):
            if not tok or tok.startswith("-") or tok == ":":
                continue
            if not tok.startswith((".", "/", "~")) and not _PINNED.search(tok):
                return True
            break
    return False


def _unpinned_git(line):
    for m in _GIT_URL.finditer(line):
        path = m.group(0).split("//", 1)[1].partition("/")[2]
        if not _GIT_PINNED.search(path):
            return True
    return False


def unpinned_rule(texts):
    """VS006: npx/uvx/pipx run/bunx of an unpinned package, or a git+https dependency with no revision."""
    out = []
    for path, n, line in iter_lines(texts):
        for v in variants(line):
            if _unpinned_launcher(v):
                note = "launcher runs an unpinned package: whatever is newest runs, with your privileges"
            elif _unpinned_git(v):
                note = "git dependency without a pinned revision: whatever is on the branch is installed"
            else:
                continue
            out.append(_finding("VS006", "medium", path, n, line, note))
            break
    return out


# --- VS007-VS009: what the code does with your machine ---

_SENSITIVE = re.compile(
    r"~/\.(ssh|aws|claude|config/gcloud)|\.env\b|os\.environ(?!\.get\()|/\.claude/projects|id_rsa|credentials\.json",
    re.I)
_OUTBOUND = re.compile(
    r"\brequests\.(post|put)|urllib\.request\.urlopen|\bfetch\(|\bhttpx\.(post|put)"
    r"|\bsocket\.connect|XMLHttpRequest", re.I)
# curl is judged per line as two separate linear searches (the command, then a standalone data flag),
# so no distance between them can be used as padding and nothing backtracks across the line.
_CURL = re.compile(r"\bcurl\b", re.I)
_CURL_FLAG = re.compile(r"(?<![\w-])(-d|--data[\w-]*|-F|-T|--form[\w-]*|--upload-file)(?![\w-])")


def _outbound(text):
    if _OUTBOUND.search(text):
        return True
    if not _CURL.search(text):
        return False
    return any(_CURL.search(l) and _CURL_FLAG.search(l) for l in split_lines(text))


def exfil_rule(texts):
    """VS007: one file that both reads a sensitive source and makes an outbound upload-style call.
    Each half is looked for in the text as written and with separators read as spaces or deleted."""
    out = []
    for path, text in texts.items():
        vs = variants(text)
        if not (any(_SENSITIVE.search(v) for v in vs) and any(_outbound(v) for v in vs)):
            continue
        lines = split_lines(text)
        n = next((i for i, l in enumerate(lines, 1)
                  if any(_SENSITIVE.search(v) for v in variants(l))), 1)
        out.append(_finding("VS007", "high", path, n, lines[n - 1][:160],
                            "reads a sensitive source and makes an outbound call in the same file"))
    return out


_WIDE_BIND = re.compile(
    r"""(host\s*=|listen\()\s*["']?(0\.0\.0\.0\b|::(?![\w:]))|bind\(\s*\(?["']0\.0\.0\.0""", re.I)
_AUTH_WORD = re.compile(r"token|api[_-]?key|authorization|bearer|password|auth", re.I)


def wide_bind_rule(texts):
    """VS008: binds to every interface. High when the file never mentions an auth word, else medium."""
    out = []
    for path, text in texts.items():
        severity = None
        for p, n, line in iter_lines({path: text}):
            if any(_WIDE_BIND.search(v) for v in variants(line)):
                severity = severity or ("medium" if _AUTH_WORD.search(text) else "high")
                out.append(_finding("VS008", severity, p, n, line,
                                    "listens on every network interface, not just this machine"))
    return out


_SHELL_ALWAYS = re.compile(r"shell\s*=\s*True|os\.popen\(|\beval\(", re.I)
_SHELL_NEEDS_MARKER = re.compile(r"os\.system\(|child_process\.exec\(", re.I)
_INTERPOLATION = re.compile(r"\b[rb]?f[\"']|\+|%s|\$\{|\.format\(", re.I)


def shell_exec_rule(texts):
    """VS009: shell execution. os.system and child_process.exec count only with an interpolated command."""
    out = []
    for path, n, line in iter_lines(texts):
        for v in variants(line):
            if _SHELL_ALWAYS.search(v) or (_SHELL_NEEDS_MARKER.search(v) and _INTERPOLATION.search(v)):
                out.append(_finding("VS009", "medium", path, n, line,
                                    "runs a shell command or evaluates a string: check what feeds it"))
                break
    return out


RULES = [steering_rule, invisible_rule, obfuscation_rule, long_line_rule,
         pipe_to_shell_rule, install_hook_rule, unpinned_rule,
         exfil_rule, wide_bind_rule, shell_exec_rule]
FLOORS = {"VS001": "block", "VS002": "block", "VS003": "caution", "VS010": "caution",
          "VS004": "block", "VS005": "caution", "VS006": "caution",
          "VS007": "block", "VS008": "caution", "VS009": "caution"}
