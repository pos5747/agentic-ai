"""Build explorer/runs.json, the data behind the "Explore the runs" page (runs.qmd).

Usage, from site/:   python3 explorer/build-runs.py

Reads the four graded batches in ../local-agent-example/results/full-<model>/
(outside this repo) and writes one compact file:
  - one record per row of each batch's runs.csv (750 in all): the grade
    (stage, claimed, the grader's note), time, cost, the agent's messages and
    tool calls (name, a short argument, a trimmed output for shell calls),
    a diff of logit.R from the starting file to the agent's version,
    after.txt, the new files, and whether data.csv changed;
  - the 15 prompts, verbatim, from the batch's own prompts.tsv;
  - the deck's eight lecture runs.
The raw log.jsonl files are never copied. Logs are parsed with
../local-agent-example/tools/logparse.py, the parser the graders' transcripts
came from, so "final message" means the same thing here as in the grading.

Privacy: the macOS username (read from this machine), home paths, and email
addresses are replaced before writing, and the script stops if any remain.
Counts: the script stops unless the four outcomes and the fully-correct
counts equal runs.csv, results/full-summary.md, and the deck's Totals slide.
"""
import csv
import difflib
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(HERE, "..", "..", "local-agent-example"))
RES = os.path.join(SRC, "results")
OUT = os.path.join(HERE, "runs.json")
HOME = os.path.expanduser("~")    # the runs were made on this machine, so its
USER = os.path.basename(HOME)     # home path and username are what to remove
sys.path.insert(0, os.path.join(SRC, "tools"))
from logparse import events as parse_events  # noqa: E402

MODELS = [  # batch, short id, label, interface
    ("full-haiku", "haiku", "Haiku", "Claude Code"),
    ("full-sonnet", "sonnet", "Sonnet", "Claude Code"),
    ("full-qwen", "qwen", "qwen", "OpenCode"),
    ("full-gptoss", "gptoss", "gpt-oss", "OpenCode"),
]

TASKS = [  # task, [(prompt key, label)]
    ("Summarize", [("print-naive", "naive"), ("print-better", "better")]),
    ("Find", [("bugs-naive", "naive"), ("bugs-better", "better")]),
    ("Fix", [("fix-vague", "vague"), ("fix-naive", "naive"), ("fix-better", "better"), ("fix-scope", "scoped")]),
    ("Probability", [("prob-naive", "naive"), ("prob-better", "better")]),
    ("Confidence interval", [("ci-naive", "naive"), ("ci-better", "better")]),
    ("IQR effect", [("iqr-naive", "naive"), ("iqr-base", "better"), ("iqr-fn", "+ function name")]),
]

# The deck's eight runs (header comment of slides/slides.qmd).
LECTURE = {
    "haiku/fix-scope-r6": 1, "haiku/fix-vague-r1": 2, "haiku/fix-better-r8": 3,
    "gptoss/fix-naive-r3": 4, "sonnet/bugs-naive-r5": 5, "gptoss/prob-better-r6": 6,
    "qwen/iqr-base-r4": 7, "haiku/ci-better-r1": 8,
}

# The Totals slide: fully correct / claimed success, wrong result /
# claimed success, flawed run / honest failure.
TOTALS = {"haiku": [146, 37, 32, 10], "sonnet": [200, 0, 17, 8],
          "qwen": [40, 46, 21, 43], "gptoss": [30, 54, 34, 32]}
OUTCOMES = ["correct", "wrong", "flawed", "honest"]

ARG_CAP = 160      # characters of a tool call's argument shown in its row
OUT_CAP = 700      # characters of a shell call's output (head + tail)
FILE_CAP = 6000    # characters of a new file's contents


def outcome(stage, claimed):
    if stage == "S6":
        return "correct"
    if claimed == "1" and stage in ("S2", "S3"):
        return "wrong"
    if claimed == "1" and stage in ("S4", "S5"):
        return "flawed"
    return "honest"


