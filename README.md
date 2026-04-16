# CR Homie

A comprehensive code review skill for AI agents. Performs structured reviews with a senior engineer lens, covering architecture, security, performance, testing, frontend quality, API contracts, and code quality.

## Installation

```bash
npx skills add YuArtian/cr-homie
```

## Features

- **SOLID Principles** — Detect SRP, OCP, LSP, ISP, DIP violations with refactor heuristics
- **Security Scan** — XSS, injection, SSRF, race conditions, auth gaps, secrets leakage, package manager consistency. **Attack chain verification**: traces entry point → framework/middleware → vulnerable code before reporting exploitability
- **Performance** — N+1 queries, CPU hotspots, missing cache, memory issues
- **Error Handling** — Swallowed exceptions, async errors, missing boundaries
- **Boundary Conditions** — Null handling, empty collections, off-by-one, numeric limits
- **Testing Quality** — Coverage gaps, test anti-patterns, over-mocking, flaky tests
- **Frontend Quality** — Code principles (KISS, FP, DRY, YAGNI, Clean Architecture), a11y, rendering perf, bundle, CSS, state, i18n
- **Fake Data Detection** — Hardcoded mock data, placeholder content, stub features flagged as P0/P1
- **API Contracts** — Breaking changes, backward compatibility, versioning
- **Removal Planning** — Identify dead code with safe deletion plans
- **Observability** — Logging gaps, missing metrics, alerting blind spots
- **Page Verification** — Runtime validation via Chrome DevTools MCP: Lighthouse, console errors, network inspection, visual checks

## How It Works

### Design Principles

- **Review-first** — Only outputs findings. Never auto-fixes code until you explicitly confirm
- **Iron Law** — Every finding must cite exact `file:line`, explain the concrete risk, and propose a specific fix. No vague advice like "consider improving error handling"
- **Verify before reporting** — Every finding must be validated against surrounding context (callers, route definitions, config) before inclusion. Pattern-match alone is not enough
- **Progressive loading** — Reference checklists are loaded on-demand per workflow step, not all at once, keeping context usage efficient
- **Conditional steps** — Frontend quality, API contract checks, and removal planning only activate when the diff touches relevant code
- **Anti-pattern guarded** — Explicit rules prevent severity inflation, duplicate findings, and out-of-scope suggestions

### Workflow

```
git diff → Preflight → Review Steps → Self-Check → Page Verify? → Output → User Confirms
              │                                        │              │
              ├─ detect scope, language, critical paths │              ├─ Lighthouse audit
              │                                        │              ├─ console errors
              │        ┌───────────────────────┐       │              ├─ fake data detection
              │        │    Review Steps        │       │              ├─ a11y tree check
              │        ├───────────────────────┤       │              └─ visual + responsive
              │        │ SOLID + Architecture   │       │
              │        │ Security Scan ⚠️       │       ├─ verify file:line on every finding
              │        │ Code Quality           │       ├─ verify severity is justified
              │        │ Testing Quality ⚠️     │       └─ verify no duplicates
              │        │ Frontend Quality (if)  │
              │        │ API Contracts (if hit) │
              │        │ Removal Plan (if hit)  │
              │        └───────────────────────┘
```

