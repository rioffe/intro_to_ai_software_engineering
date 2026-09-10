-- keep-with-diagram.lua -- two PDF-only fixes for mermaid diagrams.
--
-- (1) KEEP A DIAGRAM WITH ITS INTRODUCING SENTENCE.
-- Pandoc renders a mermaid diagram as a paragraph holding a single image,
-- straight after the prose that introduces it ("The whole derivation, on one
-- page:").  Those are two ordinary paragraphs, so LaTeX may break between them,
-- stranding the sentence at the foot of one page and starting the diagram on
-- the next.  \needspace reserves room for BOTH before the sentence is set; if
-- the page cannot supply it, the break falls before the sentence instead and
-- the pair travels together.
--
-- (2) LET A WIDE DIAGRAM USE A LITTLE OF THE MARGIN.
-- mermaid-cli renders every diagram into a 600pt-wide page, so a wide diagram
-- is already squeezed once before LaTeX sees it; \pandocbounded then squeezes
-- 600pt down to \linewidth (345pt).  After that double reduction the labels in
-- a wide diagram are markedly smaller than those in a narrow one -- text size
-- runs as \linewidth / natural-width.  This book's page carries 267pt of
-- margin around a 345pt text block, so a wide figure can be set slightly wider
-- than the measure, centred, and still sit comfortably inside the paper.  Only
-- diagrams that would otherwise be shrunk are widened, and never past MAXWIDTH.
--
-- Both need the image's real dimensions, read with pdfinfo, so this filter must
-- run AFTER mermaid-filter.  LaTeX-only: the HTML build scrolls and has neither
-- page breaks nor a measure to overflow.

if FORMAT ~= 'latex' and FORMAT ~= 'beamer' then return {} end

local LINEWIDTH  = 345.0             -- \the\linewidth  (documentclass=book, letter)
local TEXTHEIGHT = 550.0             -- \the\textheight for the same
local MAXWIDTH   = LINEWIDTH * 1.20  -- 414pt: 45pt into each 133pt margin

local function page_size(src)
  local ok, out = pcall(pandoc.pipe, 'pdfinfo', { src }, '')
  if not ok or not out then return nil end
  local w, h = out:match 'Page size:%s+([%d%.]+) x ([%d%.]+) pts'
  if not w then return nil end
  w, h = tonumber(w), tonumber(h)
  if not w or not h or w <= 0 or h <= 0 then return nil end
  return w, h
end

-- The width and height this image will actually be set at.
local function typeset_size(w, h)
  local target = math.min(math.max(w, 0), MAXWIDTH)
  local scale  = target / w
  if h * scale > TEXTHEIGHT then scale = TEXTHEIGHT / h end
  return w * scale, h * scale
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

-- Replace pandoc's \pandocbounded wrapper, which can only ever shrink to the
-- measure, with an explicitly sized box centred on it.
local function sized_image(image, tw, th)
  return pandoc.RawBlock('latex', string.format(
    '\\noindent\\makebox[\\linewidth][c]{\\includegraphics[width=%.1fpt,height=%.1fpt,keepaspectratio]{%s}}',
    tw, th, image.src))
end

-- Rough height of a paragraph of body text at this measure, so the reservation
-- covers the introducing sentence and not just the diagram under it.
local CHARS_PER_LINE = 66
local BASELINESKIP   = 12.0

local function para_height(block)
  local n = #pandoc.utils.stringify(block)
  local lines = math.max(1, math.ceil(n / CHARS_PER_LINE))
  return lines * BASELINESKIP
end

-- A reservation is only worth making if it can actually be met.  Demanding
-- close to \textheight is worse than demanding nothing: the request can never
-- be satisfied part-way down a page, so LaTeX sets one line, breaks, and leaves
-- a nearly blank page behind.  Past this ceiling, let the diagram flow.
local MAXRESERVE = TEXTHEIGHT * 0.80

function Blocks(blocks)
  local out, i = {}, 1
  while i <= #blocks do
    local this, after = blocks[i], blocks[i + 1]
    local image = after and lone_image(after) or nil
    local handled = false

    if image and this.t == 'Para' and not lone_image(this) then
      local w, h = page_size(image.src)
      if w then
        local tw, th = typeset_size(w, h)
        local want = th + para_height(this) + 6.0

        -- A heading immediately above belongs to the same unit: reserving after
        -- it would break the bond LaTeX keeps between a heading and its first
        -- line, stranding the heading alone at the foot of the page.
        local header = nil
        if #out > 0 and out[#out].t == 'Header' then
          header = table.remove(out)
          want = want + 2.2 * BASELINESKIP
        end

        if want <= MAXRESERVE then
          out[#out + 1] = pandoc.RawBlock('latex',
            string.format('\\needspace{%.1fpt}', want))
        end
        if header then out[#out + 1] = header end
        out[#out + 1] = this
        out[#out + 1] = pandoc.RawBlock('latex', '\\nopagebreak')
        out[#out + 1] = (w > LINEWIDTH) and sized_image(image, tw, th) or after
        i = i + 2
        handled = true
      end
    end

    if not handled then
      -- A diagram with no introducing paragraph still deserves the extra width.
      local solo = lone_image(this)
      if solo then
        local w, h = page_size(solo.src)
        if w and w > LINEWIDTH then
          local tw, th = typeset_size(w, h)
          out[#out + 1] = sized_image(solo, tw, th)
          i = i + 1
          goto continue
        end
      end
      out[#out + 1] = this
      i = i + 1
    end
    ::continue::
  end
  return out
end
