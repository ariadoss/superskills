# Clearwing

<img width="400" alt="image" src="https://github.com/user-attachments/assets/c0444f24-32d8-4d62-af66-f1b7d8a123ba" />

By Eric Hartford, Lazarus AI

Inspired by Anthropic's Glasswing.  

The challenge:  Produce similar results as Glasswing - using models everyone has access to.

**Autonomous vulnerability scanner and source-code hunter.** Built on
`genai-pyo3`, a native Rust-backed LLM runtime speaking every major
provider (Anthropic, OpenAI, OpenRouter, Ollama, LM Studio, Together,
Groq, DeepSeek, MiniMax, Gemini, any OpenAI-compatible endpoint).

Clearwing is a dual-mode offensive-security tool:

- **Network-pentest agent** — a ReAct-loop agent with 63 bind-tools
  that scans live targets, detects services and vulnerabilities,
  runs sandboxed Kali tools, attempts exploits (gated through a
  human-approval guardrail), and writes reports to a persistent
  knowledge graph.
- **Source-code hunter** — a file-parallel agent-driven
  pipeline that ranks source files, fans out per-file hunter agents
  (full-shell or constrained), uses ASan/UBSan crashes as ground
  truth, verifies findings with a 4-axis validator (REAL /
  TRIGGERABLE / IMPACTFUL / GENERAL), runs PoC stability checks
  across fresh containers, optionally generates validated patches,
  and emits SARIF/markdown/JSON reports with explicit evidence levels
  (`suspicion → static_corroboration → crash_reproduced →
  root_cause_explained → exploit_demonstrated → patch_validated`).
  Features three-band budget promotion, entry-point sharding for
  large files, cross-subsystem hunting, a shared findings pool with
  root-cause deduplication, multi-turn agentic exploit development,
  and human-in-the-loop exploit elaboration.
- **N-day exploit pipeline** — given CVE IDs, builds the
  vulnerable version, develops working exploits, and validates
  against the patched version to confirm the fix.
- **Reverse engineering pipeline** — decompiles closed-source
  ELF binaries via Ghidra, reconstructs plausible source with an
  LLM, then hunts vulnerabilities using a hybrid source + binary
  validation approach.
- **Campaign orchestration** — runs sourcehunt across dozens or
  hundreds of repositories from a single YAML config with shared
  budget, checkpoint/resume, and aggregate reporting.
- **Responsible disclosure** — human-in-the-loop validation
  workflow with MITRE/HackerOne template generation, SHA-3
  cryptographic commitments for provable priority, timeline
  tracking, and batched disclosure.
- **Benchmarking & evaluation** — OSS-Fuzz crash severity
  ladder for model comparison, and an A/B testing framework for
  measuring whether preprocessing helps or hurts finding quality.

**Authorized use only.** Clearwing is a dual-use offensive-security
tool. Run it only against targets you own or have explicit written
authorization to test. Operators are responsible for scope, legal
authorization, and disclosure. See `SECURITY.md`.

## Install

**End users** — install the tagged release straight from GitHub:

```bash
git clone https://github.com/Lazarus-AI/clearwing.git
cd clearwing

# uv sync is recommended because Clearwing pins genai-pyo3 through
# tool.uv.sources in pyproject.toml.
uv sync --all-extras
source .venv/bin/activate  # fish: source .venv/bin/activate.fish

# Interactive setup wizard — menu-driven provider selection,
# credential entry, optional live test, persists to ~/.clearwing/config.yaml
clearwing setup

# Environment check — verifies Python, credentials, Docker daemon,
# external tools, optional extras, and network reachability
clearwing doctor

clearwing --version   # 1.0.0
clearwing --help
```

Or skip the wizard and configure directly:

```bash
# Anthropic direct
export ANTHROPIC_API_KEY=sk-ant-...

# Or any OpenAI-compatible endpoint — OpenRouter, Ollama, LM Studio,
# vLLM, Together, Groq, DeepSeek, OpenAI:
export CLEARWING_BASE_URL=https://openrouter.ai/api/v1
export CLEARWING_API_KEY=sk-or-...
export CLEARWING_MODEL=anthropic/claude-opus-4
```

