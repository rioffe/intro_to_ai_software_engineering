# Makefile -- build the book with a two-level table of contents.
#
# Borrowed from ai_systems_engineering_bootcamp (its `make book-local` target),
# adapted to this repo: the source is a flat manuscript/ directory of
# zero-padded NN-*.md files instead of curriculum/week*/chapterN.md plus
# separate introduction/license/supplemental_docs.
#
#   make book      -> book.pdf: the whole manuscript assembled into one book with
#                    a TWO-LEVEL, clickable, paginated TOC -- a short master
#                    "Contents" (chapters only, top-level) PLUS a compact
#                    per-chapter "Contents" page at the top of each chapter.
#                    This is the equivalent of the reference project's
#                    `make book-local`.
#   make clean     -> remove the generated book.pdf.
#   make help      -> show the targets and overridable variables.
#
# Overridable variables (pass on the make command line):
#   make book AUTHOR="Robert Ioffe"
#   make book TITLE="..." DATE="..." LOCAL_DEPTH=2 OUTPUT=mybook.pdf
#   make book FRONTMATTER=0            (give the first file a local "Contents" too)
# The generated PDF starts with assets/book_cover.png, followed by the title page.
# The shell scripts resolve paths relative to their own directory, so a single
# broken step is reported but make still exits non-zero when the build fails.

ROOT     ?= .
MK        := bash $(CURDIR)/tools/build-book-localtoc.sh

.PHONY: book clean help

# The single default goal: assemble the book with a two-level TOC.
.DEFAULT_GOAL := book
book:
	$(MK)

## Help / overridable variables
help:
	@echo "make targets: book, clean, help"
	@echo
	@echo "Overridable variables (pass on the make command line):"
	@echo "  make book AUTHOR=\"...\"            Author on the title page."
	@echo "  make book TITLE=\"...\"           Book title (default: Introduction to AI Software Engineering)."
	@echo "  make book DATE=\"...\"             Date on the title page (default: this year)."
	@echo "  make book LOCAL_DEPTH=2|3         Per-chapter local TOC depth (default 3: sections + subsections)."
	@echo "  make book OUTPUT=mybook.pdf       Output PDF path (default: book.pdf at repo root)."
	@echo "  make book MARGIN=0.5in            Page margin on all sides (default: pandoc's layout; e.g. 1cm, 0.3in)."
	@echo "  make book FRONTMATTER=0           Give the first file a local \"Contents\" page too."
	@echo "  Cover: assets/book_cover.png is added as the first PDF page."

## Remove the generated book
clean:
	@rm -f book.pdf
