# Chapter 2 — Writing SPEC.md

## 2.1 Why This Chapter Exists

At the end of Chapter 1, you gave Pi a one-line instruction and reviewed a one-line change. That worked because the task was tiny enough to hold in your head. The mortgage calculator won't be tiny for long. This chapter gives you — and Pi — something more durable to work from than a chat message: a written spec, committed to the repository alongside the code it describes.

By the end of this chapter, you'll have a first draft of `SPEC.md`, committed to your repository. It won't be complete, and it won't be entirely correct — Chapter 4 exists specifically to find out where.

## 2.2 What a Spec Is (and Isn't)

### 2.2.1 Intent, Written Before Code

A spec, as this book uses the term, is a description of what a system should do, written before the system exists to do it. It's not a design document — it doesn't describe *how* the calculator will compute a payment, only *what* it means for that computation to be right. It's also not a requirements document in the heavyweight, sign-off-required sense you might associate with large organizations. Think of it as closer to a clear, written promise than a contract: a statement specific enough to hold yourself to, informal enough to write in an afternoon.

### 2.2.2 Living, Not Fixed

The most important thing to understand about SPEC.md before you write a word of it: it will be wrong in places, and that's expected. You'll revise it in Chapter 4 once real mortgage math enters the picture, again in Chapters 9 and 11 as new interfaces get added, and a final time in Chapter 13 once the whole system exists and you can check the spec against what actually got built. A spec that never changes usually means nobody's been checking it against reality.

### 2.2.3 Three Readers, One Document

SPEC.md serves three different readers, and it's worth writing with all three in mind:

- **You, in three weeks** — when you've forgotten exactly what "valid" was supposed to mean for a loan term.
- **A classmate or collaborator** — who needs to understand the project without reading every line of code first.
- **Pi** — which will read this file as context for later tasks, the same way it read your one-line instruction in Chapter 1, just at greater length and with more precision.

> **Process concept: same contract, three altitudes.** SPEC.md is the first of three places this book will write down what "correct" means for this system. Chapter 5's tests are the second — the same intent, made executable. Chapter 7 and Chapter 10's schemas are the third — the same intent again, made machine-readable enough for a language model to call. You're not writing three different things across the book; you're writing one idea, at three different levels of formality, for three different audiences.

## 2.3 Anatomy of a Lightweight SPEC.md

A spec at this scale needs four things, no more:

### 2.3.1 What the Calculator Does

One paragraph, plain language. Not a feature list — a description someone with no context could read and understand the point of the project.

### 2.3.2 Inputs and Outputs

Named, with types. Not formulas yet — that's Chapter 4's job, once the domain math has been properly explained. For now, just: what goes in, what comes out.

### 2.3.3 What "Correct" Means

The criteria something must meet to count as working — even before you know the exact math. For a mortgage calculator, this might be as simple as "the computed payment, multiplied by the number of payments, should recover the total amount paid" — a property you can state and check without yet having derived the formula that produces it.

### 2.3.4 What's Out of Scope

Often more useful than what's in scope. Explicitly naming what this project *won't* do — variable-rate mortgages, refinancing calculations, multiple currencies — prevents scope from quietly expanding one "just add this one thing" at a time.

## 2.4 Writing the First Draft, With Pi

### 2.4.1 Prompting Pi to Help Structure the Draft

Applying the same "prompting as spec-writing" idea from Chapter 1.6, but at document scale rather than one-line scale:

```bash
pi "Draft a SPEC.md for a fixed-rate mortgage \
    calculator. It should describe what the tool does, \
    its inputs and outputs, what 'correct' means for it, \
    and what's explicitly out of scope. Keep it under \
    one page."
```

### 2.4.2 Reading Pi's Suggestions Critically

Pi will likely produce something reasonable-looking and, in at least one place, quietly wrong or presumptuous — filling a gap you didn't actually specify with a plausible-sounding assumption. This is exactly the risk this chapter exists to teach you to catch. A common example: Pi may assume monthly payments without your having said so, or describe "periodic interest rate" as if it were the same thing as the annual rate. Read every sentence and ask, for each one: *did I actually mean this, or did the agent fill in a gap I left open?*

### 2.4.3 Editing Down to What You Actually Mean

Take Pi's draft and cut, correct, and rewrite until every sentence is something you'd defend if asked. Below is roughly what a reasonable first draft looks like at this point in the book — deliberately imperfect, in ways Chapter 4 will catch:

