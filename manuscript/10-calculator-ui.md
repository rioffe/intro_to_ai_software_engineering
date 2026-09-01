# Chapter 9 — Calculator UI

## 9.1 Why This Chapter Exists

Chapter 8 gave the calculator its first user-facing surface. This chapter gives it a second, entirely different one — a graphical desktop window — calling the exact same validation and core logic underneath. If Chapter 6's insistence on a pure core and Chapter 7's separate validation layer were worth the discipline, this chapter is where that discipline pays for itself directly: almost none of the code you write here will touch mortgage math at all.

By the end, you'll have a working PyQt5 window that takes the same four inputs as the CLI and produces the same result, with no duplicated calculation logic anywhere.

## 9.2 Two Front Ends, One Core

### 9.2.1 The Rule for This Chapter

Chapter 6.2 established that the core has no I/O. Chapter 7.7 established that `MortgageInput` and `calculate_validated_payment` are the one supported path into it. Nothing in this chapter changes either of those. This chapter only adds a new way to *call* that existing path — not a new way to compute anything.

### 9.2.2 What's Allowed to Change, and What Isn't

Allowed: how input is collected, how output is displayed, anything about layout, styling, and interaction. Not allowed: reimplementing any part of the payment calculation, or duplicating validation logic that already exists in `MortgageInput`. If you notice yourself writing an `if` statement that checks whether a number is positive, that's a sign you've drifted into re-doing Chapter 7's job instead of reusing it.

## 9.3 PyQt5 Basics

### 9.3.1 Installing

```bash
uv add pyqt5
```

### 9.3.2 The Smallest Possible Window

```python
import sys

from PyQt5.QtWidgets import QApplication, QWidget

app = QApplication(sys.argv)
window = QWidget()
window.setWindowTitle("Hello, PyQt5")
window.show()
sys.exit(app.exec_())
```

`QApplication` manages the application as a whole — there's exactly one per program. `QWidget` is the base building block for anything visible; an empty one, as above, is just a blank window. `.show()` makes it visible, and `app.exec_()` starts the **event loop** — the process that waits for and responds to user interaction (clicks, typing, resizing) until the window is closed.

### 9.3.3 Core Widgets for This Project

- `QLineEdit` — a single-line text input, for the four numeric fields
- `QLabel` — non-editable text, for both field labels and the result display
- `QPushButton` — a clickable button, to trigger the calculation
- `QFormLayout` — arranges label/input pairs in neat rows, exactly the shape this calculator's input form needs
- `QVBoxLayout` — stacks widgets vertically; used here to stack the form, the button, and the result label

### 9.3.4 Signals and Slots

PyQt5's event handling works through **signals** (something happened — a button was clicked) connected to **slots** (a function that runs in response). `button.clicked.connect(some_function)` means: whenever this button is clicked, call `some_function`. That's the entire mechanism this project needs — PyQt5 has many more signal types, but this one covers everything the calculator does.

## 9.4 Designing the Calculator Window

### 9.4.1 Sketching the Layout

Four labeled inputs, matching `SPEC.md`'s fields exactly, a calculate button, and a result area below it:

```
Principal ($):           [____________]
Annual rate (e.g. 0.06): [____________]
Term (years):            [____________]
Payments per year:       [____________]

[ Calculate ]

Fixed periodic payment: $1,199.10
```

### 9.4.2 What's Worth Planning vs. What Isn't

The field order and labels above are worth deciding deliberately, since they directly mirror the spec. Exact pixel spacing, colors, and fonts are not worth planning in advance — PyQt5's defaults are perfectly usable, and this book treats visual polish as something to iterate on directly in code, not something to wireframe first.

## 9.5 Wiring the UI to Validation and the Core

### 9.5.1 The Full Window

In `src/mortgage_calculator/ui.py`:

```python
import sys

from PyQt5.QtWidgets import (
    QApplication,
    QFormLayout,
    QLabel,
    QLineEdit,
    QPushButton,
    QVBoxLayout,
    QWidget,
)
from pydantic import ValidationError

from mortgage_calculator.validation import MortgageInput, calculate_validated_payment


class MortgageCalculatorWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Mortgage Calculator")

        self.principal_input = QLineEdit()
        self.rate_input = QLineEdit()
        self.term_input = QLineEdit()
        self.frequency_input = QLineEdit("12")

        self.result_label = QLabel("")
        self.calculate_button = QPushButton("Calculate")
        self.calculate_button.clicked.connect(self.on_calculate)

        form = QFormLayout()
        form.addRow("Principal ($):", self.principal_input)
        form.addRow("Annual rate (e.g. 0.06):", self.rate_input)
        form.addRow("Term (years):", self.term_input)
        form.addRow("Payments per year:", self.frequency_input)

        layout = QVBoxLayout()
        layout.addLayout(form)
        layout.addWidget(self.calculate_button)
        layout.addWidget(self.result_label)
        self.setLayout(layout)

    def on_calculate(self) -> None:
        try:
            data = MortgageInput(
                principal=float(self.principal_input.text()),
                annual_rate=float(self.rate_input.text()),
                term_years=int(self.term_input.text()),
                payments_per_year=int(self.frequency_input.text()),
            )
        except (ValueError, ValidationError) as exc:
            self.result_label.setText(f"Error: {exc}")
            return

        payment = calculate_validated_payment(data)
        self.result_label.setText(f"Fixed periodic payment: ${payment:,.2f}")


def main() -> None:
    app = QApplication(sys.argv)
    window = MortgageCalculatorWindow()
    window.show()
    sys.exit(app.exec_())


if __name__ == "__main__":
    main()
```

