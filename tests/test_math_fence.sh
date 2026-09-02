#!/usr/bin/env bash
# Regression test for the fence-aware [ / ] -> $$ math preprocessor
# (tools/math-fence.awk), the piece of md2pdf.sh's "fence-aware" learning that
# guards our book build.  The bug it guards: a lone "]" line that lives INSIDE a
# fenced code block (e.g. pyproject.toml's `authors = [ ... ]`) must NOT be
# rewritten into a stray "$$" math-fence opener.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AWK="$ROOT/tools/math-fence.awk"

[ -f "$AWK" ] || {
     echo "FAIL: $AWK not found"
     exit 1
}

# Build a fixture that mixes (a) a real math fence OUTSIDE any code block and
# (b) a pyproject.toml-style code block whose `authors = [ ... ]` has a bare "]"
# line that would corrupt an earlier, non-fence-aware pass.
in="$(mktemp /tmp/math-fence-in.XXXXXX.md)"
out="$(mktemp /tmp/math-fence-out.XXXXXX.md)"
trap 'rm -f "$in" "$out"' EXIT
cat >"$in" <<'EOF'
# A real math fence lives outside any code block:
[
x + y
]

```toml
authors = [
      { name = "Robert Ioffe", email = "robert.ioffe@vinipuh.com" }
]
reads = "ok"
```
EOF

awk -f "$AWK" "$in" >"$out"

# (1) The toml "]" is preserved: exactly ONE bare "]" line remains, and it is the
# toml one -- the real math fence's "]" was consumed into "$$".
bare_closing="$(grep -c '^]$' "$out" || true)"
if [ "$bare_closing" -ne 1 ]; then
     echo "FAIL: expected exactly one preserved bare ']'", got "$bare_closing:" >&2
     grep -n '^]$' "$out" || true
     exit 1
fi

# (2) The real math fence was converted: the lone "[" and "]" became a pair of
# "$$" display-math fences.
dollar_dollar="$(grep -cFx '$$' "$out" || true)"
if [ "$dollar_dollar" -ne 2 ]; then
     echo "FAIL: expected 2 literal dollar-dollar math fences (outer math block), got $dollar_dollar:" >&2
     grep -nFx '$$' "$out" || true
     exit 1
fi

# (3) The toml block body is untouched -- the authors line survives verbatim.
grep -Fq 'authors = [' "$out" || {
     echo "FAIL: toml '[' body was mangled"
     exit 1
}
grep -Fq 'reads = "ok"' "$out" || {
     echo "FAIL: line after toml ']' was mangled"
     exit 1
}

# (4) The builder actually uses this shared awk (no drift: inline vs shared copy).
grep -Fq 'awk -f "$ROOT/tools/math-fence.awk"' "$ROOT/tools/build-book-localtoc.sh" ||
     {
          echo "FAIL: build-book-localtoc.sh does not call tools/math-fence.awk"
          exit 1
     }

echo "PASS: fence-aware math preprocessor is correct and wired into the build"
