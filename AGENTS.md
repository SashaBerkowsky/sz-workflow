# AGENTS.md

Instructions for any AI agent (Claude Code, Codex, others) working **on this
repo**. What was decided and why lives in `decisions.md`. How to install and
use the workflow lives in `README.md`.

## What this repo is

The owner's personal, provider-agnostic AI dev workflow: scripts, skills and
config they install on each machine with `install.sh`. It is optimised for one
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
its own.

**Minimal footprint.** An automation does its stated job and nothing else:
no stray files, no state in the work tree when `.git/config` or the user's
config will do, no actions beyond what was asked. Installs create symlinks
only, never overwrite what they didn't create, and can be undone.

**Narrow permissions.** Allow the specific subcommand (`Bash(sz-commit check *)`),
never a broad rule (`Bash(git *)`, `Bash(*)`). Read-only commands may be
allowed; anything that writes stays on `ask`. Never suggest broad allow
rules.

**Portability.** Flag every vendor-specific piece explicitly and name the
portable alternative or fallback. Keep one copy of each skill in `skills/`
(Agent Skills `SKILL.md` format); `install.sh` links it to each tool's
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
4. **At the end of each feature**, add a short entry to `decisions.md`:
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
- Lint clean with `shellcheck -s sh`. Don't silence a warning without a
  comment explaining why.
- Validate every argument a model can pass. Fail with one clear line on
  stderr and a non-zero exit; never guess.
- Pass paths as data (`--`, `GIT_LITERAL_PATHSPECS=1`), never as patterns.
- Test under both `dash` and `bash` on a scratch repo, including the failure
  paths, before calling a change done.

## Skills

- One folder per skill under `skills/<name>/`, with `SKILL.md` and any
  supporting files the skill reads only when needed (see
  `skills/commit-plan/setup.md`).
- Frontmatter: `name` and `description` are portable. Anything else (for
  example `disable-model-invocation`) is vendor-specific; note it in
  `decisions.md`.
- Spell out the commands the skill runs, the rules it must not break, and
  where it stops for approval or on failure.

## Repo layout

```
AGENTS.md         this file
README.md         install and usage
decisions.md      decision log
install.sh        symlinks bin/ and skills/ into $HOME
bin/              scripts, linked to ~/.local/bin
skills/<name>/    skills, linked to each AI tool's skills folder
config/           vendor-specific config, merged by hand
```

Keep the layout organised by what things are, not by where they get
installed. A new AI tool means one more line in `install.sh`, not a new
folder.

## Conventions this repo already uses

- Commits: `type(scope): subject` with conventional-commit types, made with
  `sz-commit`, whole files only, `Refs: PRO-<n>` trailer from the branch.
- Never add AI attribution (co-author trailers, "Generated with" footers) to
  commits or PRs.
- Branches: `[c<N>/]pro-<n>` (Linear ticket, optional cycle prefix).
