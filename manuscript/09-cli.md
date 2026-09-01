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
mortgage-calculator --principal 200000 --annual-rate 0.06 --term-years 30
# Fixed periodic payment: $1,199.10
```

And with an invalid input:

```bash
mortgage-calculator --principal -1000 --annual-rate 0.06 --term-years 30
# Error: principal must be positive
```

Having this shape settled before writing `argparse` code turns the implementation into a matter of matching a known target, the same discipline Chapter 5 established for the core library.

## 8.3 argparse Basics

### 8.3.1 Why argparse

`argparse` ships with Python — no new dependency, no version to track, and it's more than capable of everything this project needs. Typer and similar libraries offer a nicer developer experience at the cost of an added dependency; for a first CLI, that trade isn't worth making yet.

### 8.3.2 Arguments, Types, Defaults, Help Text

```python
import argparse

parser = argparse.ArgumentParser(description="Calculate a fixed mortgage payment.")
parser.add_argument("--principal", type=float, required=True,
                    help="Loan amount, in dollars")
parser.add_argument("--annual-rate", type=float, required=True,
                    help="Annual rate, e.g. 0.06 for 6%")
```

`type=float` means argparse converts the string a user typed before your code ever sees it — `"200000"` arrives as `200000.0`, not a string you'd have to convert yourself. `required=True` means argparse handles the "you forgot an argument" error entirely on its own, with no code from you.

### 8.3.3 A Minimal Working Parser

In `src/mortgage_calculator/cli.py`:

```python
import argparse


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Calculate the fixed periodic payment for a fixed-rate mortgage."
    )
    parser.add_argument("--principal", type=float, required=True,
                        help="Loan amount, in dollars")
    parser.add_argument(
        "--annual-rate", type=float, required=True, 
        help="Annual interest rate, e.g. 0.06 for 6%"
    )
    parser.add_argument("--term-years", type=int, required=True,
                        help="Loan term, in years")
    parser.add_argument(
        "--payments-per-year", type=int, default=12,
        help="Payments per year (default: 12)"
    )
    parser.add_argument(
        "--format", choices=["text", "json"], default="text", help="Output format"
    )
    return parser
```

### 8.3.4 Aside: Typer

Typer builds on Python type hints to generate a CLI with less boilerplate than `argparse`, and produces friendlier help text by default. It's a reasonable choice for a larger project. This book sticks with `argparse` specifically to avoid a dependency the project doesn't strictly need — worth knowing Typer exists for whenever a future project's CLI grows complex enough to justify it.

## 8.4 Wiring the CLI to Validation and the Core

### 8.4.1 The Full Pipeline, Assembled

```python
import sys

from pydantic import ValidationError

from mortgage_calculator.validation import MortgageInput, calculate_validated_payment


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

