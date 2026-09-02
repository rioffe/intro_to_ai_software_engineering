# math-fence.awk -- fence-aware [ / ] -> $$ /$$ math fence preprocessor.
#
# Markdown here uses a bare "[" line to OPEN and a bare "]" line to CLOSE a
# display-math fence (pandoc renders each pair as $$...$$).  This must NOT fire
# on a lone '[' or ']' line that lives INSIDE a fenced code block -- e.g. a
# pyproject.toml whose `authors = [ ... ]` has a bare ']' line that the old
# non-fence-aware sed version turned into a stray '$$' and corrupted the sample.
#
# We toggle a state on every ``` / ~~~ fence and substitute only outside it:
# a line that is only "[ " opens a math fence; only "]" closes it.  See the
# regression test tests/test_math_fence.sh.

BEGIN { fence = 0 }

# Toggle fence state on the fence line itself; pass it through untouched.
/^[[:space:]]*(\x60\x60\x60|~~~)/ { fence = !fence; print; next }

# Only outside a code fence: convert a bare "[ " / "]" line to a math fence.
!fence {
  if ($0 ~ /^[[:space:]]*\[[[:space:]]*$/) { print "$$"; print ""; next }
  if ($0 ~ /^[[:space:]]*\][[:space:]]*$/) { print ""; print "$$"; next }
}

{ print }
