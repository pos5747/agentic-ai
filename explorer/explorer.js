// The "Explore the runs" page (runs.qmd). Loads runs.json, built by
// explorer/build-runs.py, and draws the compare view and the run view.
// Every piece of run text goes into the page with textContent, never as HTML.
(function () {
  "use strict";

  const OUTCOMES = {
    correct: { label: "Fully correct", glyph: "✓" },
    wrong: { label: "Claimed success, wrong result", glyph: "✗" },
    flawed: { label: "Claimed success, flawed run", glyph: "!" },
    honest: { label: "Honest failure", glyph: "–" },
  };
  const ORDER = ["correct", "wrong", "flawed", "honest"];
  const WRITE_LABEL = { write: "A Write call on ", edit: "An Edit call on ", shell: "A shell command that writes " };
  const FULL_NAME = {
    haiku: "Haiku 4.5 · Claude Code",
    sonnet: "Sonnet 5 · Claude Code",
    qwen: "qwen3-coder:30b · OpenCode",
    gptoss: "gpt-oss:20b · OpenCode",
  };

  let DATA = null;
  const byId = new Map();
  const state = { task: 0, key: null, model: "all", run: null };
  let sequence = []; // every run, model by model, in task and prompt order

  // ---------- small helpers ----------
  function el(tag, attrs, ...kids) {
    const e = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (v === null || v === undefined || v === false) continue;
      if (k === "class") e.className = v;
      else if (k === "text") e.textContent = v;
      else if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
      else e.setAttribute(k, v === true ? "" : v);
    }
    for (const kid of kids.flat(Infinity)) {
      if (kid === null || kid === undefined || kid === false) continue;
      e.appendChild(typeof kid === "string" ? document.createTextNode(kid) : kid);
    }
    return e;
  }
  const $ = (id) => document.getElementById(id);
  const promptInfo = (key) => {
    for (const t of DATA.tasks) for (const p of t.prompts) if (p.key === key) return { task: t, prompt: p };
    return null;
  };
  const modelInfo = (id) => DATA.models.find((m) => m.id === id);
  const runsFor = (model, key) => DATA.runs.filter((r) => r.model === model && r.key === key).sort((a, b) => a.rep - b.rep);
  const fmtSecs = (s) => (s >= 60 ? `${Math.floor(s / 60)} min ${s % 60} s` : `${s} s`);

  // ---------- URL hash: #task=Fix&prompt=fix-better&model=all&run=haiku/fix-better-r8 ----------
  function readHash() {
    const h = new URLSearchParams(location.hash.slice(1));
    const run = h.get("run");
    if (run && byId.has(run)) {
      const r = byId.get(run);
      state.run = run;
      state.key = r.key;
    } else {
      state.run = null;
    }
    const key = h.get("prompt");
    if (!state.run && key && promptInfo(key)) state.key = key;
    if (!state.key) state.key = DATA.tasks[0].prompts[0].key;
    state.task = DATA.tasks.indexOf(promptInfo(state.key).task);
    const m = h.get("model");
    state.model = m && modelInfo(m) ? m : "all";
  }
  function writeHash(push) {
    const h = new URLSearchParams();
    h.set("prompt", state.key);
    if (state.model !== "all") h.set("model", state.model);
    if (state.run) h.set("run", state.run);
    const url = "#" + h.toString();
    if (push) history.pushState(null, "", url);
    else history.replaceState(null, "", url);
  }

  // ---------- controls ----------
  function pill(text, active, onclick, extra) {
    return el("button", Object.assign({ type: "button", class: "rx-pill" + (active ? " is-active" : ""), "aria-pressed": active ? "true" : "false", onclick }, extra || {}), text);
  }
  function drawControls() {
    const tasks = $("rx-tasks");
    tasks.replaceChildren(
      ...DATA.tasks.map((t, i) =>
        pill(t.task, i === state.task, () => {
          state.task = i;
          state.key = t.prompts[0].key;
          state.run = null;
          update(true);
        })
      )
    );
    const prompts = $("rx-prompts");
    prompts.replaceChildren(
      ...DATA.tasks[state.task].prompts.map((p) =>
        pill(p.label, p.key === state.key, () => {
          state.key = p.key;
          state.run = null;
          update(true);
        })
      )
    );
    const models = $("rx-models");
    models.replaceChildren(
      pill("All four", state.model === "all", () => {
        state.model = "all";
        update(true);
      }),
      ...DATA.models.map((m) =>
        pill(m.label, state.model === m.id, () => {
          state.model = m.id;
          update(true);
        }, { "data-model": m.id })
      )
    );
    $("rx-prompt-text").textContent = promptInfo(state.key).prompt.text;
  }

  function drawLegend() {
    $("rx-legend").replaceChildren(
      ...ORDER.map((o) =>
        el("span", { class: "rx-legend-item" }, el("span", { class: `rx-swatch o-${o}`, "aria-hidden": "true" }, OUTCOMES[o].glyph), OUTCOMES[o].label)
      ),
      el("span", { class: "rx-legend-item" }, el("span", { class: "rx-swatch rx-swatch-lecture", "aria-hidden": "true" }, "1"), "shown in lecture (as run 1 to 8)")
    );
  }

  // ---------- compare view ----------
  function tile(r) {
    const o = OUTCOMES[r.outcome];
    const title = `${modelInfo(r.model).label}, run ${r.rep}: ${o.label}` + (r.lecture ? ` (shown in lecture as run ${r.lecture})` : "");
    return el(
      "button",
      {
        type: "button",
        class: `rx-tile o-${r.outcome}` + (state.run === r.id ? " is-open" : "") + (r.lecture ? " is-lecture" : ""),
        title,
        "aria-label": title,
        onclick: () => openRun(r.id, true),
      },
      el("span", { class: "rx-glyph", "aria-hidden": "true" }, o.glyph),
      el("span", { class: "rx-rep", "aria-hidden": "true" }, String(r.rep)),
      r.lecture ? el("span", { class: "rx-lecture-badge", "aria-hidden": "true" }, String(r.lecture)) : null
    );
  }
  function counts(runs) {
    const c = { correct: 0, wrong: 0, flawed: 0, honest: 0 };
    runs.forEach((r) => c[r.outcome]++);
    return c;
  }
  function drawCompare() {
    const models = state.model === "all" ? DATA.models : [modelInfo(state.model)];
    const box = $("rx-compare");
    box.classList.toggle("is-single", models.length === 1);
    box.replaceChildren(
      ...models.map((m) => {
        const runs = runsFor(m.id, state.key);
        const c = counts(runs);
        return el(
          "div",
          { class: "rx-col", "data-model": m.id },
          el("div", { class: "rx-col-head" }, el("span", { class: "rx-col-name" }, m.label), el("span", { class: "rx-col-sub" }, FULL_NAME[m.id])),
          el("div", { class: "rx-tiles" }, runs.map(tile)),
          el(
            "ul",
            { class: "rx-counts", "data-model": m.id, "data-key": state.key },
            ORDER.map((o) =>
              el(
                "li",
                { class: c[o] ? "" : "is-zero", "data-outcome": o },
                el("span", { class: `rx-swatch rx-swatch-sm o-${o}`, "aria-hidden": "true" }, OUTCOMES[o].glyph),
                el("span", { class: "rx-count" }, String(c[o])),
                el("span", { class: "rx-count-label" }, OUTCOMES[o].label)
              )
            ),
            el("li", { class: "rx-count-n" }, `${runs.length} runs`)
          )
        );
      })
    );
    // One model: list its runs in order, with the grader's note.
    const list = $("rx-list");
    if (models.length === 1) {
      const runs = runsFor(models[0].id, state.key);
      list.replaceChildren(
        el("h3", { class: "rx-list-head" }, `${models[0].label}'s ${runs.length} runs, in order`),
        el(
          "ol",
          { class: "rx-list-items" },
          runs.map((r) =>
            el(
              "li",
              {},
              el(
                "button",
                { type: "button", class: "rx-list-btn" + (state.run === r.id ? " is-open" : ""), onclick: () => openRun(r.id, true) },
                el("span", { class: `rx-swatch rx-swatch-sm o-${r.outcome}`, "aria-hidden": "true" }, OUTCOMES[r.outcome].glyph),
                el("span", { class: "rx-list-run" }, `Run ${r.rep}`),
                el("span", { class: "rx-list-note" }, r.note || OUTCOMES[r.outcome].label)
              )
            )
          )
        )
      );
    } else list.replaceChildren();
  }

  // ---------- run view ----------
  function pane(cls, title, ...body) {
    return el("div", { class: `rx-pane ${cls}` }, el("div", { class: "rx-pane-title" }, title), el("div", { class: "rx-pane-body" }, body));
  }
  function conversation(r, prompt) {
    const items = [el("div", { class: "rx-msg rx-user" }, el("div", { class: "rx-who" }, "You"), el("div", { class: "rx-text" }, prompt.text))];
    if (!r.conv.length) items.push(el("p", { class: "rx-empty" }, "(The log is empty.)"));
    for (const c of r.conv) {
      if (c.t === "tool") {
        const head = el("span", { class: "rx-call" }, el("span", { class: "rx-tool" }, c.name), c.arg ? el("span", { class: "rx-arg" }, c.arg) : null);
        if (c.out) items.push(el("details", { class: "rx-step" }, el("summary", {}, head), el("pre", { class: "rx-out" }, c.out)));
        else items.push(el("div", { class: "rx-step rx-step-plain" }, head));
      } else if (c.t === "text") {
        items.push(
          el(
            "div",
            { class: "rx-msg rx-agent" + (c.final ? " is-final" : "") },
            el("div", { class: "rx-who" }, c.final ? "Agent · final message" : "Agent"),
            el("div", { class: "rx-text" }, c.text)
          )
        );
      } else if (c.t === "subtext") {
        items.push(el("div", { class: "rx-msg rx-sub" }, el("div", { class: "rx-who" }, "Subagent"), el("div", { class: "rx-text" }, c.text)));
      } else {
        items.push(el("div", { class: "rx-msg rx-err" }, el("div", { class: "rx-who" }, "Error"), el("div", { class: "rx-text" }, c.text)));
      }
    }
    return items;
  }
  function diffView(r) {
    if (!r.changed) {
      return [el("p", { class: "rx-empty" }, "logit.R is unchanged."), el("pre", { class: "rx-code" }, DATA.starts[promptInfo(r.key).prompt.group])];
    }
    const rows = [];
    let a = 0,
      b = 0;
    for (const line of r.diff.split("\n")) {
      const m = line.match(/^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/);
      if (m) {
        a = +m[1];
        b = +m[2];
        rows.push(el("tr", { class: "d-hunk" }, el("td", { colspan: "3" }, line)));
      } else if (line.startsWith("-")) {
        rows.push(el("tr", { class: "d-del" }, el("td", { class: "d-n" }, String(a++)), el("td", { class: "d-n" }, ""), el("td", { class: "d-t" }, line)));
      } else if (line.startsWith("+")) {
        rows.push(el("tr", { class: "d-add" }, el("td", { class: "d-n" }, ""), el("td", { class: "d-n" }, String(b++)), el("td", { class: "d-t" }, line)));
      } else {
        rows.push(el("tr", {}, el("td", { class: "d-n" }, String(a++)), el("td", { class: "d-n" }, String(b++)), el("td", { class: "d-t" }, line)));
      }
    }
    return [el("div", { class: "rx-diff-wrap" }, el("table", { class: "rx-diff" }, el("tbody", {}, rows)))];
  }
  function filesView(r) {
    const items = [
      el("li", {}, el("code", {}, "logit.R"), r.changed ? el("span", { class: "f-chg" }, " changed") : el("span", { class: "f-same" }, " unchanged")),
      el("li", {}, el("code", {}, "data.csv"), r.dataChanged ? el("span", { class: "f-bad" }, " changed") : el("span", { class: "f-same" }, " unchanged")),
    ];
    const out = [el("ul", { class: "rx-files" }, items)];
    if (r.dataChanged) {
      if (r.dataWrites && r.dataWrites.length) {
        for (const w of r.dataWrites) {
          out.push(el("details", { class: "rx-file" }, el("summary", {}, WRITE_LABEL[w.how], el("code", {}, "data.csv")), el("pre", { class: "rx-out" }, w.text)));
        }
      } else out.push(el("p", { class: "rx-empty" }, "The log does not show what it wrote."));
    }
    for (const f of r.newFiles) {
      out.push(el("details", { class: "rx-file" }, el("summary", {}, "New file: ", el("code", {}, f.name)), el("pre", { class: "rx-out" }, f.text)));
    }
    if (!r.newFiles.length) out.push(el("p", { class: "rx-empty" }, "No new files."));
    return out;
  }
  function neighbors(r) {
    const mine = sequence.filter((x) => x.model === r.model);
    const i = mine.indexOf(r);
    return [mine[i - 1] || null, mine[i + 1] || null];
  }
  function drawRun() {
    const box = $("rx-run");
    if (!state.run) {
      box.hidden = true;
      box.replaceChildren();
      return;
    }
    const r = byId.get(state.run);
    const m = modelInfo(r.model);
    const info = promptInfo(r.key);
    const o = OUTCOMES[r.outcome];
    const [prev, next] = neighbors(r);
    const navBtn = (x, label) =>
      x ? el("button", { type: "button", class: "rx-nav", onclick: () => openRun(x.id, true) }, label) : el("span", { class: "rx-nav is-off" }, label);
    const facts = [
      ["Time", fmtSecs(r.secs)],
      ["Cost", r.cost === null ? "$0 (local)" : `$${r.cost.toFixed(3)}`],
      ["Tool calls", String(r.tools)],
      ["Ran R", r.ranR ? "yes" : "no"],
      ["Stage", r.stage],
    ];
    box.hidden = false;
    box.replaceChildren(
      el(
        "div",
        { class: "rx-run-head", "data-model": r.model },
        el(
          "div",
          { class: "rx-run-title" },
          el("h2", { class: "rx-run-h" }, `${m.label} · ${info.task.task}, ${info.prompt.label} · run ${r.rep}`),
          el("button", { type: "button", class: "rx-close", "aria-label": "Close this run", onclick: () => { state.run = null; update(true); } }, "×")
        ),
        el(
          "div",
          { class: "rx-badges" },
          el("span", { class: `rx-badge o-${r.outcome}` }, `${o.glyph} ${o.label}`),
          r.lecture ? el("span", { class: "rx-badge rx-badge-lecture" }, `Shown in lecture as run ${r.lecture}`) : null
        ),
        el("dl", { class: "rx-facts" }, facts.map(([k, v]) => el("div", {}, el("dt", {}, k), el("dd", {}, v)))),
        r.note ? el("p", { class: "rx-note" }, el("strong", {}, "Grader's note: "), r.note) : null,
        el("div", { class: "rx-navs" }, navBtn(prev, `← ${m.label}'s previous run`), navBtn(next, `${m.label}'s next run →`))
      ),
      el(
        "div",
        { class: "rx-panes" },
        pane("p-chat", "The conversation", conversation(r, info.prompt)),
        el(
          "div",
          { class: "rx-side" },
          pane("p-diff", "The code: logit.R, from the start to the agent's version", diffView(r)),
          pane("p-out", "The output: what logit.R printed when we ran it afterward", el("pre", { class: "rx-code" }, r.after || "(nothing)")),
          pane("p-files", "The files", filesView(r))
        )
      )
    );
  }
  function openRun(id, push) {
    state.run = id;
    state.key = byId.get(id).key;
    state.task = DATA.tasks.indexOf(promptInfo(state.key).task);
    update(push);
    $("rx-run").scrollIntoView({ behavior: "smooth", block: "start" });
  }

  function update(push) {
    writeHash(push);
    drawControls();
    drawCompare();
    drawRun();
  }

  window.addEventListener("popstate", () => {
    readHash();
    drawControls();
    drawCompare();
    drawRun();
  });

  fetch("explorer/runs.json")
    .then((res) => {
      if (!res.ok) throw new Error(res.status);
      return res.json();
    })
    .then((d) => {
      DATA = d;
      d.runs.forEach((r) => byId.set(r.id, r));
      const keyOrder = d.tasks.flatMap((t) => t.prompts.map((p) => p.key));
      sequence = d.models.flatMap((m) =>
        d.runs.filter((r) => r.model === m.id).sort((a, b) => keyOrder.indexOf(a.key) - keyOrder.indexOf(b.key) || a.rep - b.rep)
      );
      readHash();
      drawLegend();
      update(false);
      if (state.run) $("rx-run").scrollIntoView({ block: "start" });
    })
    .catch((e) => {
      $("rx-compare").replaceChildren(el("p", { class: "rx-loading" }, `Could not load the runs (${e.message}).`));
    });
})();
