#!/bin/bash
# build-book-localtoc.sh -- assemble the whole manuscript into one "book" PDF with
# a TWO-LEVEL, clickable, paginated table of contents.
#
# Borrowed from ai_systems_engineering_bootcamp/tools/build-book-localtoc.sh,
# which is that project's `make book-local` target.  Adapted to this repo, where
# the source is a flat manuscript/ directory of zero-padded NN-*.md files instead
# of curriculum/week*/chapterN.md + separate introduction/license/supplemental_docs.
#
#   Level 1 (master): a front-matter "Contents" listing ONLY the top-level
#                      chapters (each file's single H1 "Chapter N: ..." -> \chapter).
#                      Built by `pandoc --toc --toc-depth=1`; a short book Contents
#                      instead of the ~30-page single-deep-master-TOC alternative.
#   Level 2 (local):  every chapter opens with its OWN "Contents" page -- a
#       per-chapter table of contents built by the etoc package, listing that
#       chapter's ## sections / ### subsections, WITH page numbers and clickable
#       (hyperref) links.
#
# Layout produced for each chapter:
#       page 1: the chapter title, alone
#       page 2: the chapter's local "Contents" (this chapter's sections)
#       page 3: the start of the chapter body
# i.e. the title is isolated on its own page, and the local TOC is on its own
# page, separated from the body by a page break.  The first file
# (00-front-matter.md) is treated as front matter -- it lands at the top of the
# master "Contents" but gets NO per-chapter local "Contents" page (like the
# reference's Introduction / NOLOCAL).
#
#   tools/build-book-localtoc.sh              -> book.pdf at repo root
#   tools/build-book-localtoc.sh out.pdf      -> custom output path
#   TITLE="..." AUTHOR="..." tools/build-book-localtoc.sh
#   OUTPUT=book-local.pdf tools/build-book-localtoc.sh   (via the Makefile: OUTPUT=)
#   LOCAL_DEPTH=2 tools/build-book-localtoc.sh           -> sections only (default 3)
#
# Why latexmk, not xelatex: a per-chapter \tableofcontents needs several LaTeX
# passes for the cross-references (page numbers) to stabilise.  pandoc runs its
# pdf engine only once, so we use the latexmk engine -- which iterates to a fixed
# point -- via `--pdf-engine=latexmk`.  latexmk still runs inside pandoc's work
# dir, so (had any chapter embedded mermaid) the mermaid-filter images resolve
# exactly as in build-book.sh / md2pdf.sh.
#
# Same math preprocessor ([ ... ] -> $$ ... $$) as md2pdf.sh / build-book.sh.
# This manuscript embeds no mermaid diagrams, but the handling is kept verbatim
# so a future mermaid chapter "just works".

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Source dir of zero-padded manuscript files.  Overridable for other layouts.
CURRIC="manuscript"
OUT="${OUTPUT:-${1:-$ROOT/book.pdf}}"
TITLE="${TITLE:-Introduction to AI Software Engineering}"
AUTHOR="${AUTHOR:-}"
DATE="${DATE:-$(date +%Y)}"

# Depth of the per-chapter local TOC: 2 = sections only; 3 (default) =
# sections + subsections (###).  Override via LOCAL_DEPTH env.
LOCAL_DEPTH="${LOCAL_DEPTH:-3}"
COVER_IMAGE="$ROOT/assets/book_cover.png"

if [ ! -f "$COVER_IMAGE" ]; then
 echo "build-book-localtoc: cover image not found: $COVER_IMAGE" >&2
 exit 1
fi

# ---- ordered chapter source list: every manuscript/*.md in filename order ------
# Files are zero-padded (00-, 01-, ...), so a lexical sort is numeric order.
# Only *.md -- this excludes the sibling *.pdf artifacts and any *.swp notes.
chapters="$(
 python3 - "$CURRIC" <<'PY'
import glob, os, sys
cur = sys.argv[1]
# sorted() over the glob keeps the zero-padded numeric order.
for p in sorted(glob.glob(os.path.join(cur, "*.md"))):
    print(p)
PY
)"

if [ -z "$chapters" ]; then
 echo "build-book-localtoc: no *.md files found under $CURRIC" >&2
 exit 1
fi

# ---- mark the first file as front matter (NOLOCAL) ----------------------------
# The first manifest file (00-front-matter.md) is the book's front matter: it
# lands at the top of the master "Contents" but, like the reference's
# Introduction, earns NO per-chapter local "Contents" page.  Set FRONTMATTER=0
# to give it a local "Contents" page too; FRONTMATTER=<path|basename> to name a
# different file as the NOLOCAL one.
NOLOCAL=""
case "${FRONTMATTER:-first}" in
0 | off | no | "") NOLOCAL="" ;;
first | "*") NOLOCAL="$(printf '%s\n' "$chapters" | head -1)" ;;
*) NOLOCAL="$FRONTMATTER" ;;
esac

total="$(printf '%s\n' "$chapters" | grep -c .)"

# ---- assemble the combined source, injecting a local TOC per chapter -------
SRC="$(mktemp /tmp/bblt-src.XXXXXX.md)"
PROC="${SRC}.proc.md"
LIST="$(mktemp /tmp/bblt-list.XXXXXX.txt)"
ASMPY="$(mktemp /tmp/bblt-asm.XXXXXX.py)"
HEADER="$(mktemp /tmp/bblt-header.XXXXXX.tex)"
trap 'rm -f "$SRC" "$PROC" "$LIST" "$ASMPY" "$HEADER"' EXIT

