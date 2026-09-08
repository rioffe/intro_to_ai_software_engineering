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

Before touching mortgage math, try the cycle on something small enough to see the whole shape at once. This needs one tool you haven't installed yet — pytest, the test runner this book uses from here on. Section 5.3 covers it properly; for now, just get it installed so this example can actually run:

```bash
uv add --dev pytest
```

This adds `pytest` to the `dev` dependency group in `pyproject.toml` — alongside `ruff`, already there since Chapter 3.4.1:

```toml
[dependency-groups]
dev = [
    "ruff>=0.14.0",
    "pytest>=8.4.2",
]
```

(Your exact version numbers may differ.) This is the same mechanism `uv add requests` used back in 0.7.4, just landing in a group reserved for tools you use while developing rather than ones the calculator needs at runtime.

Create a `tests` directory and open a new file in it — this is a good first real use for the vi skills from 0.5:

```bash
mkdir tests
vi tests/test_scratch.py
```

Type in the following (`i` to start typing, `Esc` then `:wq` to save and exit):

```python
def test_add_returns_sum():
    from mortgage_calculator_book.scratch import add
    assert add(2, 3) == 5
```

Run it:

```bash
pytest tests/test_scratch.py -v
```

It fails — an import error, since `mortgage_calculator_book.scratch` doesn't exist yet, rather than a failed assertion, but a failure either way. That's **red**. Now create the missing piece the same way:

```bash
vi src/mortgage_calculator_book/scratch.py
```

```python
def add(a, b):
    return a + b
```

Run the test again:

```bash
pytest tests/test_scratch.py -v
```

**Green.** There's nothing to refactor yet, but the cycle is complete. Delete both scratch files once you've felt the shape of it — they're not part of the real project:

```bash
rm tests/test_scratch.py src/mortgage_calculator_book/scratch.py
```

## 5.3 pytest Basics

### 5.3.1 Installing

5.2.3 already had you install this, to make the tiny example runnable. If you skipped ahead and don't have it yet:

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
    """Answer key from docs/derivation.md: $200k/6%/30yr monthly."""
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
from mortgage_calculator_book.core import calculate_payment

def test_matches_worked_example(worked_example):
    payment = calculate_payment(
        principal=worked_example["principal"],
        annual_rate=worked_example["annual_rate"],
        term_years=worked_example["term_years"],
        payments_per_year=worked_example["payments_per_year"],
    )
    assert payment == pytest.approx(
        worked_example["expected_payment"], abs=0.01
    )
```

Note `pytest.approx(..., abs=0.01)` rather than a plain `==`. Chapter 4.5 computed the exact payment as `1199.1010503...` before rounding — comparing floating-point results with plain equality is a reliable way to get bitten by a rounding difference in the fifteenth decimal place that has nothing to do with whether your code is actually correct. `abs=0.01` means "correct to the cent," which is the precision that actually matters for currency here. You don't need `import pytest` twice — add it to the top of the file alongside the `calculate_payment` import.

### 5.5.2 Running It — and Watching It Fail

```bash
pytest tests/test_core.py -v
```

This fails immediately, with an import error: `mortgage_calculator_book.core` doesn't exist yet. **This is the "red" in red/green/refactor, made concrete.** You haven't done anything wrong.

### 5.5.3 Why a Failing Test Is a Milestone

It's worth pausing on this rather than rushing past it: you now have a precise, automatic, unambiguous definition of what Chapter 6 needs to build. Not "make a mortgage calculator" in the abstract — make this exact test pass. That's a meaningfully smaller, clearer target than the one you started the book with.

## 5.6 Agent-Assisted TDD: Letting Pi Draft Test Skeletons

### 5.6.1 Prompting from the Spec

```bash
pi "Read SPEC.md and propose additional pytest test \
    cases for calculate_payment, beyond the worked \
    example already in tests/test_core.py. Don't \
    implement calculate_payment itself — just propose \
    the test functions."
