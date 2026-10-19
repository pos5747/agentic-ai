-- agent-gui.lua
-- Turns plain-text blocks under a level-2 heading into the mock "agent
-- workspace" slides. Styling is in mock-gui.css. Everything else in the deck
-- is ordinary Quarto revealjs markdown.
--
-- Activate in the YAML header of ../slides.qmd:
--   filters: [src/agent-gui.lua, quarto]
--
-- ===========================================================================
-- 1. A run slide:   ## Title {.agent-gui agent="Claude Code · Haiku"}
-- ===========================================================================
-- Under the heading, write fenced code blocks, in any order. Each is plain
-- text, shown exactly as typed.
--
--   ```{.chat}       the conversation (see the line prefixes below)
--   ```{.code}       the script before the agent's turn (the whole file)
--   ```{.after}      the script after the agent's turn (the whole file).
--                    Leave this block out if the agent did not change it.
--   ```{.output}     what R prints when you run the script afterward
--   ```{.files}      one file per line:  name  [M|A|D]  [note]
--   ```{.captions}   five lines, one per step (see below)
--   ```{.diff file="data.csv" count="+11 −501"}   optional, see below
--
-- The diff pane is computed from .code and .after; you never type it. Add a
-- .diff block only for another file (it is appended), or with file="logit.R"
-- to replace the computed diff with a shortened one. In a .diff block, lines
-- that start with "-" are removed lines, "+" added lines, anything else a
-- dim note such as " … 500 more lines removed". Add flag="true" to mark the
-- file name at the last step.
--
-- Line prefixes in .chat:
--   > text       the prompt (first line of the block, on one line)
--   text         something the agent says (gets a bullet)
--   (2 spaces)   a continuation line of what the agent says (no bullet)
--   * Name(arg)  a tool call
--   | text       tool output (consecutive lines stay together, spacing kept)
--   (4 spaces)   a code block the agent printed
--   ...          steps or text left out
-- Inside what the agent says: `code`, **bold**, *italic*.
--
-- The marker:  wrap text in ==double equals== in any block. It is shown
-- normally and turns yellow at the last step.
--
-- .captions, one line per step, written as  Bold part. | The rest.
--   line 1  before anything happens
--   line 2  the prompt is typed          (numbered "1 ·" automatically)
--   line 3  the agent replies            ("2 ·")
--   line 4  you run the code             ("3 ·")
--   line 5  the point, when the marker appears
--
-- Optional heading attributes:
--   agent="OpenCode · qwen"     label on the conversation pane
--   file="logit.R"              name shown on the code pane and in the diff
--   path="~/project"            shown at the top right
--   code=1.2 out=1              heights of the two left panes (a ratio)
--   diff=0.7 chat=1.3           heights of the two right panes (a ratio)
--   flag-nochange="true"        mark "No changes." and "none" at the last step
-- Optional attribute on .code or .after:
--   show="1-4,12-23"            lines to display ("…" stands in for the rest;
--                               the diff still uses the whole file)
--
-- ===========================================================================
-- 2. A teaser slide:   ## Run 1 {.teaser count="1" of="3"}
-- ===========================================================================
--   One or more paragraphs (the setup), a ```{.prompt agent="…"} block, then
--   `. . .` and one paragraph per line to reveal. The last one gets the
--   five-pane glyph.
--
-- 3. An opener:        ## Three things that can go wrong {.opener}
--   The heading is the big title. Paragraphs, `. . .`, reveal lines, as above.
--
-- 4. A recap:          ## Three runs, three panes {.recap}
--   ```{.rows}  one line per run:  said | what happened | small note | pane
--   where pane is one of  code  out  diff  chat  files  all  none.
--   A paragraph after the block is the closing line.
--
-- 5. The anatomy:      ## Five things to watch {.anatomy}
--   ```{.panes}  one line per pane:  key | tool | role | what it tells | caveat
--   with key one of  code  out  diff  chat  files. A paragraph is the caption.
-- ===========================================================================

local stringify = pandoc.utils.stringify

-- ---------------------------------------------------------------- helpers --

local function esc(s)
  s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
  return s
end

local FLAG = '<span class="fragment flag" data-fragment-index="3">%1</span>'
local function flags(s) return (s:gsub("==(.-)==", FLAG)) end
local function strip_flags(s) return (s:gsub("==(.-)==", "%1")) end

