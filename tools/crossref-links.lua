-- tools/crossref-links.lua
--
-- Make the book's in-prose cross-references clickable in the built PDF (and in
-- any other pandoc output).  The manuscript points at other parts of itself in
-- plain prose -- "Chapter 6", "Chapter 4.4.3", "Chapters 8 and 9",
-- "(Chapters 10-11)", "section 1.4", "Sections 8.3 through 8.5", a bare
-- "1.4.3 below" or "Running the 2.4.1 prompt", "Appendix A.5", "the Appendix",
-- "the Closing" -- and never as Markdown links.  This filter builds a table of
-- every heading's *printed* number ("6", "4.4.3", "A.5", "C.2", ...) from the
-- heading text itself, then walks the body prose and turns each reference into
-- an internal link to the matching section, using Pandoc's own auto-generated
-- section identifiers so the anchors are always correct.
--
-- What gets linked:
--   Chapter N                    -> the "Chapter N -- ..." H1
--   Chapter N.M[.K...]           -> the "N.M[.K] ..." section / subsection
--   Chapters X, Y and Z          -> X, Y and Z each linked individually
--   Chapters N-M                 -> both endpoints (en dash, em dash or hyphen)
--   section/Section/sections N.M -> the "N.M ..." section (keyword kept in link)
--   a bare N.M / N.M.K           -> the matching section, when it resolves
--   Appendix A.M                 -> the "A.M ..." appendix section
--   Appendix / the Appendix      -> the "Appendix -- ..." H1
--   Closing (standalone)         -> the "Closing" H1
--
-- The chapter number in a reference is the number the chapter's own H1 prints
-- ("Chapter 4"), which is also the leading component of that chapter's section
-- numbers ("4.5", "4.4.3"), so every reference resolves unambiguously against a
-- single flat table.  A reference whose number has no matching heading is left
-- as plain text.  Headings themselves are never rewritten (the filter does not
-- descend into them); `inline code` and code blocks are never text, so they are
-- never touched either.
--
-- A *bare* number (no "Chapter"/"section" in front) is only linked when it
-- carries at least one dot -- a lone integer like the "1" in "$1,199.10" is
-- never a reference -- and, for a single-dot number like "1.5" that could just
-- be a quantity, only when nothing around it looks like a measurement
-- ("0.5%", "1.5 (150%)", "0.3 microseconds", "roughly 4.2 ...").  Two-dot
-- numbers ("2.4.1") are unambiguous and always linked when they resolve.
--
-- Leading and trailing punctuation is preserved outside the link: "(Chapter 6)"
-- keeps its parentheses, "Chapter 1.6." keeps its full stop, "9.4.1's" keeps
-- its possessive, "Chapters 5, 6, 8" keeps its commas.
--
-- Requires Pandoc >= 2.17 (Pandoc:walk, top-down traversal short-circuit).

-- number string ("6", "4.4.3", "A.5", "C.2") -> heading identifier
local index = {}
-- "appendix" / "closing" -> heading identifier of that top-level section
local special = {}

local DASHES = { '\u{2013}', '\u{2014}', '-' } -- en dash, em dash, hyphen

-- keywords that introduce one or more section/chapter numbers
local KEYWORD = {
  Chapter = 0, Chapters = 0,             -- allow a bare integer ("Chapter 6")
  Section = 1, Sections = 1,             -- require a dotted number ("Section 7.5")
  section = 1, sections = 1,
}

-- words that mark the following number as a quantity, not a reference
local HEDGE = {
  about = true, roughly = true, around = true, approximately = true,
  nearly = true, almost = true, like = true, over = true, under = true,
}

-- unit nouns that mark a preceding number as a measurement, not a reference
local UNIT = {
  second = true, seconds = true, minute = true, minutes = true,
  hour = true, hours = true, day = true, days = true, week = true, weeks = true,
  month = true, months = true, year = true, years = true,
  ms = true, sec = true, secs = true, ns = true,
  millisecond = true, milliseconds = true, microsecond = true,
  microseconds = true, nanosecond = true, nanoseconds = true,
  percent = true, times = true,
}

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

local function dotCount(s)
  return select(2, s:gsub('%.', ''))
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

-- The Str word just before / after position `i` (skipping one Space), lowercased
-- and stripped of surrounding punctuation; nil when there is no adjacent Str.
local function neighbourWord(inlines, i, step)
  local j = i + step
  if inlines[j] and inlines[j].t == 'Space' then j = j + step end
  local e = inlines[j]
  if e and e.t == 'Str' then return e.text:gsub('^%p+', ''):gsub('%p+$', ''):lower() end
  return nil
end

