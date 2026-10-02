# Contributing to Clearwing

Thanks for wanting to help. This doc covers dev setup, the CI gate,
the PR checklist, and commit style.

## Dev setup

Clearwing targets Python 3.10+. Use `uv`, not raw `pip`.
The fastest path to a working dev environment:

```bash
# Install uv once: https://docs.astral.sh/uv/
curl -LsSf https://astral.sh/uv/install.sh | sh

git clone https://github.com/Lazarus-AI/clearwing.git
cd clearwing
uv sync --all-extras
uv run clearwing --help
```

`uv sync --all-extras` reads `pyproject.toml` + `uv.lock` and builds a
virtualenv in `.venv/` with the exact package set. Use `uv run ...` for
every project command so you are executing against the locked environment.

When you bump a dependency in `pyproject.toml`, run `uv lock` to
regenerate the lockfile and commit both files together. CI reads from
`pyproject.toml` only (to catch lockfile drift) but local development
is faster and more reproducible with `uv sync`.

## The local gate

Every PR is expected to pass `make gate` locally before it's opened.
That target mirrors CI exactly:

```bash
uv run make gate
```

which is shorthand for:

```bash
uv run make lint          # ruff check + ruff format --check
uv run make type          # scoped mypy on the typed-core modules
uv run make test-strict   # pytest -q --strict-markers --strict-config
uv run make build         # python -m build + twine check
```

Individual targets:

| Target | What it runs |
|---|---|
| `uv run make lint` | `ruff check clearwing/ tests/` + `ruff format --check clearwing/ tests/` |
| `uv run make format` / `uv run make fmt` | `ruff format` + `ruff check --fix` (writes changes) |
| `uv run make type` | `mypy --follow-imports=silent clearwing/findings clearwing/sourcehunt clearwing/capabilities.py` |
| `uv run make test` | `pytest -q` |
| `uv run make test-strict` | `pytest -q --strict-markers --strict-config` (CI mode) |
| `uv run make build` | `python -m build` + `twine check dist/*` (auto-cleans first) |
| `uv run make clean` | wipes `dist/`, `build/`, `*.egg-info/`, `__pycache__/`, `.pytest_cache/`, `.ruff_cache/`, `.mypy_cache/` |

If `make gate` is green locally, CI will be green remotely. If it's
red locally, fix before pushing — CI won't give you anything new.

## PR checklist

Before opening a PR, confirm:

- [ ] `uv run make gate` passes locally.
- [ ] New tests cover the change. For bug fixes, add a regression
      test that fails on main without the fix. For features, add a
      test that exercises the golden path and at least one edge case.
- [ ] **PR title is the release-notes line.** Write it as imperative,
      user-facing prose. That literal string will appear in the next
      GitHub Release under the category your label assigns. "Fix
      sandbox startup on Docker >= 25" ✅ — "fix bug" ❌.
- [ ] **Apply exactly one category label** (see below). PRs without a
      label land in the "Other changes" bucket; meta / test-only PRs
      should use `skip-changelog`.
- [ ] `pyproject.toml` version is **not** bumped in the PR — version
      bumps happen at release time, not per-PR.
- [ ] No secrets, credentials, API keys, or customer data in the
      diff. Grep for `api_key`, `password`, `token`, `BEGIN` before
      committing if you're unsure.
- [ ] Commit messages follow the style below.

### Release-notes labels

Release notes are generated automatically by GitHub from merged-PR
titles, grouped by label. The config is in
[`.github/release.yml`](.github/release.yml). Use one of:

| Label | Bucket | When to use |
|---|---|---|
| `breaking-change` | ⚠️ Breaking changes | API change, removed flag, required config migration. Can be combined with another label. |
| `enhancement` or `feature` | 🚀 Features | New user-visible capability. |
| `bug` | 🐛 Fixes | Fixing a regression or reported defect. |
| `security` | 🔒 Security | Anything security-sensitive — pairs with a CVE / advisory. |
| `documentation` | 📚 Docs | Docs-only change. |
| `chore` | 🧰 Maintenance | Deps, CI, tooling, refactors with no behavior change. |
| `skip-changelog` | (excluded) | Test-only PRs, meta PRs, trivial follow-ups. |

For all other PRs, there is no longer a `CHANGELOG.md` to update —
the old hand-curated file is archived at
[`docs/CHANGELOG-v1.0.md`](docs/CHANGELOG-v1.0.md) and the root
[`CHANGELOG.md`](CHANGELOG.md) is just a pointer to GitHub Releases.

## Commit message style

Short, declarative subject line. Body explains **why**, not **what**
(the diff already tells you what).

```
Phase 5c: extract analysis tools to hunt/analysis.py

Third of four commits splitting hunter_tools.py.

Moves `compile_file`, `run_with_sanitizer`, `write_test_case`,
`fuzz_harness` into a `build_analysis_tools(ctx)` factory so each
workflow phase (discovery, analysis, reporting) lives in its own
file. The tool-registry snapshot test stays green because the
aggregator composes the four builders in the original order.

Co-Authored-By: ...
```

Rules:
- Imperative subject ("Add X", not "Added X").
- Keep the subject under 72 chars.
- Wrap the body at ~72 chars too — `git log` on a terminal doesn't
  soft-wrap, and neither do most code-review tools.
- Reference the phase number (`Phase 5c:`) for refactor work that
  tracks against the [refactor plan](https://github.com/Lazarus-AI/clearwing/blob/main/docs/refactor-plan.md).
- If the change has a non-obvious reason (avoided a race, worked
  around a library bug, responds to a code review concern) —
  explain it. Future-you will want to know.

## Branch naming

```
<kind>/<short-slug>
```

Where `<kind>` is one of:
- `feat/` — new feature or user-visible capability
- `fix/` — bug fix
- `refactor/` — internal restructuring with no behavior change
- `docs/` — docs-only change
- `test/` — test-only change
- `chore/` — tooling, CI, dependency bumps

Example: `refactor/hunt-split-discovery-tools`

## Running against a real target

Clearwing is an offensive-security tool. Do not run it against
systems you don't own or aren't explicitly authorized to test.
See `SECURITY.md` for the distinction between "vulnerabilities in
Clearwing" (report to us) and "vulnerabilities Clearwing finds in
other software" (report to that vendor).

## Reporting vulnerabilities in Clearwing itself

See [`SECURITY.md`](SECURITY.md). **Don't** open a public issue for
security impact — use GitHub Security Advisories or email the
maintainer.