Parsed arguments flow into `MortgageInput` (Chapter 7), which flows into `calculate_validated_payment` (also Chapter 7, which itself calls Chapter 6's `calculate_payment`) — three chapters of work, connected for the first time.

### 8.4.2 Handling Validation Failure Gracefully

Notice what the `except ValidationError` block does *not* do: it doesn't let Pydantic's default error formatting — which is detailed, but written for developers, not end users — reach the terminal directly. It extracts just the message from each error and prints it the way a person asked to fix their input actually wants to read it. Try it with `--principal -1000` and compare the output to what you'd get without this handling (temporarily remove the `try`/`except` to see the difference, then put it back).

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

## 8.6 Agent-Assisted Build, With Tests First

### 8.6.1 CLI-Level Tests

In `tests/test_cli.py`:

```python
import json

import pytest

from mortgage_calculator.cli import main


def test_text_output(capsys):
    exit_code = main([
            "--principal", "200000",
            "--annual-rate", "0.06",
            "--term-years", "30"
        ])
    captured = capsys.readouterr()
    assert exit_code == 0
    assert "1,199.10" in captured.out


def test_json_output(capsys):
    exit_code = main([
            "--principal", "200000",
            "--annual-rate", "0.06",
            "--term-years", "30",
            "--format", "json",
        ])
    captured = capsys.readouterr()
    assert exit_code == 0
    data = json.loads(captured.out)
    assert data["payment"] == pytest.approx(1199.10, abs=0.01)


def test_invalid_input_returns_error(capsys):
    exit_code = main([
            "--principal", "-1000",
            "--annual-rate", "0.06",
            "--term-years", "30"
        ])
    captured = capsys.readouterr()
    assert exit_code == 1
    assert "Error" in captured.err
```

`capsys` is a built-in pytest fixture — following the same fixture mechanism from Chapter 5.4, just one pytest already provides — that captures anything printed during a test, so you can assert on it without the output actually appearing in your terminal.

### 8.6.2 Prompting Pi

```bash
pi "Implement build_parser and main in src/mortgage_calculator/cli.py" \
   "to make the tests in tests/test_cli.py pass, wiring together" \
   "MortgageInput and calculate_validated_payment from validation.py."
```

### 8.6.3 Reviewing the Diff

Same habit as every chapter since 1.6 — with one thing specific to this chapter worth checking closely: does the error-handling path actually write to `stderr`, not `stdout`? It's an easy detail for an agent (or a human) to get backwards, and `test_invalid_input_returns_error` above only catches it because it checks `captured.err` specifically rather than just checking that *some* output happened.

## 8.7 Environment Variables and `.env`

### 8.7.1 Why Now, Not Chapter 11

Nothing in this chapter needs a secret. This section exists here anyway, deliberately early, so that the pattern is already familiar and already trusted by the time Chapter 11 actually needs it for a real API key — rather than introducing "environment variables" and "never commit a secret" for the first time in the same chapter you're handling money-costing API calls.

### 8.7.2 python-dotenv

```bash
uv add python-dotenv
```

Create `src/mortgage_calculator/config.py`:

```python
import os

from dotenv import load_dotenv

load_dotenv()

OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
```

`load_dotenv()` reads a `.env` file in your project root (if one exists) and makes its contents available via `os.getenv`. Nothing in this book's code reads `OPENROUTER_API_KEY` until Chapter 11 — this module exists now purely to establish the pattern.

### 8.7.3 Never Commit Your Secrets

Create `.env.example` (committed, safe — no real values) and add `.env` itself to `.gitignore`:

```
# .env.example
OPENROUTER_API_KEY=your-key-here
```

```
# .gitignore (add this line)
.env
```

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

    uv run mortgage-calculator --principal 200000 \
           --annual-rate 0.06 --term-years 30
    # Fixed periodic payment: $1,199.10

    uv run mortgage-calculator --principal 200000 \
           --annual-rate 0.06 --term-years 30 --format json
    # {"payment": 1199.1}
```

Write this now, not after the project is "finished" — there's no such moment in this book, and a README that only gets written at the end tends not to get written at all.

> **Process concept: documentation as a living artifact.** This is the same spirit as `SPEC.md` from Chapter 2, aimed at a different reader: the spec is written for a collaborator (including Pi) who needs to know what the system should do; the README is written for a new user who just needs to know how to run it. Both get revised as the project changes — this README will need another pass once Chapter 9 adds a second way to run the calculator.

## 8.9 Refactor and Ruff Pass

```bash
ruff check . && ruff format .
```

## 8.10 Checkpoint

Before moving to Chapter 9, this should all be true:

- [ ] `mortgage-calculator --principal ... --annual-rate ... --term-years ...` prints a correct, human-readable result
- [ ] `--format json` prints correctly structured JSON
- [ ] Invalid input produces a clear error message on `stderr` and a non-zero exit code
- [ ] `.env.example` is committed; `.env` is git-ignored and confirmed via `git check-ignore .env`
- [ ] `README.md` describes setup and usage with real, working examples
- [ ] All CLI tests pass alongside every earlier chapter's tests
- [ ] `ruff check .` and `ruff format .` both pass

**What's next:** Chapter 9 builds a second front end — a graphical interface — calling this exact same validated core, proving the separation of concerns from Chapter 6 actually pays off.
