# Chapter 7 — Validation

## 7.1 Why This Chapter Exists

Chapter 6 left you with a trusted, correct core — but one that will compute a confident answer for a negative principal, a 400% interest rate, or a term of zero years, because nothing has ever told it not to. This chapter builds the layer that catches bad input before it ever reaches `calculate_payment`.

By the end, a Pydantic-based input model will sit between the outside world and Chapter 6's core, fully tested, enforcing exactly what SPEC.md says is valid.

## 7.2 Why Validation Is Its Own Layer, Not Bolted onto the Core

### 7.2.1 Revisiting Purity

Chapter 6.2 established a firm rule: the core has no I/O, no dependencies outside its own arguments — nothing but calculation. Validation is different in kind, not just in code: it exists specifically to deal with input from the outside world, which is exactly what the core was built to never touch directly. Putting a check like `if principal <= 0: raise ValueError` inside `calculate_payment` would quietly violate the boundary Chapter 6 spent a whole chapter establishing.

### 7.2.2 What Skipping This Layer Costs

Without it, bad input doesn't announce itself clearly — it either crashes somewhere unhelpful (a `ZeroDivisionError` three function calls deep, far from where the bad number actually entered the system) or, worse, produces a number that looks like a real answer but means nothing (a "payment" computed from a negative principal). Neither is a good experience for a user, and neither is easy to debug.

### 7.2.3 Where This Is Headed

Notice the shape of what you're about to build: a declarative description of what valid input looks like, expressed as a schema. Chapter 10's tool interface needs almost exactly this same shape — a schema a language model can read and be held to — which is why this chapter's work gets reused rather than redone.

## 7.3 What Needs Validating

### 7.3.1 Revisiting SPEC.md's Inputs

From Chapter 4.7.3's revised spec: `principal`, `annual_rate`, `term_years`, `payments_per_year`. Each needs a definition of "valid" beyond just "the right type":

