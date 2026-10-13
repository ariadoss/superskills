"""userfacing.py: which files hold user-facing copy, and which lines of them are prose.

    python3 userfacing.py classify PATH   # markdown|text|html|template|locale|source|none
    python3 userfacing.py extract  PATH   # visible copy, one output line per source line

User-facing means words real people read: READMEs and documentation, blog posts,
marketing pages, help text, locale strings, UI labels, and the pages or files that
code generates for people to read. Code logic, code comments, prompts, agent
instructions, tests and generated or vendored trees are out of scope.

Classification is language-agnostic: a deny-list on the path first (so it holds in
any repo), then a content type by extension. Code files (Go, Rust, PHP, Python,
Node, TypeScript, Ruby, Java, Kotlin, Swift, C#, ...) count only when the file
visibly renders pages or writes files people read; their string literals are then
scanned, comments and log/error text excluded. `extract` blanks everything that is
not copy but keeps line numbers, so a scanner's line numbers are the source's.
"""
import html
import json
import os
import re
import subprocess
import sys
from html.parser import HTMLParser
from pathlib import PurePosixPath

# Never scanned, README included: vendored, built, cached or generated trees.
GENERATED_DIRS = {
    "node_modules", "vendor", "_vendor", "third_party", "dist", "build", "out", "target",
    "coverage", "__pycache__", ".git", ".next", ".nuxt", ".svelte-kit", ".output", ".turbo",
    ".cache", "_site", ".venv", "venv", "site-packages", "pods", "carthage", ".gradle",
    ".terraform", ".dart_tool", "deriveddata", ".idea", ".vscode", "generated", "__generated__",
    "migrations", "htmlcov", "storybook-static", "playwright-report", ".docusaurus",
    ".nyc_output", "test-results",
}
# Agent instructions, prompts and tests: not copy, except a README that explains them.
INSTRUCTION_DIRS = {
    "evals", "eval", "tests", "test", "__tests__", "fixtures", "__fixtures__",
    "__mocks__", "mocks", "prompts", "prompt", "skills", "marketing-skills", "design-skills",
    "agents", ".claude", ".codex", ".cursor", ".github",
}
DENY_NAMES = {
    "skill.md", "claude.md", "agents.md", "gemini.md", ".cursorrules", "package-lock.json",
    "yarn.lock", "pnpm-lock.yaml", "cargo.lock", "composer.lock", "go.sum", "poetry.lock",
    "gemfile.lock", "conftest.py", "robots.txt", "cmakelists.txt",
}
DENY_NAME_RES = [re.compile(p, re.I) for p in (
    # prompt files (prompt.md, system_prompt.txt, x.prompt.md), not guides ABOUT prompts
    r"^(system[-_]?)?prompts?\.[a-z0-9]+$", r"\.prompt\.[a-z0-9]+$",
    r"^(license|licence|copying|notice)(\.|$)",
    # agent-to-agent bridge notes written by /handoff and /quota-resilience
    r"^handoff-([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f-]{20,}|\d{8}t\d{6}z-\d+)\.md$", r"^quota-resume\.md$",
    r"\.min\.", r"\.lock$", r"\.d\.ts$", r"\.config\.", r"\.generated\.", r"_generated\.",
    r"\.pb\.go$", r"_test\.(go|py|rs|rb|exs?)$", r"\.(test|spec)\.[cm]?[jt]sx?$",
    r"^test_.*\.py$", r"_spec\.rb$", r"^(requirements|constraints)[\w.-]*\.txt$",
)] + [re.compile(r"[a-z0-9]Test\.(php|java|kt|cs)$")]