See [`docs/providers.md`](docs/providers.md) for provider-specific
recipes and per-task routing.

**Developers** — clone and install the locked development environment:

```bash
git clone https://github.com/Lazarus-AI/clearwing.git
cd clearwing
uv sync --all-extras
source .venv/bin/activate  # fish: source .venv/bin/activate.fish
clearwing --help
```

Requirements: Python 3.10+ and optionally Docker for the Kali container
and sanitizer-image sandbox features. `genai-pyo3` ships as prebuilt
wheels on PyPI (linux x86_64/aarch64, macOS universal2, windows x86_64,
Python 3.9–3.13), so no Rust toolchain is needed for installation.

## Quickstart

```bash
# Network scan a single target
clearwing scan 192.168.1.10 -p 22,80,443 --detect-services

# Source-code hunt a repo (standard depth — sandboxed LLM hunters,
# adversarial verifier, mechanism memory, variant loop)
clearwing sourcehunt https://github.com/example/project \
    --depth standard

# N-day exploit pipeline — build and exploit known CVEs
clearwing sourcehunt https://github.com/example/project \
    --nday --cve-list CVE-2024-1234,CVE-2024-5678

# Reverse engineering — hunt vulnerabilities in closed-source binaries
clearwing sourcehunt /path/to/binary --reveng --arch x86_64

# Campaign-scale orchestration across multiple projects
clearwing campaign run campaign.yaml

# Responsible disclosure workflow
clearwing disclose queue ./results/sourcehunt/sh-*/
clearwing disclose review

# OSS-Fuzz crash severity benchmark
clearwing bench ossfuzz --corpus-dir ./oss-fuzz-projects --mode standard

# A/B test whether preprocessing helps or hurts
clearwing eval preprocessing --project https://github.com/example/project \
    --configs glasswing_minimal,sourcehunt_full --runs 3

# Interactive ReAct chat with the full tool set
clearwing interactive

# Non-interactive CI mode with SARIF output for GitHub Code Scanning
clearwing ci --config .clearwing.ci.yaml --sarif results.sarif
```

See [`docs/quickstart.md`](docs/quickstart.md) for a fuller walkthrough
including credentials, session resume, and mission-mode operation.

## Running sourcehunt on a local repo (FFmpeg example)

The `clearwing sourcehunt <url>` CLI clones a remote URL. To hunt an
already-cloned tree (e.g. FFmpeg) with the native-async pipeline and a
self-hosted OpenAI-compatible backend, drive `SourceHuntRunner` directly:

```bash
# 1. Clone the target once
git clone https://github.com/FFmpeg/FFmpeg.git

# 2. Run sourcehunt against the local checkout
uv run python -u - <<'PY'
import logging
from clearwing.llm.native import AsyncLLMClient
from clearwing.sourcehunt.runner import SourceHuntRunner

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(name)s: %(message)s')

REPO = './FFmpeg'
RUN_DIR = './results/sourcehunt'
COMMON = dict(
    provider_name='openai_resp',            # or 'openai' for /v1/chat/completions
    api_key='YOUR_KEY',
    base_url='http://localhost:8183/v1',    # any OpenAI-compatible endpoint
    max_concurrency=15,
)

# One client per stage — routes each stage to a different model
ranker_llm    = AsyncLLMClient(model_name='gpt-5.4-mini',  **COMMON)
hunter_llm    = AsyncLLMClient(model_name='gpt-5.4',       **COMMON)
verifier_llm  = AsyncLLMClient(model_name='gpt-5.4-mini',  **COMMON)
exploiter_llm = AsyncLLMClient(model_name='gpt-5.3-codex', **COMMON)

runner = SourceHuntRunner(
    repo_url=REPO, local_path=REPO,
    depth='standard',
    budget_usd=1000.0,
    max_parallel=15,
    output_dir=RUN_DIR,
    output_formats=['json', 'markdown'],
    ranker_llm=ranker_llm,
    hunter_llm=hunter_llm,
    verifier_llm=verifier_llm,
    exploiter_llm=exploiter_llm,
    enable_patch_oracle=True,
)

print(runner.run())   # sync wrapper; internally drives SourceHuntRunner.arun()
PY
```

