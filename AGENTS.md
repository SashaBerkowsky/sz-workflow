# AGENTS.md

Instructions for any AI agent (Claude Code, Codex, others) working **on this
repo**. What was decided and why lives in `docs/decisions.md`. How to install and
use the workflow lives in `README.md`.

## What this repo is

The owner's personal, provider-agnostic AI dev workflow: scripts, skills and
config they install on each machine with `setup.sh`. It is optimised for one
person. Generalising it for a team is a separate, later step that happens
only when the owner asks for it.

Goals, in order:
1. Reduce stress and workload. More output is not a goal.
2. Keep the owner in control of their machine.
3. Stay portable across AI tools (Claude Code today, Codex or others later).

## Core principles

**Prompts for judgment, deterministic mechanisms for invariants.**
Anything that must always hold (message format, what gets staged, no AI
attribution) is enforced by a script, git hook or permission rule, not by
wording in a prompt. Skills handle what needs judgment (grouping, wording,
proposing) and call scripts for everything else.

**Skills call scripts; the model passes only the variable parts.**
A skill never runs the underlying commands (`git add`, `git commit`, ...)
itself. It calls a script in `bin/` with arguments, and the script validates
them and refuses bad input with a clear error. Give each script a `check` or
dry-run mode so a skill can validate a plan before the user sees it.

**The user approves before anything irreversible or outward-facing.**
Skills show the exact commands and wait. Nothing pushes, posts or deletes on
its own. Local commits made through `sz-commit` are the one exception: the
owner reviews them afterwards in the summary tree (see `docs/decisions.md`).

**Minimal footprint.** An automation does its stated job and nothing else:
no stray files, no state in the work tree when `.git/config` or the user's
config will do, no actions beyond what was asked. Installs create symlinks
only, never overwrite what they didn't create, and can be undone. The one
exception is MCP servers: `setup.sh` registers them with each tool's own
`mcp add` command, skips a name that is already taken, and removes them on
uninstall only with `--mcp`. Anything a script writes outside the work tree
(repo settings in `.git/config`, the repo list in `~/.config/sz-workflow`)
must be reset by `setup.sh uninstall`.

**Narrow permissions.** Allow the specific subcommand (`Bash(sz-commit check *)`),
never a broad rule (`Bash(git *)`, `Bash(*)`). Read-only commands may be
allowed; anything that writes stays on `ask`. Never suggest broad allow
rules.

**Portability.** Flag every vendor-specific piece explicitly and name the
portable alternative or fallback. Keep one copy of each skill in `skills/`
(Agent Skills `SKILL.md` format); `setup.sh` links it to each tool's
folder. Vendor-only config goes in `config/` and is merged by hand.

**Balance the owner's way of working with LLM readability.** For every
format or convention (commit messages, file layout, naming), state the
tradeoff between how the owner works and what makes the repo and git
history easy for an LLM session to read, then give a recommendation.

## How to make changes

1. **Before recommending a tool**, check its current state: active
   maintenance, recent releases, a real maintainer or foundation, wide
   adoption. Prefer CLI-first, open-source tools with a track record. If you
   could not verify something, say so. Verify tool-specific details (flags,
   settings keys, file locations) against current docs instead of memory;
   they change.
