---
name: cr-homie
description: "Expert code review of git changes with a senior engineer lens. Detects SOLID violations, security risks, race conditions, performance issues, testing gaps, API breaking changes, and proposes actionable improvements. Use when user wants to review code, check code quality, find bugs, security audit, PR review. Triggers: 'review my changes', 'check this code', 'code review', 'find issues', 'is this safe to merge', 'review PR', 'look at my diff', 'what is wrong with this code', 'review this commit', 'check for security issues', 'code quality check'."
---

# Code Review Master

IRON LAW: Every finding MUST cite the exact `file:line`, explain the concrete risk with a realistic scenario, and propose a specific fix. Never output vague advice like "consider improving error handling." Never implement changes without explicit user confirmation.

## Arguments

| Argument | Description |
| -------- | ----------- |
| `<scope>` | What to review (default: branch-aware smart detection — see Phase 1). Accepts: `unstaged`, `staged`, `commit:<hash>`, `pr:<number>` (requires `gh` CLI), `branch:<name>`, `project[:<path>]`, or a file path |
| `--focus <area>` | Focus area: `security`, `solid`, `testing`, `quality` (includes `performance` and `api` aliases), `frontend`, `all` (default: `all`) |
| `--min-severity <level>` | Minimum severity to report: `P0`, `P1`, `P2`, `P3` (default: `P3`) |
| `--quick` | Quick scan — only P0/P1, skip SOLID and frontend analysis |
| `--verify` | Enable page-level verification via Chrome DevTools MCP (requires `--url` and MCP server) |
| `--url <url>` | Dev server URL for page verification (e.g., `http://localhost:3000`) |

## Severity Levels

The authoritative Severity table with calibration rules lives in `agents/_base-reviewer.md` and is inherited by every review agent. User-facing summary:

| Level | Name | Must do |
| ----- | ---- | ------- |
| **P0** | Critical | Block merge — exploitable security, data loss, correctness bug, fake data in prod path |
| **P1** | High | Fix before merge — significant vulnerability, logic error in critical path, missing critical tests, breaking API change without migration |
| **P2** | Medium | Fix in this PR or create follow-up — defense-in-depth gap, code smell, missing edge tests |
| **P3** | Low | Optional — style, naming, minor optimization |

## HIGH SIGNAL Philosophy

cr-homie aims for **HIGH SIGNAL findings only**. The shared rule set in `agents/_base-reviewer.md` defines what every review agent MUST silently drop:

- Linter-catchable issues (formatting, unused imports, basic type errors)
- Pre-existing issues in code NOT touched by the diff (exception: `project` scope)
- Looks-like-a-bug-but-actually-correct patterns (framework auto-escapes, caller holds lock, etc.)
- Pedantic nitpicks a senior engineer would not raise
- Speculative refactors without evidence of current pain
- Tests that already exist (a grep would have found them)
- Generic advice with no concrete fix ("consider improving error handling")
- Duplicates across agents — stay in your lane
- Hypothetical future requirements

Every agent inherits this filter from `agents/_base-reviewer.md`. The orchestrator (this file) and the `finding-verifier` agent in Phase 3 enforce it again.

## Anti-Patterns (DO NOT)

All Anti-Patterns are centralized in `agents/_base-reviewer.md`. The orchestrator-specific additions:

- ❌ Start implementing fixes before user confirms (Phase 3 Step 6 gate)
- ❌ Produce a final report that contains findings without a `Verified:` line — if present, route them through `finding-verifier` before output
- ❌ Run the pipeline if the diff is empty — inform the user and suggest `project` mode or a different scope

## Review Agents

| Agent | Domain | Model | Condition |
| ----- | ------ | ----- | --------- |
| `security-reviewer` | Security, reliability, race conditions, supply chain, package manager consistency | opus | Always (REQUIRED) |
| `testing-reviewer` | Test coverage, quality, anti-patterns | inherit | Always (REQUIRED) |
| `quality-reviewer` | Runtime quality (error handling, perf, boundaries, concurrency, observability) + API contracts (breaking changes, backward compat, versioning) + dead code removal | inherit | Always unless `--focus` excludes. API sub-domain activates if API surface detected; removal sub-domain activates if dead-code signals detected. |
| `solid-reviewer` | SOLID principles, architecture smells | opus | Unless `--quick` or `--focus` excludes |
| `frontend-reviewer` | 7 frontend principles, a11y, perf, bundle, CSS, state, i18n, production readiness | inherit | If frontend files detected or `--focus frontend` |
| `page-verifier` | Runtime page verification via Chrome DevTools MCP | inherit | If `--verify` AND `--url` provided AND MCP available |
| `finding-verifier` | Evidence-based verification of all findings (replaces confidence scoring) | inherit | Always in Phase 3 |

