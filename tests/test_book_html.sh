#!/usr/bin/env bash
# Regression test for the HTML book build (tools/build-book-html.sh), the sibling
# of the PDF build's tests/test_book_cover.sh.  It builds a small book.html and
# asserts the properties that make HTML distinct from the LaTeX build:
#   * a two-level, IN-PAGE table of contents (a master list PLUS per-chapter
#     "Contents" boxes, all anchored -- not page numbers);
#   * no leaked LaTeX \newpage page breaks (the HTML assembler must not emit them);
#   * every in-page #anchor the build generates actually resolves to an id the
#     document defines -- the core correctness guarantee of the marker/post-process
#     design; and
#   * the math survives into the HTML (class="math" spans are present).
# It also asserts the builder wires the shared, drift-proof pieces
# (tools/math-fence.awk + tools/local-toc-html.py) into the HTML path.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/tools/build-book-html.sh"
[ -f "$BUILD" ] || {
 echo "FAIL: $BUILD not found"
 exit 1
}

out="$(mktemp /tmp/book-html-test.XXXXXX.html)"
trap 'rm -f "$out"' EXIT

# Build the HTML book with a custom output path (via the shared make target).
OUTPUT="$out" make -C "$ROOT" book-html >/tmp/book-html-test.log 2>&1 || {
 echo "FAIL: 'make book-html' failed:" >&2
 sed 's/^/  /' /tmp/book-html-test.log >&2
 exit 1
}

# (1) A non-empty, single, self-contained HTML file.
[ -s "$out" ] || {
 echo "FAIL: $out is empty or missing" >&2
 exit 1
}

# (2) No LaTeX page breaks leaked into HTML.
if grep -Fq '\\newpage' "$out"; then
 echo "FAIL: a LaTeX '\newpage' page break leaked into the HTML output" >&2
 grep -Fn '\\newpage' "$out" | head >&2
 exit 1
fi

# (3) The master table of contents is present.
grep -qF 'class="master-toc"' "$out" || {
 echo "FAIL: no master 'Contents' (master-toc) found in $out" >&2
 exit 1
}

# (4) At least one per-chapter local "Contents" box was generated.
local_count="$(grep -oc "<nav class='local-toc'>" "$out" || true)"
if [ "${local_count:-0}" -lt 1 ]; then
 echo "FAIL: expected >=1 per-chapter local 'Contents' box, found $local_count" >&2
 exit 1
fi

# (5) Every in-page '#' anchor the build emits resolves to an id the document
#     defines -- the heart of the marker-expansion design.
python3 - "$out" <<'PY'
import re, sys
html_path = sys.argv[1]
with open(html_path, encoding="utf-8") as f:
    doc = f.read()
ids = set(re.findall(r'\sid="([^"]+)"', doc))
anchors = set(re.findall(r'href="#([^"]+)"', doc)) | set(re.findall(r"href='#([^']+)'", doc))
anchors.discard("")
missing = sorted(a for a in anchors if a and a not in ids)
if missing:
    print("FAIL: %d in-page #anchor(s) do not resolve to a doc id:" % len(missing))
    for a in missing[:10]:
        print("   #", a, "-> no such id")
    sys.exit(1)
print("PASS: %d in-page anchors all resolve to a document id" % len(anchors))
PY

# (6) The book's math survived into the HTML (KaTeX renders these client-side).
if ! grep -qF 'class="math' "$out"; then
 echo "FAIL: no math (class=\"math\") found -- the [..]->$$ preprocessor or pandoc math was lost" >&2
 exit 1
fi

# (7) Drift guard: the HTML build wires the shared, tested pieces.
grep -Fq 'awk -f "$ROOT/tools/math-fence.awk"' "$BUILD" || {
 echo "FAIL: build-book-html.sh does not call the shared tools/math-fence.awk" >&2
 exit 1
}
grep -Fq 'local-toc-html.py' "$BUILD" || {
 echo "FAIL: build-book-html.sh does not run the local-TOC post-processor local-toc-html.py" >&2
 exit 1
}

# (8) Informational: is the math actually INLINED for offline reading?  A CDN
#     reference (rather than a data: URI) is not fatal to the structure -- it just
#     means the build machine lacked the network to fetch the KaTeX source -- so
#     this is a note, not a failure.
if grep -Eq '(src|href)="https?://[^"]*(katex|mathjax|\.js)|\.css"' "$out"; then
 echo "NOTE: $out still references an external JS/CSS (e.g. the KaTeX CDN). Rebuild where"
 echo "      the network is available (or vendor KaTeX locally) to keep it offline."
fi

echo "PASS: book.html built with a two-level in-page TOC; all in-page anchors resolve; math present; shared pieces wired."