```

### 5.6.2 Reviewing What It Proposes

Read every proposed test with two questions in mind: does it test *behavior* described in SPEC.md, or does it quietly test some *implementation detail* that hasn't been decided yet? And does its expected value actually follow from the formula in Chapter 4.4, or is it a plausible-looking number Pi generated without truly computing it? A test with a wrong expected value is worse than no test at all — it will pass or fail for the wrong reasons, and it'll sit there looking trustworthy until something forces you to check it by hand.

### 5.6.3 Accepting, Correcting, or Rejecting Each One

Treat this the same way you've treated every other agent proposal so far: some of what Pi suggests will be worth keeping as-is, some will need a corrected expected value, and some won't belong in this test file at all. All three outcomes are normal.

> **Process concept: tests as the executable proof of the spec, not a restatement of it.** A test that just re-describes SPEC.md in code form ("test that calculate_payment exists and returns a number") isn't pulling its weight. A good test asserts something specific enough that it could actually fail in a way that teaches you something — which is exactly what section 5.5's worked-example test does, and what you should be checking Pi's proposals against.

### 5.6.4 What a Larger Model Actually Produced

The 5.6.1 prompt against a larger model — qwen3.8:27b-mlx, from Chapter 1.4.2 — can produce something considerably more ambitious than a handful of test skeletons: nine cases plus three explicit "I won't guess at this, decide first" questions about behavior SPEC.md doesn't define (what should happen at `term_years = 0`? should negative principal raise or just compute?). That last part is worth calling out on its own — flagging an undecided contract instead of quietly assuming one is exactly the discipline this book has been asking *you* to practice, showing up unprompted in the agent's own output.

Some of the proposed cases are genuinely strong, and worth knowing about even though this book's test suite stays simpler: a **present-value round-trip** check — that discounting every payment back at the periodic rate recovers the original principal, which is SPEC.md's own definition of "correct" turned into a test that doesn't depend on the implementer's formula at all — plus **linearity** (doubling the principal should exactly double the payment) and **monotonicity** (a longer term should always lower the payment; a higher rate should always raise it). These are called *property tests*: instead of asserting one hand-computed number, they assert a relationship that has to hold regardless of how the formula is written. That's a real technique, worth filing away even if this book doesn't build a full property-based suite around it.

One proposed case uses a pytest feature this book hasn't shown yet — **parametrize** — and it's worth pausing on the syntax before getting to what went wrong with it. Rather than write four nearly-identical test functions (one each for annual, quarterly, biweekly, and weekly payments), `@pytest.mark.parametrize` lets you write the test body *once* and run it several times, once per row of a table you supply. The decorator's first argument is a string naming the values that change from run to run; the second is a list of tuples supplying those values, one tuple per run. Pytest calls the test function once per tuple, passing each value in by name — which means the function's own parameter list has to actually include those names, or pytest has nowhere to put them. Here, `ppy` is short for "payments per year" — matching the `payments_per_year` argument `calculate_payment` itself expects — and `expected` is the payment each row claims is correct:

```python
@pytest.mark.parametrize("ppy,expected", [
    (1,  212_000.0),
    (4,  3603.70),
    (26, 553.17),
    (52, 594.74),
])
def test_non_monthly_frequencies(
    principal=200_000, annual_rate=0.06, term_years=30
):
    payment = calculate_payment(
        principal=principal, annual_rate=annual_rate,
        term_years=term_years, payments_per_year=ppy,
    )
    assert payment == pytest.approx(expected, abs=0.01)