- `principal` — must be positive; a loan of zero or negative dollars isn't a loan.
- `annual_rate` — must be a plausible rate. Zero is valid (Chapter 6.6.1's edge case); something like 1.5 (150%) almost certainly represents a typo, not a real mortgage.
- `term_years` — must be positive.
- `payments_per_year` — must be positive.

### 7.3.2 Turning Edge Cases into Explicit Boundaries

Chapter 6's zero-interest case showed that `annual_rate = 0` is a legitimate input, not an error — which means the validation boundary here has to be "rate cannot be negative," not "rate must be strictly positive." Get this wrong and you'll accidentally reject a test case Chapter 6 was specifically built to handle.

## 7.4 Introducing Pydantic

### 7.4.1 The Problem It Solves

A validation function built from a chain of `if` statements works, but it scales badly — the checks live separately from the data they're checking, error messages have to be written by hand for every case, and there's no single place that describes what "valid input" even means at a glance. Pydantic solves this by letting you declare validity as part of a data model's definition, rather than as separate procedural code.

### 7.4.2 Installing

```bash
uv add pydantic
```

Unlike Ruff and pytest, this isn't a `--dev` dependency — the calculator needs Pydantic at runtime, not just while you're developing it.

### 7.4.3 A First Minimal Model

```python
from pydantic import BaseModel

class Example(BaseModel):
    name: str
    age: int
```

`Example(name="Robert", age=40)` works. `Example(name="Robert", age="not a number")` raises a `ValidationError` automatically — Pydantic enforces the declared types without you writing a single `isinstance` check.

## 7.5 Building the Input Model

### 7.5.1 The Model

In `src/mortgage_calculator/validation.py`:

```python
from pydantic import BaseModel, field_validator


class MortgageInput(BaseModel):
    """Validated input for a fixed-rate mortgage payment calculation."""

    principal: float
    annual_rate: float
    term_years: int
    payments_per_year: int = 12

    @field_validator("principal")
    @classmethod
    def principal_must_be_positive(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("principal must be positive")
        return v

    @field_validator("annual_rate")
    @classmethod
    def rate_must_be_plausible(cls, v: float) -> float:
        if v < 0:
            raise ValueError("annual_rate cannot be negative")
        if v >= 1:
            raise ValueError("annual_rate must be less than 1 (e.g. 0.06 for 6%)")
        return v

    @field_validator("term_years")
    @classmethod
    def term_must_be_positive(cls, v: int) -> int:
        if v <= 0:
            raise ValueError("term_years must be positive")
        return v

    @field_validator("payments_per_year")
    @classmethod
    def payments_per_year_must_be_positive(cls, v: int) -> int:
        if v <= 0:
            raise ValueError("payments_per_year must be positive")
        return v
```

### 7.5.2 Custom Validators, Explained

Each `@field_validator` runs after Pydantic's own type checking, and raises a plain `ValueError` with a message written for a human to read — not a generic type error. Notice `rate_must_be_plausible` allows exactly zero (`v < 0` rejects negative, but zero passes through) while rejecting anything at or above 100% — matching 7.3.2's requirement precisely.

### 7.5.3 Error Messages as a User-Facing Surface

The strings inside each `raise ValueError(...)` aren't incidental — they're what a user of Chapter 8's CLI or Chapter 9's UI will actually see when they enter something invalid. Write them the way you'd want to read them yourself: specific about what's wrong, not just "invalid input."

## 7.6 Agent-Assisted TDD, Applied to Validation

### 7.6.1 Writing the Failing Tests First

In `tests/test_validation.py`:

```python
import pytest
from pydantic import ValidationError

from mortgage_calculator.validation import MortgageInput


def test_valid_input_accepted():
    result = MortgageInput(
        principal=200_000, annual_rate=0.06, term_years=30, payments_per_year=12
    )
    assert result.principal == 200_000


def test_negative_principal_rejected():
    with pytest.raises(ValidationError):
        MortgageInput(principal=-1000, annual_rate=0.06, term_years=30)


def test_zero_principal_rejected():
    with pytest.raises(ValidationError):
        MortgageInput(principal=0, annual_rate=0.06, term_years=30)


def test_zero_rate_accepted():
    """Zero interest is a valid edge case (see Chapter 6.6.1), not an error."""
    result = MortgageInput(principal=12_000, annual_rate=0.0, term_years=1)
    assert result.annual_rate == 0.0


def test_negative_rate_rejected():
    with pytest.raises(ValidationError):
        MortgageInput(principal=200_000, annual_rate=-0.01, term_years=30)


def test_rate_above_one_rejected():
    with pytest.raises(ValidationError):
        MortgageInput(principal=200_000, annual_rate=1.5, term_years=30)


def test_zero_term_rejected():
    with pytest.raises(ValidationError):
        MortgageInput(principal=200_000, annual_rate=0.06, term_years=0)
```

Run this before `validation.py` exists — red, for the familiar reason.

### 7.6.2 Prompting Pi

```bash
pi "Implement MortgageInput in src/mortgage_calculator/validation.py" \
   "as a Pydantic model to make the tests in tests/test_validation.py pass." \
   "Read SPEC.md first for what counts as valid input."
```

### 7.6.3 Reviewing the Proposal

Check specifically that the boundaries match SPEC.md and Chapter 7.3 exactly, not just "look reasonable" — a proposal that rejects `annual_rate = 0` would pass a casual read but silently break Chapter 6.6.1's zero-interest case the moment this validation layer gets wired in front of it.

## 7.7 Wiring Validation to the Core

### 7.7.1 The Only Path In

Add one more function to `validation.py`, or to a small new module, that connects the two:

```python
from mortgage_calculator.core import calculate_payment
from mortgage_calculator.validation import MortgageInput


def calculate_validated_payment(data: MortgageInput) -> float:
    """The only supported entry point: validated input in, a payment out."""
    return calculate_payment(
        principal=data.principal,
        annual_rate=data.annual_rate,
        term_years=data.term_years,
        payments_per_year=data.payments_per_year,
    )
```

### 7.7.2 Confirming the Boundary

`calculate_payment` still never sees raw, unvalidated input — it only ever receives values that have already passed through `MortgageInput`. And `MortgageInput` never performs any mortgage math itself — it only validates. Each piece does exactly one job, which is the same separation-of-concerns idea from Chapter 6.2, now applied one layer further out.

### 7.7.3 Running Everything

```bash
pytest -v
```

Chapter 6's three tests, plus this chapter's seven, all green.

## 7.8 Refactor and Ruff Pass

```bash
ruff check . && ruff format .
```

Same habit as every prior chapter — nothing new here, which is itself a small sign the habit has taken hold.

## 7.9 Checkpoint

Before moving to Chapter 8, this should all be true:

- [ ] Pydantic is installed as a runtime dependency
- [ ] `MortgageInput` enforces every constraint from SPEC.md: positive principal, rate in `[0, 1)`, positive term, positive payment frequency
- [ ] `test_zero_rate_accepted` passes — confirming validation didn't accidentally break Chapter 6's zero-interest case
- [ ] `calculate_validated_payment` is the only path from raw input to a payment result
- [ ] The full test suite (10 tests: 3 from Chapter 6, 7 from this chapter) is green
- [ ] Everything is committed

**What's next:** Chapter 8 gives this validated core its first real user-facing surface — a command-line interface a person can actually run.
