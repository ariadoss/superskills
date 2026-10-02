#!/usr/bin/env bats
# Contract pins for the vendored Shannon snapshot (vendor/shannon) that
# skills/pentest Mode 5 runs on the calling agent. Every test here guards a
# fact the agent-driven integration relies on; a vendored-tree refresh
# (scripts/sync-shannon.sh) that moves any of them must fail here before it
# reaches a user's scan. This is the drift detector: upstream releasing a new
# version changes nothing until someone runs the sync script, and the sync
# output that breaks these pins is rejected by ./tests/run.sh.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  VENDOR="$REPO_ROOT/vendor/shannon"
}

@test "the vendor snapshot exists with provenance and a pinned upstream revision" {
  [ -f "$VENDOR/UPSTREAM" ] || { echo "missing vendor/shannon/UPSTREAM"; return 1; }
  [ -f "$VENDOR/LICENSE" ] || { echo "missing vendor/shannon/LICENSE (AGPL)"; return 1; }
  grep -qF 'https://github.com/KeygraphHQ/shannon' "$VENDOR/UPSTREAM" || false
  grep -qF 'v3.3.0' "$VENDOR/UPSTREAM" || false
  grep -qF '327c10fd90a6186a9f035b4b6ddb5bbba1839e92' "$VENDOR/UPSTREAM" || false
  grep -qi 'AGPL' "$VENDOR/UPSTREAM" || false
  # Refreshes are deliberate, never automatic — the pin is the point.
  grep -qF 'never auto' "$VENDOR/UPSTREAM" || false
}

@test "the CLI forwards SHANNON_AI_MODEL and the generic API key into the scan container" {
  # The container only sees vars the CLI forwards by name; our bridge config
  # rides SHANNON_AI_MODEL + SHANNON_AI_API_KEY (any non-empty placeholder is
  # accepted for a non-curated provider — pinned in the env test below).
  grep -qF "'SHANNON_AI_MODEL'" "$VENDOR/apps/cli/src/env.ts" || false
  grep -qF "GENERIC_API_KEY_ENV" "$VENDOR/apps/cli/src/env.ts" || false
  grep -qF "SHANNON_AI_API_KEY" "$VENDOR/apps/worker/src/ai/models.ts" || false
}

@test "a non-curated provider needs only a non-empty generic key (no format check)" {
  # hasCredential(): curated providers have named keys; everything else falls
  # back to Boolean(SHANNON_AI_API_KEY). If this branch disappears, the
  # placeholder credential stops validating and every agent-driven run dies
  # at preflight.
  grep -qF 'return Boolean(process.env[GENERIC_API_KEY_ENV])' "$VENDOR/apps/cli/src/env.ts" || false
}

@test "start accepts --models-config — the custom-provider entry point our bridge uses" {
  grep -qF "'--models-config <path>'" "$VENDOR/apps/cli/src/help.ts" || false
  grep -qF "modelsConfig: ['--models-config']" "$VENDOR/apps/cli/src/index.ts" || false
  # The worker merges that file over its catalogue, so an unknown provider id
  # (calling-agent) resolves.
  grep -qF 'MODELS_CONFIG_PATH' "$VENDOR/apps/worker/src/ai/models.ts" || false
}

@test "the scan container reaches the host through host.docker.internal" {
  # macOS Docker Desktop has it built in; the CLI adds the host-gateway mapping
  # on Linux. If this disappears, the container cannot see the host-side
  # bridge and every request dies on connection refused.
  grep -qF 'host.docker.internal:host-gateway' "$VENDOR/apps/cli/src/docker.ts" || false
}

@test "the local entry point runs the CLI from this tree, not from npx" {
  # ./shannon sets SHANNON_LOCAL=1 and imports apps/cli/dist — running from
  # the vendored tree is what makes the pin real (no npx fetch, no Docker Hub
  # tag drift; the worker image builds from the vendored Dockerfile).
  grep -qF 'SHANNON_LOCAL' "$VENDOR/shannon" || false
  grep -qF './apps/cli/dist/index.mjs' "$VENDOR/shannon" || false
}

@test "the pi harness version is locked, so the chat-completions wire contract is reproducible" {
  # The bridge speaks OpenAI chat completions because pi's 'openai-completions'
  # api does; that implementation is the npm dep @earendil-works/pi-ai, pinned
  # by the committed lockfile. A lockfile without the pin = unverifiable wire.
  grep -q "@earendil-works/pi-ai" "$VENDOR/pnpm-lock.yaml" || false
}