def scrub(s):
    """Shorten the harness's paths and remove anything personal."""
    here = lambda m: "./" if m.group(0).endswith("/") else "."
    s = re.sub(r"(/private)?/tmp/agent-trials/full-[a-z]+/[a-z]+-[a-z]+-r\d+/?", here, s)
    s = re.sub(r"(/private)?/tmp/agent-trials/full-[a-z]+/?", here, s)
    s = s.replace(HOME + "/agent-trials/fakehome", "~")
    s = s.replace(HOME, "~")
    s = re.sub(r"/Users/[A-Za-z0-9._-]+", "~", s)
    s = re.sub(re.escape(USER), "user", s, flags=re.I)
    s = re.sub(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}", "[email]", s)
    return s


def trim(s, cap):
    s = str(s).rstrip()
    if len(s) <= cap:
        return s
    head = int(cap * 0.6)
    return s[:head] + "\n…\n" + s[-(cap - head):]


def short_arg(inp):
    """One short argument for a tool call: the command, path, URL, or query."""
    if not isinstance(inp, dict):
        return trim(str(inp), ARG_CAP)
    for k in ("command", "file_path", "filePath", "path", "url", "query", "pattern",
              "description", "prompt", "skill"):
        v = inp.get(k)
        if isinstance(v, str) and v:
            v = v.strip()
            if k in ("file_path", "filePath", "path"):
                v = re.sub(r"^.*/agent-trials/full-[a-z]+/[a-z]+-[a-z]+-r\d+/", "", v)
            return v if len(v) <= ARG_CAP else v[:ARG_CAP] + "…"
    if "todos" in inp:
        return "(to-do list)"
    return ""


def is_shell(name):
    return name.split(":")[-1].lower() == "bash"


def data_writes(events):
    """What the agent wrote to data.csv, when the log shows it."""
    found = []
    for e in events:
        if e[0] != "tool":
            continue
        _, name, inp, _ = e
        if not isinstance(inp, dict):
            continue
        path = inp.get("file_path") or inp.get("filePath") or ""
        base = name.split(":")[-1].lower()
        if path.endswith("data.csv") and base == "write":
            found.append(("write", inp.get("content", "")))
        elif path.endswith("data.csv") and base == "edit":
            found.append(("edit", f"- {inp.get('old_string', inp.get('oldString', ''))}\n"
                                  f"+ {inp.get('new_string', inp.get('newString', ''))}"))
        elif is_shell(name) and re.search(r">\s*['\"]?(\./)?data\.csv", inp.get("command", "")):
            found.append(("shell", inp.get("command", "")))
    return found


def unified(a, b):
    lines = list(difflib.unified_diff(a.splitlines(), b.splitlines(), "start", "agent", lineterm="", n=3))
    return "\n".join(lines[2:])  # drop the ---/+++ header; the page draws its own


