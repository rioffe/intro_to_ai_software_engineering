# Chapter 0 — Orientation

## 0.1 Why This Chapter Exists

Every chapter after this one assumes you have a few things already in place: a terminal you're not afraid of, a git repository that's tracking your work, and a Python project set up the way the rest of this book expects. This chapter builds all of that. Nothing here is specific to mortgages, AI, or agents — it's the ground floor everything else stands on.

By the end of this chapter, you'll have an empty-but-real project: initialized, version-controlled, pushed to GitHub, and ready to hand to a coding agent in Chapter 1.

## 0.2 The Terminal

### 0.2.1 Opening a Terminal

- **macOS**: open Spotlight (Cmd+Space), type `Terminal`, press Enter.
- **Linux**: almost every distribution ships a terminal app in its applications menu; on many, Ctrl+Alt+T opens one directly.
- **Windows**: install [Windows Terminal](https://apps.microsoft.com/detail/9n0dx20hk701) from the Microsoft Store, and use it to run WSL (Windows Subsystem for Linux) rather than the classic Command Prompt. This book assumes a Unix-like shell throughout; WSL gives you one without leaving Windows.

Whichever you use, you should end up looking at a mostly-empty window with a blinking cursor next to a **prompt** — something like `robert@machine ~ %`. That prompt is waiting for you to type a command.

### 0.2.2 Navigation

Three commands get you almost everywhere:

```bash
pwd        # print working directory — "where am I?"
ls         # list what's in the current directory
cd Documents   # change directory — "go here"
```

A few navigation shortcuts worth knowing immediately:

```bash
cd ..      # go up one level
cd ~       # go to your home directory
cd -       # go back to wherever you just were
```

Paths can be **relative** (`cd Documents`, starting from where you are) or **absolute** (`cd /Users/robert/Documents`, starting from the very top). When in doubt, `pwd` tells you where "where you are" actually is.

### 0.2.3 File Basics

```bash
mkdir mortgage-calculator   # make a new directory
touch notes.txt             # create an empty file
cat notes.txt               # print a file's contents
rm notes.txt                # delete a file — there is no trash can, no undo
```

That last one deserves its own line: **`rm` does not ask twice, and it does not go to a recycle bin.** Get in the habit of double-checking what you're about to delete, especially once wildcards enter the picture (`rm *.txt` deletes *every* `.txt` file in the current directory, no confirmation).

### 0.2.4 Why the Terminal Matters More Now, Not Less

It might seem like an AI-assisted book would need the terminal less than an older one — surely the agent handles the typing? In practice, the opposite is true. Pi, the coding agent you'll meet in Chapter 1, does its work *in* a terminal: reading files, running commands, executing tests. Understanding the terminal isn't a prerequisite you'll outgrow once the agent shows up — it's how you'll read what the agent is actually doing, and how you'll independently verify it.

## 0.3 Git Basics

### 0.3.1 What Version Control Is Actually For

Git is often introduced as "backup," which undersells it. What git actually gives you is a series of **checkpoints** — snapshots of your project at moments you chose, each one recoverable, each one comparable to any other. That matters for any project, but it matters especially once an agent is also editing your files: git is how you know exactly what changed, when, and whether you want to keep it.

### 0.3.2 Installing and Configuring Git

Check whether you already have it:

```bash
git --version
```

If that fails, install it via your system's package manager (`brew install git` on macOS, `sudo apt install git` on Debian/Ubuntu-based Linux, or the WSL equivalent). Then tell git who you are — it stamps this on every commit you make:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### 0.3.3 The Core Loop

```bash
cd mortgage-calculator
git init                       # start tracking this directory
git status                     # what's changed since the last commit?
git add SPEC.md                # stage a specific file
git add .                      # stage everything that's changed
git commit -m "Initial commit" # save a checkpoint, with a message
```

`git status` is the command you'll run constantly — more than any other in this book. It tells you what's staged, what's changed but unstaged, and what git doesn't know about yet. Run it often; there's no penalty for checking.

### 0.3.4 Reading a Commit Log

```bash
git log --oneline
```

This gives you a compact history of every checkpoint you've made — one line per commit, most recent first. As this project grows across the rest of the book, this is how you'll orient yourself: "what did I actually do in Chapter 4?"

> **Process concept: commits as checkpoints.** A commit is cheap, fast, and reversible in a way that makes it worth doing far more often than feels necessary at first. Get in the habit now, before Chapter 1 hands your repository to an agent: commit before you let anything — agent or otherwise — make a change you haven't reviewed yet. If something goes wrong, you want a recent checkpoint to fall back to, not a blank slate.

## 0.4 GitHub.com

### 0.4.1 Creating an Account and a Repository

Sign up at [github.com](https://github.com) if you haven't already, then create a new repository — call it `mortgage-calculator`, leave it empty (no README, no `.gitignore` yet; you'll add those yourself). GitHub will show you a page of commands for connecting an existing local project, which is exactly what you have.

### 0.4.2 Connecting Local to Remote

```bash
git remote add origin https://github.com/your-username/mortgage-calculator.git
git branch -M main
git push -u origin main
```

`git remote add origin ...` tells your local repository where its GitHub counterpart lives. `git push` sends your commits there. After this, `git push` alone (no flags) will work for future commits.

### 0.4.3 Branches

A **branch** is a parallel line of history — a place to make changes without touching your main line of work until you're ready to merge them back in.

```bash
git checkout -b try-something    # create and switch to a new branch
git checkout main                # switch back
```

This matters sooner than you might expect: in Chapter 1, you'll want a branch to work in *before* an agent starts editing your project, so that reviewing its changes is a matter of looking at a diff, not untangling your main line of history.

### 0.4.4 A First Look at a Pull Request

A pull request (PR) is GitHub's way of proposing that changes on one branch be merged into another — with a place to review the diff, leave comments, and decide whether to accept it. You don't need the full workflow yet; just recognize the shape of one when you see it. We'll use pull requests informally, as they come up naturally, rather than teaching the whole GitHub Flow up front.

## 0.5 vi, Just Enough

### 0.5.1 Why Bother

You will, at some point in this book — maybe editing a file over SSH, maybe in the middle of a git commit message — end up in a terminal with no other editor available. vi (or its more common modern form, vim) is installed almost everywhere by default. Twenty minutes now saves you from being stuck later.

### 0.5.2 Modes

vi's defining quirk is that it has **modes** — the same keys do different things depending on which mode you're in.

- **Normal mode** (where you start): keys are commands, not text.
- **Insert mode**: keys are text, typed normally.
- **Command mode**: for saving, quitting, and search-and-replace.

### 0.5.3 The Commands You Actually Need

```
i        enter insert mode (start typing)
Esc      leave insert mode, back to normal
:w       write (save)
:q       quit
:wq      write and quit
dd       delete the current line
/word    search for "word"
```

That's genuinely enough to survive. Open a scratch file and practice: `vi scratch.txt`, press `i`, type a sentence, press `Esc`, then `:wq`.

### 0.5.4 When to Reach for It

vi is not this book's daily driver — most of your editing will happen in whatever full editor you're comfortable with, or through the agent itself. Treat vi as a tool for the specific situation where nothing else is available, not as something you need to master.

## 0.6 Python 3.12

### 0.6.1 Installing

Download Python 3.12 from [python.org](https://www.python.org/downloads/) or install it via your package manager. This book uses 3.12 specifically — later chapters rely on language features and standard-library behavior introduced by that version, so an older Python may produce confusing, version-specific errors that have nothing to do with your code.

### 0.6.2 Checking Your Install

```bash
python3 --version
```

You're looking for `Python 3.12.x`. If you have multiple versions installed and the wrong one shows up, `uv` (0.7 below) will help you pin the right one per-project, so don't spend too long fighting your system's default.

### 0.6.3 What's Relevant Here

If you've seen Python tutorials from a few years ago, a couple of things have changed enough to be worth a sixty-second note: type hints are more expressive and more commonly used in ordinary code now, not just in large codebases, and error messages are noticeably more specific about *where* and *why* something went wrong. Both matter for this book — you'll be reading type hints throughout, and reading error messages closely is a skill this book leans on more than most.

## 0.7 uv & Good Project Structure

### 0.7.1 What uv Is

`uv` is a fast, modern tool for managing Python projects — dependencies, virtual environments, and the Python version itself, all through one tool instead of the traditional pip-plus-venv-plus-something-else combination. This book uses `uv` throughout because it removes a category of setup friction that has nothing to do with learning software engineering.

Install it following the instructions at [docs.astral.sh/uv](https://docs.astral.sh/uv/), then confirm:

```bash
uv --version
```

### 0.7.2 Initializing the Project

```bash
uv init
```

This generates a `pyproject.toml` — the file that describes your project: its name, its dependencies, and how it's built. You'll come back to this file constantly; every `uv add` command in later chapters edits it for you.

### 0.7.3 Project Layout

This book uses a **src layout**: your actual package lives inside a `src/` directory, rather than sitting directly in the project root.

```
mortgage-calculator/
|-- pyproject.toml
|-- uv.lock
|-- README.md
|-- SPEC.md
|-- src/
|   `-- mortgage_calculator/
|       `-- __init__.py
`-- tests/
```

The reason: a src layout forces your code to be *installed* to be imported, the same way it would be for anyone else using it — which catches a whole class of "works on my machine because I happened to be in the right directory" bugs before they happen. It's a small amount of extra structure up front that pays for itself the moment you write your first test in Chapter 5.

### 0.7.4 Adding a Dependency

```bash
uv add requests
```

This updates `pyproject.toml` and creates (or updates) `uv.lock` — a file that pins the *exact* version of every dependency, direct and indirect, so that "it works on my machine" means the same thing on any machine that runs `uv sync`. You won't need any dependencies yet in this chapter; you'll see this command for real starting in Chapter 5.

### 0.7.5 The Skeleton You're Building Toward

By the end of this chapter, your project should match the layout above, minus anything you haven't built yet — just `pyproject.toml`, `uv.lock`, an empty `README.md` and `SPEC.md`, and an empty `mortgage_calculator` package. Every later chapter adds to this same skeleton; nothing gets rebuilt from scratch.

Confirm it works:

```bash
uv run python -c "import mortgage_calculator; print('ok')"
```

If that prints `ok`, your project is wired together correctly.

## 0.8 Checkpoint

Before moving to Chapter 1, this should all be true:

- [ ] You can open a terminal and navigate with `pwd`, `ls`, `cd`
- [ ] Git is installed and configured with your name and email
- [ ] `mortgage-calculator` is a git repository with at least one commit
- [ ] That repository is pushed to a GitHub repo you created
- [ ] You can open, edit, and save a file in vi without help
- [ ] `python3 --version` reports 3.12.x
- [ ] `uv run python -c "import mortgage_calculator; print('ok')"` prints `ok`

**What's next:** Chapter 1 hands this repository to a coding agent for the first time — installing Pi, connecting it to a local model, and making your first small, reviewed, agent-assisted change.
