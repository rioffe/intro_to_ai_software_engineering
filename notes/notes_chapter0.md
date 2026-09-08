# Notes


## 0.4.2

The instructions there are: 

```bash
git remote add origin https://github.com/your-username/mortgage-calculator.git
git branch -M main
git push -u origin main
```

you should actually do the following: 

```bash
# 1. Create the empty repo on GitHub first (do this in your browser
#    at https://github.com/new  — name it "mortgage-calculator-book",
#    do NOT initialize with a README/.gitignore), OR via CLI:
gh repo create mortgage-calculator-book --public --source . --remote origin
# 2. If you used the browser instead, add the remote:
git remote add origin git@github.com:YOUR_USERNAME/mortgage-calculator-book.git
# 3. Push main and set upstream:
git push -u origin main   
```

So we should introduce gh as well and talk about ssh keys (a bit involved, but still)

Here screenshots of what is going on and the finnl repo should be in order.
TODO: ask Claude to provide a list of suggested screenshots

## 0.4.3

Looking at a diff: does the reader knows what a diff is? Probably not!
Introduce the diff.

## 0.5.1

editing a file over SSH: does the reader know? Explain better

## 0.5.3

verify with: cat scratch

## 0.6.3

type hints: what are they


## 0.7.1

uv can be installed via package manager as well, e.g. vi brew install uv on Mac

## 0.7.2

Show content of pyproject.toml:

```
cat pyproject.toml                          
[project]
name = "mortgage-calculator-book"
version = "0.1.0"
description = "Add your description here"
readme = "README.md"
authors = [
    { name = "Robert Ioffe", email = "robert.ioffe@vinipuh.com" }
]
requires-python = ">=3.12"
dependencies = []

[project.scripts]
mortgage-calculator-book = "mortgage_calculator_book:main"

[build-system]
requires = ["uv_build>=0.12.5,<0.13.0"]
build-backend = "uv_build"
```

## 0.7.3

Maybe mention tree utility (brew install tree on Mac) and ls -R (or other ways to view directory structure)

Add instructions to commit and push your work so far and verify it on github.com

## 0.8.0

update checkpoint to git add/git commit/git push and inspect github.com to make sure things got there


