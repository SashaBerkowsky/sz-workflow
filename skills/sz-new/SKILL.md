---
name: sz-new
description: Turn a problem or bug the user saw into a new Linear ticket - gather the facts, draft it, and create it after approval. Use only when the user asks to create or file a ticket.
disable-model-invocation: true
---

# Ticket new

Turn something the user noticed into a Linear ticket that someone else could
pick up without asking them questions. You gather the facts and write the
draft; the user approves it before anything is created.

## Rules

- Create or change nothing in Linear before the user approves the exact
  draft. A ticket is visible to the whole team.
- Write only what you saw or the user told you. Mark guesses as guesses
  ("likely cause: ..."), and leave out what you don't know.
- Never paste secrets, tokens, personal data or full env files into a
  ticket. Trim logs to the lines that matter.

## 1. Find the team

```sh
sz-commit config
```

- `prefix:` set (e.g. `sza`): use the Linear team whose issue key matches
  it (`SZA`). If no team or several teams match, ask.
- `prefix:` says `(not set, ...)`: ask the user which team, then offer to
  save its key as this repo's prefix with `sz-commit ticket-prefix PREFIX`.

## 2. Gather the facts

From what the user said, and from anything they point you to (a file, an
error, a log, a failing command), work out:

- what happens, and what should happen instead;
- how to reproduce it, as steps;
- where in the code it likely lives (paths, with line numbers if you found
  them);
- how bad it is: who or what it blocks.

Read the code they mention; run read-only commands to reproduce if that is
cheap and safe. Ask at most two short questions, only for things the draft
can't do without.

Search Linear for an existing ticket about the same problem. If you find a
likely duplicate, show it and ask whether to go on.

## 3. Draft

Show the draft in this shape:

```
Team:     SZA
Title:    <imperative or symptom, specific: "Login fails when email has a plus sign">
Labels:   <only labels that exist in the team, e.g. Bug>
Priority: <only if the user said, or it clearly blocks work>

## What happens
## Expected
## Steps to reproduce
## Where to look
## Notes
```

Leave out empty sections. Then wait for the user to approve or edit it.

## 4. Create

Create the ticket with the Linear MCP server (`linear-server`), exactly as
approved. Show its id and URL.

## 5. Next

Offer once: "Start working on it now?" If yes, follow the `sz-work`
skill for the new ticket.
