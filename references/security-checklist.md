# Security and Reliability Checklist

## Input/Output Safety

- **XSS**: Unsafe HTML injection, `dangerouslySetInnerHTML`, unescaped templates, innerHTML assignments
- **Injection**: SQL/NoSQL/command/GraphQL injection via string concatenation or template literals
- **SSRF**: User-controlled URLs reaching internal services without allowlist validation
- **Path traversal**: User input in file paths without sanitization (`../` attacks)
- **Prototype pollution**: Unsafe object merging in JavaScript (`Object.assign`, spread with user input)

## AuthN/AuthZ

- Missing tenant or ownership checks for read/write operations
- New endpoints without auth guards or RBAC enforcement
- Trusting client-provided roles/flags/IDs
- Broken access control (IDOR — Insecure Direct Object Reference)
- Session fixation or weak session management

## JWT & Token Security

- Algorithm confusion attacks (accepting `none` or `HS256` when expecting `RS256`)
- Weak or hardcoded secrets
- Missing expiration (`exp`) or not validating it
- Sensitive data in JWT payload (tokens are base64, not encrypted)
- Not validating `iss` (issuer) or `aud` (audience)

## Secrets and PII

- API keys, tokens, or credentials in code/config/logs
- Secrets in git history or environment variables exposed to client
- Excessive logging of PII or sensitive payloads
- Missing data masking in error messages

## Supply Chain & Dependencies

- Unpinned dependencies allowing malicious updates
- Dependency confusion (private package name collision)
- Importing from untrusted sources or CDNs without integrity checks
- Outdated dependencies with known CVEs

### Package Manager Consistency (Node.js)

> Only when Preflight detected `package.json` in scope.

#### Conflicting Lock Files (P1)
- Multiple lock files in same directory: `package-lock.json` + `yarn.lock`, `package-lock.json` + `pnpm-lock.yaml`, etc.
- Each lock file implies a different resolution algorithm — coexistence means different environments may install different dependency trees
- **Fix**: Delete the extra lock file(s), keep only the one matching the intended package manager, add others to `.gitignore`

#### packageManager Field Mismatch (P1)
- `package.json` declares `"packageManager": "pnpm@x.y.z"` but only `package-lock.json` (npm) exists, or vice versa
- Confuses Corepack, CI, and new contributors — declared intent contradicts actual tooling
- **Fix**: Align the `packageManager` field with the lock file in use, or switch to the declared package manager and regenerate the lock file

#### Missing Package Manager Enforcement (P2)
- Project uses a specific package manager but has no enforcement:
  - No `"preinstall": "npx only-allow <pm>"` in `package.json` scripts
  - No `packageManager` field for Corepack enforcement
- **Fix**: Add `"preinstall": "npx only-allow <pm>"` or set `packageManager` field and enable Corepack

#### Dockerfile Package Manager Mismatch (P1)
- Dockerfile uses `npm ci` but project uses pnpm/yarn (or vice versa)
- Also: `COPY package-lock.json` but actual lock file has different name
- **Fix**: Align Dockerfile install commands and COPY directives with the project's package manager

#### Questions to Ask
- "Is there exactly one lock file at each package root?"
- "Does the `packageManager` field match the lock file?"
- "Does the Dockerfile install command match the project's package manager?"

## CORS & Headers

- Overly permissive CORS (`Access-Control-Allow-Origin: *` with credentials)
- Missing security headers (CSP, X-Frame-Options, X-Content-Type-Options)
- Exposed internal headers or stack traces

## Runtime Risks

- Unbounded loops, recursive calls, or large in-memory buffers
- Missing timeouts, retries, or rate limiting on external calls
- Blocking operations on request path (sync I/O in async context)
- Resource exhaustion (file handles, connections, memory)
- ReDoS (Regular Expression Denial of Service)

## Cryptography

- Weak algorithms (MD5, SHA1 for security purposes)
- Hardcoded IVs or salts
- Using encryption without authentication (ECB mode, no HMAC)
- Insufficient key length

## Data Integrity

- Missing transactions, partial writes, or inconsistent state updates
- Weak validation before persistence (type coercion issues)
- Missing idempotency for retryable operations
- Lost updates due to concurrent modifications

---

## Race Conditions

Race conditions deserve special attention — they cause intermittent failures and security vulnerabilities that are hard to reproduce.

### Shared State Access
- Multiple threads/goroutines/async tasks accessing shared variables without synchronization
- Global state or singletons modified concurrently
- Lazy initialization without proper locking (double-checked locking issues)
- Non-thread-safe collections used in concurrent context

### Check-Then-Act (TOCTOU)
- `if (exists) then use` patterns without atomic operations
- `if (authorized) then perform` where authorization can change
- File existence check followed by file operation
- Balance check followed by deduction (financial operations)
- Inventory check followed by order placement

### Database Concurrency
- Missing optimistic locking (`version` column, `updated_at` checks)
- Missing pessimistic locking (`SELECT FOR UPDATE`)
- Read-modify-write without transaction isolation
- Counter increments without atomic operations (`UPDATE SET count = count + 1`)
- Unique constraint violations in concurrent inserts

### Distributed Systems
- Missing distributed locks for shared resources
- Leader election race conditions
- Cache invalidation races (stale reads after writes)
- Event ordering dependencies without proper sequencing
- Split-brain scenarios in cluster operations

### Dangerous Patterns

```
# TOCTOU
if not exists(key):
    create(key)

# Read-modify-write without atomicity
value = get(key)
value += 1
set(key, value)

# Check-then-act without lock
if user.balance >= amount:
    user.balance -= amount
```

### Questions to Ask
- "What happens if two requests hit this code simultaneously?"
- "Is this operation atomic or can it be interrupted?"
- "What shared state does this code access?"
- "How does this behave under high concurrency?"

---

## Language-Specific Security Flags

### JavaScript/TypeScript
- `eval()`, `Function()`, `setTimeout(string)` — code injection
- `innerHTML`, `document.write` — XSS
- `child_process.exec` with user input — command injection
- Prototype pollution via `Object.assign({}, userInput)`

### Go
- `fmt.Sprintf` in SQL queries — SQL injection
- `os/exec.Command` with unsanitized args — command injection
- `net/http` without timeouts — resource exhaustion
- Ignoring `err` return values — silent failures

### Python
- `pickle.loads` on untrusted data — arbitrary code execution
- `os.system` / `subprocess.call(shell=True)` with user input — command injection
- `yaml.load` without `Loader=SafeLoader` — code execution
- `eval()` / `exec()` — code injection

### Java
- Deserialization of untrusted data (`ObjectInputStream`) — RCE
- `Runtime.exec` with user input — command injection
- XML parsing without disabling external entities (XXE)
- Logging user input with Log4j patterns — log injection
