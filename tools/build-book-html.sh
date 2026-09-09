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
#   Two-level TOC.  The PDF uses LaTeX etoc \localtableofcontents per chapter and
#   Pandoc --toc for the master list.  HTML has no etoc, so the assembler injects
#   a raw-HTML marker (<!--LOCAL-TOC-->) after each chapter's first H1, and
#   tools/local-toc-html.py -- run AFTER pandoc -- expands each marker into a
#   per-chapter "Contents" box using pandoc's OWN emitted anchor ids.  The master
#   list is pandoc's native --toc.
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
# Layout produced at the top of the book:
#       cover image (embedded)  ->  title / subtitle / author / date
#       ->  master "Contents" (chapters, in-page anchors)
#       ->  each chapter: its H1, a local "Contents" box, then the body
#  The first file (00-front-matter.md) is front matter: it sits at the top of the
#  master Contents but, like the PDF NOLOCAL, earns NO local "Contents" box.
#
#   tools/build-book-html.sh                 -> book.html at repo root
#   tools/build-book-html.sh out.html        -> custom output
#   OUTPUT=book.html tools/build-book-html.sh
#   TITLE="..." AUTHOR="..." tools/build-book-html.sh
#   TOC_DEPTH=2 tools/build-book-html.sh       -> per-chapter TOC: sections only (3)
#   FRONTMATTER=0 tools/build-book-html.sh     -> front matter gets a local TOC too
#
# Why this order: pandoc runs once and emits stable #anchor ids; the marker
# expansion must happen on that rendered HTML so every local-TOC link points at a
# real id.  Mermaid math/diagrams are resolved by pandoc's filters first.
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
LUATEST="$ROOT/tools/local-toc-html.py" # marker-expansion post-processor

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

# ---- mark the first file as front matter (NOLOCAL), like the PDF build --------
NOLOCAL=""
case "${FRONTMATTER:-first}" in
0 | off | no | "") NOLOCAL="" ;;
first | "*") NOLOCAL="$(printf '%s\n' "$chapters" | head -1)" ;;
*) NOLOCAL="$FRONTMATTER" ;;
esac
total="$(printf '%s\n' "$chapters" | grep -c .)"

# ---- assemble the combined source, injecting a local-TOC marker per chapter ----
SRC="$(mktemp /tmp/bbh-src.XXXXXX.md)"
PROC="$(mktemp /tmp/bbh-proc.XXXXXX.md)"
COVER="$(mktemp /tmp/bbh-cover.XXXXXX.html)"
STYLE="$(mktemp /tmp/bbh-style.XXXXXX.html)"
LIST="$(mktemp /tmp/bbh-list.XXXXXX.txt)"
ASMPY="$(mktemp /tmp/bbh-asm.XXXXXX.py)"
trap 'rm -f "$SRC" "$PROC" "$COVER" "$STYLE" "$LIST" "$ASMPY"' EXIT

# The assembler (argv: LIST, DEPTH, NOLOCAL) reads the ordered chapter paths and,
# for each chapter that has ## / ### subsections and is NOT the front matter,
# injects a raw-HTML marker right after the chapter's first REAL H1.  Fenced code
# blocks are skipped when locating that H1, exactly like build-book-localtoc.sh,
# so an embedded "# SPEC.md" inside a ```markdown fence is never mistaken for the
# chapter title.  The marker is later expanded by local-toc-html.py.
printf '%s\n' "$chapters" >"$LIST"
cat >"$ASMPY" <<'PY'
import re, sys

LIST, DEPTH, NOLOCAL = sys.argv[1], sys.argv[2], sys.argv[3]
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
SUBSECTION = re.compile(r"^#{2,4}\s+\S")   # ## .. #### => a chapter has a local TOC
FENCE = re.compile(r"^\s*(```|~~~)")
MARKER = (
    "```{=html}\n"
    "<!--LOCAL-TOC-->\n"
    "```"
)

paths = [l.strip() for l in open(LIST, encoding="utf-8") if l.strip()]
out = []
for n, path in enumerate(paths):
    with open(path, encoding="utf-8", errors="replace") as f:
        src = f.read().splitlines()

    is_nolocal = NOLOCAL != "" and path == NOLOCAL
    has_subs = any(SUBSECTION.match(l) for l in src) and not is_nolocal

    # First REAL H1: skip fenced code blocks (an embedded '# SPEC.md' lives inside
    # a ```markdown fence, so pandoc never turns it into a heading).
    h1 = 0
    in_fence = False
    for i, ln in enumerate(src):
        if FENCE.match(ln):
            in_fence = not in_fence
            continue
        m = HEADING.match(ln)
        if m and len(m.group(1)) == 1:
            h1 = i
            break

    chunk = list(src[: h1 + 1])
    if has_subs:
        chunk += ["", MARKER, ""]
    chunk += src[h1 + 1:]

    text = "\n".join(chunk)
    out.append(text)

# Chapters are plain markdown, separated by blank lines; each opens at its own H1
# (HTML has no page break).   The markers injected above build the per-chapter
# local TOC; no thematic break sits between chapters -- the H1 heading styles it.
sys.stdout.write("\n\n\n".join(out))
PY
python3 "$ASMPY" "$LIST" "$TOC_DEPTH" "$NOLOCAL" >"$SRC"

if [ ! -s "$SRC" ]; then
  echo "build-book-html: assembled source is empty" >&2
  exit 1
fi

echo "build-book-html: assembled $total chapters ($(wc -l <"$SRC") source lines); front matter (no local TOC): ${NOLOCAL:-<none>}"

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

echo "build-book-html: building $OUT (master TOC depth=1 via pandoc --toc; per-chapter local TOC depth=$TOC_DEPTH via marker markers; offline via KaTeX + --embed-resources)"

#     --toc --toc-depth=1          -> master "Contents" lists the chapters only.
# Per-chapter local TOCs are the markers, expanded after rendering by local-toc-html.py.
#     --lua-filter crossref-links.lua -> plain-prose cross-references become links.
#     --math-method=katex --embed-resources -> inlined, offline math (no CDN).
# $mermaid_args (when set) -> crisp, embeddable SVG diagrams.
# shellcheck disable=SC2086
pandoc "$PROC" \
  --toc \
  --toc-depth=1 \
  --lua-filter "$ROOT/tools/crossref-links.lua" \
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

# ---- expand the per-chapter local-TOC markers into real anchor links -----------
echo "build-book-html: expanding per-chapter local TOCs (depth=$TOC_DEPTH)"
TOC_DEPTH="$TOC_DEPTH" python3 "$LUATEST" "$OUT"

echo "Success! Created '$OUT'.  (self-contained: math + diagrams + CSS + cover inlined; opens offline and at any GitHub Pages sub-path.)"
