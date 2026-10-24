---
name: sz-new
description: Turn a problem or bug the user saw into a new Linear ticket - gather the facts, draft it from the team's matching issue template, and create it after approval. Use only when the user asks to create or file a ticket.
disable-model-invocation: true
---

# Ticket new

Turn something the user noticed into a Linear ticket that someone else could
pick up without asking them questions. You gather the facts, pick the
team's issue template that fits, and write the draft; the user approves it
before anything is created.

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

## 3. Pick a template

List the team's issue templates with the Linear MCP server
(`list_templates` for the team, type `issue`); the result includes the
workspace-level ones too.

- **None:** use the fixed shape in step 4.
- **One or more:** from the facts in step 2, infer what kind of ticket this
  is (a bug, a feature request, a chore, ...) and pick the template made
  for that kind, by its name and content. Say which one you picked and
  why.
  - Several could fit, or you can't tell what kind of ticket this is: ask
    the user to pick, listing each template's name, plus "no template (the
    fixed shape)".
  - None fits: use the fixed shape, and say so.

Read the picked template with `get_template`: its body, the labels and
fields it sets, its sub-issues, and whether it is a **form template** (it
has form fields).

**Form templates.** Use a form template like any other when it is the one
that fits; don't skip it. Fill its form fields from the facts, as you
would sections. If the MCP server gives no way to submit form answers (at
the time of writing, `get_template` says applying a form template creates
the issue with the form unanswered), tell the user before drafting, and
ask:

- create it from the form template anyway, with the form unanswered and
  your answers written in the description, under the field names, so they
  can copy them into the form in Linear; or
- use another template, or the fixed shape.

## 4. Draft

**With a template:** keep its headings and their order, and fill each
section from the facts. Write "n/a" in a section that doesn't apply rather
than delete it, and keep its checkboxes, ticking only what is true. Show
the draft as:

```
Team:      SZA
Template:  <name>  (<why it fits>)
Title:     <specific, as in the fixed shape below>
Applies:   <labels, fields and sub-issues the template sets>
Labels:    <extra labels, only ones that exist in the team>
Priority:  <only if the user said, or it clearly blocks work>

<the filled template body>
```

**Without a template**, show the draft in this shape:

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

Leave out empty sections.

Either way, wait for the user to approve or edit the draft.

## 5. Create

Create the ticket with the Linear MCP server (`linear-server`), exactly as
approved. With a template, pass it as `template` together with the filled
body as `description`: the description replaces the template's body, while
its labels, fields and sub-issues are still applied. Show the ticket's id
and URL, and what the template added (labels, sub-issues).

## 6. Next

Offer once: "Start working on it now?" If yes, follow the `sz-work`
skill for the new ticket.
