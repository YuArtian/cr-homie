# CR Homie

An evidence-based code review skill for AI agents. Six specialized reviewers run in parallel, then an independent verifier agent proves or refutes each finding against the codebase — replacing numeric confidence scoring with fact-checking.

## Installation

```bash
npx skills add YuArtian/cr-homie
```

## What it checks

- **Security** — XSS, injection, SSRF, path traversal, auth/authz gaps, secret leakage, race conditions, supply chain, package manager consistency. Every exploitable claim is backed by a traced attack chain (entry → framework/middleware → vulnerable code) and a confidence label: `Confirmed exploitable` / `Defense-in-depth gap` / `Needs verification`.
- **Quality** (three sub-domains in one agent)
  - Runtime quality — error handling, performance (N+1, hot-path CPU, missing cache), boundary conditions, concurrency, observability
  - API contracts — breaking changes in REST/GraphQL/exports/schemas, backward compatibility, type safety regressions, versioning
  - Dead code removal — unused exports, deprecated paths, stale feature flags, with safe-delete vs defer-with-plan recommendations
- **SOLID** — SRP/OCP/LSP/ISP/DIP violations, code smells, with incremental refactor plans sized to the current diff
- **Testing** — coverage gaps, behavioral vs implementation-detail tests, anti-patterns (flakiness, over-mocking, testing private internals), language-specific checks for JS/TS/Go/Python/Java
- **Frontend** — 7 code principles (KISS, Component SRP, FP, DRY, Clean Architecture, YAGNI, Production Readiness), a11y, rendering perf, bundle, CSS, state, i18n. Fake data / mock URLs in prod code paths are always P0/P1.
- **Page verification** (optional) — runtime validation via Chrome DevTools MCP: console errors, fake network requests, Lighthouse audits, a11y tree, visual layout, dark mode, performance traces.

## How it works

### Design principles

- **Verification > Scoring** — findings are validated by an independent verifier agent that uses `grep`, `Read`, and `Bash` to check attack chains, callers, tests, and consumers. Replaces the previous Haiku-scoring filter.
- **HIGH SIGNAL only** — 9 explicit categories are silently dropped (linter-catchable, pre-existing, looks-like-a-bug-but-correct, pedantic nitpicks, speculative refactors, already-tested, generic advice, cross-agent duplicates, hypothetical future needs).
- **Iron Law** — every finding MUST cite exact `file:line`, describe a realistic risk scenario, and propose a specific fix. No vague advice like "consider improving error handling".
- **Review-first** — the skill reports findings and waits for your confirmation before implementing any fix.
- **Shared meta-rules** — Iron Law, HIGH SIGNAL filter, Severity calibration, Verify Before Reporting, and Anti-Patterns live in a single file ([agents/_base-reviewer.md](agents/_base-reviewer.md)) inherited by every reviewer, so rules can't drift between agents.
- **Multi-agent parallel** — domain-specific reviewers run concurrently on the same Preflight Context Block, reducing token pressure and improving coverage.
- **Conditional activation** — frontend, page verification, and the API / removal sub-domains of the quality reviewer only activate when Preflight detects relevant signals.

### Architecture

```text
Phase 1: Preflight (orchestrator)
    ├─→ Smart scope detection (branch-aware — branch diff on feature branch, unstaged/staged on main)
    ├─→ Two-pass mode if diff > 2000 lines or > 15 files
    ├─→ Detect languages, frontend, API surface, dead code, linter configs, package manager
    └─→ Build Preflight Context Block
    ↓
Phase 2: Parallel Review Agents
    ├─→ security-reviewer   [opus]    ← always required
    ├─→ testing-reviewer    [inherit] ← always required
    ├─→ quality-reviewer    [inherit] ← runtime + API (if detected) + dead code (if detected)
    ├─→ solid-reviewer      [opus]    ← unless --quick or --focus excludes
    ├─→ frontend-reviewer   [inherit] ← if frontend detected or --focus frontend
    └─→ page-verifier       [inherit] ← if --verify + --url + MCP available
    ↓ findings from all agents
Phase 3: Aggregation (orchestrator)
    ├─→ Collect + Deduplicate
    ├─→ finding-verifier    [inherit] ← CONFIRMED / DOWNGRADED / REFUTED / NEEDS-MANUAL-REVIEW
    ├─→ Safety overrides (SEC-P0 strong-evidence bar, production readiness, consensus lock)
    ├─→ Self-check + HIGH SIGNAL re-filter
    ├─→ Format output (markdown-link file:line, merge verification evidence)
    └─→ Next-steps confirmation ⚠️
```