# LaTeX preamble for the local TOC: load hyperref FIRST so etoc can attach
# clickable links, then etoc.  pandoc adds "bookmark" + \hypersetup after this.
printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
 '\usepackage[hidelinks=true]{hyperref}' \
 '\usepackage{graphicx}' \
 '\usepackage{eso-pic}' \
 '\usepackage{etoc}' \
 '\let\originalmaketitle\maketitle' \
 '\renewcommand{\maketitle}{%' \
 '\AddToShipoutPictureBG*{\AtPageLowerLeft{\includegraphics[width=\paperwidth,height=\paperheight]{assets/book_cover.png}}}\null\clearpage%' \
 '\begingroup\let\cleardoublepage\clearpage\originalmaketitle\endgroup}' >"$HEADER"

# The assembler reads the ordered chapter paths from LIST (argv[1]), the local
# TOC depth from argv[2], and the single NOLOCAL front-matter path from argv[3]
# (empty => every file gets a local TOC).  For each chapter it injects -- right
# after the chapter's first H1 (# "Chapter N"), and only when the chapter has
# ## /### subsections -- a raw LaTeX block:
#     \newpage                                    -> local TOC on its own page
#     {\etocsettocdepth{N}\localtableofcontents}  -> etoc prints this chapter's
#                          local TOC (sections/subsections, WITH page numbers
#                          and clickable links, because hyperref is loaded first)
#     \newpage                                    -> chapter body starts fresh
# No heading parsing/escaping is needed: etoc reads the real \section titles.
printf '%s\n' "$chapters" >"$LIST"
cat >"$ASMPY" <<'PY'
import re, sys

LIST, DEPTH = sys.argv[1], sys.argv[2]
NOLOCAL = sys.argv[3] if len(sys.argv) > 3 else ""
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
SUBSECTION = re.compile(r"^#{2,4}\s+\S")       # ## .. #### => a local-TOC entry
BLOCK = (
       "```{=latex}\n"
    r"\newpage" + "\n"
    r"{\etocsettocdepth{" + DEPTH + r"}\localtableofcontents}" + "\n"
    r"\newpage" + "\n"
       "```"
)

paths = [l.strip() for l in open(LIST, encoding="utf-8") if l.strip()]
out = []
for n, path in enumerate(paths):
    with open(path, encoding="utf-8", errors="replace") as f:
        src = f.read().splitlines()

    is_nolocal = NOLOCAL != "" and path == NOLOCAL
    has_subs = any(SUBSECTION.match(l) for l in src) and not is_nolocal

      # locate the chapter's first H1 (# "Chapter N: ...").  Embedded "# SPEC.md"
     # style headings live inside fenced ```markdown blocks, so pandoc never sees
     # them and the first REAL H1 is always the chapter title.
    h1 = 0
    for i, ln in enumerate(src):
        m = HEADING.match(ln)
        if m and len(m.group(1)) == 1:
            h1 = i
            break

    chunk = list(src[:h1 + 1])
    if has_subs:
        chunk += ["", BLOCK, ""]
    chunk += src[h1 + 1:]

    text = "\n".join(chunk)
      # chapters are separated by a blank page break
    out.append(text if n == 0 else r"\newpage" + "\n" + text)

sys.stdout.write("\n\n".join(out) + "\n")
PY

python3 "$ASMPY" "$LIST" "$LOCAL_DEPTH" "$NOLOCAL" >"$SRC"

if [ ! -s "$SRC" ]; then
 echo "build-book-localtoc: assembled source is empty" >&2
 exit 1
fi

echo "build-book-localtoc: assembled $total chapters ($(wc -l <"$SRC") source lines); front matter (no local TOC): ${NOLOCAL:-<none>}"

# ---- apply the SAME [ / ] -> $$ math preprocessor as md2pdf.sh -----------
sed -e 's/^[[:space:]]*\[[[:space:]]*$/$$\n/' \
 -e 's/^[[:space:]]*\][[:space:]]*$/\n$$/' \
 "$SRC" >"$PROC"

# ---- decide on the mermaid-filter, then auto-detect a Chrome/Chromium -----
# This manuscript embeds no mermaid, but keep the detection so a future chapter
# with ```mermaid just works.
mermaid_args=""
if grep -q '^```mermaid' "$SRC"; then
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
  echo "build-book-localtoc: mermaid browser: $PUPPETEER_EXECUTABLE_PATH"
 else
  echo "build-book-localtoc: WARNING: no Chrome/Chromium found; mermaid diagrams may fail." >&2
 fi
 mermaid_args="--filter mermaid-filter"
fi

echo "build-book-localtoc: building $OUT"
echo "build-book-localtoc: master TOC depth=1 (chapters); per-chapter local TOC depth=$LOCAL_DEPTH (etoc, linked; multi-pass via latexmk)"

#    --toc --toc-depth=1         -> master "Contents" lists chapters only.
# Per-chapter local TOCs are injected as raw etoc blocks (see above); latexmk
# iterates xelatex to a fixed point so the page numbers are correct.
# $mermaid_args is a pre-split arg list (--filter mermaid-filter), expanded
# unquoted on purpose.
# shellcheck disable=SC2086
pandoc "$PROC" \
 --toc --toc-depth=1 \
 --pdf-engine=latexmk \
 --pdf-engine-opt="-xelatex" \
 --pdf-engine-opt="-interaction=nonstopmode" \
 --include-in-header="$HEADER" \
 --variable documentclass=book \
 --variable colorlinks=true \
 --metadata "title=$TITLE" \
 --metadata "author=$AUTHOR" \
 --metadata "date=$DATE" \
 $mermaid_args \
 --output "$OUT" && echo "Success! Created '$OUT'."
