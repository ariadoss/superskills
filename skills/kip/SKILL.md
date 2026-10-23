---
name: kip
description: |
  Kip framework contract for building and maintaining Kip apps
  (~/Sites/MVC-Lite) and KipSaaS (~/Sites/kipsaas): constraints, commands,
  ports, style, and the performance budget. Load when working in either repo.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Kip

Kip (~/Sites/MVC-Lite) is a plain-PHP, batteries-included, server-rendered
framework: PHP 8.3+, zero runtime dependencies, zero JavaScript, SQLite by
default. KipSaaS (~/Sites/kipsaas) is its SaaS starter kit: multi-tenant
subscriptions with production-hardened Stripe billing.

## Read the committed contracts first

- ~/Sites/MVC-Lite/AGENTS.md is committed product: hard constraints, the
  gate command, the writing style, the one-query budget. Read it before
  touching anything in that repo.
- ~/Sites/kipsaas/AGENTS.md likewise, including the engine-vs-demo boundary
  (src/ is generic machinery; the demo app binds config) and the porting
  leak-guard grep.

## Non-negotiables in both repos

- Full gate before reporting done:
  `PATH="/opt/homebrew/bin:$PATH" composer check`
  (the default `php` on this machine is 5.6; the Homebrew one is required).
  In KipSaaS the suite alone is
  `PATH="/opt/homebrew/bin:$PATH" vendor/bin/phpunit`.
- Zero runtime dependencies (Kip: php + ext-pdo only), zero JavaScript, no
  build step, every framework class final.
- No em dashes in any committed file. Operator voice, real numbers, no
  banned words (leverage, synergy, empower, revolutionize, supercharge,
  delve, unlock, elevate, seamless, robust).
- Ports: never touch 8090; ad-hoc dev servers use 8093+.
- Never spend money or start anything with a recurring cost without asking.
- Phase protocol (both repos): /write-plan, /plan-eng-review, subagent
  execution with review gates, /qa-full, tracker updated per phase
  (docs/superpowers/ is workspace-private in both repos and never ships).
- AI-behavior changes (prompts, agent features) get evals, not just unit
  tests: superskills evals/METHODOLOGY.md.

## Where things live

- Kip roadmap ledger: ~/Sites/MVC-Lite/TODOS.md (untracked).
- KipSaaS roadmap ledger: ~/Sites/kipsaas/docs/superpowers/TODOS.md
  (untracked).
- Agent-facing docs surface (committed product in Kip): root AGENTS.md,
  root llms.txt, guide chapter 16.
