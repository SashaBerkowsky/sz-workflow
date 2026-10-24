---
name: commit-plan
description: Split the current uncommitted changes into whole-file conventional commits, validate them and commit them with sz-commit. Use only when the user asks for a commit plan.
disable-model-invocation: true
---

# Commit plan

Turn the working tree's changes into a short list of commits and commit them.
You decide the grouping and the wording; the `sz-commit` script decides
whether they are valid and does all staging and committing. The user reviews
the result afterwards, in the summary tree; commits stay local, so nothing
here is outward-facing.

## Rules

- Commit only through `sz-commit apply`, and uncommit only through
  `sz-commit undo`. Never run `git add`, `git commit`, `git reset` or
  `git stash` yourself, and never pass `--no-verify`.
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
mapped to them, the ticket prefix and the ticket parsed from the branch. If
no scopes are configured, read `setup.md` next to this file and do that
one-time setup first, then continue here.

If `prefix:` says `(not set, ...)`, ask the user which ticket prefix this
repo uses (`pro`, `sza`, ...) and save their answer with
`sz-commit ticket-prefix PREFIX`. Do this once per clone, then run
`sz-commit config` again.

If `ticket:` is empty, ask the user once for the whole plan whether to
reference a ticket. If they give one, pass `-r PREFIX-<n>` on every commit;
if not, pass `-R` on every commit. Never guess a ticket number.

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
- When the branch has a ticket, leave it alone; `sz-commit` adds
  `Refs: PREFIX-<n>` from the branch. Pass `-r PREFIX-<n>` only if the user
  names a different ticket. With no ticket on the branch, use what the user
  chose in step 1.

## 4. Validate

Run `sz-commit check` with exactly the arguments you plan to use, once per
commit. Fix anything it rejects and check again. Every commit must pass
before you apply any of them.

Paths are relative to the repo root, as `git status --porcelain` prints them.
Quote any path with spaces or shell characters.

## 5. Apply

Do not stop to ask for approval of the plan; go straight to applying it.
If the user asked to review the plan first this time, show the numbered
`sz-commit apply` commands and wait instead.

Run the `sz-commit apply` commands one per tool call, in order. On the first
failure, stop: show the output, say which commits landed, and do nothing
else. `sz-commit` has already unstaged the failed commit's files.

## 6. Report

Run `sz-commit summary <number of commits applied>` and `git status --short`,
and show both outputs to the user as they are, in code blocks. The summary
lists each commit with its files as a tree.

End with "Not committed:" listing any changed files left out and why, or
"none".

## 7. Resume after a failure

When the user has fixed the problem and asks to continue:

1. Run `git status --porcelain --untracked-files=all`.
2. Run `sz-commit check` for the failed commit and every commit after it.
3. If all pass and no file outside the remaining commits changed, apply
   them and report as in step 6.
4. Otherwise (the fix touched other files, or a check fails), plan again from
   step 1 for what is left uncommitted. Commits that already landed stay.

## 8. Redo the last run

When the user says the last run missed something and wants the new or
forgotten changes folded into those commits, rather than added as a new one:

1. Work out N, the number of commits the last run applied: from this
   conversation, or from `sz-commit summary` / `git log --oneline` together
   with the user. If unsure, ask; never guess.
2. Run `sz-commit undo --dry-run N` and check that it lists exactly the
   last run's commits. If it refuses (pushed, merge, staged changes), stop
   and show the message; do not work around it.
3. Run `sz-commit undo N`. Their changes go back to the working tree,
   uncommitted, next to the new ones. Keep the `git reset <hash>` line it
   prints, in case the user wants the old commits back.
4. Plan again from step 1 with everything that is now uncommitted, reusing
   the earlier grouping and wording where it still fits, and apply as usual.
