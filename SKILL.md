---
name: cr-homie
description: "Expert code review of git changes with a senior engineer lens. Detects SOLID violations, security risks, race conditions, performance issues, testing gaps, API breaking changes, and proposes actionable improvements. Use when user wants to review code, check code quality, find bugs, security audit, PR review. Triggers: 'review my changes', 'check this code', 'code review', 'find issues', 'is this safe to merge', 'review PR', 'look at my diff', 'what is wrong with this code', 'review this commit', 'check for security issues', 'code quality check'."
---

# Code Review Master

IRON LAW: Every finding MUST cite the exact `file:line`, explain the concrete risk with a realistic scenario, and propose a specific fix. Never output vague advice like "consider improving error handling." Never implement changes without explicit user confirmation.

## Arguments

| Argument | Description |
|----------|-------------|
| `<scope>` | What to review (default: unstaged changes). Accepts: `staged`, `commit:<hash>`, `pr:<number>`, `branch:<name>`, `project[:<path>]`, or a file path |
| `--focus <area>` | Focus area: `security`, `solid`, `performance`, `quality`, `testing`, `api`, `frontend`, `all` (default: `all`) |
| `--min-severity <level>` | Minimum severity to report: `P0`, `P1`, `P2`, `P3` (default: `P3`) |
| `--quick` | Quick scan — only P0/P1, skip SOLID and removal analysis |
| `--verify` | Enable page-level verification via Chrome DevTools MCP (requires `--url`) |
| `--url <url>` | Dev server URL for page verification (e.g., `http://localhost:3000`) |

## Severity Levels

| Level | Name | Description | Action |
|-------|------|-------------|--------|
| **P0** | Critical | Security vulnerability, data loss risk, correctness bug | Must block merge |
| **P1** | High | Logic error, significant SOLID violation, performance regression, missing critical tests | Should fix before merge |
| **P2** | Medium | Code smell, maintainability concern, minor SOLID violation, test gaps | Fix in this PR or create follow-up |
| **P3** | Low | Style, naming, minor suggestion | Optional improvement |

## Anti-Patterns (DO NOT)

- ❌ Report vague findings like "this could be improved" without a concrete fix
- ❌ Inflate severity — a naming issue is P3, not P1
- ❌ Suggest adding tests for code that already has adequate coverage
- ❌ Mechanically apply every checklist item — use judgment about relevance
- ❌ Report the same issue multiple times across different sections
- ❌ Suggest refactors larger than the change being reviewed
- ❌ Add findings about unchanged code (unless directly affected by the diff)
- ❌ Start implementing fixes before user confirms
- ❌ Ignore fake data / mock URLs / placeholder content in non-test code — always flag as P0/P1

## Workflow

### 1) Preflight Context ⛔ BLOCKING

Determine review scope based on arguments:

| Input | Command |
|-------|---------|
| _(default)_ | `git diff` (unstaged changes) |
| `staged` | `git diff --cached` |
| `commit:<hash>` | `git show <hash>` |
| `pr:<number>` | `gh pr diff <number>` |
| `branch:<name>` | `git diff main...<name>` |
| file path | `git diff -- <path>` |
| `project` | Full project scan (all source files in working directory) |
| `project:<path>` | Full project scan limited to `<path>` subdirectory |

Then:
1. Run `git diff --stat` (for the determined scope) to get file list and line counts.
2. If diff is empty → inform user and ask if they meant a different scope.
3. If diff > 500 lines → summarize by file first, then review in batches by module.
4. Detect primary language(s) from file extensions for language-specific checks.
5. Detect frontend code: files matching `.tsx`, `.jsx`, `.vue`, `.svelte`, `.css`, `.scss`, `.less`, or framework configs (`next.config`, `vite.config`, `nuxt.config`, etc.). If found, mark as frontend-relevant for Step 6.
6. Use `rg` or `grep` to find related modules, usages, and contracts when needed.
7. Identify critical paths: auth, payments, data writes, network, database migrations.

#### Project Scope — Full Project Scan

When scope is `project` or `project:<path>`:

1. This mode reviews **all source files** in the project (or specified subdirectory), not just git changes.
2. Use `find` + file extension filters to collect source files. Respect `.gitignore` — exclude `node_modules`, `dist`, `build`, `.git`, vendor directories, generated files, lock files, and binary assets.
3. Group files by top-level directory (module), count files and estimate total lines per module.
4. **Confirmation gate** ⛔ BLOCKING — Before scanning, present the user with a summary and ask for explicit confirmation. Use the following format:

   ```markdown
   ## Project Scan Preview

   **Target**: [working directory or specified path]
   **Total**: X source files, ~Y lines across Z modules

   | Module | Files | ~Lines | Languages |
   |--------|-------|--------|-----------|
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

5. Wait for user confirmation. Do NOT proceed without it.
6. After confirmation, review in batches by module. Each module batch follows Steps 2–9 as normal, reading full file contents instead of diffs.
7. For project scan, the Anti-Pattern rule "Add findings about unchanged code" does NOT apply — all code is in scope.
8. Accumulate findings across all batches and present a single unified report in Step 11.

### 2) SOLID + Architecture Smells

> Skip if `--quick` or `--focus` excludes it.

Load `references/solid-checklist.md`.

- Check for SRP, OCP, LSP, ISP, DIP violations in changed code.
- When proposing a refactor: explain *why* it improves cohesion/coupling and outline a minimal, safe split.
- If refactor is non-trivial, propose an incremental plan instead of a large rewrite.

### 3) Security and Reliability Scan ⚠️ REQUIRED

Load `references/security-checklist.md`.

- Check for: XSS, injection, SSRF, path traversal, auth gaps, secret leakage, race conditions, unsafe deserialization, weak crypto.
- For each finding, state both **exploitability** (how easy to trigger) and **impact** (what damage results).

### 4) Code Quality Scan

Load `references/code-quality-checklist.md`.

- Check for: error handling anti-patterns, performance issues (N+1, hot path CPU), boundary conditions (null, empty, off-by-one), concurrency bugs.
- Flag issues that may cause silent failures or production incidents.

### 5) Testing Quality ⚠️ REQUIRED

Load `references/testing-checklist.md`.

- Are changed code paths covered by tests?
- Do tests verify behavior, not implementation details?
- Are edge cases and error paths tested?
- Any test anti-patterns (flaky, over-mocking, testing private internals)?

### 6) Frontend Quality _(conditional)_

> Only if Preflight detected frontend files, or `--focus frontend`.

Load `references/frontend-checklist.md`.

First, apply the **Frontend Code Principles** (KISS, Component SRP, FP, DRY, Clean Architecture, YAGNI, Production Readiness) to evaluate code structure and design quality. Then check specific areas:

- **Production Readiness** ⚠️: Fake data, mock URLs, placeholder content, stub features — flag as P0/P1.
- Accessibility: missing alt text, keyboard navigation, ARIA attributes, focus management.
- Rendering performance: unnecessary re-renders, missing memoization, large lists without virtualization, memory leaks.
- Bundle size: full library imports, missing code splitting, dev-only code in production.
- CSS/styling: z-index wars, missing responsive handling, layout overflow issues.
- State management: prop drilling, derived state stored separately, missing loading/error states.
- i18n: hardcoded strings, string concatenation for sentences, text overflow with translations.

### 7) API & Contract Changes _(conditional)_

> Only if diff touches public interfaces, API endpoints, types/schemas, or exported functions.

Load `references/api-contract-checklist.md`.

- Check for: breaking changes, backward compatibility, versioning, documentation updates.

### 8) Removal Candidates _(conditional)_

> Only if diff reveals dead code, deprecated paths, or stale feature flags. Skip if `--quick`.

Load `references/removal-plan.md`.

- Distinguish **safe delete now** vs **defer with plan**.
- Provide follow-up plan with concrete steps and checkpoints.

### 9) Self-Check ⛔ BLOCKING

Before presenting output, verify:

- [ ] Every finding has exact `file:line` reference
- [ ] Every finding has a justified severity level
- [ ] No duplicate findings across sections
- [ ] No vague suggestions without concrete fix proposals
- [ ] Severity levels are not inflated (re-check each P0/P1)
- [ ] Findings about unchanged code are marked as "adjacent risk"
- [ ] "No issues" sections state what was checked and what wasn't covered

### 10) Page-Level Verification _(conditional)_

> Only if `--verify` and `--url` are provided. Requires Chrome DevTools MCP.

Load `references/page-verification-guide.md`.

1. Navigate to the provided URL.
2. **Console errors**: Capture errors/warnings — uncaught exceptions are P0, framework warnings are P1.
3. **Fake data detection**: Inspect network requests for `localhost`/mock URLs; evaluate runtime for mock flags and placeholder text.
4. **Lighthouse audit**: Run a11y + best practices snapshot — score < 50 is P1, 50-89 is P2.
5. **A11y tree snapshot**: Check semantic structure, missing labels, heading hierarchy.
6. **Visual check**: Desktop screenshot + mobile viewport (375px) — check layout overflow, broken images, blank sections.
7. **Dark mode** _(if applicable)_: Emulate dark color scheme, check for invisible text or hardcoded colors.
8. **Performance trace** _(optional)_: Only if page feels slow — report LCP, INP, CLS.

Append results to the main review output as a "Page Verification Results" section.

### 11) Output

```markdown
## Code Review Summary

**Scope**: [what was reviewed]
**Files reviewed**: X files, Y lines changed
**Primary language(s)**: [detected]
**Overall assessment**: [APPROVE / REQUEST_CHANGES / COMMENT]

---

## Findings

### P0 - Critical
(none or list)

### P1 - High
1. **[file:line]** Brief title
   - **Risk**: What goes wrong and how likely
   - **Fix**: Specific code change or approach

### P2 - Medium
2. (continue numbering across sections)
   - ...

### P3 - Low
...

---

## Removal/Iteration Plan
(if applicable)

## Not Covered
(areas outside review scope or requiring manual verification)
```

**Clean review**: If no issues found, explicitly state what was checked and any residual risks.

### 12) Next Steps Confirmation ⚠️ REQUIRED

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

## Resources

| File | Purpose | When to Load |
|------|---------|--------------|
| `references/solid-checklist.md` | SOLID smell prompts and refactor heuristics | Step 2 |
| `references/security-checklist.md` | Security, reliability, and race condition checks | Step 3 |
| `references/code-quality-checklist.md` | Error handling, performance, boundary conditions | Step 4 |
| `references/testing-checklist.md` | Test quality, coverage, anti-patterns | Step 5 |
| `references/frontend-checklist.md` | Code principles, a11y, perf, bundle, CSS, state, i18n | Step 6 (conditional) |
| `references/api-contract-checklist.md` | Breaking changes, compatibility, versioning | Step 7 (conditional) |
| `references/removal-plan.md` | Deletion candidates and follow-up planning | Step 8 (conditional) |
| `references/page-verification-guide.md` | Chrome DevTools MCP page-level verification | Step 10 (conditional, `--verify`) |