**Shared rules** for all review agents are in `agents/_base-reviewer.md` (Iron Law, HIGH SIGNAL filter, Verify Before Reporting, Severity calibration, Anti-Patterns, Finding Output Format). Each individual agent file contains only its domain-specific signals and calibration.

---

## Workflow

### Phase 1: Preflight Context ⛔ BLOCKING

#### Step 0 — Repo probes (run once, reuse everywhere below)

Before any scope work, gather these facts about the repo:

- **Default branch** (`$DEFAULT_BRANCH`):
  1. Try `git symbolic-ref refs/remotes/origin/HEAD` → strip `refs/remotes/origin/` prefix
  2. If that fails (no origin remote / never fetched), probe locally: `main`, `master`, `develop`, `trunk` — use the first that `git rev-parse --verify` accepts
  3. Still nothing → record `$DEFAULT_BRANCH = null` and skip all branch-vs-default comparisons in Smart Detection. When null, `branch:<name>` scope also cannot resolve — ask user to pass one of: `commit:<hash>`, `staged`, `unstaged`, `file path`, or `project[:<path>]`.
- **Current branch** (`$CURRENT_BRANCH`): `git symbolic-ref --short -q HEAD`. If it fails (detached HEAD — on a tag or commit), record `$CURRENT_BRANCH = null`. In this state, Smart Detection falls back to unstaged → staged only; branch-vs-default is skipped.
- **`gh` CLI availability**: `command -v gh`. Record as `$HAS_GH = true/false`. Used to gate `pr:<number>` scope.

#### Step 1 — Determine review scope based on arguments

| Input | Command | Prerequisite |
| ----- | ------- | ------------ |
| _(default)_ | **Smart detection** (see below) | — |
| `unstaged` | `git diff` | — |
| `staged` | `git diff --cached` | — |
| `commit:<hash>` | `git show <hash>` | hash must exist |
| `pr:<number>` | `gh pr diff <number>` | `$HAS_GH = true`; if false, error with install hint: `brew install gh` or `https://cli.github.com/` |
| `branch:<name>` | `git diff $DEFAULT_BRANCH...<name>` | `$DEFAULT_BRANCH ≠ null`; `<name>` must exist |
| file path | `git diff -- <path>` | — |
| `project` | Full project scan (all source files in working directory) | — |
| `project:<path>` | Full project scan limited to `<path>` subdirectory | — |

**Smart detection** (when no scope argument is provided): context-aware pick based on current branch, NOT a fixed priority chain. Uses `$DEFAULT_BRANCH` and `$CURRENT_BRANCH` from Step 0.

**Step 2a — gather applicable signals** (run in parallel, record line counts for each):

| Signal | Command | Skip when |
| ------ | ------- | --------- |
| unstaged | `git diff --stat` | — |
| staged | `git diff --cached --stat` | — |
| branch-vs-default | `git diff $DEFAULT_BRANCH...HEAD --stat` | `$DEFAULT_BRANCH = null` OR `$CURRENT_BRANCH = null` (detached HEAD) OR `$CURRENT_BRANCH = $DEFAULT_BRANCH` |

Only signals not skipped run; the number of signals varies (typically 2 on trunk / detached HEAD, 3 on a feature branch with origin).

**Step 2b — pick the scope by branch context:**

| Current state | Default scope (in priority order) | Rationale |
| ------------- | -------------------------------- | --------- |
| On `$DEFAULT_BRANCH` (trunk) | unstaged → staged → "nothing to review" | On the trunk, uncommitted work is what's under review; branch diff would be empty |
| Detached HEAD (`$CURRENT_BRANCH = null`) | unstaged → staged → "nothing to review, pass explicit `commit:<hash>`" | No branch to compare; usually means user checked out a tag or specific commit |
| No `$DEFAULT_BRANCH` found | unstaged → staged → "nothing to review, pass explicit scope" | Can't compare against anything |
| Any other branch (feature branch) | branch-vs-default → unstaged → staged | On a feature branch, the full branch delta represents the unit of work; a tiny unstaged edit should NOT mask a 20-commit branch |

