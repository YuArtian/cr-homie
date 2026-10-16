#!/usr/bin/env bash
# Run the cr-homie eval suite. ALWAYS use this wrapper instead of calling
# `claude plugin eval` directly: some suites (evals-private/) hold confidential
# code, and on a claude.ai subscription plugin eval otherwise publishes its
# HTML report (prompts, rubrics, judged excerpts) as an artifact.
#
#   evals/run.sh --case pub-sqli-search --runs 1 --ablation none
#   evals/run.sh --private --runs 3 --ablation none
#
# --private (must be the first argument) syncs the private suite from
# $CR_HOMIE_PRIVATE_CASES (default ~/cr-homie-evals-private/cases — kept
# outside any git repo) into the git-ignored evals-private/ and runs it there.
#
# Grants Bash (git diff etc., runs under Claude Code's OS sandbox) and Write
# (the --format json report) to every case. Scaffold scripts are ours, so
# --scaffold is always on.
set -euo pipefail

cd "$(dirname "$0")/.."

export CLAUDE_CODE_DISABLE_ARTIFACT=1

eval_dir=()
if [[ "${1:-}" == "--private" ]]; then
  shift
  src="${CR_HOMIE_PRIVATE_CASES:-$HOME/cr-homie-evals-private/cases}"
  git check-ignore -q evals-private/ || { echo "evals-private/ is not git-ignored; refusing" >&2; exit 1; }
  mkdir -p evals-private
  rsync -a --delete --exclude results/ "$src"/ evals-private/
  eval_dir=(--eval-dir evals-private)
fi

exec claude plugin eval . \
  --no-publish \
  --trust-plugin \
  --scaffold \
  ${eval_dir[@]+"${eval_dir[@]}"} \
  "$@" \
  --allow-tools Write Bash