1. **Preflight** ⛔ — **Smart detection**: when no scope is specified, auto-detects unstaged → staged → branch diff (uses the first with content). Collects changed files, detects language(s), identifies critical paths (auth, payments, data writes). If diff is empty, suggests `project` mode. If >2000 lines or >15 files, uses **two-pass review** (Pass 1: quick scan for hotspots; Pass 2: deep review with context expansion). For `project` scope: two-pass strategy applies — quick scan all modules first, then deep review each hotspot.
2. **SOLID + Architecture** — Load `solid-checklist.md`. Check for SRP/OCP/LSP/ISP/DIP violations. Propose incremental refactors, not rewrites.
3. **Security Scan** ⚠️ — Load `security-checklist.md`. Check XSS, injection, SSRF, auth gaps, race conditions, secrets leakage, package manager consistency. **Verify attack chains**: for each security finding, trace external entry point → framework handling → vulnerable code. Report as `Confirmed exploitable`, `Defense-in-depth gap`, or `Needs verification`.
4. **Code Quality** — Load `code-quality-checklist.md`. Check error handling anti-patterns, N+1 queries, hot path CPU, boundary conditions (null, empty, off-by-one), observability gaps.
5. **Testing Quality** ⚠️ — Load `testing-checklist.md`. Check if changed paths have tests, whether tests verify behavior (not implementation), flag over-mocking and flaky tests.
6. **Frontend Quality** _(conditional)_ — Load `frontend-checklist.md` when diff contains frontend files. Apply code principles (KISS, FP, DRY, YAGNI, Clean Architecture). Check fake data (P0/P1), a11y, rendering perf, bundle, CSS, state, i18n.
7. **API Contracts** _(conditional)_ — Load `api-contract-checklist.md` only when diff touches public interfaces, endpoints, or exported types. Check breaking changes and backward compatibility.
8. **Removal Candidates** _(conditional)_ — Load `removal-plan.md` only when diff reveals dead code or stale feature flags. Distinguish safe-delete-now vs defer-with-plan.
9. **Self-Check** ⛔ — Validate all findings before output: every finding has `file:line`, severity is justified, no duplicates, no vague suggestions.
10. **Page Verification** _(conditional)_ — Load `page-verification-guide.md` when `--verify` is set. Navigate to `--url`, run Lighthouse, check console errors, detect fake data via network/runtime, take screenshots for desktop + mobile, check dark mode.
11. **Output** — Structured report grouped by severity (P0–P3), plus page verification results if applicable.
12. **Confirmation** ⚠️ — Present options: fix all / fix P0-P1 only / fix specific items / no changes. Do nothing until user confirms.

> ⛔ = BLOCKING (must complete before proceeding) · ⚠️ = REQUIRED (must not skip)

## Usage

```bash
/cr-homie                        # Smart detect: unstaged → staged → branch diff
/cr-homie staged                 # Review staged changes
/cr-homie commit:abc123          # Review a specific commit
/cr-homie pr:42                  # Review a PR
/cr-homie project                # Full project scan (all source files)
/cr-homie project:src/           # Scan only src/ directory
/cr-homie --focus security       # Focus on security only
/cr-homie --focus frontend       # Focus on frontend quality
/cr-homie --quick                # Quick scan (P0/P1 only)
/cr-homie --verify --url http://localhost:3000  # Code review + page verification
```

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `<scope>` | What to review: `staged`, `commit:<hash>`, `pr:<number>`, `branch:<name>`, `project[:<path>]`, or file path | smart detection |
| `--focus <area>` | Limit to: `security`, `solid`, `performance`, `quality`, `testing`, `frontend`, `api`, `all` | `all` |
| `--min-severity <level>` | Minimum severity to report: `P0`, `P1`, `P2`, `P3` | `P3` |
| `--quick` | Only report P0/P1, skip SOLID and removal analysis | off |
| `--verify` | Enable page-level verification via Chrome DevTools MCP (requires `--url`) | off |
| `--url <url>` | Dev server URL for page verification | — |

## Output Example

```markdown
## Code Review Summary

**Scope**: unstaged changes
**Files reviewed**: 3 files, 87 lines changed
**Primary language(s)**: TypeScript
**Overall assessment**: REQUEST_CHANGES

---

## Findings

### P0 - Critical
(none)

### P1 - High
1. **src/auth/login.ts:42** SQL injection via string interpolation
   - **Attack path**: `POST /api/login` → Express route `req.body.username` → `login()` → raw SQL concat
   - **Risk**: Attacker can extract/modify database via crafted username input
   - **Confidence**: Confirmed exploitable
   - **Fix**: Use parameterized query: `db.query('SELECT * FROM users WHERE name = ?', [username])`

### P2 - Medium
2. **src/services/file.ts:73** Path concatenation without validation
   - **Attack path**: `GET /files/{name}` → Express `req.params.name` only matches single segment (no `/`) → `../` blocked at route level
   - **Risk**: Code lacks its own path validation, relies on framework routing behavior
   - **Confidence**: Defense-in-depth gap
   - **Fix**: Add `path.resolve()` + prefix check to match `deleteFile()` pattern

3. **src/services/order.ts:118** Read-modify-write without transaction
   - **Risk**: Concurrent orders can oversell inventory under load
   - **Fix**: Wrap in transaction with `SELECT ... FOR UPDATE`

### P3 - Low
4. **src/utils/format.ts:7** Magic number 86400
   - **Risk**: Readability — unclear what 86400 represents
   - **Fix**: Extract to `const SECONDS_PER_DAY = 86400`

---

## Not Covered
- Database migration files not included in diff
- No integration test environment available to verify query changes
```