**Step 2c — confirm before committing to the scope** (⛔ BLOCKING gate):

When multiple signals have content (e.g., on feature branch with both branch diff AND unstaged edits), present a one-screen summary and let the user override:

```markdown
## Scope detection

Current branch: <$CURRENT_BRANCH or "(detached HEAD)">
Default branch: <$DEFAULT_BRANCH or "(not found)">
Detected:
- Branch diff (vs $DEFAULT_BRANCH): X files, Y lines (default)
- Unstaged: A files, B lines
- Staged: C files, D lines

**Proceeding with**: <default scope per table above>

Reply with `staged`, `unstaged`, or explicit scope (e.g., `commit:HEAD`) to override; otherwise press enter / say "go" to continue.
```

Skip this gate if only ONE signal has content — proceed silently.

Skip this gate if the user invoked with an explicit scope argument — the arg always wins.

All applicable signals empty → inform user "没有检测到可 review 的内容", suggest `project` mode or an explicit scope.

Then:

1. Use the per-file breakdown already captured in Step 1 for the determined scope — do NOT re-run `git diff --stat`.
2. If the determined-scope diff is empty despite signals claiming content (e.g., binary-only changes) → inform user and ask if they meant a different scope.
3. **Large input handling**: If diff > 2000 lines OR touches > 15 files, use two-pass review:
   - **Pass 1 (Quick scan — orchestrator-inline, NO separate agent)**: The orchestrator itself skims the full diff and produces a hotspot list (file:line + one-line reason), grouped by code type (backend routes, data layer, frontend components, state management, config/infra). No agent is launched for Pass 1 — delegating this to a sub-agent would just fan out the same large diff that two-pass is trying to avoid. Do NOT produce findings at this stage; hotspots are annotations, not findings.
   - **Pass 2**: The orchestrator constructs the Preflight Context Block differently depending on recipient:
     - **For Phase 2 agents (hotspot-focused)**: Diff Content is the hotspot-filtered slice (saves context window). Two-pass mode = true. Agents prioritize hotspots but may surface highly material findings elsewhere — they are not forbidden from touching non-hotspot regions, just optimized for the hotspots.
     - **For Phase 3 `finding-verifier`**: Diff Content is the FULL original diff (needed to verify locations and trace attack chains). The verifier additionally has Bash access to re-run `git diff ...` if needed.
   - For smaller diffs (≤ 2000 lines AND ≤ 15 files), skip Pass 1 entirely. Everyone gets the full diff. Two-pass mode = false.
