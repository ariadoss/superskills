---
name: vercel-cli-with-tokens
description: Deploy and manage projects on Vercel using token-based authentication. Use when working with Vercel CLI using access tokens rather than interactive login — e.g. "deploy to vercel", "set up vercel", "add environment variables to vercel".
metadata:
  author: vercel
  version: "1.0.0"
---

# Vercel CLI with Tokens

Deploy and manage projects on Vercel using the CLI with token-based authentication, without relying on `vercel login`.

## Step 1: Locate the Vercel Token

Before running any Vercel CLI commands, identify where the token is coming from. Work through these scenarios in order:

### A) `VERCEL_TOKEN` is already set in the environment

```bash
printenv VERCEL_TOKEN
```

If this returns a value, you're ready. Skip to Step 2.

### B) Token is in a `.env` file under `VERCEL_TOKEN`

```bash
grep '^VERCEL_TOKEN=' .env 2>/dev/null
```

If found, export it:

```bash
export VERCEL_TOKEN=$(grep '^VERCEL_TOKEN=' .env | cut -d= -f2-)
```

### C) Token is in a `.env` file under a different name

Look for any variable that looks like a Vercel token (Vercel tokens typically start with `vca_`):

```bash
grep -i 'vercel' .env 2>/dev/null
```

Inspect the output to identify which variable holds the token, then export it as `VERCEL_TOKEN`:

```bash
export VERCEL_TOKEN=$(grep '^<VARIABLE_NAME>=' .env | cut -d= -f2-)
```

### D) No token found — ask the user

If none of the above yield a token, ask the user to provide one. They can create a Vercel access token at vercel.com/account/tokens.

---

**Important:** Once `VERCEL_TOKEN` is exported as an environment variable, the Vercel CLI reads it natively — **do not pass it as a `--token` flag**. Putting secrets in command-line arguments exposes them in shell history and process listings.

```bash
# Bad — token visible in shell history and process listings
vercel deploy --token "vca_abc123"

# Good — CLI reads VERCEL_TOKEN from the environment
export VERCEL_TOKEN="vca_abc123"
vercel deploy
```

## Step 2: Locate the Project and Team

```bash
# Check environment
printenv VERCEL_PROJECT_ID
printenv VERCEL_ORG_ID

# Or check .env
grep -i 'vercel' .env 2>/dev/null
```

**If you have a project URL** (e.g. `https://vercel.com/my-team/my-project`), extract the team slug:

```bash
echo "$PROJECT_URL" | sed 's|https://vercel.com/||' | cut -d/ -f1
```

**If you have both `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID` in your environment**, export them — the CLI will use these automatically:

```bash
export VERCEL_ORG_ID="<org-id>"
export VERCEL_PROJECT_ID="<project-id>"
```

Note: `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID` must be set together — setting only one causes an error.

## CLI Setup

Ensure the Vercel CLI is installed and up to date:

```bash
npm install -g vercel
vercel --version
```

## Deploying a Project

Always deploy as **preview** unless the user explicitly requests production.

### Quick Deploy (have project ID — no linking needed)

```bash
vercel deploy -y --no-wait
vercel deploy --scope <team-slug> -y --no-wait
vercel deploy --prod --scope <team-slug> -y --no-wait  # production only if explicitly requested
```

Check status:

```bash
vercel inspect <deployment-url>
```

### Full Deploy Flow (no project ID — need to link)

```bash
# Check git remote and link state
git remote get-url origin 2>/dev/null
cat .vercel/project.json 2>/dev/null || cat .vercel/repo.json 2>/dev/null

# Link with git remote (preferred)
vercel link --repo --scope <team-slug> -y

# Link without git remote
vercel link --scope <team-slug> -y

# Link to specific project
vercel link --project <project-name> --scope <team-slug> -y
```

Then deploy via git push (if remote exists) or `vercel deploy -y --no-wait`.

## Managing Environment Variables

```bash
# Set for all environments
echo "value" | vercel env add VAR_NAME --scope <team-slug>

# Set for a specific environment (production, preview, development)
echo "value" | vercel env add VAR_NAME production --scope <team-slug>

# List environment variables
vercel env ls --scope <team-slug>

# Pull env vars to local .env.local file
vercel env pull --scope <team-slug>

# Remove a variable
vercel env rm VAR_NAME --scope <team-slug> -y
```

## Inspecting Deployments

```bash
# List recent deployments
vercel ls --format json --scope <team-slug>

# Inspect a specific deployment
vercel inspect <deployment-url>

# View build logs (requires Vercel CLI v35+)
vercel inspect <deployment-url> --logs

# View runtime request logs
vercel logs <deployment-url>
```

## Working Agreement

- **Never pass `VERCEL_TOKEN` as a `--token` flag.** Export it as an environment variable and let the CLI read it natively.
- **Check the environment for tokens before asking the user.** Look in the current env and `.env` files first.
- **Default to preview deployments.** Only deploy to production when explicitly asked.
- **Ask before pushing to git.** Never push commits without the user's approval.
- **Do not modify `.vercel/` files directly.** The CLI manages this directory. Reading them is fine.
- **Do not curl/fetch deployed URLs to verify.** Just return the link to the user.
- **Use `--format json`** when structured output will help with follow-up steps.
- **Use `-y`** on commands that prompt for confirmation to avoid interactive blocking.

## Troubleshooting

### Token not found

```bash
printenv | grep -i vercel
grep -i vercel .env 2>/dev/null
```

### Authentication error

If the CLI fails with `Authentication required`:
- The token may be expired or invalid.
- Verify: `vercel whoami` (uses `VERCEL_TOKEN` from environment).
- Ask the user for a fresh token.

### Wrong team

```bash
vercel whoami --scope <team-slug>
```

### Build failure

```bash
vercel inspect <deployment-url> --logs
```

Common causes:
- Missing dependencies — ensure `package.json` is complete and committed.
- Missing environment variables — add with `vercel env add`.
- Framework misconfiguration — check `vercel.json`.

### CLI not installed

```bash
npm install -g vercel
```
