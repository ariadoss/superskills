---
name: iac-scan
version: 1.0.0
description: |
  Infrastructure-as-Code security scan for changed deploy config — Dockerfiles,
  docker-compose, Terraform, Kubernetes/Helm, and CI/CD workflows. Flags
  misconfigurations and exposed secrets (root containers, open ingress, wildcard
  IAM, privileged pods, untrusted CI triggers). Static diff-scoped analysis (safe
  to auto-run); uses tfsec/checkov/hadolint/actionlint when present. Use when asked
  to "scan infra", "IaC scan", "check the Dockerfile/terraform/k8s", "CI security",
  or after changing deploy/infra config.
triggers:
  - iac scan
  - scan infra
  - infrastructure scan
  - check the dockerfile
  - terraform security
  - kubernetes security
  - ci security review
argument-hint: '<optional: paths/globs to scope (defaults to changed infra files)>'
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Task
  - WebFetch
---

# /iac-scan

Scan changed infrastructure/deploy config for security misconfigurations and
exposed secrets. **Static and read-only** — analyzes the files directly (safe to
auto-run); shells out to dedicated scanners only if they're already installed.

## Hard rules

- **Evidence-grounded:** file:line, the offending directive, the rule/CWE, and the
  concrete risk ("container runs as root", "0.0.0.0/0 on port 22", "secret baked
  into image layer").
- **Severity by blast radius:** internet-exposed, privilege-escalating, or
  secret-leaking misconfigs are CRITICAL/HIGH; style/pinning nits are LOW.
- **Smallest correct fix**, shown as a diff; do not apply it.
- **Scope to the changed infra files.** Don't re-scan the whole tree.
- **Prefer real scanners when present** (tfsec, checkov, hadolint, kube-score,
  actionlint, trivy); fall back to the signature checks below when they're absent —
  and say which mode ran.

## Trigger (what counts as infra/deploy config)

- Containers: `Dockerfile`, `*.dockerfile`, `docker-compose*.y*ml`, `.dockerignore`
- Terraform: `*.tf`, `*.tfvars`
- Kubernetes / Helm: `*.y*ml` with `kind:` under `k8s/`, `manifests/`, `charts/`,
  `helm/`, or `deploy/`
- CI/CD: `.github/workflows/**`, `.gitlab-ci.yml`, `Jenkinsfile`, `*.circleci/*`
- Web/proxy/cloud: `nginx.conf`, `Caddyfile`, `*.tf` cloud resources, `serverless.yml`

If none of these changed, say so and stop.

## What to check

**Docker** — non-root `USER`; pinned base image (no `:latest`); no secrets in
`ENV`/`ARG`/layers; no `ADD http://…`; minimal surface; `HEALTHCHECK`; no
unnecessary `EXPOSE`; `--no-install-recommends`/cleaned caches. *(hadolint)*

**docker-compose** — no `privileged: true`; no `network_mode: host`; never bind
`/var/run/docker.sock`; secrets via `secrets:` not `environment:`; pinned image tags.

**Terraform** — no security-group/firewall `0.0.0.0/0` on sensitive ports
(22/3389/DB); no public buckets/blobs; no IAM `Action: "*"` / `Resource: "*"`;
encryption at rest + in transit enabled; no hardcoded secrets/keys; remote state
with locking; logging/versioning on. *(tfsec / checkov)*

**Kubernetes / Helm** — `runAsNonRoot`, drop `privileged`/`allowPrivilegeEscalation`;
no `hostPath`/`hostNetwork`/`hostPID`; resource `limits`/`requests` set;
`readOnlyRootFilesystem`; no `default` ServiceAccount with broad RBAC / `cluster-admin`;
pinned image digests; NetworkPolicy present; no secrets in plain env. *(kube-score / kubesec)*

**CI/CD (GitHub Actions et al.)** — no `pull_request_target` running untrusted PR
code; least-privilege top-level `permissions:`; third-party actions pinned to a
**full commit SHA** (not a moving tag); no script injection via unsanitized
`${{ github.event.* }}` in `run:`; secrets never `echo`ed; no `persist-credentials`
left on when not needed. *(actionlint + zizmor)*

**Web/proxy** — TLS enforced; security headers (HSTS, CSP, X-Content-Type-Options);
no directory listing; no server tokens leaking versions.

## Steps

1. **Scope** — resolve changed infra files (or `$ARGUMENTS`). None → stop.
2. **Tool pass** — for each file type, if the matching scanner is installed, run it
   scoped to the changed files and capture findings verbatim. Note which tools ran.
3. **Signature pass** — for file types with no installed scanner, Grep/Read for the
   patterns above. Mark these **Observed** (clear match) vs **Suspected**.
4. **Secrets sweep** — across all changed infra files, flag high-entropy strings,
   `AKIA…`, private keys, tokens, `password=`/`secret=` literals. (Complements
   `/defense`'s app-code secret scan.)
5. **Report** — group by severity; smallest fix per finding as a diff.

## Report format

```markdown
# IaC scan — <scope> @ <date>

Scanners run: hadolint ✓ / tfsec ✗ (signature mode) / actionlint ✓ …

## CRITICAL / HIGH
- <file:line> — <directive> — <rule/CWE> — <risk> — <fix>

## MEDIUM / LOW
- …

## Secrets
- <file:line> — <kind> — rotate + move to a secret manager
```

## Anti-patterns (do not do)

- Claiming a misconfig without quoting the directive and naming the risk.
- Scanning the whole repo instead of the changed infra files.
- Applying fixes or rewriting manifests — this scans and drafts; the user applies.
- Treating a pinning/style nit as CRITICAL, or burying an open-to-the-world port.

## Related commands

- `/defense` — app-code OWASP/secrets sweep; `/iac-scan` is its infra counterpart.
- `/pentest` — deeper external scanner; recommend after `/iac-scan` finds HIGH/CRITICAL
  or when a live environment needs probing.
- `/cso` — threat-model the deployment topology at design time (`/write-plan`).