### Workflow

1. **Phase 1: Preflight** ⛔ — Runs all three scope signals (unstaged, staged, branch-vs-main) in parallel and picks based on current branch: on `main` it falls back to uncommitted work; on a feature branch the branch diff is the default (so a tiny unstaged edit cannot mask a 20-commit branch). When multiple signals have content, shows a one-screen summary and lets you override before committing to a scope. Detects languages, frontend files, API surface, dead code signals, linter configs (ESLint/tsc/Prettier/Ruff/golangci-lint/etc. — controls HIGH SIGNAL linter-catchable filter), package manager consistency. If diff > 2000 lines OR > 15 files → two-pass mode (Pass 1 hotspot detection, Pass 2 filtered context to agents). For `project` scope, enforces hard limits (300 files / 50k lines soft warn; 1k files / 150k lines hard gate that forces you to narrow or switch to hotspot-only mode).

2. **Phase 2: Parallel agents** — 2 always run (security, testing) + quality (unless focus excludes) + solid (unless --quick) + frontend and page-verifier conditionally. All inherit shared rules from `agents/_base-reviewer.md`. Each agent must attach a `Verified:` line showing which callers / tests / framework behavior it checked before reporting.

3. **Phase 3: Aggregation** ⛔ — Deduplicates overlapping findings. `finding-verifier` then reads the full original diff (never the two-pass filtered slice) plus each finding's file:line context and returns one of four outcomes per finding. Safety overrides protect Security P0s (REFUTE requires strong, unambiguous evidence), fake-data-in-prod findings, and co-flagged locations (at least one must survive). The orchestrator then merges agent `Verified:` with verifier `Evidence:` into a single field, converts `file:line` to IDE-clickable markdown links, applies `--min-severity`, runs a final HIGH SIGNAL sweep, and asks you how to proceed.

> ⛔ = BLOCKING (must complete before proceeding) · ⚠️ = REQUIRED (must not skip)

## Usage

```bash
/cr-homie                        # Smart scope detection based on current branch
/cr-homie staged                 # Review staged changes
/cr-homie commit:abc123          # Review a specific commit
/cr-homie pr:42                  # Review a PR
/cr-homie branch:feat/login      # Review a named branch vs main
/cr-homie project                # Full project scan (subject to hard limits)
/cr-homie project:src/           # Scan only src/ directory
/cr-homie --focus security       # Focus on security only
/cr-homie --focus quality        # Focus on quality (includes API + dead code sub-domains)
/cr-homie --focus frontend       # Focus on frontend quality
/cr-homie --quick                # P0/P1 only; skip SOLID and frontend
/cr-homie --verify --url http://localhost:3000   # Code review + runtime page verification
```

