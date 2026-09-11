#!/usr/bin/env bash
# Regression test for tools/local-toc-html.lua -- the Pandoc filter that builds
# the HTML book's two-level TOC and wraps each chapter for the side-rail layout.
#
# pandoc-only (no TeX, browser, or network).  It runs the filter over a small
# synthetic book and asserts:
#   * build-book-html.sh wires the filter in;
#   * every chapter (H1 to next H1) is wrapped in a .chapter section holding the H1,
#     the rail box (when there is one), and a .chapter-body with the rest;
#   * one local box per chapter that has ## sections, none for a chapter without;
#   * local_toc_skip_nth gives exactly the named chapter the MASTER list (all
#     H1s) in its rail instead of a local box; 0 = every chapter gets a local
#     box and the master list stands alone ahead of chapter 1;
#   * local_toc_depth=3 nests ### under ##, depth=2 does not;
#   * every link in every box resolves to a heading id.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILTER="$ROOT/tools/local-toc-html.lua"
[ -f "$FILTER" ] || { echo "FAIL: $FILTER not found" >&2; exit 1; }
command -v pandoc >/dev/null || { echo "FAIL: pandoc not on PATH" >&2; exit 1; }

grep -Fq 'local-toc-html.lua' "$ROOT/tools/build-book-html.sh" || {
  echo "FAIL: build-book-html.sh does not run --lua-filter .../local-toc-html.lua" >&2
  exit 1
}

work="$(mktemp -d /tmp/localtoc-test.XXXXXX)"
trap 'rm -rf "$work"' EXIT
src="$work/mini.md"

cat >"$src" <<'EOF'
# Front Matter

## Overview

Front-matter prose.

## Also

More.

# Chapter One — Alpha

## 1.1 First Section

Body.

### 1.1.1 A Nested Subsection

Body.

## 1.2 Second Section

Body.

# Chapter Two — Beta

## 2.1 The Only Section

Body.

# Chapter Three — Bare

Just a paragraph, no sections at all.
EOF

render() {  # DEPTH SKIP_NTH -> HTML on stdout
  pandoc "$src" -f markdown -t html --wrap=none \
    --lua-filter "$FILTER" \
    --metadata "local_toc_depth=$1" \
    --metadata "local_toc_skip_nth=$2"
}

render 3 1 >"$work/d3s1.html"
render 2 1 >"$work/d2s1.html"
render 3 0 >"$work/d3s0.html"

python3 - "$work/d3s1.html" "$work/d2s1.html" "$work/d3s0.html" <<'PY'
import re, sys
d3s1, d2s1, d3s0 = (open(p, encoding="utf-8").read() for p in sys.argv[1:4])
fail = 0

def boxes(doc):
    # each local-toc div, from its open tag to the matching depth-0 close
    out, i = [], 0
    for m in re.finditer(r'<div class="local-toc">', doc):
        depth, j = 1, m.end()
        for t in re.finditer(r'<div\b|</div>', doc[m.end():]):
            depth += 1 if t.group().startswith('<div') else -1
            if depth == 0:
                j = m.end() + t.start()
                break
        out.append(doc[m.start():j])
    return out

def anchors_resolve(doc):
    ids = set(re.findall(r'\sid="([^"]+)"', doc))
    return not [a for a in re.findall(r'href="#([^"]+)"', doc) if a and a not in ids]

def chapter(doc, title):
    # the slice of doc from a chapter's own <h1> to the next <h1> (or the end)
    starts = [m.start() for m in re.finditer(r'<h1\b', doc)]
    mine = re.search(r'<h1[^>]*>' + re.escape(title), doc).start()
    nxt = [x for x in starts if x > mine]
    return doc[mine:nxt[0] if nxt else len(doc)]

# every chapter is wrapped: 4 H1s -> 4 .chapter wrappers, each with a
# .chapter-body (pandoc renders a Div that opens with a heading as a <section>
# carrying that heading's id, so match by class, not tag)
for name, doc in (("d3s1", d3s1), ("d3s0", d3s0)):
    if doc.count('class="chapter">') != 4 or doc.count('class="chapter-body">') != 4:
        print("FAIL: %s -> expected 4 .chapter wrappers with a .chapter-body each" % name); fail = 1
    if doc.count('class="master-toc"') != 1:
        print("FAIL: %s -> expected exactly one master-toc" % name); fail = 1

# depth 3, skip chapter 1: local boxes for "Chapter One" and "Chapter Two" only.
b = boxes(d3s1)
if len(b) != 2:
    print("FAIL: depth=3 skip_nth=1 -> expected 2 boxes, got %d" % len(b)); fail = 1
# front matter (first H1) hosts the MASTER list (every H1, in order), no local box
head = chapter(d3s1, 'Front Matter')
if 'class="local-toc"' in head:
    print("FAIL: skip_nth=1 still gave the front matter a local Contents box"); fail = 1
if 'class="master-toc"' not in head:
    print("FAIL: skip_nth=1 did not put the master list beside the front matter"); fail = 1
m = re.search(r'<div class="master-toc"[^>]*>(.*?)</ul>', d3s1, re.S)
if not m or re.findall(r'href="#([^"]+)"', m.group(1)) != ['front-matter', 'chapter-one-alpha', 'chapter-two-beta', 'chapter-three-bare']:
    print("FAIL: master list does not list every H1 in order"); fail = 1
if 'class="master-toc"' in chapter(d3s1, 'Chapter One'):
    print("FAIL: master list leaked into Chapter One"); fail = 1
# the "Chapter One" box nests 1.1.1 under 1.1 (a <ul> inside the box's <ul>)
if b and b[0].count('<ul>') < 2:
    print("FAIL: depth=3 did not nest ### under ## in the first box"); fail = 1
if not anchors_resolve(d3s1):
    print("FAIL: depth=3 skip_nth=1 -> a box link does not resolve"); fail = 1

# depth 2: the same first box must be flat (no nested <ul>)
b2 = boxes(d2s1)
if b2 and b2[0].count('<ul>') != 1:
    print("FAIL: depth=2 first box is not flat (%d <ul>)" % b2[0].count('<ul>')); fail = 1

# skip_nth=0: front matter now gets a box too -> 3 boxes ("Bare" chapter has none)
b0 = boxes(d3s0)
if len(b0) != 3:
    print("FAIL: skip_nth=0 -> expected 3 boxes, got %d" % len(b0)); fail = 1
if 'class="local-toc"' not in chapter(d3s0, 'Front Matter'):
    print("FAIL: skip_nth=0 did not give the front matter a box"); fail = 1
# ...and the master list then stands alone, before the first chapter wrapper
if d3s0.index('class="master-toc"') > d3s0.index('class="chapter">'):
    print("FAIL: skip_nth=0 did not place the master list ahead of chapter 1"); fail = 1
if 'class="master-toc"' in chapter(d3s0, 'Front Matter'):
    print("FAIL: skip_nth=0 still put the master list inside the front matter"); fail = 1

if fail:
    sys.exit(1)
print("PASS: chapter wrappers, master list placement, local boxes, skip_nth, depth nesting, and anchor resolution all correct")
PY

echo "PASS: local-toc-html.lua wired into the HTML build and behaves correctly."