TEMPLATE_SUFFIXES = (
    ".blade.php", ".html.erb", ".html.tmpl", ".phtml", ".gohtml", ".gotmpl", ".tmpl", ".tpl",
    ".njk", ".nunjucks", ".liquid", ".hbs", ".handlebars", ".mustache", ".ejs", ".erb",
    ".twig", ".jinja", ".jinja2", ".j2", ".latte", ".cshtml",
)
BY_EXT = {
    ".md": "markdown", ".mdx": "markdown", ".markdown": "markdown", ".mdown": "markdown",
    ".txt": "text", ".rst": "text", ".adoc": "text", ".asciidoc": "text",
    ".html": "html", ".htm": "html", ".xhtml": "html",
    ".json": "locale", ".yaml": "locale", ".yml": "locale", ".arb": "locale",
    ".po": "locale", ".pot": "locale", ".properties": "locale", ".strings": "locale",
    ".jsx": "source", ".tsx": "source", ".vue": "source", ".svelte": "source", ".astro": "source",
}
CODE_EXTS = {".py", ".rb", ".go", ".rs", ".php", ".js", ".mjs", ".cjs", ".ts", ".mts",
             ".java", ".kt", ".swift", ".cs", ".dart", ".scala"}
LOCALE_DIRS = {"locales", "locale", "i18n", "l10n", "lang", "langs", "languages", "translations",
               "messages", "copy", "strings", "intl", "dictionaries"}
LOCALE_NAME = re.compile(
    r"^([a-z]{2,3}([-_][a-z]{2,4})?|messages|translations?|strings|copy)(\.[\w-]+)?\.(json|ya?ml)$", re.I)
# A code file is copy only if it visibly renders pages or writes files people read.
OUTPUT_SIGNAL = re.compile(r"""
    <\s*/?\s*(?:html|body|head|title|h[1-6]|p|div|section|article|header|footer|nav|main|ul|ol|li
               |table|tr|td|span|a|img|form|button|meta|br)\b[^>]*>
  | \b(?:file_put_contents|fwrite|fputs|writeFile|writeFileSync|appendFile|appendFileSync|WriteFile
        |write_text|write_bytes|render_template|render_to_string|TemplateResponse|html/template
        |text/template|askama|maud|minijinja|handlebars|liquid|mustache|nunjucks|jinja2|HttpResponse)\b
  | \bos\.(?:Create|WriteFile)\b | \bFile::create\b | \bfs::write\b | \bFiles\.write\b
  | \bopen\s*\([^)]*['"][wa]b?\+?['"]
  | \bres\.(?:send|render|write|end)\b | \bresponse\.(?:write|send|html)\b | \bw\.Write\b
  | \bfmt\.Fprint\w*\(\s*w\b | \btemplate\.(?:Execute|Must|New|ParseFiles|ParseGlob)\b
""", re.X)
_CODE_TEMPLATE = re.compile(r"\.(js|css|json|rb|ya?ml|sh|csv|svg|sql)\.(erb|ejs|j2|jinja2?|tmpl|tpl|hbs|liquid|twig)$")
MAX_BYTES = 512_000  # a user-facing page beyond this is data or a bundle, and scanning it must stay bounded
MIN_LITERAL_WORDS = 4
_SQL = re.compile(r"^\s*(select|insert|update|delete|create|alter|drop|with|order|group|where|from|on|and|or|set|values|join|left|inner|limit|having|union)\b\s+\w", re.I)


def repo_relative(path: str) -> str:
    """Deny-list directories must match inside the repo, never above it (a checkout under
    /tmp/test/ is not a test tree). Absolute paths are made relative to cwd or to the
    file's git toplevel; anything else is used as given."""
    if not os.path.isabs(path):
        return path
    try:
        cwd = os.getcwd()
    except OSError:
        cwd = None
    # Compare real paths: /var/... and /private/var/... name one directory on macOS.
    path = os.path.join(os.path.realpath(os.path.dirname(path)), os.path.basename(path))
    for base in (cwd, _git_toplevel(path)):
        if base:
            base = os.path.realpath(base)
            if os.path.commonpath([base, path]) == base:
                return os.path.relpath(path, base)
    return path


