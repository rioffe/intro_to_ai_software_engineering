#!/bin/bash
# tools/build-book-html.sh -- assemble the whole manuscript into ONE self-contained
# HTML book with a two-level, in-page table of contents, built for reading offline
# and for publishing to GitHub Pages.
#
# This is the HTML sibling of build-book-localtoc.sh (the PDF build).  It shares
# that build's ORDERING and FRONT-MATTER logic, its FENCE-AWARE math preprocessor
# (tools/math-fence.awk, guarded by tests/test_math_fence.sh), and its mermaid
# browser detection.  What differs, and why:
#
#   Two-level TOC, in a rail to the LEFT of the text.  The PDF uses LaTeX etoc
#   \localtableofcontents per chapter and Pandoc --toc for the master list.
#   HTML has no etoc, so a pandoc Lua filter (tools/local-toc-html.lua) builds
#   BOTH lists from pandoc's OWN heading identifiers in the same run that
#   assigns them, and wraps each chapter (H1 + its Contents + body) in a
#   <section class="chapter"> that tools/style.css lays out as a two-column
#   grid: the Contents in a sticky left rail, the chapter's text beside it.
#   The master "Contents" (chapters only) rides in the front matter's rail --
#   i.e. at the beginning of the book -- and every other chapter's rail holds
#   its own local "Contents".  (Pandoc's native --toc is NOT used: it can only
#   land above the body, never beside it.)
#
#   Self-contained (offline + GitHub Pages).  Math is rendered by KaTeX and the
#   whole document is inlined with --embed-resources, and mermaid is rendered to
#   SVG data-URIs (mmdc), so book.html needs NO external requests to read: math,
#   diagrams, and the cover are all embedded.  Relative asset paths keep it
#   publishable at any sub-path (username.github.io/...).
#
#   Clickable cross-references.  The shared tools/crossref-links.lua filter (also
#   used by the PDF build) turns the manuscript's plain-prose references --
#   "Chapter 6", "section 1.4", a bare "2.4.1", the Closing's C.3 table -- into
#   in-page #anchor links, using pandoc's own heading ids.
#
# Layout produced (wide screens; narrow screens and print stack the rail above):
#       cover image (embedded)  ->  title / subtitle / author / date
#       ->  front matter: its H1, then  [master "Contents" | front-matter text]
#       ->  each chapter:  its H1, then  [local "Contents"  | chapter text]
#  The first file (00-front-matter.md) is front matter: it sits at the top of the
#  master Contents and, like the PDF NOLOCAL, earns NO local "Contents" box --
#  its rail carries the master list instead.
#
#   tools/build-book-html.sh                 -> book.html at repo root
#   tools/build-book-html.sh out.html        -> custom output
#   OUTPUT=book.html tools/build-book-html.sh
#   TITLE="..." AUTHOR="..." tools/build-book-html.sh
#   TOC_DEPTH=2 tools/build-book-html.sh       -> per-chapter TOC: sections only (3)
#   FRONTMATTER=0 tools/build-book-html.sh     -> front matter gets a local TOC too
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# ---- CLI args ------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: build-book-html.sh [OPTIONS] [OUTPUT]

OPTIONS:
    --help          Show this help and exit.
The OUTPUT path may also be given via OUTPUT= (default: book.html at repo root).

Overridable variables (env or on the make command line):
    TOC_DEPTH       Per-chapter local TOC depth: 2 = sections only,
                    3 = sections + subsections (default).
    FRONTMATTER     "first" (default): the first file gets no local TOC.
                    "0" / "off" / "no": give the first file a local TOC too.
                    <path>: name a different file as the one with no local TOC
                    (mirrors build-book-localtoc.sh).
EOF
}

# Capture the OUT env (short form) before the loop below resets OUT to hold the
# positional argument; OUTPUT is captured the same way (PDF-build compatibility).
OUT_ENV="${OUT:-}"
OUTPUT_ENV="${OUTPUT:-}"
OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  --)
    shift
    break
    ;;
  *)
    if [ -n "$OUT" ]; then
      echo "build-book-html: ignoring extra argument: $1" >&2
    else
      OUT="$1"
    fi
    ;;
  esac
  shift
done
# Precedence: a positional argument > the OUT env (short) > OUTPUT env > the default.
OUT="${OUT:-${OUT_ENV:-${OUTPUT_ENV:-$ROOT/book.html}}}"

# Source dir of zero-padded manuscript files.  Overridable for other layouts.
CURRIC="manuscript"
# Per-chapter local TOC depth, mirroring the PDF build's LOCAL_DEPTH default (3).
TOC_DEPTH="${TOC_DEPTH:-3}"
TITLE="${TITLE:-Introduction to Software Engineering in the Age of AI}"
SUBTITLE="${SUBTITLE:-A hands-on introduction, built one working system at a time}"
AUTHOR="${AUTHOR:-}"
DATE="${DATE:-$(date +%Y)}"
COVER_IMAGE="$ROOT/assets/book_cover.png"
TEMPLATE="$ROOT/tools/book-html.html"
CSS="$ROOT/tools/style.css"