4. Detect primary language(s) from file extensions for language-specific checks.
5. Detect frontend code: files matching `.tsx`, `.jsx`, `.vue`, `.svelte`, `.css`, `.scss`, `.less`, or framework configs (`next.config`, `vite.config`, `nuxt.config`, etc.). If found, mark `frontend_detected = true`.
6. Detect API surface changes: files touching public interfaces, API endpoints, types/schemas, or exported functions. If found, mark `api_surface_detected = true`.
7. Detect dead code signals: deprecated paths, stale feature flags, unused exports revealed by the diff. If found, mark `dead_code_detected = true`.
8. Use `rg` or `grep` to find related modules, usages, and contracts when needed.
9. Identify critical paths: auth, payments, data writes, network, database migrations.
10. **Package manager detection** (Node.js projects only): If any `package.json` exists in scope:
    a. Check which lock files exist at each package root: `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `bun.lockb`
    b. Extract the `packageManager` field from `package.json` (if present)
    c. Check `scripts.preinstall` for enforcement hooks (e.g., `only-allow`)
    d. Record signals for security-reviewer
11. **Linter detection** — probe for linter configs at repo root and record which are present. Used by agents to decide whether HIGH SIGNAL rule #1 (drop linter-catchable findings) applies:

    | Linter | Signal files |
    | ------ | ------------ |
    | ESLint | `.eslintrc*`, `eslint.config.{js,mjs,ts,cjs}`, `"eslintConfig"` in `package.json` |
    | TypeScript (`tsc`) | `tsconfig.json` anywhere in scope |
    | Prettier | `.prettierrc*`, `prettier.config.{js,mjs,cjs}`, `"prettier"` in `package.json` |
    | Ruff | `ruff.toml`, `[tool.ruff]` in `pyproject.toml` |
    | mypy | `mypy.ini`, `[tool.mypy]` in `pyproject.toml` |
    | Flake8 / Pylint | `.flake8`, `setup.cfg` with `[flake8]`, `.pylintrc` |
    | golangci-lint | `.golangci.yml`, `.golangci.yaml`, `.golangci.toml` |
    | Clippy (Rust) | `clippy.toml` OR any Rust project (Clippy ships with rustup) |

    Record the list of detected linters in the Preflight Context Block's `Linters configured` field.

#### Project Scope — Full Project Scan

When scope is `project` or `project:<path>`:

1. This mode reviews **all source files** in the project (or specified subdirectory), not just git changes.
2. Use `find` + file extension filters to collect source files. Respect `.gitignore` and exclude the following directories:

   | Category | Excluded directories |
   | -------- | -------------------- |
   | **Dependencies** | `node_modules`, `vendor`, `bower_components` |
   | **Build outputs** | `dist`, `build`, `out`, `.output`, `target`, `bin`, `obj` |
   | **Framework artifacts** | `.next`, `.nuxt`, `.svelte-kit`, `.expo`, `storybook-static` |
   | **Tool caches** | `.cache`, `.turbo`, `.parcel-cache`, `.vite` |
   | **Test/coverage** | `coverage`, `.nyc_output` |
   | **Python** | `__pycache__`, `.pytest_cache`, `.mypy_cache`, `.venv`, `venv`, `.tox` |
   | **VCS/IDE** | `.git`, `.idea`, `.vscode` |
   | **Deployment** | `.vercel`, `.netlify` |

   Also exclude from content review: generated files, lock files (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Gemfile.lock`, `poetry.lock`, `Cargo.lock`), and binary assets (images, fonts, compiled binaries). Note: lock file _existence_ is still checked during Preflight for package manager consistency — only their content diff is excluded.
3. Group files by top-level directory (module), count files and estimate total lines per module.
4. **Hard limits + degradation** ⛔ BLOCKING — before showing the preview, enforce these thresholds to prevent context-window overflow:

   | Metric | Soft limit (warn) | Hard limit (force degradation) |
   | ------ | ----------------- | ------------------------------ |
   | Total files | 300 | 1,000 |
   | Total lines | 50,000 | 150,000 |
   | Single module | 150 files OR 25,000 lines | 500 files OR 75,000 lines |

   When soft limit exceeded: show the preview with a ⚠️ warning banner and a recommendation to narrow scope via `project:<path>`.

   When hard limit exceeded: DO NOT show "Scan all" as an option. Replace the 3-option menu with:

   ```markdown
   ⛔ **Project exceeds scan limits** — this would overflow the model context window.

   **Options:**

   1. **Narrow scope** — pick a specific subdirectory, e.g., `project:src/services/`
   2. **Hotspot-only mode** — I'll run Pass 1 (hotspot detection) only and return a prioritized list WITHOUT per-agent findings; you then pick hotspots to review in a follow-up
   3. **Cancel** — abort

   I cannot scan the full project within context bounds.
   ```

   User MUST pick option 1 or 2 — "Scan all" is not offered when hard limit is breached.

5. **Confirmation gate** ⛔ BLOCKING — within limits (or after user narrowed scope): present the user with a summary and ask for explicit confirmation. Use the following format:

   ```markdown
   ## Project Scan Preview

   **Target**: [working directory or specified path]
   **Total**: X source files, ~Y lines across Z modules

   | Module | Files | ~Lines | Languages |
   | ------ | ----- | ------ | --------- |
   | src/components/ | 42 | ~3,200 | TypeScript, TSX |
   | src/services/ | 15 | ~1,800 | TypeScript |
   | src/utils/ | 8 | ~600 | TypeScript |
   | ... | ... | ... | ... |

   ⚠️ Full project scan will review all listed files. This may take a while for large projects.

   **How would you like to proceed?**

   1. **Scan all** — Review all modules listed above
   2. **Select modules** — Tell me which modules to include/exclude
   3. **Cancel** — Abort project scan
   ```

