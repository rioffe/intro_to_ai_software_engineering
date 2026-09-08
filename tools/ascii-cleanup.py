#!/usr/bin/env python3
"""ascii-cleanup.py -- replace Unicode box-drawing characters with ASCII.

Why this exists
----------------
The book is built with `pandoc --pdf-engine=latexmk -xelatex` (see
tools/build-book-localtoc.sh).  Fenced ``` code blocks are typeset in the
`lmmono` monospace font, which does NOT contain the Unicode box-drawing
glyphs (the U+2500 block).  Every such glyph shows up at build time as:

     [WARNING] Missing character: There is no U+251C (a box glyph) in
              font [lmmono10-regular]:!

and is simply dropped from the PDF.  A directory/tree diagram like the one in
manuscript/01-orientation.md:

   mortgage-calculator-book/
     |-- pyproject.toml
     |   \\-- src/mortgage_calculator_book/
     \\-- tests/

survives only when written with ASCII.  This script rewrites the box-drawing
characters to their ordinary ASCII equivalents -- the same shape you get from
`tree -A` -- which `lmmono` DOES have, so the diagram survives the PDF build.

Mapping
-------
The single-line shapes are what tree diagrams use; double-line, heavy, and
rounded variants map to the same ASCII shape:

    horizontal   - (and double)   -> -      U+2500 U+2550
    vertical         | (and double) -> |      U+2502 U+2551
    bottom-left    \\                 -> \\      U+2514 U+255A   (a tree's
                                                             final branch)
    any other corner or join        -> +      U+250C..U+257F
    (the joins +, |, - are already ASCII and are never re-mapped)

The substitution is purely per-character; surrounding spaces are left intact,
so "ch-- name" becomes "+-- name" and "|   \\-- x" stays "|   \\-- x".  It is
idempotent: the ASCII targets ( - | \\ + ) are never inputs, so re-running is a
no-op and a re-run on already-ASCII text changes nothing.

Usage
-----
    python3 tools/ascii-cleanup.py                  # manuscript/*.md, in place
    python3 tools/ascii-cleanup.py --dry-run        # show what WOULD change
    python3 tools/ascii-cleanup.py --dry-run FILE    # inspect / preview one file
    python3 tools/ascii-cleanup.py a.md b.md         # explicit files
    python3 tools/ascii-cleanup.py --glob 'cur/**/*.md'   # any glob

Exit status is non-zero only on a write/read I/O error (or no matching files);
a file that had no box-drawing characters is left untouched and, unless
--quiet is given, reported as "(clean)".
"""

from __future__ import annotations

import argparse
import glob
import sys
from collections import Counter
from pathlib import Path

# --- The character mapping ---------------------------------------------------
# Built from the full U+2500 "Box Drawing" block so the intent is visible
# rather than a hard-coded 4-entry dict that breaks on the next diagram
# someone pastes in.
_HORIZONTAL = "─━"                 # -
_VERTICAL = "│║"                   # |
_END = "└╚"                       # \  (bottom-left; a tree's final branch)
_JOINS_AND_CORNERS = (            # +
    "┌┐┘├┤┬┴┼"           # single line
    "╒╓╔╕╖╗╘╛"         # double-line corners
    "╞╟╠╢╣╤╥╦╧"        # double-line / heavy joins
    "╨╩╪╫╬"          # heavy joins
)

BOX_TO_ASCII: dict[str, str] = {}
BOX_TO_ASCII.update({ch: "-" for ch in _HORIZONTAL})
BOX_TO_ASCII.update({ch: "|" for ch in _VERTICAL})
BOX_TO_ASCII.update({ch: "\\" for ch in _END})
BOX_TO_ASCII.update({ch: "+" for ch in _JOINS_AND_CORNERS})


def convert(text: str) -> tuple[str, Counter]:
    """Return (text with box glyphs replaced, counts of each glyph found)."""
    counts: Counter = Counter()
    out: list[str] = []
    for ch in text:
        rep = BOX_TO_ASCII.get(ch)
        out.append(rep if rep is not None else ch)
        if rep is not None:
            counts[ch] += 1
    return "".join(out), counts


def find_files(args: argparse.Namespace) -> list[Path]:
    """Resolve the list of files to process from explicit args or --glob."""
    if args.files:
        # Explicit paths: a file as given; a directory expanded to its *.md.
        paths: list[Path] = []
        for p in args.files:
            pp = Path(p)
            if pp.is_dir():
                paths += sorted(pp.rglob("*.md"))
            else:
                paths.append(pp)
        return paths
    # No files given: use --glob, resolved against the repo root (tools/ -> ..).
    repo_root = Path(__file__).resolve().parent.parent
    matches = glob.glob(args.glob, recursive=True)
    return [
        Path(m) if Path(m).is_absolute() else repo_root / m
        for m in sorted(matches)
    ]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Replace Unicode box-drawing characters with ASCII, in place."
    )
    parser.add_argument(
        "files", nargs="*",
        help="Explicit files or directories (default: files matching --glob).",
    )
    parser.add_argument(
        "--glob", default="manuscript/*.md",
        help="Pattern when no files are given (default: manuscript/*.md, "
             "resolved against the repo root).",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Report changes without writing any file.",
    )
    parser.add_argument(
        "-q", "--quiet", action="store_true",
        help="Only print files that actually changed.",
    )
    args = parser.parse_args(argv)

    files = [f for f in find_files(args) if f.is_file()]
    if not files:
        print(f"no matching files for pattern {args.glob!r}", file=sys.stderr)
        return 1

    changed = 0
    errors = 0
    for path in files:
        try:
            original = path.read_text(encoding="utf-8")
        except OSError as exc:
            print(f"[error] cannot read {path}: {exc}", file=sys.stderr)
            errors += 1
            continue

        new, counts = convert(original)
        if not counts:
            if not args.quiet:
                print(f"(clean)  {path}")
            continue

        changed += 1
        summary = "    ".join(
            f"{ch} -> {BOX_TO_ASCII[ch]!r} x{counts[ch]}"
            for ch in sorted(counts, key=lambda c: ord(c))
        )
        print(f"[*] {path}")
        print(f"    glyphs: {summary}")
        for old_line, new_line in zip(original.splitlines(), new.splitlines()):
            if old_line != new_line:
                print(f"       - {old_line}")
                print(f"       + {new_line}")

        if args.dry_run:
            print(f"     (dry-run: not writing {path})")
            continue

        try:
            path.write_text(new, encoding="utf-8")
        except OSError as exc:
            print(f"[error] cannot write {path}: {exc}", file=sys.stderr)
            errors += 1

    verb = "would change" if args.dry_run else "changed"
    suffix = " [dry-run -- no files written]" if args.dry_run else ""
    print(f"\n{verb} {changed} file(s); {errors} error(s){suffix}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