if [ ! -f "$COVER_IMAGE" ]; then
  echo "build-book-html: cover image not found: $COVER_IMAGE" >&2
  exit 1
fi

# ---- ordered chapter source list: every manuscript/*.md in filename order ------
chapters="$(
  python3 - "$CURRIC" <<'PY'
import glob, os, sys
cur = sys.argv[1]
for p in sorted(glob.glob(os.path.join(cur, "*.md"))):
    print(p)
PY
)"

if [ -z "$chapters" ]; then
  echo "build-book-html: no *.md files found under $CURRIC" >&2
  exit 1
fi

# ---- front-matter handling: mirror build-book-localtoc.sh's FRONTMATTER -------
# The first file (00-front-matter.md) is the book's front matter: it sits at the
# top of the master "Contents" and earns NO per-chapter "Contents" box -- the
# master list rides in its rail instead.  The PDF build picks a single NOLOCAL
# file the same way; we translate that file to its 1-based position and hand it
# to local-toc-html.lua as local_toc_skip_nth (0 = every chapter gets a box and
# the master list stands alone ahead of chapter 1).
NOLOCAL=""
case "${FRONTMATTER:-first}" in
0 | off | no | "") NOLOCAL="" ;;
first | "*") NOLOCAL="$(printf '%s\n' "$chapters" | head -1)" ;;
*) NOLOCAL="$FRONTMATTER" ;;
esac
SKIP_NTH=0
if [ -n "$NOLOCAL" ]; then
  SKIP_NTH="$(printf '%s\n' "$chapters" | awk -v t="$NOLOCAL" '
    $0 == t || $0 ~ ("/" t "$") { print NR; f = 1; exit }
    END { if (!f) print 0 }')"
  [ "$SKIP_NTH" != 0 ] || echo "build-book-html: WARNING: FRONTMATTER='$NOLOCAL' matched no manuscript file; every chapter gets a local TOC." >&2
fi
total="$(printf '%s\n' "$chapters" | grep -c .)"

# ---- assemble the combined source (plain concatenation, book order) -----------
SRC="$(mktemp /tmp/bbh-src.XXXXXX.md)"
PROC="$(mktemp /tmp/bbh-proc.XXXXXX.md)"
COVER="$(mktemp /tmp/bbh-cover.XXXXXX.html)"
STYLE="$(mktemp /tmp/bbh-style.XXXXXX.html)"
LIST="$(mktemp /tmp/bbh-list.XXXXXX.txt)"
trap 'rm -f "$SRC" "$PROC" "$COVER" "$STYLE" "$LIST"' EXIT

# Concatenate every manuscript file in filename (= book) order, blank-line
# separated.  No markers and no H1 hunting: the per-chapter "Contents" boxes are
# inserted from the AST by tools/local-toc-html.lua, and an embedded "# SPEC.md"
# inside a ```markdown fence is invisible to pandoc anyway.
printf '%s\n' "$chapters" >"$LIST"
python3 - "$LIST" >"$SRC" <<'PY'
import sys
paths = [l.strip() for l in open(sys.argv[1], encoding="utf-8") if l.strip()]
parts = [open(p, encoding="utf-8", errors="replace").read().rstrip("\n") for p in paths]
sys.stdout.write("\n\n\n".join(parts) + "\n")
PY

if [ ! -s "$SRC" ]; then
  echo "build-book-html: assembled source is empty" >&2
  exit 1
fi

echo "build-book-html: assembled $total chapters ($(wc -l <"$SRC") source lines); local TOC suppressed for chapter: ${SKIP_NTH:-0} (0 = none)"

# ---- math: the same fence-aware [ / ] -> $$ preprocessor as the PDF build ------
# math-fence.awk toggles only on lone [ / ] lines, so it is a no-op when there is no
# book math; like build-book-localtoc.sh we run it on every build, and
# tests/test_math_fence.sh guards that shared program so the two cannot drift.
awk -f "$ROOT/tools/math-fence.awk" "$SRC" >"$PROC"