```

Try running this exactly as given, and it doesn't get anywhere near checking any numbers — pytest refuses to even collect it:

```
ERROR test_core.py::test_non_monthly_frequencies:
function uses no argument 'ppy'
```

Look at the function signature and the reason is right there: `test_non_monthly_frequencies` takes `principal`, `annual_rate`, and `term_years` — but never `ppy` or `expected`, the two names the parametrize table is trying to hand it. Pytest has values to inject and nowhere to put them. That's the first, easiest thing to catch here — a beginner doesn't need to verify a single number by hand to notice the whole test won't even run. The fix is mechanical: add the missing names to the signature.

```python
def test_non_monthly_frequencies(
    ppy, expected, principal=200_000, annual_rate=0.06, term_years=30
):
```

Fix that, and the test is at least *runnable* — though not yet, in this project specifically: `calculate_payment` doesn't exist until Chapter 6, so right now this would fail with the same import error every other test in this chapter fails with, not a clean pass/fail split. The two-pass-two-fail result below is what you'd see *after* Chapter 6's implementation exists — worth keeping straight so you're not confused when trying this today gets you an import error instead. Once that implementation exists, though, it's genuinely informative: two rows pass, two fail. `ppy=4` and `ppy=26` check out. `ppy=1` and `ppy=52` don't, and it's worth working out why by hand — the same way 4.6 asked you to check Pi's arithmetic — rather than assuming the numbers are simply wrong. At `ppy=1`, `calculate_payment` actually returns about **$14,529.78**, not the $212,000 the table claims. But $212,000 isn't a made-up number — it's exactly what a *single* payment after one year on this loan would be (the $200,000 growing by 6% interest, paid off in one shot), a completely different scenario from the one this row's actual parameters describe (30 *annual* payments, not 1). Same story at `ppy=52`: the real result is about **$276.53**, while $594.74 is the correct weekly payment for a $30,000 loan over one year — again a genuine number, just answering a different question than the one this test's fixed `principal=200_000, term_years=30` actually poses.

Both wrong rows are individually correct arithmetic, attached to the wrong problem. That's a harder mistake to catch than a plain miscalculation, because nothing about $212,000 or $594.74 looks unreasonable in isolation — it only falls apart once you check each row against the *specific* inputs that row is actually parametrized to use, which is exactly why 5.6.2 asked you to verify expected values rather than skim them for plausibility. Two layers of review, in other words: does it even run, and only then, does it compute the right thing.

Pointing this out and asking Pi to take another pass — the normal next step, not a special one — produced a version worth looking at, because the fix isn't just "corrected numbers":

```python
@pytest.mark.parametrize(
    "principal, annual_rate, term_years, payments_per_year, expected",
    [
        (200_000, 0.06, 30,  1, 14_529.78),  # annual
        (200_000, 0.06, 30,  4,  3_603.70),  # quarterly
        (200_000, 0.06, 30, 12,  1_199.10),  # monthly (== worked example)
        (200_000, 0.06, 30, 26,    553.17),  # biweekly
        (200_000, 0.06, 30, 52,    276.53),  # weekly
    ],
)
def test_non_monthly_frequencies(
    principal, annual_rate, term_years, payments_per_year, expected
):
    payment = calculate_payment(
        principal=principal, annual_rate=annual_rate,
        term_years=term_years, payments_per_year=payments_per_year,
    )
    assert payment == pytest.approx(expected, abs=0.01)
```

This runs and all five rows pass — verify that independently, the same way as everything else in this section, rather than taking a second round of Pi's output any more on faith than the first. But notice *what* changed, not just that the numbers are now right: every row now carries its own `principal`, `annual_rate`, and `term_years` explicitly, instead of leaving three of the four inputs as fixed defaults in the function signature and only varying `payments_per_year` per row. That's not a cosmetic difference — it's what actually made the original bug possible in the first place. When only `ppy` varied per row, a row's expected value could quietly describe a *different* principal or term than the one the test would actually run with, and nothing about the test's structure would catch it. With every input explicit in the same row as its answer, that entire class of mistake has nowhere left to hide — a row is either internally consistent or it visibly isn't, without needing to cross-reference a default hiding three lines up. It also picked up a nice detail worth noticing on your own next time: the `payments_per_year=12` row's expected value is `1_199.10` — the exact Chapter 4.5 worked example, now sitting inside this table as a built-in cross-check against a number you already trust.

None of this means the larger model did badly — quite the opposite; the property tests and the "flag it, don't guess" section are better instincts than a lot of hand-written test suites manage. It means review scales with ambition: the more a model gives you, the more of it actually needs checking, not less.

## 5.7 Debugger Basics: pdb

### 5.7.1 When to Reach for It

Once Chapter 6 exists and something eventually fails in a way that isn't obvious from the error message alone, the instinct to immediately ask Pi to fix it is worth resisting, at least briefly. Finding your own bugs first — even occasionally, even just to practice — builds exactly the judgment you'll need to properly review Pi's fixes later. If you can't tell whether a fix actually addresses the bug, you're not really reviewing it.

### 5.7.2 Trying It, On Something That Actually Exists

Everything else in this chapter is either already correct (the worked-example fixture) or deliberately red because `calculate_payment` doesn't exist yet — that's Chapter 6's job, not a bug to step through. Neither gives you a real failure to investigate *right now*. So build one, small and throwaway, the same way 5.2.3 did.

```bash
vi tests/test_scratch_debug.py
```

```python
from mortgage_calculator_book.scratch_debug import total_paid

