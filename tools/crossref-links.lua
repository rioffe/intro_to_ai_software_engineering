-- tools/crossref-links.lua
--
-- Make the book's in-prose cross-references clickable in the built PDF (and in
-- any other pandoc output).  The manuscript points at other parts of itself in
-- plain prose -- "Chapter 6", "Chapter 4.4.3", "Chapters 8 and 9",
-- "(Chapters 10-11)", "Appendix A.5", "the Appendix", "the Closing" -- and
-- never as Markdown links.  This filter builds a table of every heading's
-- *printed* number ("6", "4.4.3", "A.5", "C.2", ...) from the heading text
-- itself, then walks the body prose and turns each reference into an internal
-- link to the matching section, using Pandoc's own auto-generated section
-- identifiers so the anchors are always correct.
--
-- What gets linked:
--   Chapter N               -> the "Chapter N -- ..." H1
--   Chapter N.M[.K...]      -> the "N.M[.K] ..." section / subsection heading
--   Chapters X, Y and Z     -> X, Y and Z each linked individually
--   Chapters N-M            -> both endpoints linked (en dash, em dash or hyphen)
--   Appendix A.M            -> the "A.M ..." appendix section
--   Appendix / the Appendix (standalone) -> the "Appendix -- ..." H1
--   Closing (standalone)    -> the "Closing" H1
-- The chapter number in a reference is the number the chapter's own H1 prints
-- ("Chapter 4"), which is also the leading component of that chapter's section
-- numbers ("4.5", "4.4.3"), so every reference resolves unambiguously against a
-- single flat table.  A reference whose number has no matching heading is left
-- as plain text.  Headings themselves are never rewritten (the filter does not
-- descend into them); `inline code` and code blocks are never text, so they are
-- never touched either.
--
-- Leading and trailing punctuation is preserved outside the link: "(Chapter 6)"
-- keeps its parentheses, "Chapter 1.6." keeps its full stop, "Chapter 6's"
-- keeps its possessive, "Chapters 5, 6, 8" keeps its commas.
--
-- Requires Pandoc >= 2.17 (Pandoc:walk, top-down traversal short-circuit).

-- number string ("6", "4.4.3", "A.5", "C.2") -> heading identifier
local index = {}
-- "appendix" / "closing" -> heading identifier of that top-level section
local special = {}

local DASHES = { '\u{2013}', '\u{2014}', '-' } -- en dash, em dash, hyphen

-- ---- pass 1: catalogue every heading by its printed number ----------------
local function collect(hdr)
  local text = pandoc.utils.stringify(hdr.content)

  -- "Chapter 7 -- Validation" / "Chapter 0 -- Orientation"
  local ch = text:match('^Chapter%s+(%d+)')
  if ch then
    if not index[ch] then index[ch] = hdr.identifier end
    return
  end

  -- top-level "Appendix -- Where to Go Next" and "Closing"
  if text:match('^Appendix%f[%A]') then
    if not special.appendix then special.appendix = hdr.identifier end
    return
  end
  if text:match('^Closing%f[%A]') then
    if not special.closing then special.closing = hdr.identifier end
    return
  end

  -- numbered section / subsection: "7.1 ...", "1.6.1 ...", "A.5 ...", "C.2 ..."
  -- (leading token is digits-or-A/B/C, then one or more ".<digits>" groups)
  local head = text:match('^(%S+)%s')
  if head and head:match('^[0-9A-C]+%.[0-9.]*[0-9]$') then
    if not index[head] then index[head] = hdr.identifier end
  end
end

-- ---- helpers for pass 2 --------------------------------------------------
local function linkTo(id, inlines)
  return pandoc.Link(inlines, '#' .. id)
end

-- Peel a leading chapter/section number off a bare word:
--   "6.6.1's" -> "6.6.1", "'s"    "4." -> "4", "."    "11)" -> "11", ")"
local function peelNumber(word)
  local n, tail = word:match('^(%d[%d.]*%d)(.*)$')
  if not n then n, tail = word:match('^(%d)(.*)$') end
  if not n then return nil end
  return n, tail or ''
end

-- Peel a leading "A.5"-style appendix number: "A.5's" -> "A.5", "'s".
local function peelAppendixNumber(word)
  local n, tail = word:match('^([ABC]%.[%d.]*%d)(.*)$')
  if not n then return nil end
  return n, tail or ''
end

