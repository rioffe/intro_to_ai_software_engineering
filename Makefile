# Makefile -- build the book with a two-level table of contents, in PDF and HTML.
#
# Borrowed from ai_systems_engineering_bootcamp (its `make book-local` target),
# adapted to this repo: the source is a flat manuscript/ directory of
# zero-padded NN-*.md files instead of curriculum/week*/chapterN.md plus
# separate introduction/license/supplemental_docs.
#
#   make book        -> book.pdf: the whole manuscript assembled into one book
#                       with a TWO-LEVEL, clickable, paginated TOC -- a master
#                       "Contents" (chapters only, top-level) PLUS a compact
#                       per-chapter "Contents" page at the top of each chapter.
#                       Equivalent to the reference project's `make book-local`.
#   make book-html   -> book.html: the HTML sibling -- ONE self-contained,
#                       GitHub-Pages-publishable, offline-readable book.  Same
#                       two-level TOC (a master list PLUS a per-chapter "Contents"
#                       box, in-page anchor links instead of page numbers); math,
#                       mermaid diagrams, CSS, and the cover are all INLINED, so
#                       the single book.html opens offline in any modern browser
#                       and at any GitHub Pages sub-path.
#
#   Both builds run tools/crossref-links.lua, so the manuscript's plain-prose
#   cross-references ("Chapter 6", "section 1.4", a bare "2.4.1", the C.3 table)
#   are clickable links in book.pdf and in-page anchor links in book.html.
#   make clean       -> remove the generated book.pdf and book.html.
#   make help        -> show the targets and overridable variables.
#
# Overridable variables (pass on the make command line):
#   make book      AUTHOR="..."                   PDF: author on the title page
#                                                 (default: Robert Ioffe; AUTHOR= for none).
#   make book      TITLE="..." DATE="..." LOCAL_DEPTH=2 OUTPUT=mybook.pdf
#   make book      MARGIN=0.5in                   PDF: page margin on all sides.
#   make book      FRONTMATTER=0                  give the first file a local
#                                                 "Contents" page too.
#   make book-html TOC_DEPTH=2|3 FRONTMATTER=0 AUTHOR="..." OUT=file.html
#                                                 (TOC_DEPTH maps to the PDF's
#                                                  LOCAL_DEPTH; same FRONTMATTER.)
#   PDF starts with assets/book_cover.png; book.html embeds it as an <img>.
# The shell scripts resolve paths relative to their own directory, so a single
# broken step is reported but make still exits non-zero when the build fails.

ROOT     ?= .
MK         := bash $(CURDIR)/tools/build-book-localtoc.sh
MKH        := bash $(CURDIR)/tools/build-book-html.sh

# Author on the title page of both builds. Defaults to "Robert Ioffe";
# override on the command line (make book AUTHOR="Someone Else") or pass
# AUTHOR= for no author.
AUTHOR   ?= Robert Ioffe
export AUTHOR

.PHONY: book book-html test clean help

# The default goal: the PDF book (the established primary artifact).
.DEFAULT_GOAL := book

## book: assemble the manuscript into one PDF with a two-level TOC.
book:
	$(MK)

## book-html: assemble the manuscript into one self-contained book.html.
book-html:
	$(MKH)

## test: run every tests/*.sh (also what CI runs).
test:
	@set -e; for t in $(CURDIR)/tests/*.sh; do echo "== $$t"; bash "$$t"; done

## Help / overridable variables
help:
	@echo "make targets: book, book-html, test, clean, help"
	@echo
	@echo "Overridable variables (pass on the make command line):"
	@echo "   make book:"
	@echo "  make book AUTHOR=\"...\"            Author on the title page (default: Robert Ioffe; AUTHOR= for none)."
	@echo "  make book TITLE=\"...\"           Book title (default: Introduction to AI Software Engineering)."
	@echo "  make book DATE=\"...\"             Date on the title page (default: this year)."
	@echo "  make book LOCAL_DEPTH=2|3         Per-chapter local TOC depth (default 3: sections + subsections)."
	@echo "  make book OUTPUT=mybook.pdf       Output PDF path (default: book.pdf at repo root)."
	@echo "  make book MARGIN=0.5in            Page margin on all sides (default: pandoc's layout; e.g. 1cm, 0.3in)."
	@echo "  make book FRONTMATTER=0           Give the first file a local \"Contents\" page too."
	@echo "  Cover: assets/book_cover.png is added as the first PDF page."
	@echo
	@echo "   make book-html:"
	@echo "  make book-html TOC_DEPTH=2|3     Per-chapter local TOC depth (default 3)."
	@echo "  make book-html FRONTMATTER=0     Give the first file a local \"Contents\" box too."
	@echo "  make book-html AUTHOR=\"...\"     Author on the title page (default: Robert Ioffe; also TITLE, DATE)."
	@echo "  make book-html OUT=mybook.html   Output HTML path (default: book.html at repo root)."
	@echo "  HTML: math + mermaid SVGs + CSS + cover are INLINED into book.html -- it opens"
	@echo "  offline in any modern browser and publishes to GitHub Pages at any sub-path."

## Remove the generated books
clean:
	@rm -f book.pdf book.html
