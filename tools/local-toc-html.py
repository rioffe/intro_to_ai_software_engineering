#!/usr/bin/env python3
"""tools/local-toc-html.py -- per-chapter local table-of-contents post-processor.

The HTML build injects a raw-HTML marker (``<!--LOCAL-TOC-->``) immediately after
each chapter's first H1 (see build-book-html.sh, mirroring how the PDF build
injects a per-chapter etoc block).  Pandoc renders that marker verbatim and gives
every heading its own ``id``.  This pass replaces each marker with a
``<nav class="local-toc">`` listing that chapter's own ``##`` sections -- and
``###`` subsections when depth >= 3 -- as in-page ``#anchor`` links built from
pandoc's ACTUAL emitted ids, so the links are always correct.

Depth comes from ``--depth N``, else ``TOC_DEPTH`` env, else 3 (## + ###, matching
the PDF build's LOCAL_DEPTH default).  Depth 2 lists sections only.

Pure standard library: it only READS pandoc's heading tags and SPLICES the
markers, so it never re-serialises the rest of the document by hand.  Markers and
headings are scanned with TWO independent regexes on purpose -- concatenating the
two compiled patterns would shift the capture-group numbers and the heading's own
``\\1`` level-backreference.

Usage:  local-toc-html.py INPUT [--depth N] [--out PATH]
(operates in place when --out is omitted)
"""
from __future__ import annotations

import html
import os
import re
import sys

# The bare HTML comment the assembler injects after a chapter's H1.
MARKER = "<!--LOCAL-TOC-->"
MARKER_RE = re.compile(re.escape(MARKER))
# A pandoc heading tag at level 1-3 carrying an id, plus its (inline) inner text.
# re.DOTALL lets . match across the rare multi-line inner heading.
HEADING_RE = re.compile(
    r'<h([123])\b[^>]*?\bid="([^"]+)"[^>]*>(?P<text>.*?)</h\1>',
    re.DOTALL,
)


def strip_inline(raw):
    """Turn raw heading inner HTML into plain, single-spaced link text."""
    text = re.sub(r"<[^>]+>", "", raw)  # drop any inline tags
    text = html.unescape(text)          # unescape &amp; / &#39; etc.
    return " ".join(text.split())


def build_local_toc(subs, depth):
    """Build the <nav class="local-toc"> for one chapter.

    ``subs`` is the ordered ``(level, id, text)`` list for the chapter's own
    subsections (levels 2..3).  Level-2 items become top-level <li>; when depth
    >= 3 a level-3 item nests under the preceding level-2 item, otherwise it is
    promoted to the top level.  Returns "" when there is nothing to list.
    """
    # items is a mix of plain <li> strings and [li_open_html, [nested_lis]] pairs.
    items = []
    last = None  # most recent [li_open, nested_lis] for a level-2 heading
    for level, sid, text in subs:
        link = '<a href="#%s">%s</a>' % (sid, text)
        if level == "2":
            items.append(["<li>%s" % link, []])
            last = items[-1]
        elif level == "3" and depth >= 3 and last is not None:
            last[1].append("<li>%s</li>" % link)
        else:   # level-3 promoted (depth < 3), or no level-2 yet: flat top level
            items.append("<li>%s</li>" % link)

    rendered = []
    for entry in items:
        if isinstance(entry, str):
            rendered.append(entry)
        elif entry[1]:
            rendered.append("%s<ul>%s</ul></li>" % (entry[0], "".join(entry[1])))
        else:
            rendered.append("%s</li>" % entry[0])

    if not rendered:
        return ""
    body = "<ul>%s</ul>" % "".join(rendered)
    return "<nav class='local-toc'><p class='local-toc-title'>Contents</p>%s</nav>" % body


def process(src, depth):
    """Replace every MARKER in ``src`` with that chapter's local TOC.

    A chapter's subsections are its level-2 (and, when depth >= 3, level-3)
    headings after the marker up to the next level-1 heading (each chapter opens
    with exactly one H1).  Markers and headings are scanned separately so their
    capture groups never collide.
    """
    marker_pos = sorted(m.start() for m in MARKER_RE.finditer(src))
    if not marker_pos:
        return src

    heads = [
          (m.start(), m.group(1), m.group(2), strip_inline(m.group("text")))
        for m in HEADING_RE.finditer(src)
    ]

    repl = {}
    for mp in marker_pos:
        chapter = []
        for pos, lvl, hid, text in heads:
            if pos < mp:
                continue
            if lvl == "1":
                break  # end of this chapter's scope
            if lvl == "2" or (lvl == "3" and depth >= 3):
                chapter.append((lvl, hid, text))
        repl[mp] = build_local_toc(chapter, depth)

    out = []
    last = 0
    for mp in marker_pos:
        out.append(src[last:mp])
        out.append(repl[mp])
        last = mp + len(MARKER)
    out.append(src[last:])
    return "".join(out)


def depth_from_args(argv):
    """Resolve depth: --depth N > TOC_DEPTH env > 3.  Raises SystemExit on bad N."""
    val = None
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--depth":
            val = argv[i + 1] if i + 1 < len(argv) else "missing"
            break
        if a.startswith("--depth="):
            val = a.split("=", 1)[1]
            break
        i += 1
    if val is None:
        val = os.environ.get("TOC_DEPTH", "3")
    try:
        return int(val)
    except ValueError:
        sys.stderr.write("local-toc-html: bad depth value: %r\n" % val)
        raise SystemExit(2)


def split_inputs(argv):
    """Return (input, out_path_or_None), consuming --depth/--out flags.

    A bare 2-positional form ``INP OUT`` also works; ``--out P``/``--out=P``
    otherwise name the output.
    """
    inputs = []
    out = None
    i = 0
    while i < len(argv):
        a = argv[i]
        if a.startswith("--depth=") or a == "--depth":
            i += 2 if a == "--depth" else 1
            continue
        if a == "--out":
            out = argv[i + 1] if i + 1 < len(argv) else None
            i += 2
            continue
        if a.startswith("--out="):
            out = a.split("=", 1)[1]
            i += 1
            continue
        inputs.append(a)
        i += 1
    if out is None and len(inputs) > 1:
        out = inputs.pop()
    return (inputs[0] if inputs else ""), out


# main() is the only entry point that touches the filesystem; both read and write
# are guarded below, so a missing/inaccessible file becomes a clear message, not a
# traceback.   process()/build_local_toc()/depth_from_args() never open files, so any
# exception there is a programming error, not a runtime input error.
def main(argv):
    args = argv[1:]
    inp, out = split_inputs(args)
    depth = depth_from_args(args)
    if not inp:
        sys.stderr.write("usage: local-toc-html.py INPUT [--depth N] [--out PATH]\n")
        return 2
    try:
        with open(inp, encoding="utf-8") as f:
            src = f.read()
    except OSError as e:
        sys.stderr.write("local-toc-html: cannot read %s: %s\n" % (inp, e))
        return 1
    result = process(src, depth)
    replaced = src.count(MARKER)
    target = out or inp
    try:
        with open(target, "w", encoding="utf-8") as f:
            f.write(result)
    except OSError as e:
        sys.stderr.write("local-toc-html: cannot write %s: %s\n" % (target, e))
        return 1
    sys.stderr.write(
        "local-toc-html: wrote %s (depth=%d, markers replaced: %d)\n"
        % (target, depth, replaced))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
