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

# macOS: /usr/bin/git is an xcrun shim. Inside Claude Code's Bash sandbox it
# can only work by handing off to another git on PATH (it prints xcrun cache
# errors on stderr, then runs that git); with no other git the reviewers
# cannot run git at all. See evals/README.md.
if [[ "$(uname)" == Darwin ]]; then
  if ! type -a -p git 2>/dev/null | grep -qv '^/usr/bin/git$'; then
    echo "warning: the only git on PATH is the /usr/bin/git xcrun shim, which fails" >&2
    echo "         inside the eval sandbox. Install a real git (e.g. brew install git)." >&2
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
