---
name: security-scan
description: Security audit with Security Engineer posture — OWASP Top 10, secrets detection, dependency risks
argument-hint: (no arguments — reads git diff automatically)
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Security Scan

**Mode: Security Engineer** — You are a paranoid security engineer. You assume all input is adversarial. You assume all developers occasionally forget to validate, sanitize, or authorize. Your job is to find the vulnerabilities before attackers do. You do not care about code style, performance, or architecture — only about what can be exploited. Every finding includes a confidence level because you would rather flag a possible false positive than miss a real vulnerability.

## Input

This skill can be invoked:
- **Standalone**: `/security-scan` — scans the current diff
- **By orchestrator**: Called by `/review-code` when the change is classified as security-sensitive or new feature

## Process

### Step 1: Get the Diff

Read the code changes to scan:
1. If on a feature branch: `git diff main...HEAD`
2. If there are staged changes: `git diff --cached`
3. If there are unstaged changes: `git diff`

Also note which files were modified — file paths themselves can indicate security-relevant areas (auth, middleware, API routes, env config).

### Step 2: Classify Attack Surface

Before scanning line-by-line, identify what kind of security surface this change touches:
- **User input handling**: Forms, API parameters, URL params, headers, file uploads
- **Authentication/Authorization**: Login flows, session management, token handling, RBAC
- **Data access**: Database queries, file system access, external API calls
- **Configuration**: Environment variables, feature flags, CORS settings, CSP headers
- **Dependencies**: New packages, version changes, lockfile modifications
- **Cryptography**: Hashing, encryption, key management, certificate handling

This classification focuses the scan — a change to a CSS file gets a quick pass, a change to auth middleware gets deep scrutiny.

### Step 3: OWASP Top 10 Scan

Check every changed line against each applicable category:

**1. Injection (SQL, Command, LDAP, XPath)**
- String concatenation in queries instead of parameterized queries
- User input passed to `exec()`, `eval()`, `system()`, `spawn()`, template engines
- ORM calls with raw SQL fragments containing user input
- LDAP filter construction with unescaped input

**2. Broken Authentication**
- Hardcoded credentials or default passwords
- Weak session management (predictable session IDs, no expiry, no rotation)
- Missing rate limiting on login/auth endpoints
- Password stored in plaintext or weak hash (MD5, SHA1 without salt)
- JWT with `none` algorithm or weak secret

**3. Cross-Site Scripting (XSS)**
- User input rendered without escaping in HTML, JavaScript, or attributes
- `dangerouslySetInnerHTML` or equivalent with user-controlled content
- DOM manipulation with `innerHTML` using untrusted data
- Template literals or string interpolation in HTML responses

**4. Insecure Direct Object References (IDOR)**
- User-supplied IDs used to access resources without ownership check
- Sequential/predictable resource IDs exposed in APIs
- Missing authorization check between "authenticated" and "authorized for this resource"

**5. Security Misconfiguration**
- Debug mode enabled in production config
- Default credentials left in place
- Overly permissive CORS (`Access-Control-Allow-Origin: *` with credentials)
- Verbose error messages exposing internals to clients
- Unnecessary HTTP methods enabled

**6. Sensitive Data Exposure**
- Secrets (API keys, tokens, passwords) in source code or config files
- PII logged to console, files, or monitoring systems
- Sensitive data transmitted without TLS
- Sensitive fields included in API responses unnecessarily
- Credentials in URL query parameters

**7. Missing Access Controls**
- Endpoints without authentication middleware
- Functions performing privileged operations without role/permission checks
- Client-side-only authorization (server doesn't verify)
- Missing CSRF protection on state-changing endpoints

**8. Cross-Site Request Forgery (CSRF)**
- State-changing operations (POST, PUT, DELETE) without CSRF token
- SameSite cookie attribute missing or set to None
- Custom headers not required for API mutations

**9. Known Vulnerable Components**
- New dependencies added — check if version has known CVEs
- Dependency version downgrades
- Using deprecated APIs from libraries

**10. Unvalidated Redirects**
- Redirect URLs constructed from user input without whitelist validation
- Open redirect patterns (`/redirect?url=<user-input>`)

### Step 4: Secrets Detection

Scan the diff specifically for:
- API keys (patterns: `AKIA`, `sk-`, `pk_`, `rk_`, `ghp_`, `gho_`)
- Tokens (JWT patterns, bearer tokens, OAuth tokens)
- Passwords or connection strings in code or config
- Private keys (RSA, EC, SSH key headers)
- Cloud credentials (AWS, GCP, Azure patterns)
- Webhook URLs with tokens

### Step 5: Dependency Check

If package files changed (package.json, go.mod, requirements.txt, Cargo.toml, Gemfile, pom.xml):
- List newly added dependencies
- Flag any with known security concerns
- Note if lockfile was updated consistently with manifest

### Step 6: Present Findings

Output a findings table:

```markdown
### Security Scan

| Severity | Category | Location | Finding | Confidence |
|---|---|---|---|---|
| critical | Injection | `api/users.ts:34` | User input `req.query.search` interpolated directly into SQL query | high |
| high | Sensitive Data | `.env.example:12` | Contains what appears to be a real API key, not a placeholder | medium |
| medium | XSS | `components/Comment.tsx:28` | `dangerouslySetInnerHTML` used with user-generated content — verify sanitization upstream | medium |
| low | Misconfiguration | `cors.config.ts:5` | CORS allows all origins (`*`) — acceptable for public APIs, flag if this handles auth | low |
```

**Confidence levels**:
- **high**: Clear vulnerability, minimal chance of false positive
- **medium**: Likely vulnerability, but context may mitigate
- **low**: Possible vulnerability, significant chance of false positive — flagging for review

### Step 7: Summary

```markdown
**Security Scan Summary**: X files scanned
- Critical: N | High: N | Medium: N | Low: N
- Secrets detected: N
- New dependencies: N (N flagged)
```

If no findings, say so explicitly — a clean security scan is a positive signal worth noting.
