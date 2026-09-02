# Introduction to Software Engineering in the Age of AI

*An open-educational resource.* [![Licence: CC BY 4.0](https://img.shields.io/badge/Licence-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

A hands-on introduction to software engineering, built one working system at a
time. The book braids two threads: the **tools of the trade** (terminal, git,
Python, a coding agent, local and hosted language models) introduced right before
the chapter that needs them, and **one system — a "hybrid" mortgage calculator —
extended chapter by chapter** from an empty repository to a working application
with three front ends (a command line, a graphical UI, and a language model that
can operate it on your behalf).

The through-line is a *human-verified core with an AI-assisted layer*: you design,
write, and verify the core yourself, while an agent drafts and a model reasons
around it — but neither one gets to decide what "correct" means. That judgment
stays with you, written down three times at three altitudes: a plain-language
spec, executable tests, and a formal schema a language model can call.

The full book is available as a single PDF — [**book.pdf**](book.pdf) — assembled
from the Markdown in `manuscript/`.

## Table of Contents

### Front matter

- [Introduction to Software Engineering in the Age of AI](manuscript/00-front-matter.md)

### Chapters

- [Chapter 0 — Orientation](manuscript/01-orientation.md)
- [Chapter 1 — Meet Your Coding Agent](manuscript/02-meet-your-coding-agent.md)
- [Chapter 2 — Writing SPEC.md](manuscript/03-writing-spec.md)
- [Chapter 3 — Holding the Agent to a Standard](manuscript/04-ruff.md)
- [Chapter 4 — The Domain: Fixed Mortgages](manuscript/05-fixed-mortgages.md)
- [Chapter 5 — Tests & Test-Driven Development](manuscript/06-tests-and-tdd.md)
- [Chapter 6 — Mathematical Core Library](manuscript/07-math-core-library.md)
- [Chapter 7 — Validation](manuscript/08-validation.md)
- [Chapter 8 — Command Line Interface](manuscript/09-cli.md)
- [Chapter 9 — Calculator UI](manuscript/10-calculator-ui.md)
- [Chapter 10 — Tool Interface](manuscript/11-tool-interface.md)
- [Chapter 11 — LLM Interface: A Second Model for a Second Job](manuscript/12-llm-interface.md)
- [Chapter 12 — Evaluation](manuscript/13-evaluation.md)
- [Chapter 13 — Hardening](manuscript/14-hardening.md)

### Back matter

- [Appendix — Where to Go Next](manuscript/15-appendix.md)
- [Closing](manuscript/16-closing.md)
- [License](manuscript/17-license.md)

## Repository layout

- `manuscript/`: The source of the book as a flat, zero-padded `NN-*.md`
  sequence — `00-front-matter.md` (Introduction), `01`–`16` (chapters 0–13, the
  Appendix, and the Closing), and `17-license.md` (the license page). File order
  is the book order.
- [`book.pdf`](book.pdf): The full assembled book — front matter, all chapters,
  the Appendix, the Closing, and the License page, in one PDF, with a
  **two-level, clickable, paginated table of contents** (a short front-matter
  "Contents" listing the chapters, plus a compact per-chapter "Contents" page at
  the start of each chapter), a title page, and a per-page
  `CC BY 4.0 · © 2026` footer. The first page is the cover image from
  `assets/book_cover.png`, followed by the title page.
- `assets/book_cover.png`: The cover image used as the first page of the generated PDF.
- `Makefile`: The build driver — the normal way to generate the PDF (see below).
- `tools/build-book-localtoc.sh`: Assembles `book.pdf` — concatenates every
  `manuscript/*.md` in order and runs pandoc once.
- `tools/license-footer.tex`: The shared LaTeX preamble that stamps the per-page
  license footer on every page.
- [`LICENSE`](LICENSE): The license — Creative Commons Attribution 4.0 (CC BY 4.0).
- `.gitignore`: Ignores per-chapter build artifacts (`manuscript/*.pdf`) and
  editor/OS temp files; the assembled `book.pdf` is tracked on purpose.

## Building the book

The normal way to (re)generate `book.pdf` is the `Makefile`.

### Prerequisites

- **pandoc** — the Markdown→LaTeX converter.
- **A TeX distribution that provides `xelatex` and `latexmk`** — `xelatex` renders
  the PDF and `latexmk` iterates it to a fixed point so the per-page footers and
  the two-level table of contents resolve their forward references and page
  numbers. (For example, BasicTeX on macOS, installed via `brew install --cask
  basictex`.)

The book embeds no Mermaid diagrams, so no browser is needed; the build keeps
Mermaid/Chrome detection only so a future diagram chapter "just works."

### Make targets

```sh
make                 # alias: build book.pdf (the default target)
make book            # build book.pdf (cover, two-level TOC, per-page license footer)
make clean           # remove the generated book.pdf
make help            # show the targets and overridable variables
```

### Overridable variables

```sh
make book AUTHOR="Robert Ioffe"   # author on the title page
make book TITLE="..."             # book title on the title page
make book DATE="..."              # date on the title page
make book LOCAL_DEPTH=2           # per-chapter local TOC depth (default 3: sections + subsections)
make book OUTPUT=mybook.pdf       # output path (default: book.pdf at the repo root)
make book MARGIN=0.5in             # page margin on all sides (default: pandoc's layout; e.g. 1cm, 0.3in)
make book LICENSE=0               # omit the per-page license footer
make book FRONTMATTER=0           # give the front matter a per-chapter "Contents" page too
```

### Using `build-book-localtoc.sh` directly

The `Makefile` target shells out to `tools/build-book-localtoc.sh`, which
resolves paths relative to its own location, so it can also be run directly.
The generated PDF starts with `assets/book_cover.png`, followed by the title page:

```sh
tools/build-book-localtoc.sh
AUTHOR="Robert Ioffe" tools/build-book-localtoc.sh out.pdf
tools/build-book-localtoc.sh --margin 0.5in out.pdf
```

## License

[![Licence: CC BY 4.0](https://img.shields.io/badge/Licence-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

This work is licensed under a
[Creative Commons Attribution 4.0 International License](https://creativecommons.org/licenses/by/4.0/).

This project — the book, the manuscript, and the accompanying build tooling — is
released under that license ([CC BY 4.0](LICENSE)):

- Deed: <https://creativecommons.org/licenses/by/4.0/>
- Legal code: <https://creativecommons.org/licenses/by/4.0/legalcode>

> **Copyright © 2026 Robert Ioffe — <https://github.com/rioffe>**

You are free to use, share, and adapt this material for any purpose,
**including commercial**, provided you give **appropriate credit** to Robert
Ioffe (<https://github.com/rioffe>), include a link to the license, and indicate
if changes were made (and in no way that suggests the author endorses your use).
