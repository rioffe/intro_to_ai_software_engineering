# Chapter 3 — Holding the Agent to a Standard

## 3.1 Why This Chapter Exists

You have a spec now, and a working relationship with an agent that can write code against it. Before any real code gets written, this short chapter sets up one more thing: a floor for quality that applies automatically, to every change, whether you wrote it or Pi did.

By the end of this chapter, Ruff will be installed, configured, and run against the one piece of code that already exists in your project — the docstring Pi added back in Chapter 1.6.

## 3.2 "Passes Tests" Isn't the Same as "Good Code"

### 3.2.1 Why This Matters More Once an Agent Is Involved

Code can be functionally correct and still be inconsistent, oddly formatted, or written in a style that doesn't match the rest of your project — none of which a test suite will ever catch, because tests check behavior, not style. That's true of code you write yourself, too, but it becomes a sharper problem once an agent is generating a meaningful share of your codebase: Pi has no inherent reason to match *your* conventions unless something enforces them, and "close enough" drift across dozens of agent-assisted changes adds up into a codebase that's technically correct and genuinely unpleasant to read.

### 3.2.2 A Plausible Example

Imagine asking Pi to add a function, and it comes back with correct logic, but inconsistent quote styles, an unused import left over from an earlier attempt, and inconsistent spacing around operators. Every test still passes. Nothing here is a bug. It's still worth catching, and it's not worth catching *by eye*, every time, forever.

> **Process concept: quality bars you set once, and enforce automatically.** The alternative to a linter isn't "no standard" — it's "a standard you have to remember to apply yourself, every single time, including on the days you're tired or rushing." This chapter trades that for a tool that never forgets to check.

## 3.3 What Ruff Is

### 3.3.1 Linting and Formatting, One Tool

**Linting** catches likely mistakes and style problems — unused imports, inconsistent naming, patterns known to cause bugs. **Formatting** enforces a consistent visual style — spacing, quote style, line length — regardless of who wrote the code. Ruff does both, in one fast tool.

### 3.3.2 Why Ruff, Specifically

Python has historically split this work across three separate tools — Black for formatting, Flake8 for linting, isort for import ordering. Ruff reimplements the useful parts of all three in a single, much faster tool, which is why this book uses it instead of the older combination: fewer things to install, fewer things to configure, fewer places for configuration to drift out of sync with each other.

## 3.4 Installing and Configuring Ruff

### 3.4.1 Installing

```bash
uv add --dev ruff
```

The `--dev` flag matters here: Ruff is a tool *you* use while developing, not something the calculator itself needs at runtime, so it belongs in your project's development dependencies, not its regular ones.

### 3.4.2 A Minimal Configuration

Add a small section to your existing `pyproject.toml`:

```toml
[tool.ruff]
line-length = 100

[tool.ruff.lint]
select = ["E", "F", "I"]
```

This is deliberately narrow: `E` and `F` cover common style and correctness issues, `I` handles import ordering. Ruff supports many more rule categories than this, but a first-year project doesn't need all of them enabled on day one — start narrow, and widen later if you find yourself wanting more.

### 3.4.3 Running It

`uv add --dev ruff` installs Ruff into your project's virtual environment, `.venv/` — not globally on your system. If you try `ruff check .` right after installing it and get a `command not found` error, that's why: your shell doesn't yet know to look inside `.venv/`. Activate the environment:

```bash
source .venv/bin/activate
```

(On native Windows outside WSL, the equivalent is `.venv\Scripts\activate`.)

Confirm it worked:

```bash
which ruff
```

You're looking for a path inside your project's `.venv/` — something like `.../mortgage-calculator-book/.venv/bin/ruff` — not a Ruff installed somewhere else on your system. This matters: if you happen to have a different Ruff on your machine already, `which ruff` is how you'd catch yourself accidentally running the wrong one.

Once activated, this same terminal session can run `ruff`, `pytest`, and `python` bare, without prefixing every command with `uv run` — which is why later chapters show commands like `pytest -v` directly rather than `uv run pytest -v`. `uv run ruff check .` is the alternative that works either way, activated or not, since it always runs inside the project's environment regardless of your shell's current state — reach for it instead if you'd rather not activate manually, or you're running a one-off command in a fresh terminal that isn't activated.

With Ruff actually runnable:

```bash
ruff check .     # lint
ruff format .    # format
```

`ruff check` reports problems; `ruff format` rewrites files to match the configured style. Run both — they check different things.

Installing Ruff changed `pyproject.toml` and `uv.lock` — a real change, worth its own commit:

```bash
git add .
git commit -m "Add Ruff as a dev dependency"
git push
```

## 3.5 Running Ruff Against Agent Output

### 3.5.1 Pointing It at Chapter 1's Change

```bash
ruff check src/mortgage_calculator_book/__init__.py
```

For a one-line docstring, this will likely come back clean — which is itself a useful first result: it tells you Ruff is wired up correctly, even though there was nothing to fix yet.

### 3.5.2 Reading and Fixing What It Flags

When Ruff does flag something (and it will, once real code exists from Chapter 6 onward), its output names the specific rule and line: treat each one as a small checklist item, not an annoyance to silence. If a rule genuinely doesn't fit your project, that's a configuration decision to make deliberately in `pyproject.toml` — not something to work around case by case.

### 3.5.3 Asking Pi to Fix Ruff's Complaints

```bash
ruff check . || pi "Fix the issues reported by ruff check in this project."
```

Review that diff exactly the way you reviewed Chapter 1.6's — Pi fixing a lint error is still a proposed change, and still worth reading before accepting.

## 3.6 Making It a Habit, Not a One-Off

### 3.6.1 Before Every Commit

From this point forward, run `ruff check .` and `ruff format .` before every commit, for the rest of the book. This isn't automated yet — Appendix A.5 covers pre-commit hooks, which would do this for you — but doing it by hand for now is deliberate: understanding *why* you run it matters more, this early, than automating it away before you've felt the reason for it.

### 3.6.2 Looking Ahead

Chapter 13's Hardening chapter revisits standards again, but at the level of the whole system — error handling, logging, a final consistency check. This chapter is the per-commit version of that same instinct: catch problems small and early, rather than all at once at the end.

## 3.7 Checkpoint

Before moving to Chapter 4, this should all be true:

- [ ] Ruff is installed as a dev dependency
- [ ] `pyproject.toml` has a minimal `[tool.ruff]` configuration
- [ ] `ruff check .` and `ruff format .` both run without errors against the current project
- [ ] You've run Ruff at least once against Pi-generated content, even if there was nothing to fix

**What's next:** Chapter 4 leaves tooling aside for a chapter and gets into the actual mathematics of fixed mortgages — the domain content SPEC.md will need once Chapter 4 comes back to revise it.