def _git_toplevel(path: str):
    try:
        r = subprocess.run(["git", "-C", os.path.dirname(path) or ".", "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return None
    return r.stdout.strip() if r.returncode == 0 and r.stdout.strip() else None


def classify(path: str, raw=None) -> str:
    """The content type, or "none". Code files need `raw` to show output signals."""
    p = PurePosixPath(repo_relative(path).replace("\\", "/"))
    parts = [s.lower() for s in p.parts]
    dirs, name = parts[:-1], (parts[-1] if parts else "")
    if any(d in GENERATED_DIRS for d in dirs):
        return "none"
    if name.startswith(".") or name in DENY_NAMES or any(r.search(p.name) for r in DENY_NAME_RES):
        return "none"
    if name.startswith("readme") and BY_EXT.get(p.suffix.lower()) in ("markdown", "text"):
        return BY_EXT[p.suffix.lower()]
    if any(d in INSTRUCTION_DIRS for d in dirs):
        return "none"
    if name.endswith(TEMPLATE_SUFFIXES):
        # a .js.erb or .css.j2 renders code, not copy; .html.erb and .text.erb render copy
        return "none" if _CODE_TEMPLATE.search(name) else "template"
    ext = p.suffix.lower()
    kind = BY_EXT.get(ext)
    if kind == "locale":
        if ext in (".json", ".yaml", ".yml"):
            if not (any(d in LOCALE_DIRS for d in dirs) or LOCALE_NAME.match(p.name)):
                return "none"
        return "locale"
    if kind:
        return kind
    if ext in CODE_EXTS and raw is not None and _renders_output(raw, ext):
        return "source"
    return "none"


def classify_file(path: str) -> str:
    """classify() plus the on-disk guards: symlinks and oversized files are never copy."""
    try:
        if os.path.islink(path) or os.path.getsize(path) > MAX_BYTES:
            return "none"
    except OSError:
        pass
    kind = classify(path)
    if kind != "none" or os.path.splitext(path)[1].lower() not in CODE_EXTS:
        return kind
    try:
        with open(path, encoding="utf-8") as fh:
            return classify(path, fh.read())
    except (OSError, UnicodeDecodeError):
        return "none"


def _renders_output(raw: str, ext: str) -> bool:
    """Output signals count only in code, never in comments, and `echo` only in PHP."""
    prefixes = ("#",) if ext in (".py", ".rb") else ("//", "/*", "*", "#") if ext == ".php" else ("//", "/*", "*")
    code = "\n".join(l for l in raw.split("\n") if not l.lstrip().startswith(prefixes))
    if OUTPUT_SIGNAL.search(code):
        return True
    return ext == ".php" and re.search(r"\becho\b", code) is not None


# ---- shared helpers -------------------------------------------------------------------

_INLINE_CODE = re.compile(r"`[^`]*`")
_LINK_TARGET = re.compile(r"\(https?://[^)]*\)")
FRONT_COPY_KEYS = ("title", "description", "summary", "excerpt", "subtitle", "tagline",
                   "headline", "lead", "intro", "caption", "abstract", "heading")
_FRONT_LINE = re.compile(r"^\s*(%s)\s*[:=]\s*(.+?)\s*$" % "|".join(FRONT_COPY_KEYS), re.I)


def _plain_prose(line: str) -> str:
    return _LINK_TARGET.sub("", _INLINE_CODE.sub("", line))


def _blank(s: str) -> str:
    return "\n" * s.count("\n")


def _by_line(n_lines: int, found: list) -> list:
    out = [""] * n_lines
    for lineno, text in found:
        if 1 <= lineno <= n_lines and text:
            out[lineno - 1] = (out[lineno - 1] + " " + text).strip()
    return out


def _sentence_like(s: str) -> bool:
    words = [w for w in s.split() if re.search(r"[A-Za-z]", w)]
    if len(words) < MIN_LITERAL_WORDS or not re.search(r"[A-Za-z]{2}", s):
        return False
    if sum(1 for w in words if len(w) > 1 and w.isupper()) * 2 >= len(words):
        return False  # SQL keywords, constants, shouted status codes
    if re.search(r"[=;{}()<>\\|]|https?://|\$\{|::|->|=>", s) or _SQL.match(s):
        return False
    if sum(1 for w in words if re.search(r"[-:\[\]/_.]\w|^[./]", w)) * 2 >= len(words):
        return False
    return s[0].isupper() or s.rstrip()[-1] in ".!?…:"


_PLACEHOLDERS = re.compile(
    r"\$\{[^}]*\}|\{\{[^}]*\}\}|\{[\w.:\[\]'\" -]*\}|%[-+ #0-9.]*[sdifvqxXeEgGTc@]|\$\w+|<\?.*?\?>")


def _fragment(piece: str) -> str:
    t = re.sub(r"\\[nrt]", " ", piece).replace('\\"', '"').replace("\\'", "'")
    t = _PLACEHOLDERS.sub("", t)
    t = re.sub(r"<[^>]*>", " ", t)
    return re.sub(r"\s+", " ", html.unescape(t)).strip()


# ---- markdown / text ------------------------------------------------------------------

def extract_markdown(raw: str, mdx: bool = False) -> list:
    out, fence, front, in_comment = [], None, None, False
    for i, line in enumerate(raw.split("\n")):
        s = line.strip()
        if i == 0 and s in ("---", "+++"):
            front = s
            out.append("")
            continue
        if front:
            if s in (front, "..."):
                front = None
                out.append("")
                continue
            m = _FRONT_LINE.match(line)
            out.append(m.group(2).strip("\"'") if m else "")
            continue
        if fence:
            if s.startswith(fence):
                fence = None
            out.append("")
            continue
        m = re.match(r"^(`{3,}|~{3,})", s)
        if m:
            fence = m.group(1)[:3]
            out.append("")
            continue
        if in_comment:
            if "-->" in s:
                in_comment = False
            out.append("")
            continue
        if s.startswith("<!--"):
            in_comment = "-->" not in s
            out.append("")
            continue
        if mdx and re.match(r"^(import|export)\s", s):
            out.append("")
            continue
        out.append(_plain_prose(line))
    return out


def extract_text(raw: str) -> list:
    return [_plain_prose(l) for l in raw.split("\n")]


# ---- html and template engines --------------------------------------------------------

class _Copy(HTMLParser):
    SKIP = {"script", "style", "code", "pre", "kbd", "samp", "template", "svg"}
    ATTRS = {"alt", "title", "placeholder", "aria-label"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.depth = 0
        self.found = []

    def handle_starttag(self, tag, attrs):
        if tag in self.SKIP:
            self.depth += 1
        d = dict(attrs)
        if self.depth == 0:
            for a in self.ATTRS:
                v = (d.get(a) or "").strip()
                if v and (" " in v or v[0].isupper()):  # skip identifiers like title="default"
                    self.found.append((self.getpos()[0], v))
            if tag == "meta" and (d.get("name") or "").lower() == "description" and d.get("content"):
                self.found.append((self.getpos()[0], d["content"]))

    def handle_endtag(self, tag):
        if tag in self.SKIP and self.depth:
            self.depth -= 1

    def handle_data(self, data):
        if self.depth:
            return
        start = self.getpos()[0]
        for k, piece in enumerate(data.split("\n")):
            if piece.strip():
                self.found.append((start + k, piece.strip()))


# Comments and embedded code blocks: dropped whole. Each alternative is bounded and only
# applied when its closer exists in the file, so an unterminated opener cannot scan to EOF
# once per occurrence.
_DROP_ALTS = (
    ("--}}", r"\{\{!--.{0,20000}?--\}\}"),
    ("--}}", r"\{\{--.{0,20000}?--\}\}"),
    ("#}", r"\{#.{0,20000}?#\}"),
    ("@endphp", r"@php.{0,20000}?@endphp"),
    ("endcomment", r"\{%-?\s*comment\s*-?%\}.{0,20000}?\{%-?\s*endcomment\s*-?%\}"),
    ("endschema", r"\{%-?\s*schema\s*-?%\}.{0,20000}?\{%-?\s*endschema\s*-?%\}"),
    ("endjavascript", r"\{%-?\s*javascript\s*-?%\}.{0,20000}?\{%-?\s*endjavascript\s*-?%\}"),
    ("endstylesheet", r"\{%-?\s*stylesheet\s*-?%\}.{0,20000}?\{%-?\s*endstylesheet\s*-?%\}"),
    ("endstyle", r"\{%-?\s*style\s*-?%\}.{0,20000}?\{%-?\s*endstyle\s*-?%\}"),
    ("endraw", r"\{%-?\s*raw\s*-?%\}.{0,20000}?\{%-?\s*endraw\s*-?%\}"),
)
# Output and logic tags: dropped, but a sentence-like quoted string inside (a translation
# call such as {{ __('Welcome back') }}) is copy and kept.
_TAG_ALTS = (
    ("}}}", r"\{\{\{.{0,2000}?\}\}\}"),
    ("}}", r"\{\{.{0,2000}?\}\}"),
    ("%}", r"\{%.{0,2000}?%\}"),
    ("!!}", r"\{!!.{0,2000}?!!\}"),
    ("%>", r"<%.{0,2000}?%>"),
    ("?>", r"<\?.{0,2000}?\?>"),
)
_DIRECTIVE = r"(?m:^[ \t]*@\w+(?:\([^\n]*\))?[ \t]*$)"


def _compile_for(raw: str, alts, extra=None):
    parts = [p for closer, p in alts if closer in raw]
    if extra:
        parts.append(extra)
    return re.compile("|".join(parts), re.S) if parts else None


_QUOTED = re.compile(r"\"((?:[^\"\\\n]|\\.)*)\"|'((?:[^'\\\n]|\\.)*)'")


def _template_text(raw: str):
    """(source with template syntax blanked but newlines kept, [(lineno, translated string)])."""
    drop = _compile_for(raw, _DROP_ALTS)
    stripped = drop.sub(lambda m: _blank(m.group()), raw) if drop else raw
    found = []

    def keep(m):
        line = stripped.count("\n", 0, m.start()) + 1
        for q in _QUOTED.finditer(m.group()):
            t = _fragment(q.group(1) if q.group(1) is not None else q.group(2))
            if _sentence_like(t):
                found.append((line + m.group().count("\n", 0, q.start()), t))
        return _blank(m.group())

    tags = _compile_for(stripped, _TAG_ALTS, _DIRECTIVE)
    return (tags.sub(keep, stripped) if tags else stripped), found


def extract_html(raw: str, braces: bool = False) -> list:
    body, found = _template_text(raw)
    if braces:
        body = re.sub(r"\{[^{}\n]*\}", " ", body)
    p = _Copy()
    p.feed(body)
    p.close()
    return _by_line(len(raw.split("\n")), p.found + found)


def extract_component(raw: str, ext: str) -> list:
    """.vue/.svelte/.astro: template markup is html; an astro `---` frontmatter is code."""
    if ext == ".astro" and raw.startswith("---"):
        end = raw.find("\n---", 3)
        if end != -1:
            raw = _blank(raw[: end + 4]) + raw[end + 4:]
    return extract_html(raw, braces=ext in (".svelte", ".astro"))


# ---- locale files ---------------------------------------------------------------------

_JSON_PAIR = re.compile(r'^\s*"(?:[^"\\]|\\.)*"\s*:\s*"((?:[^"\\]|\\.)*)"\s*,?\s*$')
_JSON_ITEM = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*,?\s*$')
_YAML_VAL = re.compile(r"""^\s*(?:-\s+)?(?:[\w.\-]+\s*:\s*)?(["'])(.*)\1\s*$|^\s*[\w.\-]+\s*:\s+([^#"'\[{|>&*!%@`][^#]*?)\s*$""")
_PO_LINE = re.compile(r'^\s*(?:msgid|msgstr)(?:\[\d+\])?\s+"(.*)"\s*$')
_PO_CONT = re.compile(r'^\s*"(.*)"\s*$')
_PROP = re.compile(r"^\s*[\w.\-\[\]]+\s*[=:]\s*(.+?)\s*$")
_STRINGS = re.compile(r'^\s*"(?:[^"\\]|\\.)*"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;')


def _unjson(s: str) -> str:
    try:
        return json.loads('"' + s + '"')
    except ValueError:
        return s


def extract_locale(raw: str, path: str) -> list:
    low = path.lower()
    out, in_po_value = [], False
    for line in raw.split("\n"):
        if low.endswith((".po", ".pot")):
            m = _PO_LINE.match(line)
            if m:
                in_po_value = True
                out.append(_unjson(m.group(1)))
                continue
            m = _PO_CONT.match(line) if in_po_value else None
            if m:
                out.append(_unjson(m.group(1)))
                continue
            in_po_value = False
            out.append("")
        elif low.endswith(".properties"):
            m = None if line.lstrip().startswith(("#", "!")) else _PROP.match(line)
            out.append(m.group(1) if m else "")
        elif low.endswith(".strings"):
            m = _STRINGS.match(line)
            out.append(_unjson(m.group(1)) if m else "")
        elif low.endswith((".yaml", ".yml")):
            m = _YAML_VAL.match(line)
            val = ((m.group(2) or m.group(3)) if m else "") or ""
            skip = re.fullmatch(r"-?[\d.]+|true|false|null|~", val.strip(), re.I)
            out.append("" if skip else val)
        else:
            m = _JSON_PAIR.match(line) or _JSON_ITEM.match(line)
            out.append(_unjson(m.group(1)) if m else "")
    return out


# ---- components (jsx/tsx) -------------------------------------------------------------

_LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"|\'((?:[^\'\\\n]|\\.)*)\'|`([^`\n]*)`')
_JSX_TEXT = re.compile(r">([^<>{}\n]+)<")
_SKIP_LINE = re.compile(r"^\s*(import\b|export\s+\*|from\b|require\(|console\.|logger\.|\}?\s*//|\*|/\*|\{/\*|<!--)")
_CODEY_ATTR = re.compile(r"\b(className|class|style|href|src|id|key|ref|type|name|data-[\w-]+|htmlFor)\s*=\s*$")


def extract_jsx(raw: str) -> list:
    out, in_block, prev = [], False, ""
    lines = raw.split("\n")
    for idx, line in enumerate(lines):
        s = line.strip()
        if in_block:
            if "*/" in s:
                in_block = False
            out.append("")
            continue
        if s.startswith("/*") or s.startswith("{/*"):
            in_block = "*/" not in s
            out.append("")
            continue
        if _SKIP_LINE.match(line):
            out.append("")
            continue
        code = re.sub(r"(?<=\s)//.*$", "", line)
        pieces = []
        for m in _JSX_TEXT.finditer(code):
            t = html.unescape(m.group(1)).strip()
            if _sentence_like(t) or (len(t.split()) >= 2 and t[0].isupper()):
                pieces.append(t)
        for m in _LITERAL.finditer(code):
            if _CODEY_ATTR.search(code[: m.start()]):
                continue
            t = next(g for g in m.groups() if g is not None)
            if _sentence_like(t):
                pieces.append(t)
        # a bare multi-line text node: a sentence between a closing '>' and the next tag
        if not pieces and s and prev.endswith(">") and _sentence_like(s):
            nxt = next((l.strip() for l in lines[idx + 1:] if l.strip()), "")
            if nxt.startswith(("<", "{")):
                pieces.append(s)
        out.append(" ".join(pieces))
        if s:
            prev = s
    return out


# ---- generator code (go, rust, php, python, node, ts, ruby, java, ...) ----------------

_C_LIKE = {".go", ".rs", ".js", ".mjs", ".cjs", ".ts", ".mts", ".java", ".kt", ".swift", ".cs",
           ".dart", ".scala", ".php"}
_HASH = {".py", ".rb", ".php"}
_BACKTICK = {".go", ".js", ".mjs", ".cjs", ".ts", ".mts", ".kt", ".dart", ".scala", ".rb", ".py", ".php"}
_MULTILINE_DQ = {".rs", ".php", ".swift", ".kt", ".scala"}
_LOG_BASE = (r"\b(?:log|logger|logging|console|slog|zap|logrus|tracing|syslog)\b[\w.]*\s*[.(!]"
             r"|\b(?:eprintln|eprint|dbg|panic|assert\w*|raise|throw|fatal|error_log|var_dump|sys\.exit)\b"
             r"|\b(?:info|debug|trace|warn|warning|error)!\s*\("
             r"|(?:new\s+)?\b\w*(?:Error|Exception)\s*\(|\berrors\.New\s*\(|\bErrorf\s*\("
             r"|\bfmt\.(?:Print|Println|Printf|Sprint|Sprintf|Sprintln)\b")
_LOG_CLI = re.compile(_LOG_BASE + r"|\b(?:print|println|printf|die|exit)\b\s*[!(]?", re.I)
_LOG_PHP = re.compile(_LOG_BASE + r"|\b(?:die|exit)\b\s*\(", re.I)
_IMPORT_LINE = re.compile(r"^\s*(import|from|use|require|include|package|#include|extern)\b")
_PROMPT_CTX = re.compile(r"\b\w*(?:prompt|instruction|system_?message|system_?msg)\w*\s*[:=(,]", re.I)
_SYSTEM_ROLE = re.compile(r"""["']?role["']?\s*[:=]\s*["']system["']""", re.I)
_LOOKBEHIND = 300  # bound the text examined before a string so one huge line stays linear


def _prompt_opener(raw: str, ls: int, i: int) -> bool:
    """True when this string begins its line right after a prompt assignment's opener
    (SYSTEM_PROMPT = ( / prompts = [ / "system": {)."""
    if raw[ls:i].strip():
        return False
    prev = _prev_code_line(raw, ls)
    return bool(prev) and prev[-1] in "([{=,:" and bool(_PROMPT_CTX.search(prev) or _SYSTEM_ROLE.search(prev))


def _prev_code_line(raw: str, ls: int) -> str:
    """The nearest earlier line that is neither blank nor a # comment ('' at file start)."""
    end = ls
    while end > 0:
        start = raw.rfind("\n", 0, end - 1) + 1
        text = raw[start:end].strip()
        if text and not text.startswith("#"):
            return text
        end = start
    return ""


def _scan_strings(raw: str, ext: str):
    """[(start_line, content, text_before_on_its_line)] for string literals outside comments."""
    n, i, line, out = len(raw), 0, 1, []
    ls = 0  # start offset of the current line, maintained incrementally
    c_like, hash_c = ext in _C_LIKE, ext in _HASH
    while i < n:
        ch = raw[i]
        if ch == "\n":
            line += 1
            i += 1
            ls = i
            continue
        two = raw[i:i + 2]
        if (c_like and two == "//") or (hash_c and ch == "#"):
            j = raw.find("\n", i)
            i = n if j < 0 else j
            continue
        if c_like and two == "/*":
            j = raw.find("*/", i + 2)
            j = n if j < 0 else j + 2
            line += raw.count("\n", i, j)
            i = j
            ls = raw.rfind("\n", 0, j) + 1
            continue
        before = raw[max(ls, i - _LOOKBEHIND):i]
        if ext == ".py" and raw.startswith(('"""', "'''"), i):
            q = raw[i:i + 3]
            j = raw.find(q, i + 3)
            j = n if j < 0 else j
            prev = _prev_code_line(raw, ls)
            docstring = not raw[ls:i].strip() and (not prev or prev.endswith(":"))
            if not docstring:
                out.append((line, raw[i + 3:j], before, raw[ls:ls + 40], _prompt_opener(raw, ls, i)))
            line += raw.count("\n", i, j)
            i = min(n, j + 3)
            ls = raw.rfind("\n", 0, i) + 1
            continue
        m = None
        if ext == ".php" and two == "<<":
            m = re.match(r"<<<[ \t]*(['\"]?)([A-Za-z_]\w*)\1[ \t]*\n", raw[i:i + 80])
        elif ext == ".rb" and two == "<<":
            m = re.match(r"<<[~-]?(['\"]?)([A-Z_][A-Z0-9_]*)\1[ \t]*\n", raw[i:i + 60])
        if m:
            nl = raw.find("\n", i)
            em = re.compile(r"^[ \t]*%s\b" % re.escape(m.group(2)), re.M).search(raw, nl + 1)
            j = em.start() if em else n
            out.append((line + 1, raw[nl + 1:j], before, raw[ls:ls + 40], False))
            line += raw.count("\n", i, j)
            i = j
            ls = raw.rfind("\n", 0, j) + 1
            continue
        if ext == ".rs" and ch == "r" and (i == 0 or not (raw[i - 1].isalnum() or raw[i - 1] == "_")):
            rm = re.match(r'r(#*)"', raw[i:i + 40])
            if rm:
                close = '"' + rm.group(1)
                j = raw.find(close, i + len(rm.group()))
                j = n if j < 0 else j
                out.append((line, raw[i + len(rm.group()):j], before, raw[ls:ls + 40], _prompt_opener(raw, ls, i)))
                line += raw.count("\n", i, j)
                i = min(n, j + len(close))
                ls = raw.rfind("\n", 0, i) + 1
                continue
        if ch in "\"'`":
            if ch == "`" and ext not in _BACKTICK:
                i += 1
                continue
            multiline = ch == "`" or (ch == '"' and ext in _MULTILINE_DQ)
            j = i + 1
            while j < n:
                cj = raw[j]
                if cj == "\\":
                    j += 2
                    continue
                if cj == ch:
                    break
                if cj == "\n" and not multiline:
                    j = n
                    break
                j += 1
            if j >= n:
                i += 1
                continue
            out.append((line, raw[i + 1:j], before, raw[ls:ls + 40], _prompt_opener(raw, ls, i)))
            line += raw.count("\n", i, j)
            i = j + 1
            ls = raw.rfind("\n", 0, i) + 1
            continue
        i += 1
    return out


def _code_copy(raw: str, ext: str) -> list:
    log = _LOG_PHP if ext == ".php" else _LOG_CLI
    found = []
    for lineno, content, before, head, opener in _scan_strings(raw, ext):
        if (opener or log.search(before) or _IMPORT_LINE.match(head)
                or _PROMPT_CTX.search(before) or _SYSTEM_ROLE.search(before)):
            continue
        for k, piece in enumerate(content.split("\n")):
            t = _fragment(piece)
            if t and _sentence_like(t):
                found.append((lineno + k, t))
    return _by_line(len(raw.split("\n")), found)


def extract_php(raw: str) -> list:
    html_view, code_view, last = [], [], 0
    for m in re.finditer(r"<\?(?:php|=)?(.*?)(?:\?>|\Z)", raw, re.S):
        html_view += [raw[last:m.start()], _blank(m.group())]
        code_view += [_blank(raw[last:m.start()]), m.group()]
        last = m.end()
    html_view.append(raw[last:])
    code_view.append(_blank(raw[last:]))
    h = extract_html("".join(html_view))
    c = _code_copy("".join(code_view), ".php")
    return [(a + " " + b).strip() for a, b in zip(h, c)]


# ---- dispatch + cli -------------------------------------------------------------------

def extract(path: str, raw: str, kind: str):
    ext = os.path.splitext(path)[1].lower()
    if kind == "markdown":
        return extract_markdown(raw, ext == ".mdx")
    if kind == "text":
        return extract_text(raw)
    if kind in ("html", "template"):
        return extract_html(raw)
    if kind == "locale":
        return extract_locale(raw, path)
    if kind == "source":
        if ext in (".vue", ".svelte", ".astro"):
            return extract_component(raw, ext)
        if ext in (".jsx", ".tsx"):
            return extract_jsx(raw)
        return extract_php(raw) if ext == ".php" else _code_copy(raw, ext)
    return None


def main(argv) -> int:
    if len(argv) != 3 or argv[1] not in ("classify", "extract"):
        print("usage: userfacing.py classify|extract PATH", file=sys.stderr)
        return 2
    cmd, path = argv[1], argv[2]
    if cmd == "classify":
        print(classify_file(path))
        return 0
    kind = classify_file(path)
    if kind == "none":
        return 1
    try:
        with open(path, encoding="utf-8") as fh:
            raw = fh.read()
    except (OSError, UnicodeDecodeError) as e:
        print(f"userfacing.py: cannot read {path}: {e}", file=sys.stderr)
        return 2
    print("\n".join(extract(path, raw, kind)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
