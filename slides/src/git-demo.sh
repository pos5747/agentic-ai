#!/bin/bash
# Reproduce the git output printed on the "Git" slides of ../slides.qmd.
#   src/git-demo.sh            (from slides/; runs in a temporary folder)
# Starts from local-agent-example/materials/1-bugs-z (byte-identical to the
# practice repo's logit.R and data.csv, y ~ x + z) and commits it. Then:
#   run 1 on the slides (z-haiku/fix-scope-r1): only logit.R changes;
#     status, diff, restore -> the Git section's Status, Diff, Discard slides
#   the student fixes both bugs by hand (materials/2-run-z/logit.R) and
#     commits -> the Commit slide
#   run 3 on the slides (z-qwen/iqr-fn-r10, which starts from that fixed
#     script): its logit.R and the 15-row data.csv it wrote, both copied from
#     the run's agent-test/; status and the data diff -> the "Run 3: status"
#     and "Run 3: the diff of the data" slides
# Commit hashes change on every run. (Rebuilt 2026-10-22 for the z re-run;
# the September version replayed full-haiku/fix-scope-r6 and fix-better-r8.)
set -e
src="$(cd "$(dirname "$0")" && pwd)"
A="$src/../../../local-agent-example"
work="$(mktemp -d /private/tmp/gitdemo.XXXXXX)/agentic-ai-example"
mkdir -p "$work" && cd "$work"
cp "$A/materials/1-bugs-z/logit.R" "$A/materials/1-bugs-z/data.csv" .
export GIT_AUTHOR_NAME="A Student" GIT_AUTHOR_EMAIL="student@example.com"
export GIT_COMMITTER_NAME="A Student" GIT_COMMITTER_EMAIL="student@example.com"
export GIT_PAGER=cat
show() { echo "\$ $*"; "$@"; echo; }

git init -q -b main && git add . && git commit -q -m "Add logit.R and data.csv"

echo "===== run 1 on the slides (z-haiku/fix-scope-r1)"
cp "$A/results/z-haiku/fix-scope-r1/agent-test/logit.R" logit.R
show git status
show git diff logit.R
show git restore .
show git status

echo "===== the student fixes both bugs by hand and commits"
cp "$A/materials/2-run-z/logit.R" logit.R
show git diff
show git commit -am "Fix the family typo and report the probability"
show git log --oneline

echo "===== run 3 on the slides (z-qwen/iqr-fn-r10)"
cp "$A/results/z-qwen/iqr-fn-r10/agent-test/logit.R" "$A/results/z-qwen/iqr-fn-r10/agent-test/data.csv" .
show git status
echo '$ git diff data.csv'; git diff data.csv | head -12; echo
echo '$ git diff --stat'; git diff --stat; echo
git restore .
rm -rf "$(dirname "$work")"