-- If `rest` opens with a dash + number ("-11" / "\u{2013}11"), and that number
-- resolves, return dash, number, remainder; otherwise nil.
local function peelRange(rest)
  for _, d in ipairs(DASHES) do
    if rest:sub(1, #d) == d then
      local n, tail = peelNumber(rest:sub(#d + 1))
      if n and index[n] then return d, n, tail end
    end
  end
  return nil
end

-- Append a resolved chapter/section reference (number + optional range +
-- trailing punctuation) to `out`.  `lead` inlines go inside the first link.
-- Returns true when something was linked.
local function appendRef(out, lead, word)
  local num, rest = peelNumber(word)
  if not num or not index[num] then return false end

  local first = {}
  for _, x in ipairs(lead) do first[#first + 1] = x end
  first[#first + 1] = pandoc.Str(num)
  out:insert(linkTo(index[num], first))

  local dash, num2, rest2 = peelRange(rest)
  if dash then
    out:insert(pandoc.Str(dash))
    out:insert(linkTo(index[num2], { pandoc.Str(num2) }))
    rest = rest2
  end
  if rest ~= '' then out:insert(pandoc.Str(rest)) end
  return true
end

local CONNECTOR = {
  ['and'] = true, ['&'] = true, ['through'] = true, ['to'] = true, ['or'] = true,
}

-- ---- pass 2: rewrite references in a run of inlines --------------------
local function rewrite(inlines)
  local out = pandoc.Inlines({})
  local i, n = 1, #inlines

  while i <= n do
    local el = inlines[i]
    local handled = false

    if el.t == 'Str' then
      local prefix, keyword = el.text:match('^(%p*)(%a+)$')

      if keyword == 'Chapter' or keyword == 'Chapters' then
        local sp, numTok = inlines[i + 1], inlines[i + 2]
        local scratch0 = pandoc.Inlines({})
        if sp and sp.t == 'Space' and numTok and numTok.t == 'Str'
           and appendRef(scratch0, { pandoc.Str(keyword), pandoc.Space() }, numTok.text) then
          if prefix ~= '' then out:insert(pandoc.Str(prefix)) end
          for _, x in ipairs(scratch0) do out:insert(x) end
          local k = i + 3

          -- "and 9" / ", 8" / "through 11" continuations
          while inlines[k] and inlines[k].t == 'Space' do
            local w = inlines[k + 1]
            if not (w and w.t == 'Str') then break end
            if CONNECTOR[w.text] then
              local sp2, w2 = inlines[k + 2], inlines[k + 3]
              if not (sp2 and sp2.t == 'Space' and w2 and w2.t == 'Str') then break end
              local scratch = pandoc.Inlines({})
              if not appendRef(scratch, {}, w2.text) then break end
              out:insert(pandoc.Space())
              out:insert(pandoc.Str(w.text))
              out:insert(pandoc.Space())
              for _, x in ipairs(scratch) do out:insert(x) end
              k = k + 4
            else
              local scratch = pandoc.Inlines({})
              if not appendRef(scratch, {}, w.text) then break end
              out:insert(pandoc.Space())
              for _, x in ipairs(scratch) do out:insert(x) end
              k = k + 2
            end
          end

          i = k
          handled = true
        end

      elseif keyword == 'Appendix' then
        local sp, w = inlines[i + 1], inlines[i + 2]
        if sp and sp.t == 'Space' and w and w.t == 'Str' and peelAppendixNumber(w.text) then
          local num, tail = peelAppendixNumber(w.text)
          if index[num] then
            if prefix ~= '' then out:insert(pandoc.Str(prefix)) end
            out:insert(linkTo(index[num],
              { pandoc.Str('Appendix'), pandoc.Space(), pandoc.Str(num) }))
            if tail ~= '' then out:insert(pandoc.Str(tail)) end
            i = i + 3
            handled = true
          end
        end
        if not handled and special.appendix then
          if prefix ~= '' then out:insert(pandoc.Str(prefix)) end
          out:insert(linkTo(special.appendix, { pandoc.Str('Appendix') }))
          i = i + 1
          handled = true
        end

      elseif keyword == 'Closing' and special.closing then
        -- standalone "Closing" only (never "A Closing Note" etc. -- that is a
        -- heading, which this filter does not descend into)
        if prefix ~= '' then out:insert(pandoc.Str(prefix)) end
        out:insert(linkTo(special.closing, { pandoc.Str('Closing') }))
        i = i + 1
        handled = true
      end
    end

    if not handled then
      out:insert(el)
      i = i + 1
    end
  end

  return out
end

-- ---- driver -----------------------------------------------------------
function Pandoc(doc)
  doc:walk({ Header = function(h) collect(h) end })

  return doc:walk({
    traverse = 'topdown',
    -- never rewrite a heading's own text, and never nest a link inside a link
    Header = function(h) return h, false end,
    Link = function(l) return l, false end,
    Inlines = rewrite,
  })
end
