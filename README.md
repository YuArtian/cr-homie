# Code Review Master

A comprehensive code review skill for AI agents. Performs structured reviews with a senior engineer lens, covering architecture, security, performance, testing, API contracts, and code quality.

## Installation

### From GitHub

```bash
npx skills add <your-github-user>/cr-homie
```

### From GitLab (or any Git host)

```bash
git clone <repo-url> ~/.claude/skills/cr-homie
```

### Local development

```bash
ln -s /path/to/cr-homie ~/.claude/skills/cr-homie
```

## Features

- **SOLID Principles** — Detect SRP, OCP, LSP, ISP, DIP violations with refactor heuristics
- **Security Scan** — XSS, injection, SSRF, race conditions, auth gaps, secrets leakage
- **Performance** — N+1 queries, CPU hotspots, missing cache, memory issues
- **Error Handling** — Swallowed exceptions, async errors, missing boundaries
- **Boundary Conditions** — Null handling, empty collections, off-by-one, numeric limits
- **Testing Quality** — Coverage gaps, test anti-patterns, over-mocking, flaky tests
- **API Contracts** — Breaking changes, backward compatibility, versioning
- **Removal Planning** — Identify dead code with safe deletion plans
- **Observability** — Logging gaps, missing metrics, alerting blind spots

## Usage

```bash
# Review unstaged changes (default)
/cr-homie

# Review staged changes
/cr-homie staged

# Review a specific commit
/cr-homie commit:abc123

# Review a PR
/cr-homie pr:42

# Focus on security only
/cr-homie --focus security

# Quick scan (P0/P1 only)
/cr-homie --quick
```

## Workflow

1. **Preflight** — Scope changes, detect language, identify critical paths
2. **SOLID + Architecture** — Check design principles
3. **Security Scan** — Vulnerability detection
4. **Code Quality** — Error handling, performance, boundaries, observability
5. **Testing Quality** — Coverage, anti-patterns, assertion quality
6. **API Contracts** — Breaking changes, compatibility _(conditional)_
7. **Removal Candidates** — Find dead/unused code _(conditional)_
8. **Self-Check** — Validate findings quality before output
9. **Output** — Findings by severity (P0–P3)
10. **Confirmation** — Ask user before implementing fixes

## Severity Levels

| Level | Name | Action |
|-------|------|--------|
| P0 | Critical | Must block merge |
| P1 | High | Should fix before merge |
| P2 | Medium | Fix or create follow-up |
| P3 | Low | Optional improvement |

## Structure

```
cr-homie/
├── SKILL.md                             # Main skill definition
├── agents/
│   └── agent.yaml                       # Agent interface config
└── references/
    ├── solid-checklist.md               # SOLID smell prompts
    ├── security-checklist.md            # Security & reliability
    ├── code-quality-checklist.md        # Error, perf, boundaries, observability
    ├── testing-checklist.md             # Test quality & anti-patterns
    ├── api-contract-checklist.md        # Breaking changes & compatibility
    └── removal-plan.md                  # Deletion planning template
```

## Improvements over code-review-expert

| Area | code-review-expert | cr-homie |
|------|--------------------|--------------------|
| Iron Law | None | Enforces concrete `file:line` + fix for every finding |
| Parameters | Fixed scope only | `--focus`, `--quick`, `--min-severity`, flexible scope |
| Anti-patterns | None | Explicit list of DO NOT behaviors |
| Testing review | Missing | Full checklist: coverage, quality, anti-patterns |
| API contracts | Missing | Breaking changes, compatibility, versioning |
| Observability | Missing | Logging, metrics, alerting checks |
| Self-check | None | Pre-output validation gate |
| Language-specific | Generic only | JS/TS, Go, Python, Java red flags in each checklist |
| Workflow markers | All steps equal | `⛔ BLOCKING` and `⚠️ REQUIRED` markers |
| Review scope | `git diff` only | staged, commit, PR, branch, file path |

## License

MIT