def test_total_paid_sums_all_payments():
    assert total_paid([100, 200, 300]) == 600
```

```bash
vi src/mortgage_calculator_book/scratch_debug.py
```

```python
def total_paid(payments):
    """Sum a list of periodic payments."""
    total = 0
    for amount in payments:
        total = amount
    return total
```

Run it:

```bash
pytest tests/test_scratch_debug.py -v
```

It fails: `assert 300 == 600`. That tells you *that* something's wrong, not *why*. Rather than stare at four lines until it jumps out — it will eventually, but that's not the point of this exercise — drop a breakpoint into the loop and watch it happen:

```python
def total_paid(payments):
    total = 0
    for amount in payments:
        breakpoint()
        total = amount
    return total
```

Run the test again. Execution pauses the first time the loop body runs, before that line executes. Print both variables (`p total` → `0`, `p amount` → `100`), then step past the assignment (`n`) and print `total` again — it's `100`, matching `amount`, which is expected after the first payment. Continue to the next iteration (`c`); you're back at the same breakpoint, `amount` now `200`, `total` still `100` from before. Step past the assignment again (`n`) and print `total` once more: it's `200` — not `300`, which is what `100 + 200` would give you if the loop were accumulating. That's the bug, watched directly rather than guessed at: `total = amount` should be `total += amount`.

Fix it, delete the `breakpoint()` line, and confirm:

```bash
pytest tests/test_scratch_debug.py -v
```

Green. Delete both scratch files — not part of the real project, same as 5.2.3's:

```bash
rm tests/test_scratch_debug.py \
   src/mortgage_calculator_book/scratch_debug.py
```

For reference, the commands you just used:

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

Same collection error as 5.5.2, not three separate failures — `mortgage_calculator_book.core` still doesn't exist, so pytest can't even import the file to reach any of the three tests inside it, worked example and both edge cases alike:

```
ERROR tests/test_core.py
ModuleNotFoundError: No module named 'mortgage_calculator_book.core'
```

That's still exactly the state Chapter 6 needs to find this project in — one missing module standing between here and green, not three separate bugs to chase. You'll see three individually reported passes once Chapter 6 exists; right now, before any implementation exists at all, one honest collection error covering all three is the correct red, not a sign something's already wrong.

This red suite is worth committing — it's a real, intentional artifact of this project, not a mistake to hide:

```bash
git add .
git commit -m "Add pytest and a red test suite for calculate_payment"
git push
```

## 5.9 Checkpoint

Before moving to Chapter 6, this should all be true:

- [ ] pytest is installed as a dev dependency, and `pyproject.toml` shows it under `[dependency-groups]`
- [ ] `tests/conftest.py` defines the `worked_example` fixture
- [ ] `tests/test_core.py` contains three tests: the worked example, zero-interest, and single-payment — all currently red via one collection error, since `core.py` doesn't exist yet
- [ ] You can explain why each test's expected value is correct, independent of any code
- [ ] `ruff check .` and `ruff format .` both pass on the test files
- [ ] You've used `breakpoint()` at least once, even in the scratch example
- [ ] The red suite is committed and pushed — not just sitting locally

**What's next:** Chapter 6 makes these three tests go green — the first real implementation this project has had.
