#!/bin/bash
# Render ../slides.qmd outside Dropbox and copy the finished HTML back.
#   src/render.sh          render
#   src/render.sh open     render, then open the deck in the browser
set -e
src="$(cd "$(dirname "$0")" && pwd)"
deck="$(dirname "$src")"
work="$(mktemp -d /private/tmp/slides.XXXXXX)"
mkdir "$work/src"
cp "$deck/slides.qmd" "$work/"
cp "$src/mock-gui.css" "$src/deck.css" "$src/agent-gui.lua" "$src/gh-diff.lua" "$work/src/"
cp -R "$deck/img" "$work/"
(cd "$work" && quarto render slides.qmd --quiet)
cp "$work/slides.html" "$deck/slides.html"
rm -rf "$work"
echo "rendered: $deck/slides.html"
if [ "$1" = "open" ]; then open "$deck/slides.html"; fi
