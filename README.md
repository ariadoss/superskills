# Superskills `v2.17.0`

Curated AI skills pack for Claude Code, OpenCode, Codex CLI, Continue.dev, Augment Code, Windsurf, Cursor, and Cline/Roo. Bundles [gstack](https://github.com/garrytan/gstack) (Garry Tan's virtual engineering team) and extends it with TDD, systematic debugging, security testing, spec workflows, knowledge base integration, and more.

33 core skills + 43 gstack skills + 173 marketing skills + 35 design skills. gstack is installed automatically and vendored in this repo so skills are available even if the upstream repo is removed.

> **[Full command reference →](COMMANDS.md)** — all skills with descriptions and overlap notes
> **[10x+ Engineering Workflow →](DEVELOPER_WORKFLOW.md)** — run 10+ parallel AI agents, each with a full quality pipeline ([deep dive](https://hyperion360.com/blog/parallel-ai-agents-engineering-workflow/))

## Install

```bash
git clone https://github.com/ariadoss/superskills.git ~/.claude/skills/superskills
cd ~/.claude/skills/superskills && ./setup
```

Setup will:
- Install gstack (Garry Tan's virtual engineering team skills) — required, auto-installed
- Install `bun` if needed (required by gstack's browser tool)
- Prompt you to connect knowledge base repos (optional)
- Check for optional dependencies (clearwing, ffuf)
- Auto-detect and install into: **Claude Code**, **OpenCode**, **Codex CLI**, **Continue.dev**, **Augment Code**, **Windsurf**
- Offer to add the developer workflow guide to `~/.claude/CLAUDE.md`

**Project-level installs** (run from your project root):
```bash
~/.claude/skills/superskills/setup --cursor   # Cursor (.cursor/rules/)
~/.claude/skills/superskills/setup --cline    # Cline / Roo Code (.clinerules)
```

### Install as a plugin (native update alerts)

Claude Code and Codex can install superskills as a versioned **plugin**, which
gives you a native "updated" notification when a new version ships — no manual
`git pull` needed.

**Claude Code** (exposes the core + design skills; run `./setup` for the full
marketing-skills set):
```bash
/plugin marketplace add ariadoss/superskills
/plugin install superskills@superskills
/reload-plugins
```
On a new release you'll see *"Plugins updated — run `/reload-plugins`"* at startup
(with auto-update enabled for the marketplace).

**Codex CLI:**
```bash
codex plugin marketplace add ariadoss/superskills
codex plugin install superskills
```

The plugin `version` is driven by the repo's `VERSION` file via
`scripts/sync-version.sh`, so every release bumps the version the plugin systems
watch. The `./setup` install above remains the way to get **all** skills across
every supported tool.

## Skills (28)

### Dev Methodology (from [superpowers](https://github.com/obra/superpowers))
| Command | Description |
|---------|-------------|
| `/tdd` | Test-Driven Development — RED-GREEN-REFACTOR enforcement |
| `/debug` | Systematic Debugging — 4-phase root cause analysis |
| `/daily-qa` | Daily evidence-grounded sweep — recent commits, CI failures, dep drift, perf regressions, untested paths; auto-runs `/defense` (basic OWASP) + scoped `/db-optimize` |
| `/worktrees` | Git Worktrees — isolated parallel development |
| `/finish-branch` | Branch cleanup and merge decisions |
| `/verify` | Pre-merge validation |
| `/write-plan` | Detailed implementation planning |

### Security
| Command | Description |
|---------|-------------|
| `/pentest` | Security scanning via [clearwing](https://github.com/Lazarus-AI/clearwing) |
| `/fuzz` | Web fuzzing via [ffuf](https://github.com/ffuf/ffuf) |
| `/defense` | Defense-in-depth — OWASP Top 10, secrets, auth, encryption |

### Spec Workflow (from [BB-Skills](https://github.com/buildbetter-app/BB-Skills))
| Command | Description |
|---------|-------------|
| `/specify` | Requirements and user story definition |
| `/clarify` | Pre-planning underspecification resolution |
| `/analyze` | Cross-artifact consistency checking |
| `/checklist` | Quality checklist generation |

### Startup (from [slavingia/skills](https://github.com/slavingia/skills))
| Command | Description |
|---------|-------------|
| `/validate-idea` | Test market demand before building |
| `/pricing` | SaaS pricing strategy frameworks |
| `/minimalist-review` | Decision evaluation against core principles |

### Knowledge & Content
| Command | Description |
|---------|-------------|
| `/tapestry` | Extract content from URLs, create action plans |
| `/youtube` | Extract YouTube video transcripts |
| `/article` | Extract clean text from web articles |
| `/kb-advisor` | Search and synthesize from your knowledge bases |
| `/content-writer` | Content creation backed by knowledge base research |

### Testing
| Command | Description |
|---------|-------------|
| `/playwright` | E2E testing with Playwright |

### Codebase Context (from [ariadoss/repomap](https://github.com/ariadoss/repomap), [safishamsi/graphify](https://github.com/safishamsi/graphify))
| Command | Description |
|---------|-------------|
| `/repomap` | Generate structural map of the codebase (REPOMAP.md) |
| `/dbmap` | Generate database schema map (DBMAP.md) |
| `/repomap-auto-on` | Auto-update REPOMAP.md on every code change |
| `/repomap-auto-off` | Disable automatic repo map updates |
| `/graphify` | Turn any folder into a queryable knowledge graph — HTML, JSON, audit report |

## Knowledge Bases

During setup, you can connect any git repos as knowledge bases. The `/kb-advisor` and `/content-writer` skills will search and reference them.

Configuration lives in `~/.superskills/knowledge.conf`:

```
# name|path|description|git-url
docs|~/.superskills/knowledge/docs|Internal docs|https://github.com/org/docs.git
research|~/.superskills/knowledge/research|Research notes|https://github.com/org/research.git
```

Add more anytime by editing the file and re-running `./setup`.

## Extending for Your Team

Superskills is designed to be a generic base that teams extend with domain-specific skills:

```bash
# Your team's private repo installs superskills first, then adds custom skills
git clone https://github.com/ariadoss/superskills.git ~/.claude/skills/superskills
cd ~/.claude/skills/superskills && ./setup --quiet --no-knowledge

# Then install your team's overlay
git clone https://github.com/your-org/your-skills.git ~/.claude/skills/your-skills
cd ~/.claude/skills/your-skills && ./setup
```

Your overlay repo can:
- Add domain-specific skills (e.g., `/your-defense` with project-specific checks)
- Pre-configure knowledge bases
- Override generic skills with customized versions

## Optional Dependencies

- `uv tool install clearwing` — for `/pentest` (source code + network scanning)
- `brew install ffuf` — for `/fuzz` (web fuzzing)
- Playwright — for `/playwright` (`npm install -D @playwright/test`)

## Engineering standards & tests

All executable code in this repo holds to [`ENGINEERING_STANDARDS.md`](ENGINEERING_STANDARDS.md)
(TDD · DRY · SOLID · YAGNI). Shell code is unit-tested with [bats](https://github.com/bats-core/bats-core):

```bash
./tests/run.sh    # runs tests/*.bats
```

## Updating

```bash
cd ~/.claude/skills/superskills && git pull && ./setup
```

> **Always re-run `./setup` after pulling — `git pull` alone is not enough.**
> Existing skills are live symlinks, so edits to them show up instantly. But a
> **new** skill only becomes visible once `./setup` runs again to create its
> symlink. `setup` installs a git `post-merge` hook that does this automatically
> on every pull, so after your first run you can just `git pull`. The
> `/superskills-upgrade` command also handles this for you.

## Maintenance utilities

### Idle QA browser reaper

gstack's `/qa`, `/browse`, and `/benchmark` skills launch a persistent per-project
"Chrome for Testing" browser under `~/.gstack/chromium-profile-<name>`. The profile
dir is meant to persist (it keeps logins/cookies between runs), but the browser
*process* has no idle teardown — when a skill or Claude session ends via SIGTERM,
Ctrl-C, or a crash, the browser is orphaned and can sit for hours pegging a CPU
core. A few of these stacked up will push your load average past your core count
and make the whole machine (Terminal, Claude, everything) feel sluggish.

`scripts/gstack-qa-browser-reaper.sh` kills QA browsers that have been idle past a
threshold. It is:

- **Scoped** — touches only `~/.gstack/chromium-profile-<suffix>` QA profiles. Your
  real Chrome/Firefox and the bare `chromium-profile` browser are never matched.
- **Idle-based** — uses the profile dir mtime (Chrome writes it on navigation /
  cookies; it goes stale when the browser sits idle), so it never kills a browser
  you're actively driving in another window.
- **Graceful** — SIGTERM first (Chrome tears down its own children), SIGKILL only
  if it ignores the polite ask.

Preview what it would reap without killing anything:

```bash
scripts/gstack-qa-browser-reaper.sh --dry-run
```

Install it as a background agent (launchd, runs every 15 min) plus, optionally, a
Claude Code `SessionEnd` hook the installer prints for you:

```bash
scripts/install-qa-browser-reaper.sh            # defaults: idle 30 min, every 15 min
scripts/install-qa-browser-reaper.sh --idle-min 60 --interval 1800
scripts/install-qa-browser-reaper.sh --uninstall
```

The installer is **opt-in** and never run by `./setup` — it installs a background
agent that force-kills processes, so it stays a deliberate choice. macOS only.
Threshold and process list are seam-injectable (`GSTACK_QA_REAP_IDLE_MIN`,
`GSTACK_QA_REAP_PS_FILE`) and covered by `tests/gstack-qa-browser-reaper.bats`.

## Marketing Skills (173)

From [kostja94/marketing-skills](https://github.com/kostja94/marketing-skills) — stored directly in this repo. SEO, content, paid ads, pages, channels, and strategies:

| Category | Examples |
|----------|---------|
| **SEO** | `/seo-strategy`, `/keyword-research`, `/title-tag`, `/core-web-vitals`, `/backlink-analysis`, `/local-seo` |
| **Content** | `/copywriting`, `/article-content`, `/video-marketing`, `/video-editing`, `/visual-content`, `/podcast-marketing` |
| **Paid Ads** | `/google-ads`, `/meta-ads`, `/linkedin-ads`, `/tiktok-ads`, `/paid-ads-strategy` |
| **Pages** | `/landing-page-generator`, `/homepage-generator`, `/pricing-page-generator`, `/blog-page-generator` |
| **Channels** | `/email-marketing`, `/affiliate-marketing`, `/influencer-marketing`, `/distribution-channels` |
| **Strategies** | `/branding`, `/content-marketing`, `/gtm-strategy`, `/pmf-strategy`, `/growth-funnel` |
| **Platforms** | `/linkedin-posts`, `/twitter-x-posts`, `/reddit-posts`, `/tiktok-captions`, `/youtube-seo` |
| **Analytics** | `/google-search-console`, `/seo-monitoring`, `/traffic-analysis`, `/analytics-tracking` |

## Design Skills (35)


| Category | Skills |
|----------|--------|
| **UX Frameworks** | `/ux-heuristics`, `/hooked-ux`, `/design-sprint` |
| **Visual Design** | `/high-end-visual-design`, `/minimalist-ui`, `/design-taste-frontend`, `/redesign-existing-projects`, `/ui-refactor`, `/interface-design` |
| **Design Process** | `/design-audit`, `/design-drift`, `/ux-designer`, `/emil-design-eng` |
| **Typography** | `/typography` |
| **React / Next.js** | `/react-best-practices`, `/react-view-transitions`, `/composition-patterns`, `/react-native-skills` |
| **Vercel** | `/deploy-to-vercel`, `/vercel-cli-with-tokens`, `/web-design-guidelines` |
| **Swift / iOS** | `/ios-dev`, `/swiftui-toolbars`, `/swiftui-charts-3d`, `/swiftui-alarmkit`, `/swiftui-text-editing`, `/swiftui-webkit` |
| **App Marketing** | `/app-store-screenshots` |
| **Architecture** | `/renaissance-architecture`, `/human-architect-mindset`, `/negentropy-lens`, `/relationship-design` |
| **Engineering** | `/bencium-code-conventions`, `/full-output-enforcement`, `/adaptive-communication` |
| **Campaigns** | `/organic-first-campaign` |

## Credits

Skills curated from:
- [garrytan/gstack](https://github.com/garrytan/gstack) — virtual engineering team (QA, review, ship, security, planning, browser automation)
- [obra/superpowers](https://github.com/obra/superpowers) — TDD, debugging, worktrees, planning
- [buildbetter-app/BB-Skills](https://github.com/buildbetter-app/BB-Skills) — spec workflow
- [slavingia/skills](https://github.com/slavingia/skills) — startup methodology
- [tapestry](https://github.com/michalparkola/tapestry-skills-for-claude-code) — content extraction
- [clearwing](https://github.com/Lazarus-AI/clearwing) — security scanning
- [ffuf](https://github.com/ffuf/ffuf) — web fuzzing
- [kostja94/marketing-skills](https://github.com/kostja94/marketing-skills) — 172 marketing skills
- [wondelai/skills](https://github.com/wondelai/skills) — UX heuristics, Hook Model, Design Sprint
- [emilkowalski/skill](https://github.com/emilkowalski/skill) — design engineering philosophy
- [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) — React, Next.js, Vercel deployment
- [rshankras/claude-code-apple-skills](https://github.com/rshankras/claude-code-apple-skills) — Swift/iOS/SwiftUI
- [bencium/bencium-marketplace](https://github.com/bencium/bencium-marketplace) — design audit, typography, architecture
- [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) — premium UI design systems
- [LovroPodobnik/refactoring-ui-skill](https://github.com/LovroPodobnik/refactoring-ui-skill) — UI refactoring
- [Dammyjay93/interface-design](https://github.com/Dammyjay93/interface-design) — interface design craft
- [ParthJadhav/app-store-screenshots](https://github.com/ParthJadhav/app-store-screenshots) — app store screenshot generator
- [browser-use/video-use](https://github.com/browser-use/video-use) — conversation-driven video editor (cut, grade, subtitle, animate)

## License

MIT
