---
name: sz-split
description: Split the current ticket's big branch into Linear sub-issues - parallel, stacked or a mix - from its uncommitted changes, iterate on the split with the user, create the sub-issues and blockers after approval, and optionally write a context file for later sessions. Use only when the user asks to split a ticket or a branch.
disable-model-invocation: true
---

# Ticket split

Split the ticket you are on into sub-issues, when the branch grew too big:
something else turned up along the way, or the ticket was scoped larger
than it looked. You read the changes and propose how to split them; the
user shapes the split until it's right. Then you create the sub-issues in
Linear and, if the user wants, write a context file so each sub-issue's
background survives across sessions.

## Rules

- Create or change nothing in Linear before the user approves the exact
  split (step 6). Everything you write there is visible to the team.
- Don't touch the code or git: no commits, stashes, branch switches or
  edits. The changes stay where they are; step 9 says how to carry them
  to each sub-issue's branch.
- Every changed file goes to exactly one sub-issue, or stays on the
  current ticket. Never drop one silently.
- Write only what the changes, the ticket and this session show. Mark
  guesses as guesses, and never paste secrets, tokens or personal data
  into Linear or the context file.
- Never guess a ticket number. If the branch has none, ask.

## 1. Read the state

```sh
sz-commit config
git status --porcelain --untracked-files=all
git diff --stat
git diff
```

- `ticket:` empty: ask the user which ticket to split, and stop if there is
  none. This skill doesn't change branches; if they mean another ticket's
  branch, suggest `/sz-work` first.
- Read untracked files too; `git diff` doesn't show them. For a large diff,
  start from `--stat` and read the files that matter.
- Commits already on the branch (`git log --oneline origin/BASE..HEAD`,
  with BASE the branch it was made from) stay with the current ticket:
  this skill splits only uncommitted work. Say so if there are any.

## 2. Read the ticket

With the Linear MCP server (`linear-server`), read the current ticket:
title, description, status, team, project, parent, sub-issues, relations
and comments. Ask for `cycleId` explicitly (`fields` with `cycleId`), as in
`sz-work`. Keep its URL, team, project and cycle for step 7.

If it already has sub-issues, show them: the split adds to them, and may
cover work one of them already has.

## 3. Propose the split

Group the changes by what they do, not by folder: each sub-issue is one
piece of work a reviewer could take on its own. `sz-commit scope-of` with
the changed files helps see where they belong. A sub-issue can also cover
work not started yet (what the ticket still asks for, or what turned up),
with no files.

Then pick the mode from how the pieces depend on each other:

- **Parallel**: independent pieces. Each sub-issue branches from the
  current ticket's branch and merges back into it. No blockers.
- **Stacked**: a chain. Each sub-issue is blocked by the previous one,
  branches from its branch and merges into it.
- **Hybrid**: some of each. A sub-issue blocked by two others can only
  start once both are merged into the current ticket's branch; say so in
  its line.

Recommend the mode that fits and say why in one line. The user may pick
another.

## 4. Show the tree

Number the sub-issues in the order to work on them, blockers first. One
line for the title (imperative, specific, like a ticket title), one or two
for the description, then the files:

```
SZA-7 Import customers from CSV  (current · c12/sza-7)
│  mode: hybrid · order: 1 and 2 in parallel, then 3
│
├── 1  Parse the CSV header                          parallel
│      Map header names to customer fields and reject unknown columns.
│      files: src/import/header.ts, src/import/header.test.ts
│
├── 2  Validate customer rows                        parallel
│      Check required fields and formats before anything is saved.
│      files: src/import/validate.ts
│
└── 3  Report rows that failed                       blocked by 2
       Show which rows failed validation, and why, after the import.
       files: (not started)

Stays on SZA-7: src/import/index.ts (wires the pieces together)
```

Under the tree, give in one or two sentences why it splits this way: what
turned up or what was bigger than scoped.

## 5. Iterate

Wait. The user may rename, merge or split sub-issues, move files between
them, reorder them, change a blocker or the mode. Show the whole tree again
after each change, renumbered, and check that every changed file is still
in it. Repeat until the user says the split is right.

