#!/bin/bash
# Render the site (pages + slides) outside Dropbox and copy the finished docs/ back.
# docs/ is what GitHub Pages serves at https://pos5747.github.io/agentic-ai/.
#   ./render.sh          render
#   ./render.sh open     render, then open the home page in the browser
set -e
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d /private/tmp/agentic-ai-site.XXXXXX)"
rsync -a --exclude docs --exclude _site --exclude .quarto --exclude _old --exclude slides/slides.html --exclude CLAUDE.md --exclude .claude "$here/" "$work/"
(cd "$work" && quarto render 2>&1 | grep -iE "error|warn" || true)
rsync -a --delete "$work/docs/" "$here/docs/"
touch "$here/docs/.nojekyll"   # serve files as-is on GitHub Pages
rm -rf "$work"
echo "rendered: $here/docs/index.html"
if [ "$1" = "open" ]; then open "$here/docs/index.html"; fi
