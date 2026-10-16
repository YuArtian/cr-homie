#!/usr/bin/env bash
# Run the cr-homie eval suite. ALWAYS use this wrapper instead of calling
# `claude plugin eval` directly: some suites (evals-private/) hold confidential
# code, and on a claude.ai subscription plugin eval otherwise publishes its
# HTML report (prompts, rubrics, judged excerpts) as an artifact.
#
#   evals/run.sh --case pub-sqli-search --runs 1 --ablation none
#   evals/run.sh --private --runs 3 --ablation none
#
# --private / --private-baseline (must be the first argument) sync the private
# cr-homie suite or the /code-review baseline suite from
# $CR_HOMIE_PRIVATE_ROOT (default ~/cr-homie-evals-private — kept outside any
# git repo; subdirs cases/ and cases-baseline/) into the git-ignored
# evals-private/ and run it there. The two share that directory, so never run
# them at the same time.
#
# Grants Bash (git diff etc., runs under Claude Code's OS sandbox) and Write
# (the --format json report) to every case. Scaffold scripts are ours, so
# --scaffold is always on.
set -euo pipefail

cd "$(dirname "$0")/.."

export CLAUDE_CODE_DISABLE_ARTIFACT=1

# macOS: /usr/bin/git is an xcrun shim that fails inside Claude Code's Bash
# sandbox, and eval runs take PATH from your login shell (not from this
# script), so a real git must come before /usr/bin there. See evals/README.md.
if [[ "$(uname)" == Darwin ]]; then
  login_git="$("$SHELL" -lc 'command -v git' 2>/dev/null || true)"
  if [[ "$login_git" == /usr/bin/git ]]; then
    echo "warning: your login shell resolves git to the /usr/bin/git xcrun shim, which" >&2
    echo "         fails inside the eval sandbox; reviewers will not be able to run git." >&2
    echo "         Install a real git ahead of /usr/bin (e.g. brew install git)." >&2
  fi
fi

eval_dir=()
if [[ "${1:-}" == "--private" || "${1:-}" == "--private-baseline" ]]; then
  suite=cases
  [[ "$1" == "--private-baseline" ]] && suite=cases-baseline
  shift
  src="${CR_HOMIE_PRIVATE_ROOT:-$HOME/cr-homie-evals-private}/$suite"
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
