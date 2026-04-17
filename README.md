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
- **Multi-agent parallel** — Specialized review agents run in parallel, each with its own domain expertise and checklist, reducing context pressure and improving speed
- **Confidence scoring** — A dedicated scoring agent evaluates each finding (0-100) to filter false positives before output
- **Conditional activation** — Frontend quality, API contract checks, removal planning, and page verification only activate when relevant code is detected
- **Anti-pattern guarded** — Explicit rules prevent severity inflation, duplicate findings, and out-of-scope suggestions

### Architecture

```
Phase 1: Preflight (orchestrator)
    ↓ Preflight Context Block
Phase 2: Parallel Review Agents
    ├─→ security-reviewer   [opus]    ← always
    ├─→ testing-reviewer    [inherit] ← always
    ├─→ quality-reviewer    [inherit]
    ├─→ solid-reviewer      [opus]
    ├─→ frontend-reviewer   [inherit] ← if frontend detected
    ├─→ api-reviewer        [inherit] ← if API changes detected
    ├─→ removal-reviewer    [inherit] ← if dead code detected
    └─→ page-verifier       [inherit] ← if --verify + --url
    ↓ findings from all agents
Phase 3: Aggregation (orchestrator)
    ├─→ Deduplicate + multi-agent consensus severity promotion
    ├─→ confidence-scorer   [haiku]   ← score & filter findings
    ├─→ Self-check validation
    ├─→ Format output report
    └─→ Next steps confirmation
```

### Workflow

1. **Phase 1: Preflight** ⛔ — **Smart detection**: when no scope is specified, auto-detects unstaged → staged → branch diff (uses the first with content). Collects changed files, detects language(s), identifies critical paths (auth, payments, data writes), detects frontend files and API surface changes. If diff is empty, suggests `project` mode. If >2000 lines or >15 files, uses **two-pass review** (Pass 1: quick scan for hotspots; Pass 2: filtered context to agents). Assembles a Preflight Context Block for all agents.

2. **Phase 2: Parallel Agents** — Launches specialized review agents in parallel based on Preflight signals:
   - `security-reviewer` (opus) ⚠️ — XSS, injection, SSRF, auth gaps, race conditions, attack chain verification
   - `testing-reviewer` (inherit) ⚠️ — Coverage gaps, test quality, anti-patterns
   - `quality-reviewer` (inherit) — Error handling, N+1, boundaries, observability
   - `solid-reviewer` (opus) — SRP/OCP/LSP/ISP/DIP, architecture smells
   - `frontend-reviewer` (inherit) _(conditional)_ — Code principles, a11y, perf, bundle, state, i18n
   - `api-reviewer` (inherit) _(conditional)_ — Breaking changes, backward compatibility, versioning
   - `removal-reviewer` (inherit) _(conditional)_ — Dead code identification, cleanup plans
   - `page-verifier` (inherit) _(conditional)_ — Runtime page verification via Chrome DevTools MCP

3. **Phase 3: Aggregation** ⛔ — Deduplicates findings across agents. When 2+ agents flag the same location, promotes severity by one level (adversarial consensus). Launches `confidence-scorer` (haiku) to evaluate each finding 0-100, drops low-confidence findings (<70). Runs self-check validation, formats structured output, and presents next steps for user confirmation.

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
**Agents launched**: security-reviewer, testing-reviewer, quality-reviewer, solid-reviewer
**Overall assessment**: REQUEST_CHANGES

---

## Findings

### P0 - Critical
(none)

### P1 - High
1. **src/auth/login.ts:42** SQL injection via string interpolation `[SEC-001]` `[security]`
   - **Attack path**: `POST /api/login` → Express route `req.body.username` → `login()` → raw SQL concat
   - **Risk**: Attacker can extract/modify database via crafted username input
   - **Confidence**: Confirmed exploitable
   - **Fix**: Use parameterized query: `db.query('SELECT * FROM users WHERE name = ?', [username])`

### P2 - Medium
2. **src/services/file.ts:73** Path concatenation without validation `[SEC-002]` `[security]`
   - **Attack path**: `GET /files/{name}` → Express `req.params.name` only matches single segment (no `/`) → `../` blocked at route level
   - **Risk**: Code lacks its own path validation, relies on framework routing behavior
   - **Confidence**: Defense-in-depth gap
   - **Fix**: Add `path.resolve()` + prefix check to match `deleteFile()` pattern

3. **src/services/order.ts:118** Read-modify-write without transaction `[QUAL-001]` `[quality]`
   - **Risk**: Concurrent orders can oversell inventory under load
   - **Fix**: Wrap in transaction with `SELECT ... FOR UPDATE`

### P3 - Low
4. **src/utils/format.ts:7** Magic number 86400 `[SOLID-001]` `[solid]`
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

## Review Agents

| Agent | Domain | Model | Condition |
|-------|--------|-------|-----------|
| `security-reviewer` | Security, reliability, race conditions, supply chain | opus | Always (required) |
| `testing-reviewer` | Test coverage, quality, anti-patterns | inherit | Always (required) |
| `quality-reviewer` | Error handling, performance, boundaries, observability | inherit | Default on |
| `solid-reviewer` | SOLID principles, architecture smells | opus | Default on (skip with --quick) |
| `frontend-reviewer` | Frontend principles, a11y, perf, bundle, state, i18n | inherit | If frontend files detected |
| `api-reviewer` | Breaking changes, compatibility, versioning | inherit | If API surface changes |
| `removal-reviewer` | Dead code, deprecated paths, stale feature flags | inherit | If dead code detected |
| `page-verifier` | Runtime page verification via Chrome DevTools MCP | inherit | If --verify + --url |
| `confidence-scorer` | Finding quality scoring, false positive filtering | haiku | Always in Phase 3 |

## Structure

```
cr-homie/
├── SKILL.md                             # 3-phase orchestration workflow
├── agents/
│   ├── agent.yaml                       # Agent interface + trigger keywords
│   ├── security-reviewer.md             # Security + reliability agent
│   ├── testing-reviewer.md              # Testing quality agent
│   ├── solid-reviewer.md                # SOLID + architecture agent
│   ├── quality-reviewer.md              # Code quality agent
│   ├── frontend-reviewer.md             # Frontend quality agent (conditional)
│   ├── api-reviewer.md                  # API contracts agent (conditional)
│   ├── removal-reviewer.md              # Removal planning agent (conditional)
│   ├── page-verifier.md                 # Page verification agent (conditional)
│   └── confidence-scorer.md             # Finding quality scoring agent
└── references/                          # Knowledge base (loaded by each agent)
    ├── solid-checklist.md               # SOLID smell prompts + language-specific flags
    ├── security-checklist.md            # OWASP risks, race conditions, crypto, supply chain
    ├── code-quality-checklist.md        # Error handling, N+1, caching, boundaries, observability
    ├── testing-checklist.md             # Coverage, test quality, anti-patterns
    ├── frontend-checklist.md            # Code principles + a11y, perf, bundle, CSS, state, i18n
    ├── api-contract-checklist.md        # Breaking changes, backward compat, versioning
    ├── removal-plan.md                  # Safe-delete vs defer-with-plan templates
    └── page-verification-guide.md       # Chrome DevTools MCP verification procedures
```

Each review agent loads only its own checklist from `references/`, keeping per-agent context usage efficient.

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