6. Wait for user confirmation. Do NOT proceed without it.
7. After confirmation, apply the two-pass strategy: Pass 1 identifies hotspots, then agents in Phase 2 receive hotspot-filtered context.
8. For project scan, the Anti-Pattern rule "Add findings about unchanged code" does NOT apply — all code is in scope. This is communicated to agents via the `Scope mode: project` field in the Preflight Context Block (see below).

#### Preflight Context Block

At the end of Phase 1, assemble the following context block to pass to all review agents:

```markdown
## Preflight Context

**Scope**: [scope type and description]
**Scope mode**: `diff` | `project` (⚠️ if `project`, agents MUST flip the "Add findings about unchanged code" anti-pattern — all code in listed modules is in scope)
**Files**: X files, Y lines (changed for diff scope / total for project scope)
**Languages**: [detected languages]
**Linters configured**: [list of detected linter configs — ESLint, tsc, Prettier, Ruff, golangci-lint, etc. Empty if none. Agents MUST check this before dropping findings under HIGH SIGNAL rule #1.]
**Frontend detected**: true/false
**API surface detected**: true/false
**Dead code signals**: true/false
**Critical paths touched**: [list]
**Package manager**: [if Node.js, manager + lock file + enforcement status]
**Two-pass mode**: true/false
**Quick mode**: true/false
**Focus**: [focus area]
**Min severity**: [level]

### Changed Files
| File | Lines +/- | Category |
| ---- | --------- | -------- |
| ... | ... | ... |

### Diff Content
[For Phase 2 recipients in two-pass mode: hotspot-filtered slice with file:line citations preserved. For Phase 3 finding-verifier: ALWAYS the full original diff. For all recipients when not in two-pass mode: the full diff.]
```

The orchestrator is responsible for assembling the right variant per recipient. Agents must not attempt to compensate for a partial diff by refusing to report — they trust the orchestrator's slice and focus on what's given.

---

### Phase 2: Parallel Review Agents

Based on Preflight results, launch review agents IN PARALLEL. Pass the Preflight Context Block as input to each agent. Each agent operates independently with zero cross-dependencies.

#### Agent Launch Decision Matrix

`--focus` values: `all` (default), `security`, `testing`, `quality`, `performance` (alias → quality), `solid`, `api` (alias → quality, activates API sub-domain), `frontend`.

| Agent | `all` | `security` | `testing` | `quality` / `performance` / `api` | `solid` | `frontend` | `--quick` |
| ----- | ----- | ---------- | --------- | --------------------------------- | ------- | ---------- | --------- |
| security-reviewer | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ P0/P1 only |
| testing-reviewer | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ P0/P1 only |
| quality-reviewer | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ P0/P1 only |
| solid-reviewer | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| frontend-reviewer | if frontend detected | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| page-verifier | if `--verify` + MCP available | ❌ | ❌ | ❌ | ❌ | if `--verify` + MCP available | ❌ |

**Rules:**

- `security-reviewer` and `testing-reviewer` are ALWAYS launched (even with `--focus` on other areas). They are safety-critical.
- `--focus performance` is an alias that routes to `quality-reviewer` (runtime sub-domain).
- `--focus api` is an alias that routes to `quality-reviewer` (API sub-domain activates regardless of Preflight detection).
- When `--quick`: only security / testing / quality launch, each filtering output to P0/P1 only. solid / frontend / page-verifier skipped.
- `quality-reviewer` internally activates its sub-domains based on Preflight signals: API sub-domain when `api_surface_detected = true`; Removal sub-domain when `dead_code_detected = true`.
- `frontend-reviewer` only launches when Preflight marks `frontend_detected = true` OR user passes `--focus frontend`.
- `page-verifier` only launches when `--verify` AND `--url` are provided AND Chrome DevTools MCP is reachable — otherwise it fails fast and reports a skip message.

Wait for ALL launched agents to return their findings before proceeding to Phase 3. If an agent fails (timeout, tool error, MCP unreachable for page-verifier), record the failure in the final report's `Not Covered` section but do NOT block the remaining pipeline — degrade gracefully.

---

### Phase 3: Aggregation ⛔ BLOCKING

After all agents complete, process their findings through verification-first pipeline. The ordering matters — do NOT reorder steps.

