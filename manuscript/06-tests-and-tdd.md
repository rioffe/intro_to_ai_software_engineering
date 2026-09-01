# Chapter 5 — Tests & Test-Driven Development

## 5.1 Why This Chapter Exists

Chapter 4 gave you an answer key on paper: a formula, a derivation, and one specific scenario with an exact expected answer. This chapter turns that paper answer key into something a computer can check automatically, every time, without you re-doing the arithmetic by hand.

By the end of this chapter, pytest will be installed, your test suite will have a real structure, and the Chapter 4.5 worked example will exist as an actual test function — one that currently **fails**, because there's no core library yet to run it against. That failure is the goal, not a mistake. Chapter 6 exists to turn it green.

## 5.2 What TDD Actually Is

### 5.2.1 Red, Green, Refactor

Test-driven development follows a three-step cycle, repeated over and over:

1. **Red** — write a test for something that doesn't exist yet. Run it. Watch it fail.
2. **Green** — write the smallest amount of code that makes the test pass.
3. **Refactor** — clean up what you just wrote, now that you have a passing test protecting you from breaking it by accident.

Then repeat, for the next small piece of behavior.

### 5.2.2 Why Write the Test First

This feels backwards the first time you do it — how can you test something that doesn't exist? But writing the test first forces you to answer a question you'd otherwise skip past: *what, exactly, does "working" mean here, before I've built anything and started rationalizing whatever I happened to build?* A test written after the code tends to describe what the code does. A test written before the code describes what the code is *supposed* to do — a small but real difference, and one that matters more, not less, once an agent might be the one writing the implementation.

### 5.2.3 A Tiny Example First

Before touching mortgage math, try the cycle on something small enough to see the whole shape at once. Create `tests/test_scratch.py`:

```python
def test_add_returns_sum():
    from mortgage_calculator.scratch import add
    assert add(2, 3) == 5
```

Run it — it fails, because `mortgage_calculator.scratch` doesn't exist. That's **red**. Now create `src/mortgage_calculator/scratch.py`:

```python
def add(a, b):
    return a + b
```

Run the test again — **green**. There's nothing to refactor yet, but the cycle is complete. Delete this scratch file once you've felt the shape of it; it's not part of the real project.

## 5.3 pytest Basics

### 5.3.1 Installing

```bash
uv add --dev pytest
```

### 5.3.2 Test Discovery

pytest finds tests automatically, following a convention rather than an explicit list: files named `test_*.py` (or `*_test.py`), inside functions named `test_*`. This is why the scratch example above worked without registering it anywhere — pytest went looking for exactly that pattern.

### 5.3.3 Assertions

pytest uses Python's plain `assert` statement — no special assertion methods to memorize. When an assertion fails, pytest rewrites the failure output to show you both sides of the comparison, which is more useful than it sounds the first time you see a failing test explain itself clearly.

### 5.3.4 Running the Suite

```bash
pytest              # run everything
pytest -v           # verbose — show each test by name
pytest tests/test_core.py       # run one file
pytest tests/test_core.py::test_matches_worked_example   # run one test
```

## 5.4 Fixtures, Just Enough

### 5.4.1 The Problem They Solve

Several tests in this chapter need the same data — the Chapter 4.5 worked example's principal, rate, term, and expected payment. Repeating those numbers in every test function invites the numbers to quietly drift apart from each other over time. A **fixture** is pytest's answer: shared setup, defined once, requested by any test that needs it.

### 5.4.2 The Worked Example as a Fixture

Create `tests/conftest.py`:

```python
import pytest

@pytest.fixture
def worked_example():
    """The Chapter 4.5 answer key: $200,000 / 6% / 30yr monthly."""
    return {
        "principal": 200_000,
        "annual_rate": 0.06,
        "term_years": 30,
        "payments_per_year": 12,
        "expected_payment": 1199.10,
    }
```

Any test function that takes `worked_example` as a parameter automatically receives this dictionary — pytest matches it by name, no import needed.

### 5.4.3 Scope-Setting

pytest's fixture system goes considerably further than this — different scopes, fixtures that depend on other fixtures, fixtures shared across an entire test session. This book uses exactly the pattern above and nothing more; if you want the fuller picture later, pytest's own documentation is thorough and well-written.

## 5.5 Encoding the Answer Key as a Test

### 5.5.1 Translating the Worked Example

Create `tests/test_core.py`:

```python
from mortgage_calculator.core import calculate_payment

def test_matches_worked_example(worked_example):
    payment = calculate_payment(
        principal=worked_example["principal"],
        annual_rate=worked_example["annual_rate"],
        term_years=worked_example["term_years"],
        payments_per_year=worked_example["payments_per_year"],
    )
    assert payment == pytest.approx(worked_example["expected_payment"], abs=0.01)
```

Note `pytest.approx(..., abs=0.01)` rather than a plain `==`. Chapter 4.5 computed the exact payment as `1199.1010503...` before rounding — comparing floating-point results with plain equality is a reliable way to get bitten by a rounding difference in the fifteenth decimal place that has nothing to do with whether your code is actually correct. `abs=0.01` means "correct to the cent," which is the precision that actually matters for currency here. You don't need `import pytest` twice — add it to the top of the file alongside the `calculate_payment` import.