### Parameters

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `<scope>` | `staged`, `commit:<hash>`, `pr:<number>` (requires [`gh` CLI](https://cli.github.com/)), `branch:<name>` (compared against detected default branch), `project[:<path>]`, or file path | branch-aware smart detection |
| `--focus <area>` | `security`, `quality` (includes `performance` and `api` aliases), `solid`, `testing`, `frontend`, `all` | `all` |
| `--min-severity <level>` | Minimum severity to report: `P0`, `P1`, `P2`, `P3` | `P3` |
| `--quick` | P0/P1 only; skip SOLID and frontend | off |
| `--verify` | Enable runtime page verification (requires `--url` and Chrome DevTools MCP) | off |
| `--url <url>` | Dev server URL for page verification | — |

## Output example

```markdown
## Code Review Summary

**Scope**: branch diff vs main (feat/login)
**Files reviewed**: 3 files, 87 lines changed
**Primary language(s)**: TypeScript
**Agents launched**: security-reviewer, testing-reviewer, quality-reviewer, solid-reviewer
**Overall assessment**: REQUEST_CHANGES

---

## Findings

### P0 - Critical
(none)

### P1 - High
1. **[src/auth/login.ts:42](src/auth/login.ts#L42)** SQL injection via username `[SEC-001]`
   - **Risk**: Attacker can extract/modify the users table via crafted username in POST /api/login
   - **Attack path**: POST /api/login → Express JSON body → login(req.body.username) → raw SQL concat at line 42
   - **Confidence**: Confirmed exploitable
   - **Fix**: Use parameterized query: `db.query('SELECT * FROM users WHERE name = ?', [username])`
   - **Verified**: Grepped callers of `login()` — only called from POST /api/login with no upstream validation; verifier: Confirmed — input flows unsanitized from JSON body to the raw concat.

### P2 - Medium
2. **[src/services/file.ts:73](src/services/file.ts#L73)** Path concat without validation `[SEC-002]` `[defense-in-depth gap]`
   - **Risk**: Code lacks its own path validation, relies on Express routing behavior
   - **Attack path**: GET /files/{name} → Express `req.params.name` matches a single segment → `../` blocked at the route level
   - **Confidence**: Defense-in-depth gap
   - **Fix**: Add `path.resolve()` + prefix check to match the `deleteFile()` pattern
   - **Verified**: Grepped route definitions; verifier: Downgraded — framework blocks the input, but code-level validation absent.

3. **[src/services/order.ts:118](src/services/order.ts#L118)** Read-modify-write without transaction `[QUAL-001]`
   - **Risk**: Concurrent orders can oversell inventory under load
   - **Fix**: Wrap in a transaction with `SELECT ... FOR UPDATE`
   - **Verified**: Grepped callers; no outer transaction; verifier: Confirmed — race window is real under concurrent checkout.

### P3 - Low
4. **[src/utils/format.ts:7](src/utils/format.ts#L7)** Magic number 86400 `[SOLID-001]`
   - **Risk**: Readability — unclear what 86400 represents
   - **Fix**: Extract to `const SECONDS_PER_DAY = 86400`

---

## Not Covered
- Database migration files not included in diff
- No integration test environment available to verify query changes
```

## Severity levels

| Level | Must do |
| ----- | ------- |
| **P0** | Block merge — exploitable security, data loss, correctness bug, fake data in prod path |
| **P1** | Fix before merge — significant vulnerability, logic error in critical path, missing critical tests, breaking API change without migration |
| **P2** | Fix in this PR or create follow-up — defense-in-depth gap, code smell, missing edge tests |
| **P3** | Optional — style, naming, minor optimization |

Full calibration rules and examples: [agents/_base-reviewer.md](agents/_base-reviewer.md).

## Review agents

| Agent | Domain | Model | Condition |
| ----- | ------ | ----- | --------- |
| `security-reviewer` | Security, reliability, race conditions, supply chain, package manager consistency | opus | Always (required) |
| `testing-reviewer` | Test coverage, quality, anti-patterns | inherit | Always (required) |
| `quality-reviewer` | Runtime quality + API contracts + dead code removal (three sub-domains, single agent) | inherit | Unless `--focus` excludes |
| `solid-reviewer` | SOLID principles, architecture smells | opus | Unless `--quick` or `--focus` excludes |
| `frontend-reviewer` | 7 frontend principles, a11y, perf, bundle, CSS, state, i18n, production readiness | inherit | If frontend detected or `--focus frontend` |
| `page-verifier` | Runtime page verification via Chrome DevTools MCP | inherit | If `--verify` + `--url` + MCP available |
| `finding-verifier` | Evidence-based verification (replaces confidence scoring) | inherit | Always in Phase 3 |

Shared meta-rules inherited by every reviewer live in [agents/_base-reviewer.md](agents/_base-reviewer.md).

## Structure

```text
cr-homie/
├── SKILL.md                             # 3-phase orchestration workflow
├── agents/
│   ├── agent.yaml                       # Skill interface metadata
│   ├── _base-reviewer.md                # Shared meta-rules (Iron Law, HIGH SIGNAL, Severity, Verify, Anti-Patterns, output format)
│   ├── security-reviewer.md             # Security + reliability + package manager consistency
│   ├── quality-reviewer.md              # Runtime quality + API contracts + dead code removal
│   ├── solid-reviewer.md                # SOLID + architecture smells
│   ├── testing-reviewer.md              # Testing quality + coverage
│   ├── frontend-reviewer.md             # Frontend quality (conditional)
│   ├── page-verifier.md                 # Runtime page verification (conditional)
│   └── finding-verifier.md              # Evidence-based verification agent (Phase 3)
└── references/                          # Knowledge base (loaded by each agent)
    ├── security-checklist.md            # OWASP risks, race conditions, crypto, supply chain, attack-chain verification procedure
    ├── code-quality-checklist.md        # Error handling, N+1, caching, boundaries, observability
    ├── api-contract-checklist.md        # Breaking changes, backward compatibility, versioning
    ├── removal-plan.md                  # Safe-delete vs defer-with-plan templates
    ├── solid-checklist.md               # SOLID smell prompts + language-specific flags
    ├── testing-checklist.md             # Coverage, test quality, anti-patterns
    ├── frontend-checklist.md            # 7 code principles + a11y, perf, bundle, CSS, state, i18n
    └── page-verification-guide.md       # Chrome DevTools MCP verification procedures
```

Each review agent loads only its own checklist(s) from `references/`, keeping per-agent context usage efficient.

## Page verification (Chrome DevTools MCP)

When `--verify --url <url>` is provided, CR Homie goes beyond static code review and validates the running page:

```bash
/cr-homie --verify --url http://localhost:5173
```

**Prerequisite**: Install the Chrome DevTools MCP server:

```bash
claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest
```

If the MCP server is not connected, the page-verifier fails fast with a skip notice and the rest of the review still runs.

**What it checks**:

| Check | How | Severity |
| ----- | --- | -------- |
| HTTP status | navigate + status | 5xx = P0; public 4xx = P1; auth-required 401/403 = P3 |
| Console errors | `list_console_messages` filter error/warn | Uncaught error = P0, framework warning = P1 |
| Fake data | `list_network_requests` + `evaluate_script` | Mock URLs in prod build = P0, placeholder text = P1 |
| Accessibility | `lighthouse_audit` + `take_snapshot` | Score < 50 = P1, missing labels = P2 |
| Visual layout | `take_screenshot` desktop + mobile (375px) | Overflow / broken layout = P2 |
| Dark mode | `emulate` colorScheme: dark | Invisible text / hardcoded colors = P2 |
| Performance | `performance_start_trace` (optional) | LCP > 2.5s = P1, CLS > 0.25 = P1 |

## Frontend code principles

When reviewing frontend code, CR Homie applies these 7 principles (detailed checks in [references/frontend-checklist.md](references/frontend-checklist.md)):

1. **KISS** — Delete what can be deleted. Most direct implementation wins.
2. **Component SRP** — One component = one reason to change. Componentize, but don't over-split.
3. **Functional Programming** — Business logic stays pure. Side effects live at the edges (hooks, event handlers).
4. **DRY** — Extract shared patterns at the third occurrence. Two is coincidence, three is a pattern.
5. **Clean Architecture** — Naming as documentation. Reading the code reveals intent without comments.
6. **YAGNI** — Build for today's requirements. No speculative abstractions.
7. **Production Readiness** ⚠️ — No fake data, no mock URLs, no stub features in production code (always P0/P1).

## Why verification instead of scoring

Scoring asks *"Does this finding sound correct?"* — prone to keeping plausible-sounding false positives.

Verification asks *"Can I prove this finding reaches the described failure mode?"* — requires evidence, catches hallucinations.

Code-review false positives almost always share the same shape: the pattern looks dangerous, but context already mitigates it (framework auto-escaping, upstream middleware, existing transaction, existing test). A scorer reading only the finding's text can't see that context. A verifier with grep/read can. This is the same design choice made by Anthropic's official `code-review` plugin, Cursor BugBot V11, and CodeRabbit's sandbox validation — reached after each project's scoring-only pipeline plateaued around ~50% precision.

See [ANALYSIS.md](ANALYSIS.md) for the full industry benchmark and the reasoning behind the v3 architecture.

## License

MIT