```markdown
# SPEC.md — Fixed-Rate Mortgage Calculator

## What it does
Calculates the fixed periodic payment for a fixed-rate mortgage,
given a principal amount, an interest rate, and a loan term.

## Inputs
- principal: the loan amount, in dollars
- rate: the interest rate
- term: the length of the loan, in years

## Outputs
- payment: the fixed amount paid each period

## What "correct" means
The computed payment, multiplied by the number of payments,
should equal the total amount paid over the life of the loan.

## Out of scope
- Variable-rate mortgages
- Refinancing calculations
- Multiple currencies
```

If you're reading closely, you may already see what Chapter 4 is going to have to fix: "rate" doesn't say whether it's annual or periodic, "term" doesn't say what payment frequency it implies, and "the number of payments" is used before anything defines how it's calculated. Leave it as it is for now — the gaps are the point, and finding them with real domain knowledge in hand is more useful than getting them right by luck on a first pass.

### 2.4.4 What You Might Actually See

The illustrative draft above is intentionally simple, so the specific gaps Chapter 4 needs to catch stay easy to spot. Real output varies — sometimes a lot — depending on which model actually wrote it, and it's worth seeing that difference once, concretely, before you run this exercise yourself.

Running the 2.4.1 prompt against **qwen3:8b** produced a noticeably different kind of draft. It added constraints nobody asked for — a $10,000 minimum loan amount, a rate capped at 0–100%, a term capped at 1–30 years — none of which trace back to anything in the prompt. That's exactly the risk 2.4.2 warned about: a plausible-sounding assumption filling a gap you never actually specified. It also introduced a "Rate Frequency" field ("Annual" or "Monthly," described as being for "effective annual rate calculations") that quietly conflates two genuinely different things — how often a rate is *quoted* versus how often payments are *made* — in a way that reads reasonably on a first pass and falls apart under the kind of scrutiny 4.3.2 asks you to apply.

Running the same prompt against **qwen3.8:27b-mlx** produced something considerably more ambitious: not just a payment figure, but a full month-by-month amortization schedule, with explicit rules for where rounding error is allowed to land (the final period only) and a battery of correctness properties — `payment == principal_paid + interest_paid` on every row, the closing balance reaching exactly zero, and so on. This is careful, genuinely well-specified engineering. It's also scope the 2.4.1 prompt never asked for and this book's project never builds: every chapter from here forward computes a single fixed payment, not a schedule. A more capable model didn't just fill gaps more sensibly here — it expanded the project's scope without being asked to, which needs exactly the same scrutiny as the smaller model's unrequested minimum-loan-amount constraint, just dressed up better.

Neither output is wrong to have produced — this is genuinely what real coding agents do, and it's part of why 2.4.2's instruction to read every sentence critically matters regardless of which model you're using. Your own first draft will very likely look like neither the illustrative version above nor either of these — which is fine. The skill this chapter is teaching isn't "get the spec Pi is supposed to produce"; it's "notice what you didn't actually ask for."

## 2.5 Committing the Spec

### 2.5.1 Where It Lives

`SPEC.md` sits at the root of your project, alongside `README.md` and `pyproject.toml` — visible immediately to anyone (or anything) opening the repository, not buried in a subdirectory.

### 2.5.2 Markdown, Reused

The Markdown syntax you're using here — headers, lists — is the same syntax Chapter 8 will use for the project's README. Learning it once, here, means Chapter 8 is mostly application rather than new material.

### 2.5.3 Committing It as Its Own Checkpoint

```bash
git add SPEC.md
git commit -m "Add first-draft SPEC.md"
git push
```

A spec is worth its own commit message, separate from any code — it's a real artifact of the project, not a scratch file.

## 2.6 What Happens When the Spec Is Wrong

This draft has gaps, and that's fine for now. Chapter 4 introduces the actual mathematics of fixed mortgages — periodic rates, payment frequency, the derivation of the payment formula itself — and one of that chapter's jobs is to come back to this exact document and fix what turns out to be ambiguous or simply missing. That revision is normal process, not a sign the first draft failed. Expecting it now, rather than being caught off guard by it in Chapter 4, is the whole reason this section exists.

## 2.7 Checkpoint

Before moving to Chapter 3, this should all be true:

- [ ] `SPEC.md` exists at the project root
- [ ] It describes what the calculator does, its inputs and outputs, what "correct" means, and what's out of scope
- [ ] You can point to at least one sentence in it and explain why you edited or kept what Pi originally proposed
- [ ] It's committed and pushed to GitHub

**What's next:** Chapter 3 makes sure whatever code gets written from here forward — yours or Pi's — is held to a consistent quality standard before it's ever committed. Chapter 4 will come back to this exact SPEC.md once real mortgage math is on the table.
