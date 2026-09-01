#!/usr/bin/env bash
set -euo pipefail

output="$(mktemp /tmp/book-cover-test.XXXXXX.pdf)"
trap 'rm -f "$output"' EXIT

OUTPUT="$output" make book >/dev/null

# The first PDF page must contain the supplied cover artwork as an image.
images="$(mktemp /tmp/book-cover-images.XXXXXX.txt)"
trap 'rm -f "$output" "$images"' EXIT
pdfimages -f 1 -l 1 -list "$output" >"$images"
grep -Eq '^ *1 +[0-9]+ +image ' "$images"

# The original title page must remain immediately after the cover.
pdftotext -f 2 -l 2 "$output" - | grep -Fq 'Introduction to AI Software Engineering'