Findings land in `./results/sourcehunt/sh-<session-id>/` as JSON +
markdown once the run completes. FFmpeg is ~10k source files, so expect the
large-repo ranker to preselect candidates and the tier-A hunter pool to run for hours.
Redirect stdout/stderr to a file if you plan to detach the process — the
runner's own artifacts are only written at the end.

`AsyncLLMClient` accepts `provider_name` values `openai_resp` (the streaming
`/v1/responses` shape) or `openai` (standard `/v1/chat/completions`); point
`base_url` at any OpenAI-compatible server. See
[`docs/providers.md`](docs/providers.md) for the managed-provider paths.

## Architecture at a glance

```
┌──────────────────────┐      ┌────────────────────────────────┐
│ Network-pentest agent│      │ Source-code hunter             │
│ clearwing.agent.graph│      │ clearwing.sourcehunt.runner    │
│  (63 tools, ReAct)   │      │                                │
│                      │      │ preprocess → rank → pool →     │
│                      │      │   hunter → verify → exploit →  │
│                      │      │   variant loop → auto-patch →  │
│                      │      │   report                       │
└─────────┬────────────┘      └────────┬───────────────────────┘
          │                             │
          └───────────┬─────────────────┘
                      ▼
┌───────────────────────────────────────────────────────────────┐
│ N-day pipeline │ Reveng pipeline │ Campaign orchestrator      │
│ Disclosure workflow + SHA-3 commitments                       │
├───────────────────────────────────────────────────────────────┤
│                    Shared substrate                          │
│  Finding dataclass  │  capabilities probe  │  sandbox layer  │
│  knowledge graph    │  episodic memory     │  event bus      │
│  telemetry          │  guardrails + audit  │  CVSS scoring   │
│  artifact store     │  behavior monitor    │  seccomp        │
├───────────────────────────────────────────────────────────────┤
│  Bench: OSS-Fuzz severity ladder  │  Eval: preprocessing A/B │
└───────────────────────────────────────────────────────────────┘
```

Deep dives live in [`docs/`](docs/):

| Doc | What it covers |
|---|---|
| [`docs/index.md`](docs/index.md) | Landing page + table of contents |
| [`docs/quickstart.md`](docs/quickstart.md) | Full install + first run walkthrough |
| [`docs/providers.md`](docs/providers.md) | OpenRouter / Ollama / LM Studio / vLLM / Together / Groq recipes, per-task routing, env-var precedence |
| [`docs/architecture.md`](docs/architecture.md) | Both pipelines, substrate, capability gating, tool layout |
| [`docs/cli.md`](docs/cli.md) | Every subcommand flag, grouped by workflow |
| [`docs/api.md`](docs/api.md) | API reference (mkdocstrings autogen) |

Once the GitHub Pages workflow ships, docs will be hosted at
<https://lazarus-ai.github.io/clearwing/>.

## Development

```bash
uv sync --all-extras
source .venv/bin/activate  # fish: source .venv/bin/activate.fish
pytest -q
ruff check clearwing/ tests/
ruff format --check clearwing/ tests/
mypy --follow-imports=silent \
  clearwing/findings \
  clearwing/sourcehunt \
  clearwing/capabilities.py \
  clearwing/agent/tools \
  clearwing/core
python -m mkdocs serve --dev-addr 127.0.0.1:8000
```

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full dev-setup guide and PR
checklist.

## Reporting vulnerabilities

There are two lanes, and they go to different places:

- **Vulnerabilities *in* Clearwing** → GitHub Security Advisories
  (<https://github.com/Lazarus-AI/clearwing/security/advisories/new>).
  See [`SECURITY.md`](SECURITY.md) for scope, SLA, and safe-harbor.
- **Vulnerabilities Clearwing *finds* in someone else's software** →
  that vendor's disclosure channel. `clearwing sourcehunt
  --export-disclosures` generates pre-filled MITRE CVE-request and
  HackerOne templates for every finding at
  `evidence_level >= root_cause_explained`.

## License

MIT. See [`LICENSE`](LICENSE).