@test "the launcher declares the openai-completions api and the placeholder credential" {
  LAUNCHER="$REPO_ROOT/skills/pentest/shannon-agent-driven.sh"
  [ -f "$LAUNCHER" ] || { echo "missing launcher"; return 1; }
  # models.json must declare the chat-completions dialect our bridge serves…
  grep -qF '"openai-completions"' "$LAUNCHER" || false
  # …address the container, not the host loopback…
  grep -qF 'host.docker.internal' "$LAUNCHER" || false
  # …and satisfy the credential gate with a placeholder, never a real key.
  grep -qF 'SHANNON_AI_API_KEY=agent-bridge' "$LAUNCHER" || false
  grep -qF 'SHANNON_AI_MODEL=calling-agent:calling-agent' "$LAUNCHER" || false
}

@test "the launcher keeps the CLI alive for the whole scan (--follow)" {
  # Shannon's start command WITHOUT --follow prints 'Scan started' and
  # returns while the scan continues in the Temporal worker container
  # (vendored start.ts: 'if (args.follow) await followScan(...)'; else
  # return). The launcher's liveness check and its 'when the scan exits'
  # guidance both assume the CLI process lives for the scan — so it must
  # pass --follow or it kills the bridge mid-scan on the happy path.
  grep -qF -- '--follow' "$REPO_ROOT/skills/pentest/shannon-agent-driven.sh" || false
}

@test "URL rewriting replaces the 127.0.0.1 literal, on every OS" {
  # bridge.url ALWAYS carries 127.0.0.1 (loopback is reachable under every
  # bind), while on Linux the bridge binds the docker0 IP. Rewriting by
  # \$BIND was a no-op there — the readiness probe curled 127.0.0.1 into a
  # socket bound to 172.17.0.1 and every Linux run died at readiness, and
  # models.json would have handed the container its own loopback.
  grep -qF 'DOCKER_BASE_URL="${BASE_URL/127.0.0.1/host.docker.internal}"' \
    "$REPO_ROOT/skills/pentest/shannon-agent-driven.sh" || false
  grep -qF '${BASE_URL/127.0.0.1/$BIND}' \
    "$REPO_ROOT/skills/pentest/shannon-agent-driven.sh" || false
}

@test "the workspace flag travels as one argument, spaces included" {
  # -w "My Scans/ws" word-split into two args when the flag string was
  # expanded unquoted; the array form (with the bash-3.2 set -u guard for
  # the empty case) is the fix.
  grep -qF 'WS_FLAG=(-w "$WS")' "$REPO_ROOT/skills/pentest/shannon-agent-driven.sh" || false
  grep -qF '${WS_FLAG[@]+"${WS_FLAG[@]}"}' "$REPO_ROOT/skills/pentest/shannon-agent-driven.sh" || false
}

@test "run refuses to launch before the vendored CLI is built, naming the fix" {
  # The vendored tree ships source only; dist/ appears after 'prepare'. A run
  # must fail on that fact alone, before any Docker or bridge work.
  command -v python3 >/dev/null 2>&1 || skip "python3 not installed"
  run "$REPO_ROOT/skills/pentest/shannon-agent-driven.sh" run -u http://127.0.0.1 -r "$REPO_ROOT"
  [ "$status" -ne 0 ] || { echo "run should fail on an unbuilt vendored CLI"; return 1; }
  case "$output" in
    *"prepare' first"*) : ;;
    *) echo "unexpected refusal: $output"; return 1 ;;
  esac
}

@test "teardown kills the real bridge, verifies the PID names it, and removes the spool" {
  command -v python3 >/dev/null 2>&1 || skip "python3 not installed"
  command -v curl >/dev/null 2>&1 || skip "curl not installed"
  SPOOL="$(mktemp -d)"
  PORT=$((20000 + RANDOM % 20000))
  python3 "$REPO_ROOT/skills/pentest/agent-bridge.py" "$SPOOL" "$PORT" 30 >/dev/null 2>&1 &
  local bpid=$!
  for _ in $(seq 1 100); do
    if [ -f "$SPOOL/bridge.url" ]; then break; fi
    sleep 0.1
  done
  [ -f "$SPOOL/bridge.url" ] || { kill "$bpid" 2>/dev/null; rm -rf "$SPOOL"; return 1; }
  touch "$SPOOL/req-1.json"   # the target's source — teardown must remove it
  run "$REPO_ROOT/skills/pentest/shannon-agent-driven.sh" teardown "$SPOOL"
  [ "$status" -eq 0 ] || false
  [ ! -d "$SPOOL" ] || { echo "spool survived teardown"; kill "$bpid" 2>/dev/null; return 1; }
  if kill -0 "$bpid" 2>/dev/null; then
    kill "$bpid" 2>/dev/null
    echo "bridge survived teardown"; return 1
  fi
  # A stale/recycled PID that no longer names agent-bridge must not be killed.
  SPOOL2="$(mktemp -d)"; echo "1" > "$SPOOL2/bridge.pid"
  run "$REPO_ROOT/skills/pentest/shannon-agent-driven.sh" teardown "$SPOOL2"
  [ "$status" -eq 0 ] || false
  [ ! -d "$SPOOL2" ] || return 1
}
