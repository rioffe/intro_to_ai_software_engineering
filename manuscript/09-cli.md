# Chapter 8 — Command Line Interface

## 8.1 Why This Chapter Exists

Everything so far has been invisible to anyone who isn't reading code — the core library, the validation layer, all of it only reachable through a test file. This chapter builds the calculator's first real, user-facing surface: a command a person can actually type and get an answer from.

By the end, you'll have a working CLI with both human-readable and JSON output, a `.env` pattern in place for a secret you don't need yet, and a README that describes all of it.

## 8.2 What the CLI Needs to Do

### 8.2.1 Revisiting the Spec

`SPEC.md`'s inputs — `principal`, `annual_rate`, `term_years`, `payments_per_year` — all need to become command-line flags. Its one output — `payment` — needs to be printed somewhere a user will see it. This is the first chapter where every one of the spec's inputs and outputs has to actually be exposed, rather than just referenced inside a test.

### 8.2.2 Sketching the Shape First

Before writing code:

```bash
mortgage-calculator-book \
    --principal 200000 --annual-rate 0.06 --term-years 30
# Fixed periodic payment: $1,199.10
```

And with an invalid input:

```bash
mortgage-calculator-book \
    --principal -1000 --annual-rate 0.06 --term-years 30
# Error: Value error, principal must be positive
```

Having this shape settled before writing `argparse` code turns the implementation into a matter of matching a known target, the same discipline Chapter 5 established for the core library.

## 8.3 argparse Basics

### 8.3.1 Why argparse

`argparse` ships with Python — no new dependency, no version to track, and it's more than capable of everything this project needs. Typer and similar libraries offer a nicer developer experience at the cost of an added dependency; for a first CLI, that trade isn't worth making yet.

### 8.3.2 Arguments, Types, Defaults, Help Text

```python
import argparse

parser = argparse.ArgumentParser(
    description="Calculate a fixed mortgage payment."
)
parser.add_argument(
    "--principal", type=float, required=True,
    help="Loan amount, in dollars",
)
parser.add_argument(
    "--annual-rate", type=float, required=True,
    help="Annual rate, e.g. 0.06 for 6%%",
)
```

`type=float` means argparse converts the string a user typed before your code ever sees it — `"200000"` arrives as `200000.0`, not a string you'd have to convert yourself. `required=True` means argparse handles the "you forgot an argument" error entirely on its own, with no code from you.

### 8.3.3 A Minimal Working Parser

In `src/mortgage_calculator_book/cli.py`:

```python
import argparse


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Calculate the fixed periodic payment for a "
            "fixed-rate mortgage."
        )
    )
    parser.add_argument(
        "--principal", type=float, required=True,
        help="Loan amount, in dollars",
    )
    parser.add_argument(
        "--annual-rate", type=float, required=True,
        help="Annual interest rate, e.g. 0.06 for 6%%",
    )
    parser.add_argument(
        "--term-years", type=int, required=True,
        help="Loan term, in years",
    )
    parser.add_argument(
        "--payments-per-year", type=int, default=12,
        help="Payments per year (default: 12)",
    )
    parser.add_argument(
        "--format", choices=["text", "json"], default="text",
        help="Output format",
    )
    return parser
```

Notice `6%%`, not `6%`, in the annual-rate help text — that's not a typo. `argparse` runs every `help=` string through `%`-style formatting when it renders `--help`, so a bare `%` looks like the start of a format specifier and crashes with `ValueError: incomplete format` the moment someone actually runs `--help`, not when you define the parser. `%%` is how you write a literal percent sign in that formatting style; `argparse` collapses it back down to a single `%` in what it actually prints. Worth testing directly rather than trusting this description — `main` doesn't exist until 8.4.1, so this needs the REPL technique from 7.4.3 rather than an actual command:

```bash
uv run python
```

```python
from mortgage_calculator_book.cli import build_parser
build_parser().parse_args(["--help"])
```

This prints the full help text and then raises `SystemExit` — that's normal, expected `argparse` behavior for `--help`, not a bug. Confirm the annual-rate line shows a single `%`, not two. If you want to see the actual crash first, temporarily change `6%%` back to `6%`, rerun the two lines above, and watch it raise `ValueError: incomplete format` instead — then put the `%%` back.

### 8.3.4 Aside: Typer

Typer builds on Python type hints to generate a CLI with less boilerplate than `argparse`, and produces friendlier help text by default. It's a reasonable choice for a larger project. This book sticks with `argparse` specifically to avoid a dependency the project doesn't strictly need — worth knowing Typer exists for whenever a future project's CLI grows complex enough to justify it.

## 8.4 Wiring the CLI to Validation and the Core

### 8.4.1 The Full Pipeline, Assembled

