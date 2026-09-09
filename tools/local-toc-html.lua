-- tools/local-toc-html.lua
--
-- Per-chapter local table of contents for the HTML book build -- the AST-level
-- analogue of build-book-localtoc.sh's etoc \localtableofcontents.  Immediately
-- after the H1 that opens each chapter, it inserts a compact "Contents" box
-- listing that chapter's own ## sections (and ### subsections, at depth 3) as
-- in-page #anchor links.  The links are built from pandoc's OWN heading
-- identifiers, in the same run that assigns them, so every anchor is correct by
-- construction -- no marker injection, no post-processing of rendered HTML.
--
-- The build passes two metadata keys, mirroring the PDF build's knobs:
--   local_toc_depth      2 = ## only; 3 (default) = ## + ###.   (PDF: LOCAL_DEPTH)
--   local_toc_skipfirst  "false"/"0"/"no"/"off" also give the first chapter (the
--                        front matter) a Contents box; any other value (the
--                        default) skips it.               (PDF: FRONTMATTER=first)
--
-- Emits <div class="local-toc"> with a <div class="local-toc-title"> and a
-- (possibly nested) bullet list; tools/style.css targets those classes.
--
-- Requires Pandoc >= 3.0.

local depth = 3
local skipfirst = true

-- Read a metadata key by either spelling.  `--metadata k=v` reaches a Lua
-- filter as a bare string, and `--metadata k=true|false` as a bare boolean, so
-- pick the first key that is actually present (an `or` chain would drop a
-- legitimate `false`).
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
  local s = metaValue(meta, 'local_toc_skipfirst', 'local-toc-skipfirst')
  if type(s) == 'boolean' then
    skipfirst = s
  elseif s ~= nil then
    local v = pandoc.utils.stringify(s):lower()
    skipfirst = not (v == 'false' or v == '0' or v == 'no' or v == 'off')
  end
end

-- A chapter's own heading blocks at levels 2..depth, in document order, from
-- just after its H1 up to the next H1 (or the end of the document).
local function subsectionsAfter(blocks, start)
  local subs = {}
  for j = start, #blocks do
    local b = blocks[j]
    if b.t == 'Header' and b.level == 1 then break end
    if b.t == 'Header' and b.level >= 2 and b.level <= depth then
      subs[#subs + 1] = b
    end
  end
  return subs
end

-- The "Contents" Div for one chapter, or nil when it lists nothing.
local function contentsBox(subs)
  if #subs == 0 then return nil end

  -- Each ## opens a new top-level entry; ### nest under the preceding ##
  -- (a leading ### with no ## yet is promoted to the top level).
  local groups = {}
  for _, h in ipairs(subs) do
    local link = pandoc.Link(pandoc.utils.stringify(h.content), '#' .. h.identifier)
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

function Pandoc(doc)
  readMeta(doc.meta)

  local out = {}
  local chapter = 0
  for i, b in ipairs(doc.blocks) do
    out[#out + 1] = b
    if b.t == 'Header' and b.level == 1 then
      chapter = chapter + 1
      if not (skipfirst and chapter == 1) then
        local box = contentsBox(subsectionsAfter(doc.blocks, i + 1))
        if box then out[#out + 1] = box end
      end
    end
  end
  doc.blocks = out
  return doc
end
