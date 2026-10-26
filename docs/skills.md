# Skills

One entry per skill in `skills/`: what it does, why it exists, what it
calls and where it stops for you. How to use them day to day is in
`README.md`; the full decisions are in `docs/decisions.md`.

All of them are started by you only (`disable-model-invocation`, Claude
Code only), and share these rules: scripts in `bin/` do the git work, the
skill does the judgment, and nothing outward-facing happens without your
yes.

## Contents

- [sz-commit](#sz-commit): group changes into commits
- [sz-work](#sz-work): get onto a Linear ticket's branch
- [sz-new](#sz-new): turn a bug you saw into a Linear ticket
- [sz-pr](#sz-pr): open a PR for the current ticket's branch
- [sz-adjust](#sz-adjust): answer a PR's review, list the changes asked for

## sz-commit

**What it's for**: splits the working tree's changes into whole-file
conventional commits, validates each with `sz-commit check`, applies them
and shows the commit tree.

**Why it exists**: grouping and wording need judgment; format, staging and
no attribution are invariants, so the script enforces them and the skill
only passes the variable parts. It commits without asking because the
commits are local, `check` already guards them, and `sz-commit undo` puts
them back.

**Calls**: `sz-commit config`, `scope-of`, `check`, `apply`, `summary`,
`undo`; `setup.md` the first time a repo has no scopes.

**Stops for you**: scope table and ticket prefix the first time, whether to
reference a ticket when the branch has none, and any hook failure.

## sz-work

**What it's for**: reads a Linear ticket and what it depends on, and
creates or switches to its branch, branched from the right place.

**Why it exists**: where to branch from depends on Linear data (blocked by,
parent), which is judgment; naming, reuse and never losing work are
invariants, so `sz-branch` does the git part. Starting a ticket is a
separate moment from committing, so it is its own skill.

**Calls**: `sz-commit config`, `sz-branch find`, `check`, `switch`; the
Linear MCP server.

**Stops for you**: where to branch from when it's unclear, recording a new
dependency in Linear, moving the ticket to In Progress.

## sz-new

**What it's for**: turns a problem you saw into a Linear ticket someone
else could pick up, drafted from the team's matching issue template.

**Why it exists**: tickets written in the moment miss the facts (steps,
expected vs actual) and ignore the team's templates. The skill gathers the
facts from the code or error you point to and checks for duplicates first.

**Calls**: `sz-commit config`; the Linear MCP server.

**Stops for you**: which template when several fit, the exact draft before
it is created, and whether to start on it.

## sz-pr

**What it's for**: drafts a PR for the current branch (title in the commit
standard, description from the repo's PR template, the ticket and any
notes) and pushes and opens it after approval; then moves the ticket to In
Review.

**Why it exists**: hand-written PRs didn't follow the commit standard or
the template. It stacks the PR on the branch the work was built on, so the
diff shows only this ticket. No script: the title and no-attribution rules
are enforced by the skill's wording only.

**Calls**: `sz-commit config`, `scope-of`, `sz-branch find`, `git push`,
`gh pr view`, `list`, `create`; the Linear MCP server.

**Stops for you**: uncommitted changes, which remote, and the exact push
and create commands.

## sz-adjust

**What it's for**: works through the review on the current branch's PR:
drafts short replies, in your voice, to questions and small nits, posts
them after approval, then lists the change requests to tackle.

**Why it exists**: answering a review by hand meant writing the same short
replies and rebuilding the to-do list from scattered threads. It reads the
Linear ticket and its comments too, because reviewers often ask about what
the ticket decided or left out. It changes no code and never resolves
threads: what to fix, and when a thread is done, stay your call. No script:
the reply style (no dashes, emojis, SHAs or attribution) is enforced by the
skill's wording only.

**Calls**: `sz-commit config`, `sz-branch find`, `check`, `switch`,
`gh pr view`, `gh api` (threads and thread replies), `gh pr comment`; the
Linear MCP server (read only).

**Stops for you**: which ticket you meant when the branch has no PR or
comments, and the full list of replies before anything is posted.
