---
name: sz-pr
description: Draft a pull request for the current ticket's branch - title in the commit standard, description from the repo's PR template, the ticket and any notes or plans - and push and open it after approval. Use only when the user asks to open a PR.
disable-model-invocation: true
---

# PR open

Open a pull request for the branch you are on. You read the branch, the
ticket and any notes about it, and write the title and description; the user
approves the exact commands before anything is pushed or created. Pushing
and opening a PR are outward-facing, so nothing here runs on its own.

## Rules

- Run `git push` and `gh pr create` only after the user says yes to the
  exact commands, and only as shown. Never force-push, and never pass
  `--no-verify`.
- Never add a `Co-authored-by` trailer, a "Generated with" footer or any
  other AI attribution to the title or description. Nothing checks this for
  you; check the draft yourself before showing it.
- Write only what the commits, the ticket, the notes and this session show.
  Leave out what you don't know rather than guess.
- Never paste secrets, tokens or personal data from notes into the PR.
- In Linear, change only the PR link (step 9) and the ticket's status
  (step 10), and only as part of what the user approved in step 7. Change
  nothing else there without the user's yes to the exact change.

## 1. Read the state

```sh
sz-commit config
git status --short
git remote
gh pr view --json url,state,baseRefName
```

- `ticket:` empty: ask the user which ticket the PR is for, or whether it
  has none. Never guess one.
- Uncommitted changes: say which files, and ask whether to commit them first
  (with the `sz-commit` skill) or leave them out of the PR. They are never
  part of it on their own.
- More than one remote, or none named `origin`: ask which one to push to.
- `gh pr view` finds a PR for this branch: show its URL and state and stop.
  This skill only opens new PRs.
- `gh` is missing or not logged in: stop and say so (`gh auth login`).

## 2. Read the ticket

With the Linear MCP server (`linear-server`), read the branch's ticket:
title, description, URL, parent, sub-issues, and the tickets it is
**blocked by**. Keep the ids of the ticket, its parent and its sub-issues
for step 4, and the ticket's URL for step 6.

## 3. Pick the base

The PR merges into the branch the work was built on:

- The ticket is blocked by, or is a sub-issue of, ticket D (when it is
  both, as a stacked sub-issue from `/sz-split` is, D is the blocker; when
  several tickets block it, ask which branch it was built on): find D's branch
  with `sz-branch find D` and its PR with
  `gh pr list --head <D's branch> --state all --json number,state,baseRefName`.
  - D's PR is open: the base is D's branch (a stacked PR). Say that it
    should merge after D's, and that GitHub retargets it to D's base when
    D's branch is deleted on merge.
  - D's PR is merged, or D has no branch: the base is the default branch.
  - D has a branch but no PR: ask whether to open D's PR first, or to base
    this one on the default branch (it would then include D's commits).
- Otherwise the base is the repo's default branch
  (`gh repo view --json defaultBranchRef`).

Then read what the PR contains:

```sh
git log --oneline origin/BASE..HEAD
git diff --stat origin/BASE...HEAD
git diff --name-only origin/BASE...HEAD
```

If `origin/BASE` is missing or stale, `git fetch origin BASE` first. If the
log is empty, stop: there is nothing to open a PR for.

## 4. Gather context

Use, in this order of weight: what this session did and decided, the
commits, the ticket, and notes or plans that belong to the ticket.

**Notes and plans.** Repos differ: some keep them in the repo, some in
gitignored local files, many have none. Look every time, and don't assume:

1. List candidates, tracked and gitignored:

   ```sh
   git ls-files
   git ls-files --others --ignored --exclude-standard --directory
   ```

   Candidates are files under folders or with names like `plans/`,
   `notes/`, `docs/plans/`, `docs/notes/`, `.plans/`, `.notes/`,
   `context/`, `scratch/`, `PLAN.md`, `PLANS.md`, `NOTES.md`, `TODO.md`,
   or anything else whose name says it holds plans or notes for the work.
   Don't descend into dependency or build folders (`node_modules/`,
   `dist/`, `vendor/`, ...).
2. Keep only files that belong to the work: their path or contents mention
   the ticket, its parent or one of its sub-issues, in any case
   (`SZA-6`, `sza-6`). Search inside candidates with
   `grep -il -e SZA-6 -e SZA-5 -- FILE...`.
3. Read what is left, and use what explains the change: the goal, the
   decisions and why, what was left out on purpose.

Tell the user which notes you used, or that you found none, in which case
the description comes from the session, the commits and the ticket.

## 5. Write the title

`type(scope): TICKET subject`, the commit standard with the ticket in
front of the subject:

```
feat(pr): SZA-6 add a skill that opens a PR
```

