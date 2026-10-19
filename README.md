# Getting Started with Agentic AI — the week-9 site

The public website for week 9, published at **https://pos5747.github.io/agentic-ai/**
from its own repo, `pos5747/agentic-ai`, rooted at this folder (`agentic-ai/site/`).
It holds the student pages and the lecture deck (`slides/`). Everything else in
`agentic-ai/` is working material and is not in the repo.

**Render:** `./render.sh` (or `./render.sh open`). It renders the pages and the
deck in `/private/tmp`, copies the result to `docs/`, and adds `docs/.nojekyll`.
For a quick deck-only render while editing slides, `slides/src/render.sh` still
works (its output, `slides/slides.html`, is gitignored).

**Publish:** commit the sources *and* `docs/`, then push. Nothing is live until
then.

**One-time setup (not done yet, 2026-10-19):**

1. GitHub Desktop: *File* > *Add Local Repository...* > choose this `site/`
   folder > *create a repository* here. Name it `agentic-ai`. Make the first
   commit (check that `_old/`, `_site/`, `.quarto/`, and `slides/slides.html`
   are not listed; `.gitignore` excludes them).
2. *Publish repository*: organization **pos5747**, uncheck "Keep this code
   private".
3. On GitHub: the repo's *Settings* > *Pages* > *Deploy from a branch* >
   `main`, folder `/docs`. The site appears at
   https://pos5747.github.io/agentic-ai/ (the deck at
   https://pos5747.github.io/agentic-ai/slides/slides.html).

The history below was written when this folder was `getting-started/`; the
pages and partials it describes are unchanged.

The site began (2026-10-19) as a combination of
`../local-agent-example/INSTALL.md` and `TRY-IT.md` into one page per
(interface, model) pair.

| | gpt-oss:20b (16 GB) | qwen3-coder:30b (32 GB) | Claude Haiku (Pro) |
|---|---|---|---|
| OpenCode | `opencode-gptoss.qmd` | `opencode-qwen.qmd` | not available (Anthropic bars subscriptions in third-party tools; OpenCode dropped the plugin in 1.3.0) |
| Claude Code | `claude-code-gptoss.qmd` | `claude-code-qwen.qmd` | `claude-code-claude.qmd` |

**How a page is built.** Each pair page is YAML (`pair:` and `model:` values)
plus a list of `{{< include >}}` partials from `_partials/`. The partials use
`{{< meta model.id >}}` and similar shortcodes, which Quarto expands inside code
blocks too, so one partial serves every model. Edit a partial to change every
page that includes it. Text in the partials is copied verbatim from INSTALL.md
and TRY-IT.md (Parts 1–3 and the answers were extracted by script, with "(qwen
too)" removed), except where the README hand-off or the log in `../CLAUDE.md`
says otherwise.

**`resources.qmd`** (added 2026-10-19) is a curated subset of `../resources/`,
grouped by person and ordered roughly by value to a first-timer. The format and
the rule for keeping it in step with the collection are in
`../resources/index.md`, "The student-facing Resources page."

**Restructured 2026-10-19 (later).** Pages now: `index.qmd` (Home; a placeholder
for Carlisle's content), `setup.qmd` (the old grid page, "Choose Your Setup"),
five install-only pair pages (one Windows block and one Mac block each, written
out in full, no partials), `first-example.qmd` ("A First Example": TRY-IT plus
the R and git/GitHub install steps, with the setup-specific run steps in one
five-tab tabset), and `resources.qmd`. Partials still in use: `_r`, `_git`,
`_part0`, `_run-common`, `_parts`, `_record`, `_answers`, `_memory`. The rest
are parked in `_old/partials-2026-10-19/`. The table at the top of this file
predates the restructure.