2. **Link a source only when an authoritative one exists** (official docs,
   the project's own repo or site).
3. **For each new convention**, give the tradeoff and a recommendation.
4. **At the end of each feature**, add a short entry to `docs/decisions.md`:
   what was decided, why, and which tool-specific parts would need redoing
   on migration.
5. Deliverables are plain files: markdown, POSIX shell, JSON. No build step.

## Shell scripts

- Must run unchanged on Linux (GNU userland) and macOS (BSD userland). Use
  only POSIX options of `sed`, `grep`, `awk`, `tr`, `sort` and similar.
  If a GNU-only or BSD-only flag is unavoidable, call it out in a comment and
  offer a portable alternative.
- Default to POSIX `sh` (`#!/bin/sh`, `set -eu`). Use bash only when it buys
  something real, and say so in the header comment.
- Header comment: what the script does, which shell, and the usage.
- Document every script, subcommand and flag in `docs/bin/<script>.md`
  (see Docs below). Update it in the same commit as the script.
- Lint clean with `shellcheck -s sh`. Don't silence a warning without a
  comment explaining why.
- Validate every argument a model can pass. Fail with one clear line on
  stderr and a non-zero exit; never guess.
- Pass paths as data (`--`, `GIT_LITERAL_PATHSPECS=1`), never as patterns.
- Test under both `dash` and `bash` on a scratch repo, including the failure
  paths, before calling a change done.

### Adding a subcommand or flag

Do all of these in one commit, so the script and its docs never disagree:

1. Add it to the script's header comment (the usage block) and to the
   dispatch `case` at the bottom.
2. Validate its arguments as above, and test success and failure paths.
3. Add an entry to `docs/bin/<script>.md`: the synopsis, its
   table-of-contents line, and the template under Docs.
4. If it changes what the user does, update `README.md`. If a skill should
   call it, update that skill's `SKILL.md`.
5. If Claude Code needs a permission rule, add the narrowest one to
   `config/claude-settings.json`: `allow` only if it is read-only, `ask` if
   it writes.

A new script in `bin/` follows the same steps, plus a new
`docs/bin/<script>.md` page and a line in the `README.md` layout tree.
Nothing but executables goes in `bin/`; `setup.sh` links every file there.
A script that saves settings in a repo calls `remember_repo` (see
`bin/sz-commit`), so `setup.sh uninstall` can reset them.

## Docs

Everything that is documentation but not the entry point lives in `docs/`.

| File | Holds | Update when |
|---|---|---|
| `README.md` (root) | Install and day-to-day usage | What the user types or sees changes |
| `AGENTS.md` (root) | Rules for working on the repo | A rule or convention changes |
| `docs/decisions.md` | Decision log, newest entry at the bottom | At the end of each feature |
| `docs/bin/<script>.md` | Manual for one script in `bin/` | A subcommand or flag changes |
| `docs/skills.md` | One entry per skill: what it's for, why it exists, what it calls, where it stops | A skill is added, renamed or changes what it does |

A manual page has a synopsis, a description, the configuration keys and the
exit codes, then one entry per subcommand with:

- **What it's for**: what it does, in one or two sentences.
- **Why it exists**: the problem it solves or who calls it.
- A table of its flags or arguments: name, argument, required, description.
- An example, when the usage isn't obvious.

Keep the script's header comment as the short usage and the manual as the
long form; don't copy the manual into the script.

## Skills

- One folder per skill under `skills/<name>/`, with `SKILL.md` and any
  supporting files the skill reads only when needed (see
  `skills/sz-commit/setup.md`).
- Frontmatter: `name` and `description` are portable. Anything else (for
  example `disable-model-invocation`) is vendor-specific; note it in
  `docs/decisions.md`.
- Spell out the commands the skill runs, the rules it must not break, and
  where it stops for approval or on failure.
- Add or update its entry in `docs/skills.md` in the same commit as the
  skill, and its line in the `README.md` layout tree.

## Repo layout

```
AGENTS.md         this file
README.md         install and usage
docs/             decision log (decisions.md), skills (skills.md), manuals for bin/ (bin/<script>.md)
setup.sh          install, check, status, uninstall (links bin/ and skills/ into $HOME)
bin/              scripts, linked to ~/.local/bin
skills/<name>/    skills, linked to each AI tool's skills folder
config/           vendor-specific config, merged by hand
```

Keep the layout organised by what things are, not by where they get
installed. A new AI tool means one more line in `setup.sh`, not a new
folder.

## Conventions this repo already uses

- Commits: `type(scope): subject` with conventional-commit types, made with
  `sz-commit`, whole files only, `Refs: PRO-<n>` trailer from the branch.
- Never add AI attribution (co-author trailers, "Generated with" footers) to
  commits or PRs.
- Branches: `[c<N>/]pro-<n>` (Linear ticket, optional cycle prefix).
