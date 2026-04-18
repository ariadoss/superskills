# Superskills

Curated AI skills pack for Claude Code and OpenCode. Extends [gstack](https://github.com/garrytan/gstack) with TDD, systematic debugging, security testing, spec workflows, knowledge base integration, and more.

26 focused skills, each solving one specific problem well.

## Install

```bash
git clone https://github.com/ariadoss/superskills.git ~/.claude/skills/superskills
cd ~/.claude/skills/superskills && ./setup
```

Setup will:
- Prompt you to connect knowledge base repos (optional)
- Check for optional dependencies (clearwing, ffuf)
- Symlink all skills into Claude Code and OpenCode

## Skills (26)

### Dev Methodology (from [superpowers](https://github.com/obra/superpowers))
| Command | Description |
|---------|-------------|
| `/tdd` | Test-Driven Development — RED-GREEN-REFACTOR enforcement |
| `/debug` | Systematic Debugging — 4-phase root cause analysis |
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

### Codebase Context (from [ariadoss/repomap](https://github.com/ariadoss/repomap))
| Command | Description |
|---------|-------------|
| `/repomap` | Generate structural map of the codebase (REPOMAP.md) |
| `/dbmap` | Generate database schema map (DBMAP.md) |
| `/repomap-auto-on` | Auto-update REPOMAP.md on every code change |
| `/repomap-auto-off` | Disable automatic repo map updates |

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

## Updating

```bash
cd ~/.claude/skills/superskills && git pull && ./setup
```

## Credits

Skills curated from:
- [obra/superpowers](https://github.com/obra/superpowers) — TDD, debugging, worktrees, planning
- [buildbetter-app/BB-Skills](https://github.com/buildbetter-app/BB-Skills) — spec workflow
- [slavingia/skills](https://github.com/slavingia/skills) — startup methodology
- [tapestry](https://github.com/michalparkola/tapestry-skills-for-claude-code) — content extraction
- [clearwing](https://github.com/Lazarus-AI/clearwing) — security scanning
- [ffuf](https://github.com/ffuf/ffuf) — web fuzzing

## License

MIT