- `type`: one of the `types:` from `sz-commit config`, for the PR as a
  whole (a feature with its docs and fixes is `feat`).
- `scope`: run `sz-commit scope-of` on the files from step 3.
  - They all belong to one scope: use it.
  - They span several scopes, or none, or the repo has no scopes: pick one
    from context, either the scope most of the change is in or a broader
    name that covers them all, and say what you chose and why.
- `TICKET`: the branch's ticket from step 1, in upper case (`SZA-6`), with
  no brackets. Leave it out when the PR has no ticket.
- `subject`: imperative, lower case, no trailing period, what the PR does
  as a whole ("add a skill that opens a PR", not "sz-pr changes").
- The whole title, ticket included, fits in `max:` from `sz-commit config`.

## 6. Write the description

**Template.** Look for the repo's PR template, matching file and folder
names in any case:

- `pull_request_template.md` in the repo root, `docs/` or `.github/`;
- a `PULL_REQUEST_TEMPLATE/` folder in any of those three, which may hold
  several templates.

One template: follow it. Fill every section; write "n/a" in a section that
doesn't apply rather than delete it, and keep its checkboxes, ticking only
what is true. Several: ask the user which one. None: use this shape:

```markdown
## Summary
<one to three sentences: what this PR does and why>

## Changes
- <one line per logical change, the way a reviewer would group them>

## Notes
<decisions, things left out on purpose, how to test; omit if empty>

Refs: [SZA-6](https://linear.app/<workspace>/issue/SZA-6/...)
```

Either way, end with `Refs: [<ticket>](<ticket URL>)`, the branch's ticket
linked to its Linear page, unless the template already has a place for the
ticket (then put the same link there) or the PR has no ticket. Use the URL
Linear returned in step 2; never build one by hand. Keep it at the end so
the summary is what shows in previews and notifications. Don't list every
file or repeat the diff; a reviewer reads that in the PR.

## 7. Approve

Show the user, in this order:

1. The base, and why (from step 3), and the scope choice, if you made one.
2. The notes you used, or "none found".
3. The exact commands, in one code block:

```sh
git push -u origin sza-6
gh pr create --base main --head sza-6 \
  --title 'feat(pr): SZA-6 add a skill that opens a PR for the current ticket' \
  --body-file - <<'EOF'
## Summary
...

Refs: SZA-6
EOF
```

Leave out `git push` when the branch is already pushed and up to date
(`git status` says so). Quote the title with single quotes; if it contains
one, write it as `'\''`. Keep the heredoc delimiter quoted (`<<'EOF'`) so
nothing in the body is expanded, and pick another delimiter if `EOF`
appears in the body. Add `--draft` only if the user explicitly asks for a
draft; otherwise the PR is always ready for review.

Under the commands, say what happens in Linear afterwards: "then link the
PR to <ticket> if Linear's GitHub integration doesn't", and, for a PR that
is not a draft, "move <ticket> to In Review". A draft keeps its status.

Wait for a yes. If the user edits the title or description, show the
updated commands and wait again.

## 8. Open

Run the approved commands exactly, one per tool call. If `git push` fails
(rejected, hook failure), stop and show the output; do not retry with other
flags. If `gh pr create` fails, show the output and stop.

## 9. Link the PR to the ticket

Linear's GitHub integration links the PR by itself when it is set up (the
ticket id is in the branch name or title). The MCP server can't read
whether it is, so find out from what it does, and link by hand only when it
didn't, to avoid a duplicate link:

1. Read the ticket's attachments with the Linear MCP server. If one points
   to the new PR's URL, the integration linked it; go on to step 10.
2. If not, wait about 30 seconds (the integration usually links within a
   few) and read them again.
3. Still not there: the integration is not set up, or not for this repo.
   Add the PR's URL to the ticket as a link titled
   `PR #<number>: <PR title>`, and say in the report that you linked it by
   hand and that the integration doesn't seem to be on.

Skip this step when the PR has no ticket.

## 10. Move the ticket

Only when the PR was opened as ready for review (not `--draft`), and the PR
has a ticket:

1. Read the ticket's status. If it is already In Review, or further on (the
   GitHub integration may have moved it), leave it.
2. Otherwise move it to the team's In Review status with the Linear MCP
   server. If the team has no status of that name, don't pick another one;
   say so in the report.
3. If a notes file from step 4 has an Order table listing the ticket (a
   `/sz-split` context file), update its Status cell to match.

For a draft PR, leave the ticket as it is.

## 11. Report

Show the PR's URL, how it got linked to the ticket (by the integration, or
by hand), and the ticket's status in Linear: moved to In Review, already
there, left as it is (draft), or not moved and why.
