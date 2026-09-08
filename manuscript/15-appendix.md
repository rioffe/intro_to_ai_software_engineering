# Appendix — Where to Go Next

## A.1 Why This Appendix Exists

Fourteen chapters back, the front matter promised a note on what this book deliberately left out, and why leaving it out was a choice rather than an oversight. This is that note, expanded. Each entry below gets a paragraph: what the tool or practice solves, why it stayed out of scope here, and where it would slot into a project like this one if you decided to add it later. Nothing here is a tutorial — think of it as a map for your next project, not homework for this one.

## A.2 Docker

Docker packages an application together with everything it needs to run — system libraries, Python version, dependencies — into a single, portable image that behaves identically on any machine that runs it. What it solves that this book's `uv`-based setup (Chapter 0.7) doesn't: reproducibility *across* machines, not just within one. `uv.lock` guarantees that everyone working on this project gets the same Python packages; it doesn't guarantee the same operating system, the same system libraries, or the same version of Ollama sitting alongside it. Docker was left out because that gap genuinely doesn't matter for a single-developer desktop application — it starts mattering once you're deploying to a server you don't control by hand, or handing the project to someone whose machine looks nothing like yours. If you wanted to add it, the natural place is packaging the CLI (Chapter 8) or the tool interface (Chapter 10) as a standalone service, not the PyQt5 UI, which doesn't containerize as cleanly.

## A.3 CI/CD (GitHub Actions)

Continuous integration means running your checks — Ruff (Chapter 3), pytest (Chapters 5 onward), the eval set (Chapter 12) — automatically, on every push, rather than by habit. It exists to catch the day you forget to run `ruff check .` before committing, which this book has been asking you to remember by hand since Chapter 3.6.1. GitHub Actions, specifically, connects directly to the GitHub account and repository set up in Chapter 0.4 — of everything in this appendix, it's the most natural next step, since the infrastructure it needs already exists. A minimal workflow for this project would run, in order: Ruff, then pytest, then (optionally, since it costs real API calls) the eval set — failing the whole check if any step fails. Left out here specifically so the *reason* you run these checks stayed the lesson, rather than the checks becoming something that happens invisibly before you've felt why they matter.

## A.4 mypy / Type Checking

Python's type hints — used informally throughout this project, in `MortgageInput`'s field types (Chapter 7) and every function signature since Chapter 6 — are optional and unenforced by Python itself. mypy is a separate tool that reads those hints and checks them *before* the code runs, catching a category of mistake (passing a string where a function expects a number, say) that would otherwise only surface at runtime, or not at all if the buggy path never gets exercised by a test. It was left out because Pydantic already provides real, *runtime* enforcement for the inputs that matter most in this project (Chapter 7) — mypy would add a second, static layer of type-checking on top of that, genuinely useful but genuinely additional cognitive load for a first read of this book. It would matter most applied to `core.py` (Chapter 6) and `tool.py` (Chapter 10), where a type mismatch is easiest to introduce by accident and hardest to notice without either a very specific test or a type checker looking over your shoulder.

## A.5 pre-commit Hooks

pre-commit automates exactly the habit Chapters 3.6.1 and 6.8.2 asked you to build manually: running Ruff (and, if you've added it, mypy) automatically every time you run `git commit`, rather than trusting yourself to remember. It's genuinely a small, low-cost addition once the habit already exists — which is precisely why this book didn't start with it. Automating a check away before you've felt the cost of skipping it teaches the tool, not the judgment; this book chose to teach the judgment first; you already know when and why you'd want this.

## A.6 Typer

Chapter 8.3.4 flagged this in passing: Typer builds a CLI from Python type hints directly, producing less boilerplate and friendlier help output than the `argparse` this book actually used. What would change if you swapped it in: mostly ergonomics — nicer `--help` text, less manual parser configuration — not architecture. Because Chapter 8's CLI already sits cleanly on top of `MortgageInput` and `calculate_validated_payment` (Chapter 7), replacing `argparse` with Typer touches `cli.py` alone; nothing about validation or the core would need to change. A reasonable exercise once you've finished this book, if you want to feel the difference directly.

## A.7 Direct PyQt5 Widget Testing

Chapter 9.7 pulled `parse_form_values` out of the UI specifically so it could be tested without a running window, and stopped there rather than testing the widget itself. Worth being precise about why: not because it's impossible, and not because it needs a new dependency. PyQt5 can drive a widget directly — instantiate it, call `.click()` on a button, emit a signal like `returnPressed`, and check what changed — inside a `QApplication` running in offscreen mode (`QT_QPA_PLATFORM=offscreen`, set before the application is created), with nothing beyond `pytest` and `PyQt5` already in this project. A session-scoped fixture holding one shared `QApplication` is the only new piece, and it's a handful of lines, not a new tool.

What holds it out of the main chapters is concept load, not setup cost: an offscreen platform plugin, a singleton application shared across tests, and the idea of driving a widget without a real display are three new things at once, on top of everything else Chapter 9 was already teaching. Worth trying directly if you want to feel how close it actually is — write one test that builds the calculator window, sets its fields, calls `.click()` on Calculate, and asserts on the result label. If it passes on the first real try, that's the whole technique.

## A.8 Beyond This Book

Strip away the mortgage-specific details and what's left is a pattern that has nothing to do with mortgages at all: a pure, human-verified core; a validation layer wrapping it; multiple front ends built on top — some for humans, one for a model; an evaluation discipline that checks the model-facing layer honestly rather than anecdotally; and a hardening pass that assumes the world outside your code is messier than your tests. That pattern is reusable well beyond a fixed-rate payment calculation.

Worth sitting with before you close this book: what other domain do you already understand well enough to write a Chapter 4-style primer for — one you could hand-derive a formula from, hand-verify an example against, and build the same fourteen-chapter shape around? That's the actual transferable skill this book was trying to teach, more than any individual formula or tool.
