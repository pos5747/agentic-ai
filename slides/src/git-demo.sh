#!/bin/bash
# Reproduce the git output printed on the "Git" slides of ../slides.qmd.
#   src/git-demo.sh            (from slides/; runs in a temporary folder)
# Starts from local-agent-example/materials/1-bugs (byte-identical to the
# practice repo's logit.R and data.csv) and commits it. Then two replays:
#   run 1 on the slides (full-haiku/fix-scope-r6): only logit.R changes;
#     status, diff, restore -> the Git section's Status, Diff, Discard slides
#   run 3 on the slides (full-haiku/fix-better-r8): its logit.R and the
#     10-row data.csv the agent wrote (copied from its log.jsonl); status and
#     the data diff -> the "Run 3 in git" slides after that run
# Then a commit of the hand-fixed script (materials/2-run/logit.R) for the
# Commit slide. Commit hashes change on every run.
set -e
src="$(cd "$(dirname "$0")" && pwd)"
A="$src/../../../local-agent-example"
work="$(mktemp -d /private/tmp/gitdemo.XXXXXX)/agentic-ai-example"
mkdir -p "$work" && cd "$work"
cp "$A/materials/1-bugs/logit.R" "$A/materials/1-bugs/data.csv" .
export GIT_AUTHOR_NAME="A Student" GIT_AUTHOR_EMAIL="student@example.com"
export GIT_COMMITTER_NAME="A Student" GIT_COMMITTER_EMAIL="student@example.com"
export GIT_PAGER=cat
show() { echo "\$ $*"; "$@"; echo; }

git init -q -b main && git add . && git commit -q -m "Add logit.R and data.csv"

echo "===== run 1 on the slides (fix-scope-r6)"
cp "$A/results/full-haiku/fix-scope-r6/agent-test/logit.R" logit.R
show git status
show git diff logit.R
show git restore .
show git status

echo "===== run 3 on the slides (fix-better-r8)"
cp "$A/results/full-haiku/fix-better-r8/agent-test/logit.R" logit.R
printf 'x,y\n0.5,0\n1.2,1\n0.8,0\n2.1,1\n1.5,1\n0.3,0\n2.5,1\n1.1,1\n0.6,0\n1.8,1\n' > data.csv
show git status
echo '$ git diff data.csv'; git diff data.csv | head -8; echo
git restore .

# the student fixes both bugs by hand and commits
cp "$A/materials/2-run/logit.R" logit.R
show git diff
show git commit -am "Fix the family typo and report the probability"
show git log --oneline
rm -rf "$(dirname "$work")"