# ---- decide on the mermaid-filter, then auto-detect a Chrome/Chromium ----------
# Default the diagram output to crisp SVG data-URIs (embeddable, offline, crisp at
# any zoom -- the HTML analogue of the PDF's vector default).
mermaid_args=""
if grep -q '^```mermaid' "$SRC"; then
  if [ -z "${MERMAID_FILTER_FORMAT:-}" ]; then
    MERMAID_FILTER_FORMAT="svg"
    echo "build-book-html: defaulting MERMAID_FILTER_FORMAT=svg (embeddable + offline)"
  fi
  if [ -z "${MERMAID_FILTER_SCALE:-}" ]; then
    MERMAID_FILTER_SCALE="2"
    echo "build-book-html: defaulting MERMAID_FILTER_SCALE=2"
  fi
  export MERMAID_FILTER_FORMAT MERMAID_FILTER_SCALE
  if [ -z "${PUPPETEER_EXECUTABLE_PATH:-}" ]; then
    for cand in \
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
      "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary" \
      "/Applications/Chromium.app/Contents/MacOS/Chromium" \
      "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"; do
      [ -x "$cand" ] && {
        PUPPETEER_EXECUTABLE_PATH="$cand"
        break
      }
    done
    [ -n "${PUPPETEER_EXECUTABLE_PATH:-}" ] || for c in \
      google-chrome google-chrome-stable chromium chromium-browser; do
      bin="$(command -v "$c" 2>/dev/null || true)"
      [ -n "$bin" ] && {
        PUPPETEER_EXECUTABLE_PATH="$bin"
        break
      }
    done
  fi
  if [ -n "${PUPPETEER_EXECUTABLE_PATH:-}" ]; then
    export PUPPETEER_EXECUTABLE_PATH
    echo "build-book-html: mermaid browser: $PUPPETEER_EXECUTABLE_PATH"
  else
    echo "build-book-html: WARNING: no Chrome/Chromium found; mermaid diagrams may fail." >&2
  fi
  # mermaid-filter invokes the mermaid-cli in its OWN node_modules, which it
  # pins to ^10.  That renderer silently ignores `look` and the redux themes in
  # .mermaid-config.json -- no error, just the old default styling.  Prefer a
  # newer mmdc from PATH when one is installed, and say which is being used so
  # a styling surprise is traceable.  An explicit MERMAID_FILTER_CMD_MMDC wins.
  if [ -z "${MERMAID_FILTER_CMD_MMDC:-}" ] && command -v mmdc >/dev/null 2>&1; then
   mmdc_major="$(mmdc --version 2>/dev/null | sed 's/[^0-9.].*//;s/\..*//')"
   case "$mmdc_major" in
    ''|*[!0-9]*) : ;;
    *) if [ "$mmdc_major" -ge 11 ]; then
      MERMAID_FILTER_CMD_MMDC="$(command -v mmdc)"
      export MERMAID_FILTER_CMD_MMDC
      echo "build-book-html: using mmdc $(mmdc --version) from PATH (bundled one is ^10; look/redux themes need >=11)"
     fi ;;
   esac
  fi
  mermaid_args="--filter mermaid-filter"
fi

# ---- style: inline the stylesheet as a <style> in the document head -------------
printf '<style>\n%s\n</style>\n' "$(cat "$CSS")" >"$STYLE"

# ---- cover: embedded image + a title block, injected before the body -----------
# The cover PNG is base64-inlined so book.html is a single offline file (no request
# for the image even when --embed-resources is a no-op for it).  Title-block lines
# are emitted only when non-empty.
COVER_B64="$(base64 <"$COVER_IMAGE" 2>/dev/null | tr -d '\n' || true)"
{
  echo '<div class="cover">'
  [ -n "${COVER_B64:-}" ] && echo "  <img src=\"data:image/png;base64,$COVER_B64\" alt=\"$TITLE\">"
  echo '</div>'
  echo '<div class="titleblock">'
  [ -n "${TITLE:-}" ] && printf '  <h1 class="book-title">%s</h1>\n' "$TITLE"
  [ -n "${SUBTITLE:-}" ] && printf '  <p class="book-subtitle">%s</p>\n' "$SUBTITLE"
  [ -n "${AUTHOR:-}" ] && printf '  <p class="book-author">%s</p>\n' "$AUTHOR"
  [ -n "${DATE:-}" ] && printf '  <p class="book-date">%s</p>\n' "$DATE"
  echo '</div>'
} >"$COVER"

echo "build-book-html: building $OUT (master + per-chapter TOC in a left rail via local-toc-html.lua, local depth=$TOC_DEPTH; offline via KaTeX + --embed-resources)"

#     --lua-filter crossref-links.lua -> plain-prose cross-references become links.
#     --lua-filter local-toc-html.lua -> master "Contents" (chapters only, titled
#         by toc-title) beside the front matter, a local "Contents" beside every
#         other chapter, each chapter wrapped for the rail layout
#         (local_toc_depth / local_toc_skip_nth mirror the PDF's LOCAL_DEPTH /
#          FRONTMATTER); it reads headers only, so it runs after crossref-links.
#     --math-method=katex --embed-resources -> inlined, offline math (no CDN).
# $mermaid_args (when set) -> crisp, embeddable SVG diagrams.
# shellcheck disable=SC2086
pandoc "$PROC" \
  --lua-filter "$ROOT/tools/crossref-links.lua" \
  --lua-filter "$ROOT/tools/local-toc-html.lua" \
  --metadata "local_toc_depth=$TOC_DEPTH" \
  --metadata "local_toc_skip_nth=$SKIP_NTH" \
  --metadata "toc-title=Contents" \
  --metadata "title=$TITLE" \
  --metadata "subtitle=$SUBTITLE" \
  --metadata "author=$AUTHOR" \
  --metadata "date=$DATE" \
  --template "$TEMPLATE" \
  --include-in-header "$STYLE" \
  --include-before-body "$COVER" \
  --math-method=katex \
  --embed-resources \
  $mermaid_args \
  --output "$OUT"

echo "Success! Created '$OUT'.  (self-contained: math + diagrams + CSS + cover inlined; opens offline and at any GitHub Pages sub-path.)"
