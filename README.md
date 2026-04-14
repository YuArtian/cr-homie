# CR Homie

A comprehensive code review skill for AI agents. Performs structured reviews with a senior engineer lens, covering architecture, security, performance, testing, frontend quality, API contracts, and code quality.

## Installation

```bash
npx skills add YuArtian/cr-homie
```

## Features

- **SOLID Principles** — Detect SRP, OCP, LSP, ISP, DIP violations with refactor heuristics
- **Security Scan** — XSS, injection, SSRF, race conditions, auth gaps, secrets leakage
- **Performance** — N+1 queries, CPU hotspots, missing cache, memory issues
- **Error Handling** — Swallowed exceptions, async errors, missing boundaries
- **Boundary Conditions** — Null handling, empty collections, off-by-one, numeric limits
- **Testing Quality** — Coverage gaps, test anti-patterns, over-mocking, flaky tests
- **Frontend Quality** — Accessibility, rendering performance, bundle size, CSS, state management, i18n
- **API Contracts** — Breaking changes, backward compatibility, versioning
- **Removal Planning** — Identify dead code with safe deletion plans
- **Observability** — Logging gaps, missing metrics, alerting blind spots

## How It Works

### Design Principles

- **Review-first** — Only outputs findings. Never auto-fixes code until you explicitly confirm
- **Iron Law** — Every finding must cite exact `file:line`, explain the concrete risk, and propose a specific fix. No vague advice like "consider improving error handling"
- **Progressive loading** — Reference checklists are loaded on-demand per workflow step, not all at once, keeping context usage efficient
- **Conditional steps** — Frontend quality, API contract checks, and removal planning only activate when the diff touches relevant code
- **Anti-pattern guarded** — Explicit rules prevent severity inflation, duplicate findings, and out-of-scope suggestions

### Workflow

```
git diff → Preflight → Review Steps → Self-Check → Output → User Confirms → (optional) Fix
              │                                        │
              ├─ detect scope, language, critical paths │
              │                                        ├─ verify every finding has file:line
              │        ┌───────────────────────┐       ├─ verify severity is justified
              │        │    Review Steps        │       └─ verify no duplicates
              │        ├───────────────────────┤
              │        │ SOLID + Architecture   │
              │        │ Security Scan ⚠️       │
              │        │ Code Quality           │
              │        │ Testing Quality ⚠️     │
              │        │ Frontend Quality (if)  │
              │        │ API Contracts (if hit) │
              │        │ Removal Plan (if hit)  │
              │        └───────────────────────┘
              │
              └─ large diff (>500 lines)? batch by module
```

1. **Preflight** ⛔ — Run `git diff` (or specified scope) to collect changed files, detect language(s), identify critical paths (auth, payments, data writes). If diff is empty, prompt user. If >500 lines, batch by module.
2. **SOLID + Architecture** — Load `solid-checklist.md`. Check for SRP/OCP/LSP/ISP/DIP violations. Propose incremental refactors, not rewrites.
3. **Security Scan** ⚠️ — Load `security-checklist.md`. Check XSS, injection, SSRF, auth gaps, race conditions, secrets leakage. Report both exploitability and impact.
4. **Code Quality** — Load `code-quality-checklist.md`. Check error handling anti-patterns, N+1 queries, hot path CPU, boundary conditions (null, empty, off-by-one), observability gaps.
5. **Testing Quality** ⚠️ — Load `testing-checklist.md`. Check if changed paths have tests, whether tests verify behavior (not implementation), flag over-mocking and flaky tests.
6. **Frontend Quality** _(conditional)_ — Load `frontend-checklist.md` when diff contains frontend files (`.tsx`, `.vue`, `.svelte`, `.css`, etc.). Check accessibility, rendering performance, bundle size, CSS issues, state management, i18n.
7. **API Contracts** _(conditional)_ — Load `api-contract-checklist.md` only when diff touches public interfaces, endpoints, or exported types. Check breaking changes and backward compatibility.
8. **Removal Candidates** _(conditional)_ — Load `removal-plan.md` only when diff reveals dead code or stale feature flags. Distinguish safe-delete-now vs defer-with-plan.
9. **Self-Check** ⛔ — Validate all findings before output: every finding has `file:line`, severity is justified, no duplicates, no vague suggestions.
10. **Output** — Structured report grouped by severity (P0–P3).
11. **Confirmation** ⚠️ — Present options: fix all / fix P0-P1 only / fix specific items / no changes. Do nothing until user confirms.

> ⛔ = BLOCKING (must complete before proceeding) · ⚠️ = REQUIRED (must not skip)

## Usage

```bash
/cr-homie                        # Review unstaged changes (default)
/cr-homie staged                 # Review staged changes
/cr-homie commit:abc123          # Review a specific commit
/cr-homie pr:42                  # Review a PR
/cr-homie --focus security       # Focus on security only
/cr-homie --quick                # Quick scan (P0/P1 only)
```

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `<scope>` | What to review: `staged`, `commit:<hash>`, `pr:<number>`, `branch:<name>`, or file path | unstaged changes |
| `--focus <area>` | Limit to: `security`, `solid`, `performance`, `quality`, `testing`, `frontend`, `api`, `all` | `all` |
| `--min-severity <level>` | Minimum severity to report: `P0`, `P1`, `P2`, `P3` | `P3` |
| `--quick` | Only report P0/P1, skip SOLID and removal analysis | off |

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
   - **Risk**: Attacker can extract/modify database via crafted username input
   - **Fix**: Use parameterized query: `db.query('SELECT * FROM users WHERE name = ?', [username])`

### P2 - Medium
2. **src/services/order.ts:118** Read-modify-write without transaction
   - **Risk**: Concurrent orders can oversell inventory under load
   - **Fix**: Wrap in transaction with `SELECT ... FOR UPDATE`

### P3 - Low
3. **src/utils/format.ts:7** Magic number 86400
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
    ├── frontend-checklist.md            # a11y, rendering perf, bundle, CSS, state, i18n
    ├── api-contract-checklist.md        # Breaking changes, backward compat, versioning
    └── removal-plan.md                  # Safe-delete vs defer-with-plan templates
```

The `references/` directory serves as a **progressive knowledge base** — each file is only loaded into context when its corresponding workflow step executes, keeping token usage efficient.

## License

MIT
