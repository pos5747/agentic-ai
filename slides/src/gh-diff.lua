-- gh-diff.lua: draw a plain-text diff the way GitHub Desktop shows it.
--
-- Write the diff in a fenced block with the class ghdiff:
--
--   ```{.ghdiff}
--   $ git diff logit.R          a command line (optional), shown as typed
--   @@ -1,8 +1,8 @@             a hunk header; sets the line numbers
--    unchanged line             starts with a space: context
--   -removed line               red
--   +added line                 green
--   ...                         lines left out
--   ```
--
-- Line numbers come from the @@ header (old on the left, new on the right),
-- as in GitHub Desktop. Without a header, numbering starts at 1. Styles are
-- in deck.css (.ghdiff). Added 2026-10-19.

local function esc(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function row(cls, old, new, sign, text)
  return '<tr class="' .. cls .. '"><td class="ln">' .. (old or "") ..
    '</td><td class="ln">' .. (new or "") .. '</td><td class="sign">' .. sign ..
    '</td><td class="txt">' .. esc(text) .. "</td></tr>"
end

function CodeBlock(block)
  if not block.classes:includes("ghdiff") then return nil end
  local rows = {}
  local old, new = 1, 1
  for line in (block.text .. "\n"):gmatch("(.-)\n") do
    if line:sub(1, 2) == "$ " then
      rows[#rows + 1] = '<tr class="cmd"><td colspan="4">' .. esc(line) .. "</td></tr>"
    elseif line:sub(1, 2) == "@@" then
      local a, c = line:match("^@@ %-(%d+)[^+]*%+(%d+)")
      if a then old, new = tonumber(a), tonumber(c) end
      rows[#rows + 1] = '<tr class="hunk"><td class="ln"></td><td class="ln"></td><td colspan="2">' ..
        esc(line) .. "</td></tr>"
    elseif line == "..." then
      rows[#rows + 1] = '<tr class="gap"><td class="ln">⋮</td><td class="ln">⋮</td><td colspan="2"></td></tr>'
    elseif line:sub(1, 1) == "-" then
      rows[#rows + 1] = row("del", old, nil, "−", line:sub(2)); old = old + 1
    elseif line:sub(1, 1) == "+" then
      rows[#rows + 1] = row("add", nil, new, "+", line:sub(2)); new = new + 1
    else
      local text = line:sub(1, 1) == " " and line:sub(2) or line
      rows[#rows + 1] = row("ctx", old, new, "", text); old = old + 1; new = new + 1
    end
  end
  return pandoc.RawBlock("html",
    '<div class="ghdiff"><table>' .. table.concat(rows, "") .. "</table></div>")
end