def read(path, default=None):
    if not os.path.exists(path):
        return default
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def main():
    # Prompts: the four batches ran the same prompts.tsv.
    texts = []
    for batch, *_ in MODELS:
        texts.append(read(os.path.join(RES, batch, "prompts.tsv")))
    assert len(set(texts)) == 1, "the batches ran different prompts"
    prompts = {}
    for line in texts[0].splitlines():
        if line and not line.startswith("#"):
            k, group, text = line.split("\t")
            prompts[k] = {"group": group, "text": text}
    starts = {g: read(os.path.join(SRC, "materials", g, "logit.R")) for g in ("1-bugs", "2-run", "3-new")}

    runs = []
    for batch, mid, _, _ in MODELS:
        progress = {}
        for line in open(os.path.join(RES, batch, "progress.txt")):
            if " secs=" in line:
                progress[line.split()[0]] = line
        for row in csv.DictReader(open(os.path.join(RES, batch, "runs.csv"))):
            rid = row["run"]
            d = os.path.join(RES, batch, rid)
            log = os.path.join(d, "log.jsonl")
            assert os.path.exists(log), log
            events, _ = parse_events(log) if os.path.getsize(log) else ([], {})

            conv, texts = [], []
            for e in events:
                if e[0] == "tool":
                    _, name, inp, out = e
                    item = {"t": "tool", "name": name, "arg": short_arg(inp)}
                    if is_shell(name) and out:
                        item["out"] = trim(out, OUT_CAP)
                    conv.append(item)
                elif e[0] == "text":
                    texts.append(len(conv))
                    conv.append({"t": "text", "text": e[1]})
                elif e[0] == "subtext":
                    conv.append({"t": "subtext", "text": trim(e[1], 1500)})
                else:
                    conv.append({"t": "error", "text": trim(e[1], 400)})
            if texts:
                conv[texts[-1]]["final"] = True

            start = starts[prompts[row["key"]]["group"]]
            final = read(os.path.join(d, "agent-test", "logit.R"), "")
            new_files = []
            for fn in sorted(os.listdir(os.path.join(d, "agent-test"))):
                if fn in ("logit.R", "data.csv"):
                    continue
                body = read(os.path.join(d, "agent-test", fn), "")
                new_files.append({"name": fn, "text": trim(body, FILE_CAP)})
            prog = progress[rid]
            data_changed = row["data_unchanged"] != "1"
            assert data_changed == ("data_changed=yes" in prog), rid
            listed = re.search(r"new_files=\[([^\]]*)\]", prog).group(1)
            assert sorted(x for x in listed.split(",") if x) == [f["name"] for f in new_files], rid

            uid = f"{mid}/{rid}"
            rec = {
                "id": uid, "model": mid, "key": row["key"], "rep": int(row["rep"]),
                "secs": int(row["secs"]),
                "cost": round(float(row["cost_usd"]), 4) if row["cost_usd"] else None,
                "tools": int(row["tool_calls"]), "ranR": row["ran_r"] == "True",
                "stage": row["stage"], "claimed": int(row["claimed"]),
                "outcome": outcome(row["stage"], row["claimed"]),
                "note": row["note"], "conv": conv,
                "changed": final != start, "diff": unified(start, final) if final != start else "",
                "after": read(os.path.join(d, "after.txt"), "").rstrip(),
                "dataChanged": data_changed, "newFiles": new_files,
            }
            if data_changed:
                rec["dataWrites"] = [{"how": h, "text": trim(t, 1500)} for h, t in data_writes(events)]
            if uid in LECTURE:
                rec["lecture"] = LECTURE[uid]
            runs.append(rec)
    runs.sort(key=lambda r: ([m[1] for m in MODELS].index(r["model"]), r["key"], r["rep"]))

    check(runs)

    data = {
        "models": [{"id": m, "label": lab, "interface": i, "batch": b} for b, m, lab, i in MODELS],
        "tasks": [{"task": t, "prompts": [{"key": k, "label": lab, "text": prompts[k]["text"],
                                          "group": prompts[k]["group"]} for k, lab in ps]}
                  for t, ps in TASKS],
        "starts": starts,
        "runs": runs,
    }
    text = scrub(json.dumps(data, ensure_ascii=False, separators=(",", ":")))
    leaks = re.findall(re.escape(USER) + r"|/Users/|@[A-Za-z0-9-]+\.[A-Za-z]{2,}", text, flags=re.I)
    assert not leaks, f"personal strings remain: {sorted(set(leaks))[:10]}"
    json.loads(text)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"{len(runs)} runs -> {OUT} ({len(text) / 1e6:.2f} MB)")


def check(runs):
    """The counts the page shows must equal runs.csv, full-summary.md, and the deck."""
    assert len(runs) == 750, len(runs)
    assert len({r["id"] for r in runs}) == 750
    assert sorted(LECTURE) == sorted(r["id"] for r in runs if "lecture" in r)
    for mid, want in TOTALS.items():
        got = [sum(r["outcome"] == o for r in runs if r["model"] == mid) for o in OUTCOMES]
        assert got == want, (mid, got, want)
    # The "fully correct / n" table at the top of results/full-summary.md.
    summary = read(os.path.join(RES, "full-summary.md"))
    table = summary.split("## All batches: fully correct / n")[1].split("\n## ")[0]
    cells = 0
    for line in table.splitlines():
        m = re.match(r"\| ([a-z]+-[a-z]+) \|(.*)\|$", line)
        if not m:
            continue
        for (batch, mid, *_), cell in zip(MODELS, m.group(2).split("|")):
            ok, n = map(int, cell.strip().split("/"))
            these = [r for r in runs if r["model"] == mid and r["key"] == m.group(1)]
            assert (sum(r["outcome"] == "correct" for r in these), len(these)) == (ok, n), (mid, m.group(1))
            cells += 1
    assert cells == 60, cells


if __name__ == "__main__":
    main()