## 6. Approve

Show, in this order:

1. The final tree.
2. What each sub-issue gets in Linear: the current ticket as parent, the
   same team, project and cycle as the current ticket, and its blockers
   (`blocked by` the sub-issue numbers, which become ids once created).
3. The description of each sub-issue, in this shape:

   ```markdown
   <what it does and why it's a piece of its own, two to four sentences>

   **Scope**
   - <what's in, one line each; files or areas when there are any>

   **Out of scope**
   - <what belongs to a sibling, naming it>

   Split from SZA-7.
   ```

4. The comment for the current ticket: one or two sentences on why it was
   split, the mode, and the sub-issues in order, one line each with what
   blocks it. The ids are filled in after creation.

Then ask, in one message:

- whether to assign the sub-issues to them;
- whether they want a context file, so each sub-issue's background carries
  across sessions (step 8).

Wait for a yes. If they change anything, show the changed parts and wait
again.

## 7. Create in Linear

Create the sub-issues in the numbered order, so blockers exist before the
issues they block. For each, with `save_issue`: `title`, `description`,
`team`, `parentId` (the current ticket), `project` and `cycle` when the
current ticket has them, `blockedBy` with the ids of its blockers created
before it, and `assignee: "me"` if the user said yes.

Then add the comment to the current ticket, with the new ids in it.

If a call fails, stop: say which sub-issues were created (with ids), what
is missing, and give the text to add by hand. Don't retry with other
arguments.

## 8. Context file

Only if the user said yes in step 6.

**Where.** Look for a gitignored folder for plans or notes in the repo
root: `plans/`, `.plans/`, `context-notes/`, `.context-notes/`, `notes/`,
`.notes/`, or one the repo already uses for the same. Check each that
exists with `git check-ignore -q -- FOLDER`.

- One found: use it.
- Several: ask which one.
- None: ask the user where to save it. If the path they give isn't
  ignored, say that it will show up in `git status` and could be
  committed, and ask whether to use it anyway or pick another.

**Name.** `<ticket>-split.md` in lower case (`sza-7-split.md`). If it
exists, ask whether to add a new dated section to it or use another name;
never overwrite it.

**Contents.** It names the current ticket and every sub-issue id, so
`/sz-work` and `/sz-pr` find it later:

```markdown
# SZA-7 split · Import customers from CSV

[SZA-7](<url>) · branch c12/sza-7 · split on 2026-10-26 · mode hybrid

## Why it was split
<what turned up or what was bigger than scoped, two to four sentences>

## Order
| # | Ticket | Title | Blocked by | Branch from | Status |
|---|---|---|---|---|---|
| 1 | [SZA-8](<url>) | Parse the CSV header | - | c12/sza-7 | Todo |
| 2 | [SZA-9](<url>) | Validate customer rows | - | c12/sza-7 | Todo |
| 3 | [SZA-10](<url>) | Report rows that failed | SZA-9 | sza-9 | Todo |

Stays on SZA-7: src/import/index.ts

## Shared context
<what every sub-issue needs to know: decisions already made and why,
constraints, conventions, what was tried and dropped>

## SZA-8 · Parse the CSV header
- **What**: <the description, in short>
- **Files**: <the files from the split, or "not started">
- **Context**: <what someone starting this cold needs: where in the code,
  what the current changes already do, open questions, gotchas>
- **Done when**: <how to tell it's finished>
```

One `## <id> · <title>` section per sub-issue. The Status column is
Linear's status at the time of the split; `/sz-work` and `/sz-pr` update it
when they move a sub-issue.

## 9. Report

Show:

- the sub-issues created, with ids and URLs, in order, and what blocks
  each;
- that the comment was added to the current ticket;
- the context file's path, or that none was written.

Then say how to carry on: start a sub-issue with `/sz-work SZA-8`. It
branches from the right place (the current ticket's branch, or its
blocker's), and `git switch` carries the uncommitted changes along, so
commit that sub-issue's files there with `/sz-commit` and leave the rest
uncommitted for the next one. Stop there.