local function lines(s)
  local t = {}
  for l in (s .. "\n"):gmatch("(.-)\n") do t[#t + 1] = l end
  return t
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function split_bar(s)
  local t = {}
  for part in (s .. "|"):gmatch("(.-)|") do t[#t + 1] = trim(part) end
  return t
end

-- text the agent wrote: `code`, **bold**, *italic*, ==marker==
local function inline(s)
  s = esc(s)
  local codes = {}
  s = s:gsub("`([^`]+)`", function(c)
    codes[#codes + 1] = c
    return "\1" .. #codes .. "\2"
  end)
  s = s:gsub("%*%*(.-)%*%*", "<b>%1</b>")
  s = s:gsub("%*([^%*%s][^%*]-)%*", "<i>%1</i>")
  s = flags(s)
  s = s:gsub("\1(%d+)\2", function(i)
    return '<span class="ic">' .. codes[tonumber(i)] .. "</span>"
  end)
  return s
end

-- a paragraph of ordinary markdown, as inline HTML
local function para_html(block)
  local doc = pandoc.Pandoc({ pandoc.Plain(block.content) })
  return trim(pandoc.write(doc, "html"))
end

local function is_pause(block)
  return block.t == "Para" and stringify(block) == ". . ."
end

local MINI_KEYS = { "code", "out", "diff", "chat", "files" }
local function mini(hit)
  local c = {}
  for _, k in ipairs(MINI_KEYS) do
    c[k] = k .. ((hit == k or hit == "all") and " hit" or "")
  end
  return '<div class="mini"><div class="mcol"><i class="' .. c.code .. '"></i><i class="' .. c.out ..
    '"></i></div><div class="mcol"><i class="' .. c.diff .. '"></i><i class="' .. c.chat ..
    '"></i></div><i class="' .. c.files .. '"></i></div>'
end

-- ------------------------------------------------------------- code pane --

local function code_line(l)
  local h = esc(l)
  if strip_flags(l):match("^%s*#") then
    return '<span class="cm">' .. flags(h) .. "</span>"
  end
  h = h:gsub('"[^"]*"', function(m) return '<span class="st">' .. m .. "</span>" end)
  return flags(h)
end

local function parse_show(spec, n)
  local want = {}
  if not spec or spec == "" then
    for i = 1, n do want[i] = true end
    return want
  end
  for part in spec:gmatch("[^,]+") do
    local a, b = part:match("^%s*(%d+)%s*%-%s*(%d+)%s*$")
    if not a then a = part:match("^%s*(%d+)%s*$"); b = a end
    for i = tonumber(a), tonumber(b) do want[i] = true end
  end
  return want
end

local function render_code(text, show)
  local ls = lines(text)
  local want = parse_show(show, #ls)
  local out, skipping = {}, false
  for i, l in ipairs(ls) do
    if want[i] then
      out[#out + 1] = '<div class="ln"><span class="n">' .. i .. "</span>" .. code_line(l) .. "</div>"
      skipping = false
    elseif not skipping then
      out[#out + 1] = '<div class="ln skip"><span class="n"></span>…</div>'
      skipping = true
    end
  end
  return table.concat(out, "\n")
end

-- ------------------------------------------------------------------ diff --

local function diff_ops(a, b)
  local n, m = #a, #b
  local L = {}
  for i = 0, n do
    L[i] = {}
    for j = 0, m do L[i][j] = 0 end
  end
  for i = n - 1, 0, -1 do
    for j = m - 1, 0, -1 do
      if a[i + 1] == b[j + 1] then
        L[i][j] = L[i + 1][j + 1] + 1
      else
        L[i][j] = math.max(L[i + 1][j], L[i][j + 1])
      end
    end
  end
  local ops, i, j = {}, 0, 0
  while i < n and j < m do
    if a[i + 1] == b[j + 1] then
      i = i + 1; j = j + 1
    elseif L[i + 1][j] >= L[i][j + 1] then
      ops[#ops + 1] = { "-", a[i + 1] }; i = i + 1
    else
      ops[#ops + 1] = { "+", b[j + 1] }; j = j + 1
    end
  end
  while i < n do ops[#ops + 1] = { "-", a[i + 1] }; i = i + 1 end
  while j < m do ops[#ops + 1] = { "+", b[j + 1] }; j = j + 1 end
  return ops
end

local function diff_file_header(name, count, flagged)
  local nm = esc(name)
  if flagged then nm = flags("==" .. nm .. "==") end
  return '<div class="dfile"><span>' .. nm .. '</span><span class="cnt">' .. esc(count or "") .. "</span></div>"
end

local function computed_diff(name, before, after)
  local ops = diff_ops(lines(strip_flags(before)), lines(strip_flags(after)))
  if #ops == 0 then return nil end
  local out, add, del = {}, 0, 0
  for _, op in ipairs(ops) do
    if op[1] == "-" then
      del = del + 1
      out[#out + 1] = '<div class="dl del">-' .. esc(op[2]) .. "</div>"
    else
      add = add + 1
      out[#out + 1] = '<div class="dl add">+' .. esc(op[2]) .. "</div>"
    end
  end
  return diff_file_header(name, "+" .. add .. " −" .. del, false) .. "\n" .. table.concat(out, "\n")
end

local function literal_diff(block)
  local out = {}
  for _, l in ipairs(lines(block.text)) do
    local first = l:sub(1, 1)
    local cls = (first == "-" and "del") or (first == "+" and "add") or "skip"
    out[#out + 1] = '<div class="dl ' .. cls .. '">' .. flags(esc(l)) .. "</div>"
  end
  return diff_file_header(block.attributes["file"] or "", block.attributes["count"],
    block.attributes["flag"] == "true") .. "\n" .. table.concat(out, "\n")
end

-- ---------------------------------------------------------- conversation --

local function render_chat(text)
  local ls = lines(text)
  local prompt = inline((ls[1] or ""):gsub("^>%s?", ""))
  local out, blk, res = {}, nil, nil
  local function flush()
    if blk then out[#out + 1] = '<div class="msg block">' .. table.concat(blk, "\n") .. "</div>"; blk = nil end
    if res then out[#out + 1] = '<div class="msg res">' .. table.concat(res, "\n") .. "</div>"; res = nil end
  end
  for k = 2, #ls do
    local l = ls[k]
    if l:match("^    ") then
      if res then flush() end
      blk = blk or {}
      blk[#blk + 1] = flags(esc(l:sub(5)))
    elseif l:match("^|") then
      if blk then flush() end
      res = res or {}
      res[#res + 1] = flags(esc((l:gsub("^| ?", ""))))
    elseif l:match("^%s*$") then
      if blk then
        local nx = k + 1
        while ls[nx] and ls[nx]:match("^%s*$") do nx = nx + 1 end
        if ls[nx] and ls[nx]:match("^    ") then blk[#blk + 1] = "" else flush() end
      else
        flush()
      end
    else
      flush()
      if l == "..." or l == "…" then
        out[#out + 1] = '<div class="msg cut">…</div>'
      elseif l:match("^%* ") then
        out[#out + 1] = '<div class="msg tool">' .. inline(l:sub(3)) .. "</div>"
      elseif l:match("^  ") then
        out[#out + 1] = '<div class="msg more">' .. inline(l:sub(3)) .. "</div>"
      else
        out[#out + 1] = '<div class="msg say">' .. inline(l) .. "</div>"
      end
    end
  end
  flush()
  return prompt, table.concat(out, "\n")
end

-- ------------------------------------------------------------- run slide --

local function render_output(text)
  local out = {}
  for i, l in ipairs(lines(text)) do
    local h = flags(esc(l))
    if l:match("^%$ ") then h = '<span class="cmd">' .. h .. "</span>" end
    out[i] = h
  end
  return table.concat(out, "\n")
end

local function caption(cls, idx, bold, rest)
  local b = (bold and bold ~= "") and ("<b>" .. esc(bold) .. "</b>") or ""
  return '<span class="fragment ' .. cls .. ' quiet" data-fragment-index="' .. idx .. '">' .. b .. esc(rest or "") .. "</span>"
end

local DEFAULT_CAPTIONS = {
  "The project folder.",
  "You type a prompt. | Nothing else changes.",
  "The agent replies.",
  "You run the code.",
  "",
}

local function run_slide(header, blocks)
  local at = header.attributes
  local b = { diff = {} }
  for _, blk in ipairs(blocks) do
    if blk.t == "CodeBlock" then
      local cls = blk.classes[1]
      if cls == "diff" then b.diff[#b.diff + 1] = blk elseif cls then b[cls] = blk end
    end
  end
  local file = at["file"] or "logit.R"
  local nochange_flag = at["flag-nochange"] == "true"
  local title = esc(stringify(header.content))

  -- code pane
  local code_html
  local before = b.code and b.code.text or ""
  local changed = b.after and strip_flags(b.after.text) ~= strip_flags(before)
  if changed then
    code_html = '<div class="fragment until quiet" data-fragment-index="1">\n' ..
      render_code(strip_flags(before), b.code.attributes["show"]) .. "\n</div>\n" ..
      '<div class="fragment step" data-fragment-index="1">\n' ..
      render_code(b.after.text, b.after.attributes["show"]) .. "\n</div>"
  else
    code_html = render_code(before, b.code and b.code.attributes["show"])
  end

  -- diff pane
  local parts, replaced = {}, false
  for _, d in ipairs(b.diff) do
    if d.attributes["file"] == file then replaced = true end
  end
  if changed and not replaced then parts[#parts + 1] = computed_diff(file, before, b.after.text) end
  for _, d in ipairs(b.diff) do parts[#parts + 1] = literal_diff(d) end
  local diff_html
  if #parts > 0 then
    diff_html = '<div class="idle fragment until quiet" data-fragment-index="1">No changes yet.</div>\n' ..
      '<div class="fragment step" data-fragment-index="1">\n' ..
      table.concat(parts, '\n<div class="dgap"></div>\n') .. "\n</div>"
  else
    local txt = nochange_flag and flags("==No changes.==") or "No changes."
    diff_html = '<div class="idle fragment until quiet" data-fragment-index="1">No changes yet.</div>\n' ..
      '<div class="fragment step quiet" data-fragment-index="1">' .. txt .. "</div>"
  end

  -- conversation
  local prompt, reply = render_chat(b.chat and b.chat.text or "> ")

  -- files pane
  local rows, nchanged = {}, 0
  for _, l in ipairs(lines(b.files and b.files.text or "")) do
    local name, rest = l:match("^(%S+)%s*(.*)$")
    if name then
      local badge, note = rest:match("^(%u)%s*(.*)$")
      if badge then
        nchanged = nchanged + 1
        local bh = '<span class="badge fragment step" data-fragment-index="1">' .. badge .. "</span>"
        if badge == "A" then
          rows[#rows + 1] = '<div class="f child fragment step" data-fragment-index="1"><span>' .. esc(name) ..
            '</span><span class="badge">A</span></div>'
        else
          rows[#rows + 1] = '<div class="f child"><span>' .. esc(name) .. "</span>" .. bh .. "</div>"
        end
        if note ~= "" then
          rows[#rows + 1] = '<div class="fnote fragment step quiet" data-fragment-index="3">' .. esc(note) .. "</div>"
        end
      else
        rows[#rows + 1] = '<div class="f child"><span>' .. esc(name) .. "</span></div>"
      end
    end
  end
  local changes
  if nchanged == 0 then
    changes = '<div class="f"><span>' .. (nochange_flag and flags("==none==") or "none") .. "</span></div>"
  else
    changes = '<div class="f fragment until quiet" data-fragment-index="1"><span>none</span></div>\n' ..
      '<div class="f fragment step quiet" data-fragment-index="1"><span>' .. nchanged ..
      (nchanged == 1 and " file" or " files") .. "</span></div>"
  end

  -- captions
  local caps = lines(b.captions and b.captions.text or "")
  local cap_html = {}
  for i = 1, 5 do
    local line = caps[i]
    if not line or trim(line) == "" then line = DEFAULT_CAPTIONS[i] end
    local bold, rest = line:match("^(.-)%s+|%s+(.*)$")
    if not bold then
      if i == 1 then bold, rest = "", line else bold, rest = line, "" end
    end
    if i >= 2 and i <= 4 then bold = (i - 1) .. " · " .. bold end
    if i == 1 then
      cap_html[#cap_html + 1] = caption("until", 0, bold, rest)
    else
      cap_html[#cap_html + 1] = caption("now", i - 2, bold, rest)
    end
  end

  local style = {}
  for _, k in ipairs({ "code", "out", "diff", "chat" }) do
    if at[k] then style[#style + 1] = "--" .. k .. ": " .. at[k] .. ";" end
  end
  local style_attr = #style > 0 and (' style="' .. table.concat(style, " ") .. '"') or ""

  local function pane(key, role, tool, body, raw_body)
    return '<div class="pane ' .. key .. '">\n<div class="pane-title"><span class="role">' .. role ..
      '</span><span class="name">' .. esc(tool) .. '</span></div>\n<div class="pane-body">' ..
      (raw_body and "" or "\n") .. body .. (raw_body and "" or "\n") .. "</div>\n</div>"
  end

  local out_body = '<span class="idle fragment until quiet" data-fragment-index="2">Not run yet.</span>' ..
    '<span class="fragment step" data-fragment-index="2">' .. render_output(b.output and b.output.text or "") .. "</span>"
  local chat_body = '<div class="idle fragment until quiet" data-fragment-index="0">No prompt yet.</div>\n' ..
    '<div class="msg user fragment step" data-fragment-index="0">' .. prompt .. "</div>\n" ..
    '<div class="fragment step" data-fragment-index="1">\n' .. reply .. "\n</div>"
  local files_body = '<div class="fsec">Project</div>\n<div class="f dir"><span>project/</span></div>\n' ..
    table.concat(rows, "\n") .. '\n<div class="fsec">Changes</div>\n' .. changes ..
    '\n<div class="legend"><b>M</b> modified<br><b>A</b> added<br><b>D</b> deleted</div>'

  -- tex2jax_ignore: an agent's "\\(y = 1\\)" stays as typed, not typeset as math
  return '<div class="agent-gui tex2jax_ignore"' .. style_attr .. ">\n" ..
    '<div class="bar"><span class="title">' .. title .. '</span><span class="path">' ..
    esc(at["path"] or "~/project") .. "</span></div>\n" ..
    '<div class="col left">\n' ..
    pane("code", "The code", "RStudio · " .. file, code_html) .. "\n" ..
    pane("out", "The output", "R · you run it", out_body, true) .. "\n</div>\n" ..
    '<div class="col right">\n' ..
    pane("diff", "The diff", "GitHub Desktop", diff_html) .. "\n" ..
    pane("chat", "The conversation", at["agent"] or "the agent", chat_body) .. "\n</div>\n" ..
    pane("files", "The files", "project folder", files_body) .. "\n" ..
    '<div class="status">\n' .. table.concat(cap_html, "\n") .. "\n</div>\n</div>"
end

-- ----------------------------------------------- teaser, opener, anatomy --

local function teaser_slide(header, blocks, opener)
  local setup, prompt, teases, after_pause = {}, nil, {}, false
  for _, blk in ipairs(blocks) do
    if is_pause(blk) then
      after_pause = true
    elseif blk.t == "CodeBlock" and blk.classes[1] == "prompt" then
      prompt = '<div class="tprompt"><span class="who">' .. esc(blk.attributes["agent"] or "") ..
        "</span>" .. esc(blk.text) .. "</div>"
    elseif blk.t == "Para" then
      if after_pause then teases[#teases + 1] = para_html(blk) else setup[#setup + 1] = para_html(blk) end
    end
  end
  local body = {}
  if opener then body[#body + 1] = '<div class="ttitle">' .. esc(stringify(header.content)) .. "</div>" end
  if #setup > 0 then body[#body + 1] = '<div class="setup">' .. table.concat(setup, "<br>") .. "</div>" end
  if prompt then body[#body + 1] = prompt end
  for i, t in ipairs(teases) do
    if i == #teases then
      body[#body + 1] = '<div class="tease q fragment">' .. mini() .. "<span>" .. t .. "</span></div>"
    else
      body[#body + 1] = '<div class="tease fragment">' .. t .. "</div>"
    end
  end
  local count = ""
  if not opener and header.attributes["count"] then
    count = '<div class="count"><span class="num">' .. esc(header.attributes["count"]) .. "</span>" ..
      (header.attributes["of"] and ('<span class="of">of ' .. esc(header.attributes["of"]) .. "</span>") or "") ..
      "</div>\n"
  end
  return '<div class="teaser' .. (opener and " open" or "") .. '">\n' .. count ..
    '<div class="tbody">\n' .. table.concat(body, "\n") .. "\n</div>\n</div>"
end

local PANE_LABEL = {
  code = "the code", out = "the output", diff = "the diff", chat = "the conversation",
  files = "the files", all = "all five", none = "none of them",
}

local function recap_slide(header, blocks)
  local rows, closing = {}, nil
  for _, blk in ipairs(blocks) do
    if blk.t == "CodeBlock" and blk.classes[1] == "rows" then
      for _, l in ipairs(lines(blk.text)) do
        if trim(l) ~= "" then rows[#rows + 1] = split_bar(l) end
      end
    elseif blk.t == "Para" then
      closing = para_html(blk)
    end
  end
  local out = {
    '<div class="rhead">The agent said</div><div class="rhead">What happened</div><div class="rhead">The pane that showed it</div>',
  }
  for i, r in ipairs(rows) do
    local pane = r[4] or "none"
    out[#out + 1] = '<div class="said">' .. esc(r[1] or "") .. "</div>\n" ..
      '<div class="was">' .. esc(r[2] or "") .. '<span class="freq">' .. esc(r[3] or "") .. "</span></div>\n" ..
      '<div class="pane-hit fragment" data-fragment-index="' .. (i - 1) .. '">' .. mini(pane) ..
      '<span class="' .. pane .. '">' .. (PANE_LABEL[pane] or pane) .. "</span></div>"
  end
  return '<div class="teaser recap' .. (#rows > 3 and " compact" or "") .. '">\n<div class="tbody">\n' ..
    '<div class="ttitle">' .. esc(stringify(header.content)) .. "</div>\n" ..
    '<div class="rgrid">\n' .. table.concat(out, "\n") .. "\n</div>\n" ..
    (closing and ('<div class="tease fragment" data-fragment-index="' .. #rows .. '">' .. closing .. "</div>\n") or "") ..
    "</div>\n</div>"
end

local function anatomy_slide(header, blocks)
  local p, cap = {}, ""
  for _, blk in ipairs(blocks) do
    if blk.t == "CodeBlock" and blk.classes[1] == "panes" then
      for _, l in ipairs(lines(blk.text)) do
        local r = split_bar(l)
        if r[1] and r[1] ~= "" then p[r[1]] = r end
      end
    elseif blk.t == "Para" then
      cap = para_html(blk)
    end
  end
  local function pane(key)
    local r = p[key] or { key, "", "", "", "" }
    return '<div class="pane ' .. key .. '">\n<div class="pane-title"><span class="role">' .. esc(r[3]) ..
      '</span><span class="name">' .. esc(r[2]) .. '</span></div>\n<div class="pane-body">\n' ..
      '<div class="big">' .. esc(r[3]) .. '</div>\n<div class="tells">' .. esc(r[4] or "") ..
      '</div>\n<div class="but">' .. esc(r[5] or "") .. "</div>\n</div>\n</div>"
  end
  return '<div class="agent-gui anatomy">\n<div class="bar"><span class="title">' ..
    esc(stringify(header.content)) .. '</span><span class="path">' ..
    esc(header.attributes["path"] or "~/project") .. "</span></div>\n" ..
    '<div class="col left">\n' .. pane("code") .. "\n" .. pane("out") .. "\n</div>\n" ..
    '<div class="col right">\n' .. pane("diff") .. "\n" .. pane("chat") .. "\n</div>\n" ..
    pane("files") .. '\n<div class="status"><span>' .. cap .. "</span></div>\n</div>"
end

-- ------------------------------------------------------------------ main --

local KINDS = { "agent-gui", "teaser", "opener", "recap", "anatomy" }

local function kind_of(header)
  for _, k in ipairs(KINDS) do
    if header.classes:includes(k) then return k end
  end
  return nil
end

function Pandoc(doc)
  local out = pandoc.List()
  local i, n = 1, #doc.blocks
  while i <= n do
    local blk = doc.blocks[i]
    local kind = blk.t == "Header" and blk.level == 2 and kind_of(blk) or nil
    if kind then
      local body = {}
      local j = i + 1
      while j <= n and not (doc.blocks[j].t == "Header" and doc.blocks[j].level <= 2) do
        body[#body + 1] = doc.blocks[j]
        j = j + 1
      end
      local html
      if kind == "agent-gui" then html = run_slide(blk, body)
      elseif kind == "teaser" then html = teaser_slide(blk, body, false)
      elseif kind == "opener" then html = teaser_slide(blk, body, true)
      elseif kind == "recap" then html = recap_slide(blk, body)
      else html = anatomy_slide(blk, body) end
      blk.classes = pandoc.List({ "gui-slide" })
      out:insert(blk)
      out:insert(pandoc.RawBlock("html", html))
      i = j
    else
      out:insert(blk)
      i = i + 1
    end
  end
  doc.blocks = out
  return doc
end