### 9.5.2 Displaying Errors in the UI

Notice `on_calculate` catches two different kinds of error: a plain `ValueError`, raised if `float(...)` or `int(...)` fails on genuinely non-numeric text (someone typing "abc" into the principal field), and `ValidationError`, raised by `MortgageInput` for numeric-but-invalid input (a negative principal, same as Chapter 8's CLI would reject). Both land in the same result label rather than crashing the application — a user typing garbage into a field should see a message, not watch the window disappear.

### 9.5.3 Displaying the Result

`f"${payment:,.2f}"` — the same formatting used in Chapter 8's CLI, for the same reason: consistent presentation between front ends, even though the underlying `payment` value is unrounded until this exact point (Chapter 6.8.3).

## 9.6 Where Agent Assistance Helps, and Where It Doesn't

### 9.6.1 Good Delegation: Boilerplate Widget Wiring

The widget-creation and layout code in 9.5.1 is exactly the kind of task worth handing to Pi:

```bash
pi "Add a 'Clear' button next to Calculate that resets all " \
   "four input fields and the result label."
```

This is mechanical, has an obviously correct answer, and is fast to verify — run the app, click the button, confirm the fields clear.

### 9.6.2 Poor Delegation: Layout and Visual Judgment

Asking Pi to "make this look nicer" invites a much harder review problem: "nicer" isn't a test you can run, and accepting a layout change sight-unseen means trusting an aesthetic judgment you haven't actually checked. Reviewing a UI diff correctly here means *running the application and looking at it* — reading the code alone won't tell you whether a change actually improved anything.

> **Process concept: "trust but verify" extended to a domain you check with your eyes.** Chapter 1.6 introduced verification as reading a diff. Most of this book's verification since then has been reading diffs and running tests. This is the first chapter where verification genuinely requires neither — it requires looking at the running application. Recognizing when a task needs that kind of check, rather than defaulting to "the tests still pass, so it's fine," is its own skill worth practicing here.

## 9.7 Testing UI Logic Where It's Worth It

### 9.7.1 What's Testable Without a Full GUI Framework

Testing PyQt5 windows directly — simulating clicks, reading rendered widget state — requires additional tooling this book doesn't cover, and for a project this size, the payoff doesn't justify the setup cost. What *is* cheap to test is the parsing logic hiding inside `on_calculate`. Pull it out as its own function in `ui.py`:

```python
def parse_form_values(
    principal_text: str, rate_text: str, term_text: str, frequency_text: str
) -> dict:
    """Convert raw form text into the types MortgageInput expects."""
    return {
        "principal": float(principal_text),
        "annual_rate": float(rate_text),
        "term_years": int(term_text),
        "payments_per_year": int(frequency_text),
    }
```

And update `on_calculate` to call it:

```python
    def on_calculate(self) -> None:
        try:
            values = parse_form_values(
                self.principal_input.text(),
                self.rate_input.text(),
                self.term_input.text(),
                self.frequency_input.text(),
            )
            data = MortgageInput(**values)
        except (ValueError, ValidationError) as exc:
            self.result_label.setText(f"Error: {exc}")
            return

        payment = calculate_validated_payment(data)
        self.result_label.setText(f"Fixed periodic payment: ${payment:,.2f}")
```

Now `parse_form_values` is a plain function, testable with no `QApplication` involved at all:

```python
# tests/test_ui.py
import pytest

from mortgage_calculator.ui import parse_form_values


def test_parses_valid_form_values():
    result = parse_form_values("200000", "0.06", "30", "12")
    assert result == {
        "principal": 200000.0,
        "annual_rate": 0.06,
        "term_years": 30,
        "payments_per_year": 12,
    }


def test_raises_on_non_numeric_principal():
    with pytest.raises(ValueError):
        parse_form_values("not a number", "0.06", "30", "12")
```

### 9.7.2 The Judgment of Not Over-Testing

Notice what's deliberately absent here: no test clicks the actual button, no test checks the actual label text on screen. That's not laziness — it's a decision that the layout and widget-wiring code isn't worth the tooling cost of testing directly, given how cheaply it can be checked by hand (9.6.2). Knowing where to stop testing is as much a skill as knowing where to start.

## 9.8 Running the App

### 9.8.1 A Walkthrough

```bash
uv run python -m mortgage_calculator.ui
```

Enter the Chapter 4.5 worked example — `200000`, `0.06`, `30`, `12` — click Calculate, and confirm the window shows `$1,199.10`, matching every other front end this project has produced so far.

### 9.8.2 Packaging, Briefly

Turning this into a double-clickable application (a `.app` on macOS, an `.exe` on Windows) is a real, separate topic — tools like PyInstaller handle it, but it's genuinely out of scope for this book. Flagged here, and named properly in the Appendix, rather than left as a mystery.

## 9.9 Refactor and Ruff Pass

```bash
ruff check . && ruff format .
```

## 9.10 Checkpoint

Before moving to Chapter 10, this should all be true:

- [ ] The PyQt5 window opens and displays four labeled input fields, a Calculate button, and a result area
- [ ] Entering the Chapter 4.5 worked example produces `$1,199.10`
- [ ] Invalid input (non-numeric text, or values `MortgageInput` rejects) shows an error message instead of crashing
- [ ] `parse_form_values` exists as a standalone, tested function
- [ ] No mortgage math or validation logic is duplicated anywhere in `ui.py` — it all still lives in `core.py` and `validation.py`
- [ ] `ruff check .` and `ruff format .` both pass

**What's next:** Chapter 10 builds a third front end — not for a human this time, but for a language model, exposing the same validated core as a callable tool.
