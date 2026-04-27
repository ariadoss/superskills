# 10x+ Engineering Output with Parallel AI Agents

Run 10+ features simultaneously — each built, tested, reviewed, documented, and PR'd at the same time.

**Traditional:** 1 engineer, 1 task at a time  
**With AI agents:** 1 engineer, 10+ features built, tested, reviewed, documented, and PR'd simultaneously

Engineers who master this don't just move faster — they operate at a different level entirely.

> **Deep dive:** [Parallel AI Agents Engineering Workflow](https://hyperion360.com/blog/parallel-ai-agents-engineering-workflow/) — full write-up with rationale, examples, and pitfalls.

---

## The Workflow

### 1. Spec and plan work as vertical slices

Each feature is scoped end-to-end on its own isolated branch. Nothing touches the rest of the codebase until merged.

| Command | Role |
|---------|------|
| `/specify` | Turn a natural language description into a structured feature spec |
| `/clarify` | Identify gaps and ambiguities in the spec before planning |
| `/write-plan` | Generate a detailed implementation plan from the spec |
| `/analyze` | Verify consistency across spec, plan, and tasks so nothing conflicts |
| `/autoplan` | Run automated CEO, design, and eng review chain on the plan |
| `/gstack-plan-eng-review` | Architecture, data flow, and test planning review |
| `/repomap` | Generate a structural map of the codebase so agents understand context |
| `/dbmap` | Map the database schema so agents work with accurate data models |
| `/graphify` | Turn any folder into a queryable knowledge graph so agents and engineers can navigate complex codebases |

### 2. Launch 10+ agents in parallel (one per branch)

Each agent works independently and spawns subagents. Exponentially faster than pair programming with AI one task at a time.

| Command | Role |
|---------|------|
| `/worktrees` | Create isolated git worktrees so each agent works on its own branch without interfering with others |
| `/repomap-auto-on` | Automatically keep the codebase map updated as each agent makes changes |
| `/dbmap-auto-on` | Automatically regenerate DBMAP.md after migration commands run, so agents always see the live schema |
| `/gstack-pair-agent` | Coordinate multiple AI agents sharing browser and context across workspaces |

### 3. Each agent runs the full quality pipeline simultaneously

| Command | Role |
|---------|------|
| `/tdd` | Enforce Red-Green-Refactor so tests are written before code, not as an afterthought |
| `/checklist` | Generate a custom quality checklist for the specific feature being built |
| `/playwright` | Run end-to-end tests with Playwright, automate UI verification |
| `/gstack-qa` | Browser-based testing and bug fixing using real Chromium |
| `/gstack-browse` | Direct Chromium browser control for manual-style automated QA |
| `/gstack-review` | Staff engineer-level code review focused on production readiness |
| `/gstack-investigate` | Root cause analysis with hypothesis testing when something breaks |
| `/debug` | Systematic 4-phase debugging before proposing any fix |
| `/verify` | Require passing verification commands before any agent can finish |
| `/finish-branch` | Guide branch cleanup and merge decisions when implementation is complete |

### 4. Performance & database optimization

> **DB performance should be audited early and often** — not discovered in production under load.
>
> - Run `/dbmap` first to map the schema; it will automatically flag missing indexes on foreign keys and common query patterns
> - Run `/db-optimize` on any feature that adds or modifies DB queries — catches N+1s, join opportunities, and slow queries before they ship
> - Run `/perf-profile` when response times degrade or before a launch to establish a baseline
> - Implement `/cache-strategy` for any data that is read far more than it is written

| Command | Role |
|---------|------|
| `/dbmap` | Map database schema and automatically flag missing indexes (FK columns, common query patterns) |
| `/db-optimize` | N+1 detection, EXPLAIN analysis, slow query log review, join opportunities, per-endpoint DB call audit |
| `/perf-profile` | Code execution time, DB call time, bottleneck identification across app and DB layers |
| `/cache-strategy` | Permanent cache-first strategy — read from cache, write on first miss, invalidate only on data change (no TTL) |

### 6. Security layer (runs alongside development and again after every merge)

> **Security and QA should run at multiple points — not just once.**
>
> New code introduced after an initial review can reintroduce vulnerabilities or break functionality. The right model is:
>
> 1. **Before writing code** — `/gstack-cso` and `/defense` surface threat model concerns that shape the design
> 2. **During development** — security checks catch issues while context is fresh and before bad patterns spread
> 3. **In the PR pipeline** — `/gstack-review` re-runs on every diff, so new code is always checked
> 4. **After each merge to main** — run `/pentest` and `/fuzz` again; merged code from other branches may create new attack surfaces when combined
>
> Treating security as a one-time gate at the end is the mistake. Continuous checks are cheap; a post-ship breach is not.

| Command | Role |
|---------|------|
| `/gstack-cso` | OWASP Top 10 and STRIDE threat modeling |
| `/defense` | Enforce secrets management, auth, and encryption standards |
| `/pentest` | Scan source code and network for vulnerabilities |
| `/fuzz` | Web fuzzing to surface unexpected attack surfaces before shipping |

### 7. Ship

| Command | Role |
|---------|------|
| `/gstack-ship` | Sync tests, automate CI/CD, and submit the PR |
| `/gstack-land-and-deploy` | Merge, deploy, and verify production |

---

## What is a vertical slice?

A vertical slice means one branch contains every layer a feature needs to work — UI, API, business logic, database, and tests — all together, all shippable as a unit.

The contrast is **horizontal slicing**, where work is split by layer: one branch does all the backend, another does all the frontend, a third writes the tests. Agents block on each other. Nothing works end-to-end until everything is merged. Integration risk is deferred until the worst possible moment.

A vertical slice cuts through every layer for a single feature. The branch is independently deployable and testable the moment it's done.

```
HORIZONTAL SLICES                    VERTICAL SLICES
(by layer — agents block each other) (by feature — agents are independent)

Feature A  Feature B  Feature C      Feature A   Feature B   Feature C
    │          │          │          ┌─────────┐ ┌─────────┐ ┌─────────┐
────┼──────────┼──────────┼──── UI   │ UI      │ │ UI      │ │ UI      │
    │          │          │          │ API     │ │ API     │ │ API     │
────┼──────────┼──────────┼──── API  │ Logic   │ │ Logic   │ │ Logic   │
    │          │          │          │ DB      │ │ DB      │ │ DB      │
────┼──────────┼──────────┼──── DB   │ Tests   │ │ Tests   │ │ Tests   │
    │          │          │          └─────────┘ └─────────┘ └─────────┘
────┼──────────┼──────────┼──── Tests  branch-a    branch-b    branch-c
    ↓          ↓          ↓           (ships)      (ships)     (ships)
 waits      waits      waits       independently independently independently
```

Each vertical slice lives on its own git branch (via `/worktrees`) and is owned by one agent. Nothing touches shared code until the PR merges.

---

### What goes in a vertical slice by framework

The exact files vary by stack, but the principle is the same: every file the feature needs, in one branch.

**Next.js (App Router)**
```
feature/user-invites
├── app/
│   └── invites/
│       ├── page.tsx          ← UI (server component)
│       ├── InviteForm.tsx    ← UI (client component)
│       └── actions.ts        ← Server action (middleware layer)
├── lib/
│   └── invites.ts            ← Business logic
├── db/
│   └── migrations/
│       └── 0012_invites.sql  ← Database migration
└── tests/
    ├── invites.unit.test.ts  ← Unit tests
    └── invites.e2e.test.ts   ← End-to-end tests
```

**Rails (MVC)**
```
feature/user-invites
├── app/
│   ├── controllers/
│   │   └── invites_controller.rb   ← Routing + request handling
│   ├── models/
│   │   └── invite.rb               ← Business logic + validations
│   └── views/
│       └── invites/
│           ├── index.html.erb      ← UI
│           └── new.html.erb        ← UI
├── db/
│   └── migrate/
│       └── 20240101_create_invites.rb  ← Migration
└── spec/
    ├── models/invite_spec.rb           ← Unit tests
    ├── controllers/invites_spec.rb     ← Controller tests
    └── system/invites_spec.rb          ← E2E tests
```

**FastAPI + React (separate frontend/backend in one repo)**
```
feature/user-invites
├── backend/
│   ├── routers/
│   │   └── invites.py        ← API endpoints
│   ├── services/
│   │   └── invite_service.py ← Business logic
│   ├── models/
│   │   └── invite.py         ← DB model (SQLAlchemy)
│   └── alembic/
│       └── versions/
│           └── 0012_invites.py  ← Migration
├── frontend/
│   └── src/
│       ├── pages/
│       │   └── Invites.tsx   ← Page component
│       └── components/
│           └── InviteForm.tsx ← Form component
└── tests/
    ├── test_invites_api.py   ← API tests (pytest)
    └── invites.spec.ts       ← UI tests (Playwright)
```

**iOS (SwiftUI)**
```
feature/user-invites
├── Views/
│   ├── InviteListView.swift  ← UI
│   └── InviteFormView.swift  ← UI
├── ViewModels/
│   └── InviteViewModel.swift ← State + business logic
├── Models/
│   └── Invite.swift          ← Data model
├── Services/
│   └── InviteService.swift   ← API calls
└── Tests/
    ├── InviteViewModelTests.swift  ← Unit tests
    └── InviteUITests.swift         ← UI tests
```

---

### The rule of thumb

If an agent can build, run, and test the feature without touching any other branch, it's a valid vertical slice. If it needs to wait for another agent to finish a shared layer first, it's a horizontal slice — redesign the scope.

---

### Vertical slices are independently deployable — and safely reversible

A true vertical slice has two properties beyond just "all layers together":

**1. It owns its own data.** Each slice gets its own new DB tables or columns — it never restructures existing ones. This means the migration can be applied and rolled back cleanly. Other features keep working whether the slice is present or not.

**2. It can be toggled off without breaking production.** Because it has its own tables and its UI entry points are new (a new route, a new button, a new API endpoint), removing the slice doesn't break existing code. You can deploy it dark, test it, then expose it — or roll it back entirely by reverting the branch.

```
WRONG — not a real vertical slice:
  feature/user-invites alters the existing `users` table
  → rolling back breaks the users feature
  → other branches that touched `users` now conflict

RIGHT — a real vertical slice:
  feature/user-invites creates a new `invites` table
  → rolling back is safe — nothing else references it
  → the feature can be deployed dark and enabled later
```

This is what makes parallel agents safe at scale. Ten agents can each add new tables and new endpoints simultaneously. None of them can break each other because they never modify shared state — they only add to it.

## Why security alongside development, not after?

Running security late is a known failure mode. Late-stage findings require expensive rearchitecting. Running it early means the threat model informs the design. Running it again after every merge catches the regression case — new code from other branches that wasn't in scope for the original review.

The `/gstack-review` command is designed for this: it runs on every PR diff automatically, so security and correctness checks are always current.