-- Is a single-dot bare number ("1.5") safe to treat as a reference here, or does
-- it read as a measurement / quantity?
local function looksLikeReference(inlines, i, prefix, tail)
  if prefix:find('~') then return false end          -- "~1.5"
  if tail:match('^%s*%%') then return false end       -- "0.5%"
  local nxt = inlines[i + 1]
  local nx2 = inlines[i + 2]
  local after = (nxt and nxt.t == 'Str' and nxt.text)
             or (nxt and nxt.t == 'Space' and nx2 and nx2.t == 'Str' and nx2.text)
  if after then
    if after:match('^%(?%s*%d[%d,. ]*%%') then return false end  -- "1.5 (150%)"
    local w = after:gsub('^%p+', ''):gsub('%p+$', ''):lower()
    if UNIT[w] then return false end                             -- "0.3 microseconds"
  end
  local before = neighbourWord(inlines, i, -1)
  if before and HEDGE[before] then return false end              -- "roughly 4.2"
  return true
end

-- Append a resolved chapter/section reference (number + optional range +
-- trailing punctuation) to `out`.  `lead` inlines go inside the first link.
-- `minDots` (or nil) is the minimum number of dots the number must carry.
-- Returns true when something was linked.
local function appendRef(out, lead, word, minDots)
  local num, rest = peelNumber(word)
  if not num or not index[num] then return false end
  if minDots and dotCount(num) < minDots then return false end

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

local DASH_STR = {
  ['\u{2013}'] = true, ['\u{2014}'] = true, ['-'] = true,
  ['--'] = true, ['---'] = true,
}

-- The Closing's C.3 table lists chapters as "N -- Title" in its first column.
-- When a whole inline run is exactly that ("0 -- Orientation"), wrap it in a
-- single link to "Chapter N".  Returns the wrapped Inlines, or nil.
local function wholeChapterRow(inlines)
  local a = inlines[1]
  local num = a and a.t == 'Str' and a.text:match('^(%d+)$')
  if not num or not index[num] then return nil end
  if not (inlines[2] and inlines[2].t == 'Space') then return nil end
  local d = inlines[3]
  if not (d and d.t == 'Str' and DASH_STR[d.text]) then return nil end
  if not (inlines[4] and inlines[4].t == 'Space') then return nil end
  local w = inlines[5]
  if not (w and w.t == 'Str' and w.text:match('^%u')) then return nil end
  local content = {}
  for _, x in ipairs(inlines) do content[#content + 1] = x end
  return pandoc.Inlines({ linkTo(index[num], content) })
end

-- Pull "and 9" / ", 8" / "through 11" continuations starting at inline `k`
-- (which should be a Space).  Emits into `out`; returns the new index.
local function pullContinuations(inlines, k, out, minDots)
  while inlines[k] and inlines[k].t == 'Space' do
    local w = inlines[k + 1]
    if not (w and w.t == 'Str') then break end
    if CONNECTOR[w.text] then
      local sp2, w2 = inlines[k + 2], inlines[k + 3]
      if not (sp2 and sp2.t == 'Space' and w2 and w2.t == 'Str') then break end
      local scratch = pandoc.Inlines({})
      if not appendRef(scratch, {}, w2.text, minDots) then break end
      out:insert(pandoc.Space())
      out:insert(pandoc.Str(w.text))
      out:insert(pandoc.Space())
      for _, x in ipairs(scratch) do out:insert(x) end
      k = k + 4
    else
      local scratch = pandoc.Inlines({})
      if not appendRef(scratch, {}, w.text, minDots) then break end
      out:insert(pandoc.Space())
      for _, x in ipairs(scratch) do out:insert(x) end
      k = k + 2
    end
  end
  return k
end

-- ---- pass 2: rewrite references in a run of inlines --------------------
local function rewrite(inlines)
  local row = wholeChapterRow(inlines)
  if row then return row end

  local out = pandoc.Inlines({})
  local i, n = 1, #inlines

  while i <= n do
    local el = inlines[i]
    local handled = false

    if el.t == 'Str' then
      local prefix, keyword = el.text:match('^(%p*)(%a+)$')

      if KEYWORD[keyword] then
        local minDots = KEYWORD[keyword]
        local sp, numTok = inlines[i + 1], inlines[i + 2]
        local scratch0 = pandoc.Inlines({})
        if sp and sp.t == 'Space' and numTok and numTok.t == 'Str'
           and appendRef(scratch0, { pandoc.Str(keyword), pandoc.Space() },
                         numTok.text, minDots) then
          if prefix ~= '' then out:insert(pandoc.Str(prefix)) end
          for _, x in ipairs(scratch0) do out:insert(x) end
          i = pullContinuations(inlines, i + 3, out,
                                minDots == 0 and 0 or 1)
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

      elseif not keyword then
        -- bare numeric reference: "1.4.3", "2.4.1 prompt", "9.6.2 below",
        -- "8.3 through 8.5", "(13.4-13.5)"
        local pfx, body = el.text:match('^(%p*)(%d.*)$')
        local num = body and (peelNumber(body))
        if num and num:find('%.') and index[num] then
          local _, tail = peelNumber(body)
          if dotCount(num) >= 2 or looksLikeReference(inlines, i, pfx, tail) then
            if pfx ~= '' then out:insert(pandoc.Str(pfx)) end
            local scratch = pandoc.Inlines({})
            appendRef(scratch, {}, body, 1)
            for _, x in ipairs(scratch) do out:insert(x) end
            i = pullContinuations(inlines, i + 1, out, 1)
            handled = true
          end
        end
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
