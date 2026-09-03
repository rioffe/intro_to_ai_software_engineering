# Chapter 6 — Mathematical Core Library

## 6.1 Why This Chapter Exists

Chapter 5 left you with three failing tests and a precise target: make them pass, using the formula derived in Chapter 4.4. This chapter does exactly that — the first real implementation this project has had, and the first real payoff of the red/green/refactor cycle set up in Chapter 5.

By the end, all three tests from Chapter 5 will be green, and you'll have a small, pure module that every later front end — CLI, UI, and eventually a language model — calls into without ever duplicating this logic.

## 6.2 What "Pure" Means, and Why It's the Rule Here

### 6.2.1 Pure Functions

A function is **pure** if it does one thing: given the same inputs, it always returns the same output, with no side effects — no printing, no reading files, no reaching out to a network, no depending on anything outside its own arguments. `calculate_payment(200_000, 0.06, 30, 12)` should return the same number every single time it's called, forever, with nothing else going on.

### 6.2.2 The Rule for This Module

Everything in `mortgage_calculator_book.core` follows this rule, with no exceptions. No `print()` statements for debugging left behind, no reading configuration, no formatting output for a human to read — that's the CLI's job in Chapter 8 and the UI's job in Chapter 9, not this module's.

> **Process concept: why purity matters more, not less, with an agent in the loop.** A pure function is a narrow, easily verified contract: given these inputs, this exact output. That's precisely the kind of task an agent can be checked against cheaply and completely — run the function, compare the result, done. The moment a function reaches out to the filesystem, the network, or global state, verifying an agent's implementation of it becomes considerably harder, because "correct" now depends on things outside the function's own signature. Keeping the core pure isn't just good architecture in the abstract — it's what makes Chapter 6.5's agent-assisted implementation actually checkable.

## 6.3 Module Layout

### 6.3.1 Where This Lives

Inside the `src/mortgage_calculator_book/` package from Chapter 0.7.3, create `core.py`. This is the only file this chapter touches.

### 6.3.2 Naming Things to Match the Spec

Function names in this module should read as a direct translation of `SPEC.md`'s "Derived quantities" and "Outputs" sections from Chapter 4.7.3 — not because it's required, but because it means anyone (or anything) reading the spec and the code side by side can match them up on sight.

## 6.4 Implementing the Periodic Rate and Payment-Count Helpers

### 6.4.1 Annual Rate to Periodic Rate

The conversion flagged repeatedly since Chapter 4.3.2, as its own small, independently testable function:

```python
def annual_rate_to_periodic(annual_rate: float, payments_per_year: int) -> float:
    """Convert an annual interest rate to the rate for a single period."""
    return annual_rate / payments_per_year
```

### 6.4.2 Term and Frequency to Total Payments

```python
def total_payments(term_years: int, payments_per_year: int) -> int:
    """Total number of payments over the life of the loan."""
    return term_years * payments_per_year
```

Both are one-liners, and that's fine — the point of separating them out isn't complexity, it's giving each conversion a name and a place where a mistake in either one is easy to isolate and test on its own, rather than buried inside a larger formula.

### 6.4.3 Watching the Suite

These two helpers don't make any of Chapter 5's three tests pass on their own — `calculate_payment` still doesn't exist. Run `pytest -v` anyway, out of habit; still red, as expected.

## 6.5 Implementing the Fixed Payment Formula

### 6.5.1 Code That Mirrors the Math

Translated directly from Chapter 4.4.1, term for term:

```python
def calculate_payment(
    principal: float,
    annual_rate: float,
    term_years: int,
    payments_per_year: int = 12,
) -> float:
    """Fixed periodic payment for a fixed-rate loan (see SPEC.md)."""
    r = annual_rate_to_periodic(annual_rate, payments_per_year)
    n = total_payments(term_years, payments_per_year)

    if r == 0:
        return principal / n

    return principal * (r * (1 + r) ** n) / ((1 + r) ** n - 1)
```

Notice how closely this reads against the formula: `r * (1 + r) ** n` in the numerator, `(1 + r) ** n - 1` in the denominator — the same shape as $\dfrac{r(1+r)^n}{(1+r)^n-1}$ from 4.4.1, not an optimized or rearranged version of it. Clarity against the derivation matters more here than performance; this function will never be a bottleneck in this project.

### 6.5.2 Agent-Assisted Implementation

If you'd rather have Pi draft this rather than typing it yourself:

```bash
pi "Implement calculate_payment in \
    src/mortgage_calculator_book/core.py to make the \
    tests in tests/test_core.py pass. The formula is in \
    docs/derivation.md; SPEC.md defines what counts as \
    correct output, not how to compute it. Keep the \
    function pure — no I/O, no printing."
```

