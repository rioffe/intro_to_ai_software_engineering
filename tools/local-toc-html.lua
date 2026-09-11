-- tools/local-toc-html.lua
--
-- Two-level table of contents AND the chapter layout for the HTML book build --
-- the AST-level analogue of build-book-localtoc.sh's Pandoc --toc plus etoc
-- \localtableofcontents.  Every table of contents in book.html comes from here,
-- and each one sits in a rail to the LEFT of the text it indexes:
--
--   * the master "Contents" (chapters only) is built from the level-1 headings
--     and placed beside the FRONT MATTER (the chapter named by local_toc_skip_nth),
--     i.e. at the beginning of the book;
--   * each other chapter gets a compact local "Contents" beside its own body,
--     listing that chapter's ## sections (and ### subsections, at depth 3).
--
-- To make "beside" possible, each chapter (its H1 up to the next H1) is wrapped
-- in a <div class="chapter"> holding exactly three parts: the H1, the sidebar
-- box, and a <div class="chapter-body"> with the rest.  tools/style.css lays
-- that out as a two-column grid (rail + reading column) and makes the rail
-- sticky, so the list stays in view while its chapter scrolls; on narrow screens
-- and in print it falls back to the stacked, in-flow layout.
--
-- The links are built from pandoc's OWN heading identifiers, in the same run
-- that assigns them, so every anchor is correct by construction -- no marker
-- injection, no post-processing of rendered HTML.
--
-- The build passes these metadata keys, mirroring the PDF build's knobs:
--   local_toc_depth      2 = ## only; 3 (default) = ## + ###.   (PDF: LOCAL_DEPTH)
--   local_toc_skip_nth   1-based index of the one chapter that gets the MASTER
--                        list in its rail instead of a local box; 0 = give
--                        every chapter a local box, in which case the master
--                        list stands alone ahead of chapter 1.
--                        Default 1 (the front matter).  build-book-html.sh
--                        derives it from FRONTMATTER exactly as the PDF build
--                        derives its NOLOCAL file -- FRONTMATTER=first -> 1,
--                        FRONTMATTER=0 -> 0, FRONTMATTER=<file> -> that file's
--                        position.
--   toc-title            Title of the master list (default "Contents").
--
-- Emits <div class="chapter"> wrappers; <div class="master-toc"> with a
-- <div class="toc-title">; <div class="local-toc"> with a
-- <div class="local-toc-title">; each list a (possibly nested) bullet list.
-- tools/style.css targets those classes.
--
-- Requires Pandoc >= 3.0.

local depth = 3
local skip_nth = 1
local toc_title = 'Contents'

-- Read a metadata key by either spelling (pandoc accepts both `local_toc_depth`
-- and `local-toc-depth`).  Return the first that is present.
local function metaValue(meta, snake, kebab)
  local v = meta[snake]
  if v == nil then v = meta[kebab] end
  return v
end

local function readMeta(meta)
  local d = metaValue(meta, 'local_toc_depth', 'local-toc-depth')
  if d ~= nil then
    local n = tonumber(pandoc.utils.stringify(d))
    if n and n >= 2 then depth = math.floor(n) end
  end
  local s = metaValue(meta, 'local_toc_skip_nth', 'local-toc-skip-nth')
  if s ~= nil then
    local n = tonumber(pandoc.utils.stringify(s))
    if n and n >= 0 then skip_nth = math.floor(n) end
  end
  local t = metaValue(meta, 'toc_title', 'toc-title')
  if t ~= nil then
    local str = pandoc.utils.stringify(t)
    if str ~= '' then toc_title = str end
  end
end

local function headingLink(h)
  return pandoc.Link(pandoc.utils.stringify(h.content), '#' .. h.identifier)
end

-- A chapter's own heading blocks at levels 2..depth, in document order.
local function subsections(body)
  local subs = {}
  for _, b in ipairs(body) do
    if b.t == 'Header' and b.level >= 2 and b.level <= depth then
      subs[#subs + 1] = b
    end
  end
  return subs
end

-- The local "Contents" Div for one chapter, or nil when it lists nothing.
local function contentsBox(subs)
  if #subs == 0 then return nil end

  -- Each ## opens a new top-level entry; ### nest under the preceding ##
  -- (a leading ### with no ## yet is promoted to the top level).
  local groups = {}
  for _, h in ipairs(subs) do
    local link = headingLink(h)
    if h.level == 2 or #groups == 0 then
      groups[#groups + 1] = { head = pandoc.Plain(link), kids = {} }
    else
      table.insert(groups[#groups].kids, pandoc.Plain(link))
    end
  end

  local items = {}
  for _, g in ipairs(groups) do
    local item = { g.head }
    if #g.kids > 0 then
      local nested = {}
      for _, k in ipairs(g.kids) do nested[#nested + 1] = { k } end
      item[#item + 1] = pandoc.BulletList(nested)
    end
    items[#items + 1] = item
  end

  local title = pandoc.Div(pandoc.Plain(pandoc.Str('Contents')),
                           pandoc.Attr('', { 'local-toc-title' }))
  return pandoc.Div({ title, pandoc.BulletList(items) },
                    pandoc.Attr('', { 'local-toc' }))
end

-- The master "Contents" Div: one entry per chapter H1, or nil with no chapters.
local function masterToc(h1s)
  if #h1s == 0 then return nil end
  local items = {}
  for _, h in ipairs(h1s) do
    items[#items + 1] = { pandoc.Plain(headingLink(h)) }
  end
  local title = pandoc.Div(pandoc.Plain(pandoc.Str(toc_title)),
                           pandoc.Attr('', { 'toc-title' }))
  return pandoc.Div({ title, pandoc.BulletList(items) },
                    pandoc.Attr('', { 'master-toc' },
                                { role = 'navigation', ['aria-label'] = toc_title }))
end

function Pandoc(doc)
  readMeta(doc.meta)
  local blocks = doc.blocks

  -- Chapter boundaries: the index of every level-1 heading.
  local starts, h1s = {}, {}
  for i, b in ipairs(blocks) do
    if b.t == 'Header' and b.level == 1 then
      starts[#starts + 1] = i
      h1s[#h1s + 1] = b
    end
  end
  local master = masterToc(h1s)

  local out = {}
  -- Anything before the first H1 passes through untouched.
  for i = 1, (starts[1] or #blocks + 1) - 1 do out[#out + 1] = blocks[i] end

  -- No chapter hosts the master list (skip_nth=0, or out of range): it stands
  -- alone, in flow, ahead of chapter 1.
  if master and (skip_nth < 1 or skip_nth > #starts) then
    out[#out + 1] = master
  end

  for n, s in ipairs(starts) do
    local last = (starts[n + 1] or #blocks + 1) - 1
    local body = {}
    for j = s + 1, last do body[#body + 1] = blocks[j] end

    local side
    if n == skip_nth then
      side = master
    else
      side = contentsBox(subsections(body))
    end

    local parts = { blocks[s] }
    if side then parts[#parts + 1] = side end
    parts[#parts + 1] = pandoc.Div(body, pandoc.Attr('', { 'chapter-body' }))
    out[#out + 1] = pandoc.Div(parts, pandoc.Attr('', { 'chapter' }))
  end

  doc.blocks = out
  return doc
end