#### Step 1: Collect

Gather findings from each completed agent. Each finding has a domain prefix that already identifies its source: `SEC-NNN`, `TEST-NNN`, `SOLID-NNN`, `QUAL-NNN` (with sub-prefixes `QUAL-API-NNN` / `QUAL-REM-NNN`), `FE-NNN`, `PAGE-NNN`.

Also collect each agent's `Not Covered` section — these merge into the final report.

#### Step 2: Deduplicate

Check for findings referencing the same `file:line`:

- Two agents flagging the SAME issue at the same location → keep the finding from the more domain-specific agent (e.g., `security-reviewer` over `quality-reviewer` for an injection finding; `quality-reviewer` API sub-domain over `solid-reviewer` for a breaking export)
- Two agents flagging DIFFERENT issues at the same location → keep both

Record which `file:line` locations were flagged by 2+ different agents with DIFFERENT issues — this list feeds the consensus lock safety override inside Step 3.

#### Step 3: Evidence-Based Verification ⛔ BLOCKING (replaces confidence scoring)

Launch the `finding-verifier` agent with the full merged findings list AND the Preflight Context Block assembled for Phase 3 — which, per Phase 1 Step 3, always carries the FULL original diff (never the hotspot-filtered slice that Phase 2 agents received). The verifier uses `Grep` / `Read` / `Bash` to gather concrete evidence for each finding and returns one of four outcomes per finding:

| Outcome | Orchestrator action |
| ------- | ------------------- |
| `CONFIRMED` | Keep unchanged |
| `DOWNGRADED` | Keep with adjusted severity and appended `[defense-in-depth]` or verifier's tag |
| `REFUTED` | DROP (subject to safety overrides below) |
| `NEEDS-MANUAL-REVIEW` | Keep with `[needs manual review]` tag, do NOT downgrade |

**Safety overrides (enforced here, not only by the verifier):**

- `SEC-*` with original severity P0 and outcome `CONFIRMED` → never DROP, never downgrade below P1
- Any finding involving fake data / mock URL / placeholder in a **prod-reachable code path** (see the heuristic in `agents/_base-reviewer.md` → "Prod-Reachable Code Path") → never DROP
- **Consensus lock**: if a `file:line` was flagged by 2+ agents in Step 2, at least ONE finding at that location must survive verification — DOWNGRADE is permitted, REFUTE of all is not. If the verifier tried to REFUTE all, escalate the highest-severity one to `NEEDS-MANUAL-REVIEW` and keep it.

This replaces the prior Haiku-scoring + Adversarial-Consensus pipeline. Verification replaces both scoring and severity promotion — a location that multiple agents flagged simply has multiple independent evidence trails, which the verifier considers when weighing each finding; there is no mechanical "severity +1 bump".

#### Step 4: Self-Check

Before output, verify the surviving findings:

- [ ] Every finding has an exact `file:line` reference (will be converted to markdown link in Step 5)
- [ ] Every finding carries BOTH an agent `Verified:` line AND a verifier `Evidence:` line going into Step 5 — these get merged into a single `Verified:` field during formatting
- [ ] Every finding has a justified severity level consistent with the base Severity calibration in `agents/_base-reviewer.md`
- [ ] No duplicate findings remain
- [ ] No vague suggestions without a concrete, implementable fix
- [ ] Severity not inflated — re-check each P0/P1 against the calibration rules
- [ ] For `project` scope: findings about unchanged code are in scope; for other scopes: flag any that slipped in as `[adjacent risk]` or drop
- [ ] Agents with "no findings" have their `Not Covered` sections merged into the report
- [ ] If any agent FAILED to run (timeout, tool error, MCP unreachable), record in `Not Covered`
- [ ] Apply `--min-severity` filter: drop all findings below the threshold
- [ ] HIGH SIGNAL pass: re-scan surviving findings against the filter list from `agents/_base-reviewer.md` — drop any that match (linter-catchable, pre-existing, pedantic, speculative, etc.)

#### Step 5: Format Output

**Before formatting, the orchestrator performs these transforms on each surviving finding:**