### 5.5.2 Running It — and Watching It Fail

```bash
pytest tests/test_core.py -v
```

This fails immediately, with an import error: `mortgage_calculator.core` doesn't exist yet. **This is the "red" in red/green/refactor, made concrete.** You haven't done anything wrong.

### 5.5.3 Why a Failing Test Is a Milestone

It's worth pausing on this rather than rushing past it: you now have a precise, automatic, unambiguous definition of what Chapter 6 needs to build. Not "make a mortgage calculator" in the abstract — make this exact test pass. That's a meaningfully smaller, clearer target than the one you started the book with.

## 5.6 Agent-Assisted TDD: Letting Pi Draft Test Skeletons

### 5.6.1 Prompting from the Spec

```bash
pi "Read SPEC.md and propose additional pytest test cases" \
   "for calculate_payment, beyond the worked example already" \
   "in tests/test_core.py. Don't implement calculate_payment" \
   "itself — just propose the test functions."
```

### 5.6.2 Reviewing What It Proposes

Read every proposed test with two questions in mind: does it test *behavior* described in SPEC.md, or does it quietly test some *implementation detail* that hasn't been decided yet? And does its expected value actually follow from the formula in Chapter 4.4, or is it a plausible-looking number Pi generated without truly computing it? A test with a wrong expected value is worse than no test at all — it will pass or fail for the wrong reasons, and it'll sit there looking trustworthy until something forces you to check it by hand.

### 5.6.3 Accepting, Correcting, or Rejecting Each One

Treat this the same way you've treated every other agent proposal so far: some of what Pi suggests will be worth keeping as-is, some will need a corrected expected value, and some won't belong in this test file at all. All three outcomes are normal.

> **Process concept: tests as the executable proof of the spec, not a restatement of it.** A test that just re-describes SPEC.md in code form ("test that calculate_payment exists and returns a number") isn't pulling its weight. A good test asserts something specific enough that it could actually fail in a way that teaches you something — which is exactly what section 5.5's worked-example test does, and what you should be checking Pi's proposals against.

## 5.7 Debugger Basics: pdb

### 5.7.1 When to Reach for It

Once Chapter 6 exists and something eventually fails in a way that isn't obvious from the error message alone, the instinct to immediately ask Pi to fix it is worth resisting, at least briefly. Finding your own bugs first — even occasionally, even just to practice — builds exactly the judgment you'll need to properly review Pi's fixes later. If you can't tell whether a fix actually addresses the bug, you're not really reviewing it.

### 5.7.2 The Basics

Drop a breakpoint directly into code you're investigating:

```python
def calculate_payment(principal, annual_rate, term_years, payments_per_year=12):
    breakpoint()
    ...
```

Run the test that exercises it, and execution will pause at that line, dropping you into an interactive prompt. From there:

```
n        step to the next line
s        step into a function call
c        continue running until the next breakpoint (or the end)
p some_variable   print a variable's current value
```

### 5.7.3 Why This Is Worth a Page

This isn't meant to make you a debugging expert — a page of practice won't do that. It's meant to give you one more tool between "the test failed" and "ask the agent to fix it," so that when you do read Pi's proposed fix later, you're reading it as someone who at least attempted to understand the failure themselves, not as someone encountering the bug for the first time via someone else's patch.

## 5.8 Edge Cases Worth Testing Now

### 5.8.1 The Two Cases from Chapter 4.4.3

Add these to `tests/test_core.py`, even though `calculate_payment` doesn't exist yet:

```python
def test_zero_interest_loan():
    payment = calculate_payment(
        principal=12_000,
        annual_rate=0.0,
        term_years=1,
        payments_per_year=12,
    )
    assert payment == pytest.approx(1000.00, abs=0.01)


def test_single_payment():
    payment = calculate_payment(
        principal=10_000,
        annual_rate=0.06,
        term_years=1,
        payments_per_year=1,
    )
    assert payment == pytest.approx(10600.00, abs=0.01)
```

Both use the exact numbers from Chapter 4.5's edge-case discussion — chosen there specifically because they're clean enough to verify by hand ($12,000 ÷ 12 = $1,000; $10,000 × 1.06 = $10,600).

### 5.8.2 Planting Red Tests on Purpose

Run the full suite now:

```bash
pytest -v
```

Three failing tests, all for the same reason: no core library yet. That's exactly the state Chapter 6 needs to find this project in.

## 5.9 Checkpoint

Before moving to Chapter 6, this should all be true:

- [ ] pytest is installed as a dev dependency
- [ ] `tests/conftest.py` defines the `worked_example` fixture
- [ ] `tests/test_core.py` contains three tests: the worked example, zero-interest, and single-payment — all currently failing
- [ ] You can explain why each test's expected value is correct, independent of any code
- [ ] `ruff check .` and `ruff format .` both pass on the test files
- [ ] You've used `breakpoint()` at least once, even in the scratch example

**What's next:** Chapter 6 makes these three tests go green — the first real implementation this project has had.
