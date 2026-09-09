# Introduction to Software Engineering in the Age of AI

*An open-educational resource.*
[![build](https://github.com/rioffe/intro_to_ai_software_engineering_claude/actions/workflows/ci.yml/badge.svg)](https://github.com/rioffe/intro_to_ai_software_engineering_claude/actions/workflows/ci.yml)
[![Licence: CC BY 4.0](https://img.shields.io/badge/Licence-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

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

Read it online: **<https://rioffe.github.io/intro_to_ai_software_engineering_claude/>**
— or grab the single-file [**book.pdf**](book.pdf) / [**book.html**](book.html).
All three are assembled from the Markdown in `manuscript/`.

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
- [Chapter 11 — LLM Interface: Enter A Second Model](manuscript/12-llm-interface.md)
- [Chapter 12 — Evaluation](manuscript/13-evaluation.md)
- [Chapter 13 — Hardening](manuscript/14-hardening.md)

### Back matter

- [Closing](manuscript/15-closing.md)
- [Appendix — Where to Go Next](manuscript/16-appendix.md)
- [License](manuscript/17-license.md)

## Repository layout

- `manuscript/`: The source of the book as a flat, zero-padded `NN-*.md`
  sequence — `00-front-matter.md` (Introduction), `01`–`16` (chapters 0–13, the
  Closing, and the Appendix), and `17-license.md` (the license page). File order
  is the book order.
- [`book.pdf`](book.pdf): The full assembled book — front matter, all chapters,
  the Closing, the Appendix, and the License page, in one PDF, with a
  **two-level, clickable, paginated table of contents** (a short front-matter
  "Contents" listing the chapters, plus a compact per-chapter "Contents" page at
  the start of each chapter), **clickable in-prose cross-references** ("Chapter 6",
  "section 1.4", the Closing's chapter table, and so on), the book class's running
  headers, and a per-page `CC BY 4.0 · © 2026  Robert Ioffe` footer (omit it with
  `make book LICENSE=0`). The first page is the cover image from
  `assets/book_cover.png`, followed by the title page.
- `assets/book_cover.png`: The cover image used as the first page of the generated PDF.
- [`book.html`](book.html): The self-contained HTML edition of the same book — a single file with a **two-level, in-page table of contents** (a master list *plus* a compact per-chapter "Contents" box of in-page anchor links), the same **clickable in-prose cross-references** as the PDF, and math, mermaid diagrams, the cover, and its CSS all **inlined**. It opens **offline** in any modern browser and publishes cleanly to **GitHub Pages**. Tracked on purpose, like `book.pdf`.
- `index.html` + `.nojekyll`: the GitHub Pages entry point — `index.html` is a
  one-line redirect to `book.html`; `.nojekyll` tells Pages to serve every file
  verbatim (no Jekyll). See *Publishing to GitHub Pages* below.
- `tests/`: `make test` runs all of these (also what CI runs):
  - `test_math_fence.sh` — the shared `[`/`]`→`$$` preprocessor is fence-aware.
  - `test_crossref_links.sh` — `crossref-links.lua` is wired into both builds; references link, quantities (`0.5%`, `Python 3.12`) don't, every target resolves (HTML and LaTeX).
  - `test_local_toc.sh` — `local-toc-html.lua` is wired in; boxes, `skip_nth`, depth nesting, and anchor resolution are correct.
  - `test_book_html.sh` — full `book.html` build: two-level in-page TOC, all anchors resolve, math present, self-contained (no external JS/CSS).
  - `test_book_cover.sh` — full `book.pdf` build: cover art on page 1, title page on page 2.
- `.github/workflows/ci.yml`: runs the `tests/` on every push and PR — a fast `filters` job (pandoc only) plus `html` and `pdf` jobs for the full builds.
- `Makefile`: The build driver — the normal way to generate the PDF and the HTML, and to run the tests (see below).
- `tools/build-book-localtoc.sh`: Assembles `book.pdf` — concatenates every
  `manuscript/*.md` in order and runs pandoc once.
- `tools/build-book-html.sh`: Assembles `book.html` — the HTML sibling of the PDF build — reusing that build's ordering, fence-aware math preprocessor, and mermaid detection, then rendering with two Pandoc Lua filters (cross-references and per-chapter "Contents" boxes).
- `tools/crossref-links.lua`: Shared Pandoc filter (both builds) that turns the manuscript's plain-prose cross-references into internal links, using pandoc's own heading ids.
- `tools/local-toc-html.lua`: Pandoc filter for the HTML build that inserts a per-chapter "Contents" box after each chapter's H1, built from pandoc's heading ids (the AST-level analogue of the PDF's per-chapter etoc TOC).
- `tools/math-fence.awk`: The shared, fence-aware `[`/`]`→`$$` display-math
  preprocessor, run by both builds (guarded by `tests/test_math_fence.sh`).
- `tools/book-html.html` + `tools/style.css`: the HTML5 pandoc template and its readable stylesheet.
- `tools/ascii-cleanup.py`: A helper that swaps Unicode box-drawing characters
  for ASCII (the `lmmono` PDF code font lacks them); not part of the automated build.
- `tools/license-footer.tex`: The LaTeX preamble the PDF build (`make book`)
  includes for the per-page `CC BY 4.0 · © 2026  Robert Ioffe` footer; it also
  reproduces the book class's running headers via `fancyhdr`. Skipped when
  `LICENSE=0`.
- [`LICENSE`](LICENSE): The license — Creative Commons Attribution 4.0 (CC BY 4.0).
- `.gitignore`: Ignores per-chapter build artifacts (`manuscript/*.pdf`), Python
  bytecode caches, `mermaid-filter` `.err` logs, a local `.puppeteer.json`, the
  local-only `notes/`, and editor/OS temp files; the assembled `book.pdf` and
  `book.html` are tracked on purpose.

## Building the book

The normal way to (re)generate `book.pdf` (and `book.html`) is the `Makefile`.

### Prerequisites

Common to both builds:

- **pandoc** — the Markdown converter; also runs the two Lua filters
  (`tools/crossref-links.lua`, and for HTML `tools/local-toc-html.lua`).
  Developed and CI-tested against **pandoc 3.11**; the HTML build needs
  `--math-method` / `--embed-resources`, so a recent 3.x (≳ 3.1.7).
- **Chrome / Chromium** — the manuscript embeds Mermaid diagrams (Chapter 1 and
  Chapter 13), rendered via `mermaid-filter` → `mmdc`, which drives a headless
  browser. The build auto-detects Chrome, Chrome Canary, Chromium, or Edge, or
  honours `PUPPETEER_EXECUTABLE_PATH`.
- **`mermaid-filter`** on `PATH` (`npm install -g mermaid-filter`).

For `make book` (PDF):

- **A TeX distribution that provides `xelatex` and `latexmk`** — `xelatex` renders
  the PDF and `latexmk` iterates it to a fixed point so the two-level table of
  contents resolves its forward references and page numbers. (For example,
  BasicTeX on macOS, installed via `brew install --cask basictex`; the CI `pdf`
  job installs `texlive-xetex texlive-latex-recommended texlive-latex-extra
  texlive-fonts-recommended lmodern latexmk`.)

For `make book-html` (HTML):

- No TeX. Math is rendered with pandoc's **KaTeX** method and inlined via
  `--embed-resources`, so the **first** build needs network access to fetch the
  KaTeX assets; once `book.html` is produced it is fully self-contained and opens
  offline.

### Make targets

```sh
make                 # alias: build book.pdf (the default target)
make book            # build book.pdf (cover, two-level TOC, cross-ref links, CC BY footer)
make book-html       # build book.html (self-contained: TOC, cross-ref links, math, cover inlined)
make test            # run every tests/*.sh (also what CI runs)
make clean           # remove the generated book.pdf and book.html
make help            # show the targets and overridable variables
```

### Overridable variables

Shared by both builds (`export`ed from the `Makefile`):

```sh
make book AUTHOR="Ada Lovelace"   # author on the title page (default: Robert Ioffe; AUTHOR= for none)
make book TITLE="..."             # book title
make book DATE="..."              # date on the title page (default: current year)
make book FRONTMATTER=0           # give the front matter a per-chapter "Contents" too
```

PDF only (`make book`):

```sh
make book LOCAL_DEPTH=2           # per-chapter local TOC depth (default 3: sections + subsections)
make book OUTPUT=mybook.pdf       # output path (default: book.pdf at the repo root)
make book MARGIN=0.5in            # page margin on all sides (default: pandoc's layout; e.g. 1cm, 0.3in)
make book LICENSE=0               # omit the per-page CC BY footer
```

HTML only (`make book-html`):

```sh
make book-html TOC_DEPTH=2        # per-chapter local TOC depth (default 3; the PDF's LOCAL_DEPTH)
make book-html OUT=mybook.html    # output path (default: book.html at the repo root)
```

### Using the build scripts directly

Each `Makefile` target shells out to a script under `tools/`, which resolves
paths relative to its own location, so both can also be run directly:

```sh
tools/build-book-localtoc.sh
AUTHOR="Robert Ioffe" tools/build-book-localtoc.sh out.pdf
tools/build-book-localtoc.sh --margin 0.5in out.pdf

tools/build-book-html.sh
AUTHOR="Robert Ioffe" tools/build-book-html.sh out.html
```

### Publishing to GitHub Pages

The site at
<https://rioffe.github.io/intro_to_ai_software_engineering_claude/> is served
straight from `main` (repo **Settings → Pages → Deploy from a branch → `main` /
`/`**). `index.html` redirects to the tracked `book.html`, and `.nojekyll` keeps
Pages from touching anything.

Because Pages serves the committed file, **after editing the manuscript you must
rebuild and commit `book.html`** for the site to update:

```sh
make book-html && git add book.html && git commit -m "rebuild book.html"
```

Every push to `main` then triggers a Pages redeploy (~1 min).

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