1. **file:line → markdown link** — convert agent-produced plain citations (e.g., `src/auth/login.ts:42`) to clickable markdown links (`[src/auth/login.ts:42](src/auth/login.ts#L42)`). Agents output plain `file:line`; the orchestrator is responsible for this conversion because only it knows the repo root.
2. **Merge verification fields** — each finding carries a `Verified:` line from the original review agent AND an `Evidence:` line from the verifier (Step 3). Combine them under a single `Verified:` field as: `<agent verified>; verifier: <verifier evidence>`.
3. **Apply verifier tags** — if the verifier assigned a tag (`[defense-in-depth gap]`, `[needs manual review]`), append it to the finding's title.

Final report template (after Step 5 transforms are applied):

```markdown
## Code Review Summary

**Scope**: [what was reviewed]
**Files reviewed**: X files, Y lines (changed for diff scope; total for project scope)
**Primary language(s)**: [detected]
**Agents launched**: [list of agents that ran; mark failed agents as `name (failed)`]
**Overall assessment**: [APPROVE / REQUEST_CHANGES / COMMENT]

---

## Findings

### P0 - Critical
(none or list)

### P1 - High
1. **[src/auth/login.ts:42](src/auth/login.ts#L42)** SQL injection via username `[SEC-001]`
   - **Risk**: What goes wrong and how likely
   - **Attack path**: POST /api/login → Express JSON body → login(req.body.username) → raw SQL concat at line 42
   - **Confidence**: Confirmed exploitable
   - **Fix**: Use parameterized query: `db.query('SELECT * FROM users WHERE name = ?', [username])`
   - **Verified**: <agent evidence>; verifier: <verifier evidence from Step 3>

> **Security findings** claiming external exploitability MUST include the `Attack path` and `Confidence` lines shown above.
>
> **Quality sub-domain findings** keep their sub-prefix: `QUAL-API-NNN` (breaking change — include `Consumers affected`), `QUAL-REM-NNN` (removal — include `Classification: Safe Delete | Defer with Plan`).
>
> **Non-security findings** (QUAL / SOLID / TEST / FE) use just `Risk` / `Fix` / `Verified`.

### P2 - Medium
2. (continue numbering across sections)
   - ...

### P3 - Low
...

---

## Removal / Iteration Plan
(if any `QUAL-REM-*` findings were classified as "Defer with Plan")

## Not Covered
(merged from all agents — areas outside review scope, unverifiable claims, failed agents)

## Page Verification Results
(if page-verifier ran — appended as separate section)
```

**Clean review**: If no issues found across all agents, explicitly state what was checked by each agent and any residual risks.

#### Step 6: Next Steps Confirmation ⚠️ REQUIRED

```markdown
---

## Next Steps

I found X issues (P0: _, P1: _, P2: _, P3: _).

**How would you like to proceed?**

1. **Fix all** — I'll implement all suggested fixes
2. **Fix P0/P1 only** — Address critical and high priority issues
3. **Fix specific items** — Tell me which issues to fix (by number)
4. **No changes** — Review complete, no implementation needed
```

**Do NOT implement any changes until user explicitly confirms.**

---

## Resources

| File | Purpose | Used By |
| ---- | ------- | ------- |
| `agents/_base-reviewer.md` | Shared meta-rules: Iron Law, HIGH SIGNAL filter, Verify Before Reporting, Severity calibration, Anti-Patterns, Finding Output Format | ALL review agents (inherited) |
| `references/security-checklist.md` | Security, reliability, race conditions, package manager consistency, attack-chain verification procedure | security-reviewer |
| `references/code-quality-checklist.md` | Error handling, performance, boundary conditions, concurrency, observability | quality-reviewer (runtime sub-domain) |
| `references/api-contract-checklist.md` | Breaking changes, backward compatibility, type safety, versioning | quality-reviewer (API sub-domain) |
| `references/removal-plan.md` | Safe-delete vs defer-with-plan templates for dead code | quality-reviewer (removal sub-domain) |
| `references/solid-checklist.md` | SOLID smell prompts and refactor heuristics | solid-reviewer |
| `references/testing-checklist.md` | Test quality, coverage, anti-patterns, language-specific checks | testing-reviewer |
| `references/frontend-checklist.md` | 7 frontend principles, a11y, perf, bundle, CSS, state, i18n, production readiness | frontend-reviewer |
| `references/page-verification-guide.md` | Chrome DevTools MCP verification procedures | page-verifier |