### 6.5.3 Reviewing Before Accepting

Whether you wrote it or Pi did, check specifically for the mistakes this formula invites:

- **Rate conversion**: does it use the *periodic* rate inside the exponentiation, not the raw annual rate?
- **Off-by-one in payment count**: is `n` computed as `term_years * payments_per_year`, not something shifted by one?
- **Silent float issues**: is there an unguarded division that could produce `inf` or a `ZeroDivisionError` for some input this module hasn't been asked to validate yet? (Chapter 7 handles rejecting bad input; this module just needs to not silently misbehave on the inputs it's given.)

## 6.6 Handling the Named Edge Cases

### 6.6.1 Zero-Interest Loans

The `if r == 0` branch above exists for exactly the reason 4.4.3 described: the general formula divides by `r`, which is undefined at zero, even though the real-world answer (`principal / n`) is completely well-defined. Run the zero-interest test:

```bash
pytest tests/test_core.py::test_zero_interest_loan -v
```

### 6.6.2 Single-Payment Terms

Unlike the zero-interest case, this one needs **no special branch** — as 4.4.3 noted, substituting $n=1$ into the general formula produces the same answer as the direct "principal plus one period's interest" reasoning. Run it to confirm:

```bash
pytest tests/test_core.py::test_single_payment -v
```

If this test fails, it's worth checking your formula's algebra against 4.4.1 line by line before adding a special case you don't actually need — a passing test achieved by adding an unnecessary branch is a sign something upstream is subtly wrong, not a problem solved.

### 6.6.3 Confirming Both Are Genuinely Fixed

Run the full suite:

```bash
pytest -v
```

If you see three passes here rather than three failures, double-check that you're reading real green — not a test that was quietly weakened (a loosened `abs=` tolerance, a rewritten expected value) to make a stubborn failure go away. That's the opposite of what this chapter is for.

## 6.7 Verifying Against the Answer Key

### 6.7.1 The Worked Example

```bash
pytest tests/test_core.py::test_matches_worked_example -v
```

This should now pass, confirming `calculate_payment(200_000, 0.06, 30, 12)` returns something within a cent of `$1,199.10`.

### 6.7.2 If It Doesn't Match

In order of likelihood, check: is the periodic rate actually `annual_rate / payments_per_year`, computed *before* being raised to a power (a rate accidentally raised to a power before dividing is a classic version of this bug)? Is `n` actually 360, not 30 (term years, forgetting to multiply by frequency)? Is the formula's numerator and denominator each matching 4.4.1 exactly, with no terms transposed? These three, in this order, catch the overwhelming majority of first attempts that don't match.

## 6.8 Refactor

### 6.8.1 The Refactor Step, For Real This Time

Chapter 5.2's tiny `add` example didn't have anything worth refactoring. This one might: are `annual_rate_to_periodic` and `total_payments` named clearly? Is `calculate_payment` still readable against the formula, or did fixing 6.7.2's bug leave behind anything awkward? Clean it up now, with the full test suite as a safety net — this is exactly what the "refactor" step is for.

### 6.8.2 Ruff Pass

```bash
ruff check . && ruff format .
```

Consistent with the habit established in Chapter 3.6.1 — every commit, not just some.

### 6.8.3 A Note on Rounding

You may notice `calculate_payment` currently returns full floating-point precision (`1199.1010503055138`), not a value already rounded to the cent — the tests handle that with `pytest.approx(..., abs=0.01)` rather than the function itself rounding. This is deliberate for now: rounding is a presentation decision, and mixing it into the core risks baking a specific display choice into a function that's supposed to stay pure and general. Chapter 7's validation layer is where this book properly addresses currency precision and bounds — flagged here so it doesn't feel like an oversight when it doesn't come up again until then.

## 6.9 Checkpoint

Before moving to Chapter 7, this should all be true:

- [ ] `src/mortgage_calculator_book/core.py` contains `annual_rate_to_periodic`, `total_payments`, and `calculate_payment`
- [ ] All three tests from Chapter 5 pass: `pytest -v` shows three green
- [ ] `calculate_payment` has no I/O, no printing, no dependencies outside its own arguments
- [ ] You can explain, without looking at the code, what each of the three checks in 6.7.2 is guarding against
- [ ] `ruff check .` and `ruff format .` both pass
- [ ] Everything is committed

**What's next:** Chapter 7 wraps this trusted, pure core in a validation layer — because so far, `calculate_payment` will happily compute a confident, wrong-looking answer for a negative principal or an absurd interest rate, and nothing has stopped it from being asked to.
