---
name: commit-plan
description: Split the current uncommitted changes into a reviewed plan of whole-file conventional commits, then run it with sz-commit. Use only when the user asks for a commit plan.
disable-model-invocation: true
---

# Commit plan

Turn the working tree's changes into a short list of commits the user reviews
before anything is committed. You decide the grouping and the wording; the
`sz-commit` script decides whether they are valid and does all staging and
committing.

## Rules

- Commit only through `sz-commit apply`. Never run `git add`, `git commit`,
  `git reset` or `git stash` yourself, and never pass `--no-verify`.
- Whole files only. If one file mixes two concerns, keep it whole, put it in
  the commit of its main concern and say so in the plan.
- Never add a `Co-authored-by` trailer, a "Generated with" footer or any other
  attribution. `sz-commit` rejects them anyway.
- Do not edit files to make a commit pass. If a repo hook (lint, tests)
  rejects a commit, stop and report.

## 1. Read the state

Run these and read the output:

```sh
sz-commit config
git status --porcelain --untracked-files=all
git diff
git diff --cached --stat
```

`config` lists the allowed types, the scopes for this repo with the paths
mapped to them, and the ticket parsed from the branch. If no scopes are
configured, read `setup.md` next to this file and do that one-time setup
first, then continue here.

If `git diff --cached --stat` shows staged changes, stop and ask the user
whether to unstage them; `sz-commit` refuses to run on a dirty index.

Read untracked files before grouping them. `git diff` does not show them.

## 2. Group

- Run `sz-commit scope-of` once with every changed file. It prints the
  scope each file belongs to, or `-` when no mapping covers it.
- One logical change per commit, one scope per commit. Use the scope
  `scope-of` reports; for `-` files pick the closest scope from the list
  (often `deps`, `ci` or `repo`).
- If unmapped files sit in a new folder that looks like a new service or
  area, propose a `sz-commit scope-add NAME PATH` as the plan's first step
  instead of forcing them into an existing scope.
- Order commits so each one makes sense on top of the previous ones
  (shared code and config before the code that uses it).
- Leave out files that look accidental (debug output, local env files) and
  list them under "Not committed".

## 3. Word each commit

- `-t` type: the conventional commit type that fits (`feat`, `fix`,
  `refactor`, `chore`, ...), from the configured list.
- `-m` subject: imperative, lower case, no trailing period, specific enough
  to find with `git log --grep` ("validate webhook signature", not
  "update handler"). The full header must fit in the configured max.
- `-b` body: only when the reason is not obvious from the diff. One to three
  sentences on *why*, or what a future reader debugging this would need
  (a constraint, a rejected alternative, a linked incident). Repeat `-b` for
  separate paragraphs. Do not describe what the diff already shows.
- `-B` only for a breaking change to an interface other services use.
- Leave the ticket alone; `sz-commit` adds `Refs: PRO-<n>` from the branch.
  Pass `-r PRO-<n>` only if the user names a different ticket.

## 4. Validate

Run `sz-commit check` with exactly the arguments you plan to use, once per
commit. Fix anything it rejects and check again. Every commit must pass
before you show the plan.

## 5. Present the plan

Show a numbered list. For each commit: one line saying what it groups and why,
then the exact command in a `sh` code block:

```sh
sz-commit apply -t feat -s api -m "validate webhook signature" -- services/api/webhook.ts services/api/webhook.test.ts
```

Paths are relative to the repo root, as `git status --porcelain` prints them.
Quote any path with spaces or shell characters.

End with "Not committed:" listing any changed files left out, or "none".

Then wait. The user may edit the plan (in Claude Code plan mode, Ctrl+G opens
it in their editor). Run only what they approve, as they left it.

## 6. Apply

Run the approved `sz-commit apply` commands one per tool call, in order. On
the first failure, stop: show the output, say which commits landed, and
do nothing else. `sz-commit` has already unstaged the failed commit's files.

Finish by running `sz-commit summary <number of commits applied>` and
`git status --short`, and show both outputs to the user as they are, in
code blocks. The summary lists each commit with its files as a tree.

## 7. Resume after a failure

When the user has fixed the problem and asks to continue:

1. Run `git status --porcelain --untracked-files=all`.
2. Run `sz-commit check` for the failed commit and every commit after it.
3. If all pass and no file outside the remaining commits changed, show the
   remaining commands and apply them after the user approves.
4. Otherwise (the fix touched other files, or a check fails), plan again from
   step 1 for what is left uncommitted. Commits that already landed stay.
