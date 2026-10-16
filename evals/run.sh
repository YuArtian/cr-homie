#!/usr/bin/env bash
# Run the cr-homie eval suite. ALWAYS use this wrapper instead of calling
# `claude plugin eval` directly: some suites (evals-private/) hold confidential
# code, and on a claude.ai subscription plugin eval otherwise publishes its
# HTML report (prompts, rubrics, judged excerpts) as an artifact.
#
#   evals/run.sh --case pub-sqli-search --runs 1 --ablation none
#   evals/run.sh --eval-dir evals-private --runs 3 --ablation none
#
# Grants Bash (git diff etc., runs under Claude Code's OS sandbox) and Write
# (the --format json report) to every case. Scaffold scripts are ours, so
# --scaffold is always on.
set -euo pipefail

cd "$(dirname "$0")/.."

export CLAUDE_CODE_DISABLE_ARTIFACT=1

exec claude plugin eval . \
  --no-publish \
  --trust-plugin \
  --scaffold \
  "$@" \
  --allow-tools Write Bash
