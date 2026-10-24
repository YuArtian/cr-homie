# cr-homie evals

Cases for [`claude plugin eval`](https://code.claude.com/docs/en/plugin-evals). Plan and metrics: [docs/plans/2026-10-16-cr-homie-v4-improvement.md](../docs/plans/2026-10-16-cr-homie-v4-improvement.md).

## Run

Always go through the wrapper — it forces `--no-publish` and `CLAUDE_CODE_DISABLE_ARTIFACT=1`, turns on `--scaffold`, and grants `Bash` + `Write`:

```bash
evals/run.sh --case pub-sqli-search --runs 1 --ablation none --keep-temp
evals/run.sh --runs 3 --ablation none --json evals/results/baseline.json
```

**macOS prerequisite:** reviewers run `git` inside Claude Code's Bash sandbox, where `/usr/bin/git` (an xcrun shim) fails unless another git is on `PATH`. Install one, e.g. `brew install git`; `run.sh` warns when there is none.

Even then, zsh in the sandbox still resolves `git` to the shim, because it cannot stat Homebrew's `Cellar` link target. The shim prints two xcrun cache errors on stderr, then runs the Homebrew git, so commands return correct output.

`--ablation none` skips the no-plugin arm: cr-homie only runs when named, so that arm would not review anything. Compare against the built-in `/code-review` with a separate suite instead.

## Case layout

```text
evals/<case>/
├── case.yaml          # schema_version "1.1", name, context.scaffold_script
├── fixture.sh         # builds the git repo: `main` = base, `feature` checked out = change under review
├── prompt.md          # frontmatter (tags, max_turns, timeout_seconds, allowed_tools) + the command
└── graders/*.md       # one file per check
```

- **Prompt**: `/cr-homie:cr-homie branch:feature --format json --out review.json`. Use the plugin-qualified name; an explicit scope skips the scope-confirmation gate.
- **`prompt.md` frontmatter**: `max_turns: 200`, `timeout_seconds: 2400`, `allowed_tools: [Read, Glob, Grep, Skill, Agent, TodoWrite]`.
- **Graders**:
  - Each labeled bug gets an `llm` grader (or a location `regex`) with `focus: { source: file, path: review.json }`. A bug passes when it appears in `findings` at the expected file, line range and minimum severity.
  - Each trap (looks dangerous, actually safe) gets a grader that passes when `findings` has no `P0`–`P2` entry for it. An entry in `refuted` is fine.
  - Process checks use `tool_used` on `Agent` with `subagent_type` `cr-homie:security-reviewer` and `cr-homie:finding-verifier`. Don't use `tool_used: Skill`: a slash command in the prompt expands the skill directly, so the Skill tool is never called.
- **Case names**: public cases are `pub-*`.

## Private cases

Cases built from internal repositories live in `evals-private/`, which is git-ignored and must never be committed, pushed or published. Their fixture scripts take the base and head shas from a local clone, and the case files hold only paths, shas and labels, never code. Run them with:

```bash
evals/run.sh --eval-dir evals-private --runs 3 --ablation none
```

For the full baseline on a subscription, use `evals/batch.py` instead. A subscription session window covers only about $45 (list price) of cr-homie runs, so the baseline takes many windows. The script runs one case at a time with both arms back to back, skips cases that already finished, stops on a usage-limit or login error (exit 3), and stops once `--budget` is spent in the current window:

```bash
python3 -I evals/batch.py --budget 35            # run again in the next window to continue
python3 -I evals/batch.py --merge                # → evals-private/results/baseline-{crhomie,codereview}.json
python3 -I evals/score.py evals-private/results/baseline-crhomie.json evals-private/results/baseline-codereview.json
```
