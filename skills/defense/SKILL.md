---
name: defense
description: |
  Defense-in-depth security validation — multi-layered checks for OWASP Top 10, secrets, auth, crypto, and data protection.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
---

# Defense in Depth — Security Validation

Multi-layered security audit for web applications. Runs checks across 8 security layers.

## Workflow

Run each layer sequentially. Report findings with severity (CRITICAL / HIGH / MEDIUM / LOW) and file:line references.

## Layer 1: Secrets Scanning

Search for hardcoded secrets, API keys, tokens, and credentials.

```bash
grep -rn "API_KEY\|SECRET_KEY\|DATABASE_URL\|PRIVATE_KEY\|password\s*=\|sk_live\|sk_test" . \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.env" \
  | grep -v node_modules | grep -v ".next" | grep -v ".env.example" | grep -v __pycache__
```

Check:
- No secrets in source code (should be in `.env` only)
- `.env` is in `.gitignore`
- No secrets in git history: `git log --all -p -S "sk_live\|API_KEY\|SECRET" -- . ':!.env*' | head -50`

## Layer 2: Authentication & Authorization

- **Session handling**: Token expiry, httpOnly/secure/sameSite cookies, invalidation on logout
- **Route protection**: Every API route checks auth before processing
- **Role enforcement**: Different user types can only access their own resources
- **IDOR prevention**: Resource access scoped by authenticated user

```bash
# Find potentially unprotected API routes
find . -path "*/api/*/route.ts" -o -path "*/api/*/route.js" | xargs grep -L "auth\|session\|token\|verify" 2>/dev/null
```

## Layer 3: Input Validation

- All user inputs validated (schemas, type checks)
- No raw SQL — use parameterized queries / ORM only
- No command injection via string interpolation in shell calls
- File uploads have type/size restrictions
- URL parameters sanitized

```bash
# Check for template literal SQL or shell commands
grep -rn "exec(\`\|sql\`\|query(\`" . --include="*.ts" --include="*.js" | grep -v node_modules
```

## Layer 4: Encryption

- **At rest**: Sensitive data encrypted in database
- **In transit**: HTTPS enforced, no HTTP fallbacks
- **Key management**: Keys in env vars, not source code, not logged

## Layer 5: OWASP Top 10

| # | Risk | What to Check |
|---|------|---------------|
| A01 | Broken Access Control | Resource isolation, role checks, IDOR |
| A02 | Cryptographic Failures | PII encryption, key management |
| A03 | Injection | SQL, command, template injection |
| A04 | Insecure Design | Business logic flaws |
| A05 | Security Misconfiguration | Default creds, verbose errors, debug mode |
| A06 | Vulnerable Components | `npm audit`, outdated dependencies |
| A07 | Auth Failures | Session management, brute force protection |
| A08 | Data Integrity | Webhook signatures, CSRF tokens |
| A09 | Logging Failures | Audit trail, no PII in logs |
| A10 | SSRF | URL validation on server-side requests |

```bash
# Dependency vulnerabilities
npm audit --production 2>/dev/null | head -50
```

## Layer 6: API Security

- Webhook signature verification (Stripe, etc.)
- API keys not exposed to client-side code
- Rate limiting on public endpoints
- CORS properly configured
- Content-Type validation

## Layer 7: Rate Limiting & DoS Protection

- API routes have rate limiting
- Login endpoints have brute force protection
- File upload size limits enforced
- Expensive operations throttled

## Layer 8: Sensitive Data Protection

- PII never logged
- PII not exposed in error messages
- Sensitive fields excluded from API responses
- Data retention policies enforced

```bash
# Check for PII in logs
grep -rn "console\.\(log\|error\|warn\).*\(password\|ssn\|social\|secret\|token\)" . \
  --include="*.ts" --include="*.js" | grep -v node_modules
```

## Report Format

```
## Security Audit Report

### Critical Findings
- [CRITICAL] Description — file:line

### High Findings
- [HIGH] Description — file:line

### Medium/Low Findings
- [MEDIUM/LOW] Description — file:line

### Passed Checks
- [PASS] Layer description
```
