#!/usr/bin/env bash
# Regression test for tools/crossref-links.lua -- the shared Pandoc filter that
# turns the manuscript's plain-prose cross-references ("Chapter 6", "section
# 1.4", a bare "2.4.1", the Closing's C.3 table) into internal links.
#
# It needs only pandoc (no TeX, no browser, no network): it concatenates the
# manuscript, runs the filter to HTML and to LaTeX, and asserts
#   * both build scripts actually wire the filter in;
#   * references that SHOULD link do, with the right visible text;
#   * quantities that look like section numbers ("0.5%", "1.5 (150%)",
#     "Python 3.12") do NOT link;
#   * every "#anchor" / \hyperref target the filter emits resolves to a real
#     heading id / \label -- the core correctness guarantee.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILTER="$ROOT/tools/crossref-links.lua"
[ -f "$FILTER" ] || { echo "FAIL: $FILTER not found" >&2; exit 1; }
command -v pandoc >/dev/null || { echo "FAIL: pandoc not on PATH" >&2; exit 1; }

work="$(mktemp -d /tmp/xref-test.XXXXXX)"
trap 'rm -rf "$work"' EXIT
src="$work/book.md"; html="$work/book.html"; tex="$work/book.tex"

# ---- (1) drift guard: both builds wire the filter --------------------------
for b in build-book-localtoc.sh build-book-html.sh; do
  grep -Fq 'crossref-links.lua' "$ROOT/tools/$b" || {
    echo "FAIL: tools/$b does not run --lua-filter .../crossref-links.lua" >&2
    exit 1
  }
done

# ---- assemble the manuscript (book order = zero-padded filename order) ------
: >"$src"
for f in "$ROOT"/manuscript/*.md; do cat "$f" >>"$src"; printf '\n\n\n' >>"$src"; done

# --wrap=none keeps each rendered element on one line so the line-based greps
# below see a whole <a>...</a> / \hyperref{...} at once.
pandoc "$src" -f markdown -t html  --wrap=none --lua-filter "$FILTER" -o "$html"
pandoc "$src" -f markdown -t latex --wrap=none --lua-filter "$FILTER" -o "$tex"

fail=0
want() {  # DESC : extended-regex that must match in book.html
  grep -Eq "$2" "$html" || { echo "FAIL: expected a link -- $1" >&2; fail=1; }
}
deny() {  # DESC : extended-regex that must NOT match in book.html
  grep -Eq "$2" "$html" && { echo "FAIL: should not be a link -- $1" >&2; fail=1; } || true
}

# ---- (2) references that must become links ---------------------------------
want "bare 'Chapter 6'"          '<a href="#chapter-6[^"]*">Chapter 6</a>'
want "'Chapter 4.5' subsection"  '<a href="#[^"]+">Chapter 4.5</a>'
want "'section 1.4' keyword"     '<a href="#[^"]+">section 1.4</a>'
want "bare '2.4.1' reference"    '<a href="#[^"]+">2.4.1</a>'
want "C.3 table row '0 - ...'"   '<a href="#chapter-0[^"]*">0 [—–-] Orientation</a>'
want "'Appendix' (standalone)"   '<a href="#[^"]+">Appendix</a>'

# ---- (3) quantities that must stay plain text -----------------------------
deny "'1.5' in '1.5 (150%)'"     '<a[^>]*>1\.5</a>'
deny "'3.12' in 'Python 3.12'"   '<a[^>]*>3\.12</a>'
grep -Fq '1.5 (150%)' "$html" || { echo "FAIL: '1.5 (150%)' text did not survive" >&2; fail=1; }

# ---- (4) every emitted target resolves -----------------------------------
python3 - "$html" <<'PY' || fail=1
import re, sys
doc = open(sys.argv[1], encoding="utf-8").read()
ids = set(re.findall(r'\sid="([^"]+)"', doc))
anchors = {a for a in re.findall(r'href="#([^"]+)"', doc) if a}
missing = sorted(anchors - ids)
if missing:
    print("FAIL: %d HTML #anchor(s) do not resolve:" % len(missing))
    for a in missing[:10]:
        print("   #%s" % a)
    sys.exit(1)
print("PASS: %d HTML cross-reference anchors resolve" % len(anchors))
PY

python3 - "$tex" <<'PY' || fail=1
import re, sys
tex = open(sys.argv[1], encoding="utf-8").read()
refs = set(re.findall(r'\\hyperref\[([^\]]+)\]', tex))
labels = set(re.findall(r'\\label\{([^}]+)\}', tex)) | set(re.findall(r'\\hypertarget\{([^}]+)\}', tex))
if len(refs) < 100:
    print("FAIL: only %d \\hyperref cross-references in the LaTeX (expected >100)" % len(refs))
    sys.exit(1)
missing = sorted(refs - labels)
if missing:
    print("FAIL: %d LaTeX \\hyperref target(s) have no \\label:" % len(missing))
    for a in missing[:10]:
        print("   %s" % a)
    sys.exit(1)
print("PASS: %d LaTeX cross-references, all targets resolve" % len(refs))
PY

[ "$fail" -eq 0 ] || exit 1
echo "PASS: crossref-links.lua wired into both builds; references link, quantities don't, all targets resolve."