## Severity Levels

| Level | Name | Description | Action |
|-------|------|-------------|--------|
| P0 | Critical | Security vulnerability, data loss, correctness bug | Must block merge |
| P1 | High | Logic error, major SOLID violation, perf regression, missing critical tests | Should fix before merge |
| P2 | Medium | Code smell, minor SOLID violation, test gaps | Fix in this PR or create follow-up |
| P3 | Low | Style, naming, minor suggestion | Optional improvement |

## Structure

```
cr-homie/
├── SKILL.md                             # Workflow definition + Iron Law + anti-patterns
├── agents/
│   └── agent.yaml                       # Agent interface + trigger keywords
└── references/                          # Knowledge base (loaded on-demand per step)
    ├── solid-checklist.md               # SOLID smell prompts + language-specific flags
    ├── security-checklist.md            # OWASP risks, race conditions, crypto, supply chain
    ├── code-quality-checklist.md        # Error handling, N+1, caching, boundaries, observability
    ├── testing-checklist.md             # Coverage, test quality, anti-patterns
    ├── frontend-checklist.md            # Code principles + a11y, perf, bundle, CSS, state, i18n
    ├── api-contract-checklist.md        # Breaking changes, backward compat, versioning
    ├── removal-plan.md                  # Safe-delete vs defer-with-plan templates
    └── page-verification-guide.md       # Chrome DevTools MCP verification procedures
```

The `references/` directory serves as a **progressive knowledge base** — each file is only loaded into context when its corresponding workflow step executes, keeping token usage efficient.

## Page Verification (Chrome DevTools MCP)

When `--verify --url <url>` is provided, CR Homie goes beyond static code review and validates the running page:

```bash
/cr-homie --verify --url http://localhost:5173
```

**Prerequisite**: Install Chrome DevTools MCP server:

```bash
claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest
```

**What it checks**:

| Check | How | Severity |
|-------|-----|----------|
| Console errors | `list_console_messages` filter error/warn | Uncaught error = P0, framework warning = P1 |
| Fake data | `list_network_requests` + `evaluate_script` | Mock URLs / placeholder text = P1 |
| Accessibility | `lighthouse_audit` + `take_snapshot` (a11y tree) | Score < 50 = P1, missing labels = P2 |
| Visual layout | `take_screenshot` desktop + mobile (375px) | Overflow / broken layout = P2 |
| Dark mode | `emulate` colorScheme: dark | Invisible text / hardcoded colors = P2 |
| Performance | `performance_start_trace` (optional) | LCP > 2.5s = P1, CLS > 0.25 = P1 |

## Frontend Code Principles

When reviewing frontend code, CR Homie applies these principles (detailed checks in `frontend-checklist.md`):

1. **KISS** — Delete what can be deleted. Most direct implementation wins.
2. **Component SRP** — One component = one reason to change. Componentize, but don't over-split.
3. **Functional Programming** — Business logic stays pure. Side effects live at the edges (hooks, event handlers).
4. **DRY** — Extract shared patterns at the third occurrence. Two is coincidence, three is a pattern.
5. **Clean Architecture** — Naming as documentation. Reading the code reveals intent without comments.
6. **YAGNI** — Build for today's requirements. No speculative abstractions.
7. **Production Readiness** ⚠️ — No fake data, no mock URLs, no stub features in production code (P0/P1).

## License

MIT
