-- keep-with-diagram.lua -- stop a diagram from being separated, across a page
-- break, from the sentence that introduces it.
--
-- Pandoc renders a mermaid diagram as a paragraph containing a single image,
-- immediately after the paragraph of prose that introduces it ("The whole
-- derivation, on one page:").  Those are two ordinary paragraphs, so LaTeX is
-- free to break between them -- which strands the introducing sentence alone at
-- the foot of a page while its diagram starts the next one.
--
-- The fix is \needspace: reserve, before the introducing paragraph, enough
-- vertical space for that paragraph AND the image.  If the page cannot supply
-- it, the break happens *before* the sentence and the pair travels together.
--
-- The reserved height has to be the image's height AS TYPESET, not its natural
-- height: pandoc wraps every image in \pandocbounded, which scales it down to
-- fit \linewidth (345pt in this book) and \textheight (550pt), never up.  So we
-- read the real page size out of the image file with pdfinfo and apply the same
-- clamp arithmetic here.
--
-- LaTeX-only: the HTML build renders SVG into a scrolling page and has no page
-- breaks to protect against.  Runs AFTER mermaid-filter, so the images exist.

if FORMAT ~= 'latex' and FORMAT ~= 'beamer' then return {} end

local LINEWIDTH  = 345.0   -- \the\linewidth  for documentclass=book, letter
local TEXTHEIGHT = 550.0   -- \the\textheight for the same

-- Height in points that a given image file will actually occupy, or nil if the
-- file cannot be measured (a missing file, or a raster format pdfinfo refuses).
local function typeset_height(src)
  local ok, out = pcall(pandoc.pipe, 'pdfinfo', { src }, '')
  if not ok or not out then return nil end
  local w, h = out:match 'Page size:%s+([%d%.]+) x ([%d%.]+) pts'
  if not w then return nil end
  w, h = tonumber(w), tonumber(h)
  if not w or not h or w <= 0 then return nil end
  local scale = math.min(1.0, LINEWIDTH / w)
  return math.min(h * scale, TEXTHEIGHT)
end

local function lone_image(block)
  if block.t ~= 'Para' then return nil end
  local found = nil
  for _, inline in ipairs(block.content) do
    if inline.t == 'Image' then
      if found then return nil end
      found = inline
    elseif inline.t ~= 'Space' and inline.t ~= 'SoftBreak' then
      return nil
    end
  end
  return found
end

function Blocks(blocks)
  local out, i = {}, 1
  while i <= #blocks do
    local this, next_block = blocks[i], blocks[i + 1]
    local image = next_block and lone_image(next_block) or nil
    if image and this.t == 'Para' and not lone_image(this) then
      local height = typeset_height(image.src)
      if height then
        -- The image, plus a little room for the introducing sentence itself.
        local reserve = math.min(height + 36.0, TEXTHEIGHT)
        out[#out + 1] = pandoc.RawBlock('latex',
          string.format('\\needspace{%.1fpt}', reserve))
        out[#out + 1] = this
        out[#out + 1] = pandoc.RawBlock('latex', '\\nopagebreak')
        out[#out + 1] = next_block
        i = i + 2
        goto continue
      end
    end
    out[#out + 1] = this
    i = i + 1
    ::continue::
  end
  return out
end
