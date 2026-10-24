---
name: sz-work
description: Start work on an existing Linear ticket - read it, check what it depends on, and create or switch to its branch with sz-branch. Use only when the user asks to start or pick up a ticket.
disable-model-invocation: true
---

# Ticket start

Get the user onto the right branch for a Linear ticket, branched from the
right place. You read the ticket and its dependencies in Linear and decide
where to branch from; the `sz-branch` script does all the git work.

## Rules

- Change branches only through `sz-branch switch`. Never run `git switch`,
  `git checkout`, `git branch`, `git stash` or `git reset` yourself.
- Read Linear freely; change it only after the user says yes to the exact
  change (link, comment, status). Everything you write there is visible to
  the team.
- Never guess a ticket number, a cycle or a dependency. If Linear does not
  say, ask.

## 1. Read the state

```sh
sz-commit config
git status --short
```

- `prefix:` says `(not set, ...)`: ask the user which ticket prefix this
  repo uses, save it with `sz-commit ticket-prefix PREFIX`, and run
  `sz-commit config` again.
- `ticket:` is the ticket of the branch you are on (call it the *current
  ticket*); empty when you are on `main` or another non-ticket branch.

## 2. Read the ticket

With the Linear MCP server (`linear-server`), read the target ticket:
title, status, cycle (its number), parent, sub-issues, and its relations,
especially the tickets it is **blocked by**. If the ticket does not exist,
stop and say so.

Show the user one short summary: id, title, status, cycle, and what it
depends on (blocked by, parent).

## 3. Decide where to branch from

Run `sz-branch find TARGET` first. If the target already has a branch,
skip to step 4: `switch` just goes to it, and there is no base to choose.

Otherwise, pick the case that matches:

| Target depends on (blocked by / parent) | You are on | Do |
|---|---|---|
| Ticket D | D's branch | Branch from here. No question. |
| Ticket D | another branch | Ask: branch from D's branch (recommended; find it with `sz-branch find D`), from here anyway, or from `main`. |
| Nothing | the current ticket's branch (C) | Ask: "Branch TARGET from C? That makes TARGET depend on C." If yes, branch from here and do step 5. If no, ask where to branch from instead (usually `main`). |
| Nothing | `main` or a non-ticket branch | Branch from here. No question. |

If D has no branch at all, say so and ask where to branch from.

## 4. Switch

Pass the base with `-f` only when it differs from where you are now, and
the cycle with `-c` when Linear gives one:

```sh
sz-branch check -c 12 -f c12/pro-2 PRO-3
```

Show its output. When step 3 asked nothing, go ahead; otherwise you already
have the user's answer. Then run the same arguments with `switch`:

```sh
sz-branch switch -c 12 -f c12/pro-2 PRO-3
```

If it refuses (several branches, git would overwrite a file), stop and show
the message. Do not work around it.

## 5. Record a new dependency

Only when the user agreed in step 3 to branch the target from the current
ticket C, and Linear did not already record it. Show the user exactly what
you will write, and after they say yes, in Linear:

1. Make the target a **sub-issue** of C.
2. Mark the target as **blocked by** C.
3. Comment on both tickets, one or two sentences: the target is branched
   from C's branch (name both branches), so it builds on C's changes and
   should merge after it.

If the MCP server cannot set one of these, say which, and give the user the
text to add by hand.

## 6. Status

Offer once: "Move TARGET to In Progress in Linear?" Change it only on yes.

## 7. Report

Run `git status --short` and `sz-commit config`, show the branch you are on
now, and list what you changed in Linear (or "nothing").