Same file, `src/mortgage_calculator_book/cli.py`, building on the `build_parser` function from 8.3.3 rather than replacing it. First, add these imports alongside the existing `import argparse` at the top of the file:

```python
import sys

from pydantic import ValidationError

from mortgage_calculator_book.validation import (
    MortgageInput,
    calculate_validated_payment,
)
```

Then add `main` below `build_parser`, calling it directly:

```python
def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        data = MortgageInput(
            principal=args.principal,
            annual_rate=args.annual_rate,
            term_years=args.term_years,
            payments_per_year=args.payments_per_year,
        )
    except ValidationError as exc:
        for error in exc.errors():
            print(f"Error: {error['msg']}", file=sys.stderr)
        return 1

    payment = calculate_validated_payment(data)
    print(f"Fixed periodic payment: ${payment:,.2f}")
    return 0
```

At this point `cli.py` has two imports blocks worth of content (`argparse` from 8.3.3, plus the three above) and two functions (`build_parser`, then `main`) — nothing from 8.3.3 gets removed or replaced.

Parsed arguments flow into `MortgageInput` (Chapter 7), which flows into `calculate_validated_payment` (also Chapter 7, which itself calls Chapter 6's `calculate_payment`) — three chapters of work, connected for the first time.

### 8.4.2 Handling Validation Failure Gracefully

Notice what the `except ValidationError` block does *not* do: it doesn't let Pydantic's default error formatting — which is detailed, but written for developers, not end users — reach the terminal directly. It extracts just the message from each error and prints it the way a person asked to fix their input actually wants to read it.

### 8.4.3 Wiring Up the Command, and Trying It

Chapter 0.7.2 mentioned a `[project.scripts]` entry in `pyproject.toml`, pointing at a placeholder `main` that didn't exist yet. It does now — point the entry at it:

```bash
vi pyproject.toml
```

```toml
[project.scripts]
mortgage-calculator-book = "mortgage_calculator_book.cli:main"
```

(It was `mortgage_calculator_book:main` — the package's top-level `__init__.py`, which has no `main` function. Now it points at the one you actually built, in `cli.py`.) Pick up the change:

```bash
uv sync
```

Run it for real, with the Chapter 4.5 worked example:

```bash
uv run mortgage-calculator-book \
    --principal 200000 --annual-rate 0.06 --term-years 30
```

```
Fixed periodic payment: $1,199.10
```

Matches every other front end this project will produce — the CLI is the first to confirm this number; Chapters 9 through 11 each confirm it again, a different way. Now try the error path from 8.4.2, as a real command instead of a description of one:

```bash
uv run mortgage-calculator-book \
    --principal -1000 --annual-rate 0.06 --term-years 30
```

```
Error: Value error, principal must be positive
```

That printed to `stderr`, not `stdout` — worth confirming for yourself (`... 2>/dev/null` should silence it; `... 1>/dev/null` shouldn't), since it's an easy detail to lose track of once the CLI just works and you stop looking closely.

Commit the entry-point fix on its own:

```bash
git add pyproject.toml uv.lock
git commit -m "Wire up the mortgage-calculator-book command"
git push
```

## 8.5 JSON Output

### 8.5.1 Why JSON, Not Just Text

Printed text is fine for a person typing a command directly. It's much less fine for another program trying to read the result — parsing "Fixed periodic payment: $1,199.10" back into a number is fragile and easy to break with the smallest formatting change. JSON output is a design choice made now, deliberately, for exactly the reuse Chapter 10 needs later: a machine-readable result, not just a human-readable one.

### 8.5.2 A `--format` Flag

Already present in the parser from 8.3.3 (`--format`, defaulting to `"text"`). Extend `main` to branch on it:

```python
import json


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        data = MortgageInput(
            principal=args.principal,
            annual_rate=args.annual_rate,
            term_years=args.term_years,
            payments_per_year=args.payments_per_year,
        )
    except ValidationError as exc:
        for error in exc.errors():
            print(f"Error: {error['msg']}", file=sys.stderr)
        return 1

    payment = calculate_validated_payment(data)

    if args.format == "json":
        print(json.dumps({"payment": round(payment, 2)}))
    else:
        print(f"Fixed periodic payment: ${payment:,.2f}")

    return 0
```

### 8.5.3 Serializing with the Standard Library

`json.dumps` is all this needs — no third-party JSON library required for output this simple. `round(payment, 2)` is the first place in this project payment gets rounded for display, consistent with Chapter 6.8.3's note that the core itself stays unrounded and full-precision.

### 8.5.4 Forward-Note

The shape `{"payment": 1199.10}` isn't arbitrary — it's the same shape Chapter 10's tool interface will use as its output schema, so a language model calling the calculator later gets results structured the same way a script parsing this CLI's JSON output would.

`cli.py` is feature-complete for this chapter now — commit it, since nothing has captured it yet:

```bash
git add src/mortgage_calculator_book/cli.py
git commit -m "Add CLI: argument parsing, validation wiring, JSON output"
git push
```

## 8.6 Agent-Assisted Build, With Tests First

Sections 8.3 through 8.5 had you type `build_parser` and `main` by hand, growing the file a piece at a time, before running a single test against any of it. Useful for seeing each piece land on its own, but — same issue as Chapter 7.6 — not how this book has actually been building things since Chapter 5: tests first, then an implementation that has to earn a passing result. This section does it that way for real, which means setting aside the file you just wrote and committed.

### 8.6.1 Setting Aside What You Just Built

Because 8.5.4 committed it, deleting it now doesn't lose anything — it's in git history if you want it later, including for a comparison at the end of this section:

```bash
git rm src/mortgage_calculator_book/cli.py
git commit -m "Remove hand-written cli.py to redo via TDD"
```

### 8.6.2 CLI-Level Tests

In `tests/test_cli.py`:

```python
import json

import pytest

from mortgage_calculator_book.cli import main


def test_text_output(capsys):
    exit_code = main(
        [
            "--principal", "200000",
            "--annual-rate", "0.06",
            "--term-years", "30",
        ]
    )
    captured = capsys.readouterr()
    assert exit_code == 0
    assert "1,199.10" in captured.out


def test_json_output(capsys):
    exit_code = main(
        [
            "--principal", "200000",
            "--annual-rate", "0.06",
            "--term-years", "30",
            "--format", "json",
        ]
    )
    captured = capsys.readouterr()
    assert exit_code == 0
    data = json.loads(captured.out)
    assert data["payment"] == pytest.approx(1199.10, abs=0.01)


def test_invalid_input_returns_error(capsys):
    exit_code = main(
        [
            "--principal", "-1000",
            "--annual-rate", "0.06",
            "--term-years", "30",
        ]
    )
    captured = capsys.readouterr()
    assert exit_code == 1
    assert "Error" in captured.err
```

`capsys` is a built-in pytest fixture — following the same fixture mechanism from Chapter 5.4, just one pytest already provides — that captures anything printed during a test, so you can assert on it without the output actually appearing in your terminal.

Run it:

```bash
pytest tests/test_cli.py -v
```

One collection error, same shape as Chapters 5.8.2 and 7.6.2's — `cli.py` genuinely doesn't exist right now, so pytest can't import it to reach any of these three tests.

### 8.6.3 Prompting Pi

```bash
pi "Implement build_parser and main in \
    src/mortgage_calculator_book/cli.py to make the \
    tests in tests/test_cli.py pass, wiring together \
    MortgageInput and calculate_validated_payment from \
    validation.py."
```

Once Pi's proposal is applied, confirm it actually earns green:

```bash
pytest tests/test_cli.py -v
```

### 8.6.4 Reviewing the Diff, and Comparing Notes

Same habit as every chapter since 1.6 — with one thing specific to this chapter worth checking closely: does the error-handling path actually write to `stderr`, not `stdout`? It's an easy detail for an agent (or a human) to get backwards, and `test_invalid_input_returns_error` above only catches it because it checks `captured.err` specifically rather than just checking that *some* output happened.

Worth doing once more, the same way as 7.6.4: compare Pi's version against the one you wrote by hand across 8.3 through 8.5, still in git history.

```bash
git log --oneline -- src/mortgage_calculator_book/cli.py
```

This shows every commit that touched this file — the hand-written version is the one from 8.5.4, right before the `git rm` commit from 8.6.1. Grab its hash and look at it:

```bash
git show <hash>:src/mortgage_calculator_book/cli.py
```

Once you're satisfied, commit Pi's version:

```bash
git add src/mortgage_calculator_book/cli.py tests/test_cli.py
git commit -m "Rebuild cli.py via agent-assisted TDD"
git push
```

## 8.7 Environment Variables and `.env`

### 8.7.1 Why Now, Not Chapter 11

Nothing in this chapter needs a secret. This section exists here anyway, deliberately early, so that the pattern is already familiar and already trusted by the time Chapter 11 actually needs it for a real API key — rather than introducing "environment variables" and "never commit a secret" for the first time in the same chapter you're handling money-costing API calls.

### 8.7.2 python-dotenv

```bash
uv add python-dotenv
```

Create `src/mortgage_calculator_book/config.py`:

```python
import os

from dotenv import load_dotenv

load_dotenv()

OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
```

`load_dotenv()` reads a `.env` file in your project root (if one exists) and makes its contents available via `os.getenv`. Nothing in this book's code reads `OPENROUTER_API_KEY` until Chapter 11 — this module exists now purely to establish the pattern.

### 8.7.3 Never Commit Your Secrets

Create `.env.example` (committed, safe — no real values):

```bash
vi .env.example
```

```
OPENROUTER_API_KEY=your-key-here
```

Then add one more line to `.gitignore` — the one 0.7.3 created back in Chapter 0, not a new file:

```bash
vi .gitignore
```

```
# Byte-compiled / cached Python files
__pycache__/
*.pyc
*.pyo

# Test and linter caches
.pytest_cache/
.ruff_cache/

# Virtual environments
.venv/
.env
```

Only that last line, `.env`, is actually new here — everything above it should already be sitting in the file from 0.7.3; this just confirms what you're adding to, rather than asking you to retype the whole thing from memory.

The rule this section wants you to leave with: `.env.example` is checked into git so anyone cloning the project knows what variables they need; `.env` itself, containing your actual key once you have one, never is. Confirm `.env` really is ignored before you ever put a real key in it:

```bash
git check-ignore .env
```

If this prints `.env`, git will refuse to accidentally stage it — a small, worthwhile check before it matters.

### 8.7.4 Forward-Note

Chapter 11 is where `OPENROUTER_API_KEY` actually gets used, wiring this project to a hosted language model. Everything here is preparation, not the payoff.

## 8.8 Writing the README

### 8.8.1 A Little More Markdown

You've already used headers and lists in `SPEC.md` (Chapter 2). A README additionally benefits from **code blocks** — text wrapped in triple backticks, as you've seen throughout this book's own command examples — and **links**, written as `[text](url)`. That's genuinely enough Markdown to write a good README; this isn't a full syntax reference.

### 8.8.2 What Belongs in It

- What the project is (a sentence or two — SPEC.md's opening paragraph is a good starting point)
- How to install and run it
- Example usage, with real output

### 8.8.3 A Draft

```markdown
# Mortgage Calculator

Calculates the fixed periodic payment for a fixed-rate mortgage.
See `SPEC.md` for the full specification.

## Setup

    uv sync

## Usage

    uv run mortgage-calculator-book \
        --principal 200000 --annual-rate 0.06 --term-years 30
    # Fixed periodic payment: $1,199.10

    uv run mortgage-calculator-book \
        --principal 200000 --annual-rate 0.06 --term-years 30 --format json
    # {"payment": 1199.1}
```

Write this now, not after the project is "finished" — there's no such moment in this book, and a README that only gets written at the end tends not to get written at all.

### 8.8.4 Letting Pi Draft It Instead

If you'd rather not write the README by hand, Pi can draft one from the project itself rather than from a blank page — point it at what actually exists, not just at the idea of a README:

```bash
pi "Draft README.md for this project. Read SPEC.md, \
    pyproject.toml, and src/mortgage_calculator_book/cli.py \
    first, and base the usage examples on the actual CLI \
    flags and command name you find there rather than \
    guessing at them."
```

Review it the same way as every other agent proposal, with one thing specific to documentation worth checking closely: does every command in it actually work, copy-pasted exactly as written? A README with a subtly wrong flag name or an invented example is worse than no README at all — it actively misleads the next person who trusts it, quite possibly you, in three weeks. Run each example yourself before accepting the diff. This is also where Pi is likeliest to invent a badge, a version number, or an installation step this project doesn't actually have; trim anything that describes a project slightly different from the one that exists.

> **Process concept: documentation as a living artifact.** This is the same spirit as `SPEC.md` from Chapter 2, aimed at a different reader: the spec is written for a collaborator (including Pi) who needs to know what the system should do; the README is written for a new user who just needs to know how to run it. Both get revised as the project changes — this README will need another pass once Chapter 9 adds a second way to run the calculator.

## 8.9 Refactor and Ruff Pass

```bash
ruff check . && ruff format .
```

Same habit as every prior chapter — nothing new here, which is itself a small sign the habit has taken hold.

Commit the README too — it's been sitting uncommitted since 8.8, the last real artifact this chapter produced:

```bash
git add README.md
git commit -m "Add README"
git push
```

## 8.10 Checkpoint

Before moving to Chapter 9, this should all be true:

- [ ] `pyproject.toml`'s `[project.scripts]` entry points at `mortgage_calculator_book.cli:main`, not the original placeholder
- [ ] `mortgage-calculator-book --principal ... --annual-rate ... --term-years ...` prints a correct, human-readable result
- [ ] `--format json` prints correctly structured JSON
- [ ] Invalid input produces a clear error message on `stderr` and a non-zero exit code
- [ ] `.env.example` is committed; `.env` is git-ignored and confirmed via `git check-ignore .env`
- [ ] `README.md` describes setup and usage with real, working examples, and is committed
- [ ] All CLI tests pass alongside every earlier chapter's tests
- [ ] `ruff check .` and `ruff format .` both pass

**What's next:** Chapter 9 builds a second front end — a graphical interface — calling this exact same validated core, proving the separation of concerns from Chapter 6 actually pays off.
