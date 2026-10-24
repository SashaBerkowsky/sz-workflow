# Decisions

## 2026-10-02 · Commit automation

**Decided**
- Commits go through one POSIX sh script, `sz-commit`. The agent supplies only
  type, scope, subject, optional body paragraphs and a file list; the script
  validates them, stages whole files itself and commits without `--no-verify`.
- Format: `type(scope): subject`, conventional-commit types, header ≤ 72 chars.
- Scopes are set up once per clone by the skill's `setup.md` (Nx projects,
  workspace packages, or layers/domains in single-project repos), approved by
  the user and saved by `sz-commit scope-add` as name→path entries in
  `.git/config`. Per commit, `sz-commit scope-of` looks scopes up, and
  `check` rejects a scope that contradicts the mapping.
- Footer: a `Refs: PRO-<n>` trailer added automatically from the branch name
  (`[c<N>/]pro-<n>`). No cycle in the message. Optional body for the *why*.
- No partial staging, by construction: the script has no hunk option.
- No AI attribution, in three layers: Claude Code `attribution` setting,
  `sz-commit` message check, per-repo `commit-msg` hook (repos without a
  hooks manager only).
- A `commit-plan` skill does the judgment part (grouping, wording) and must
  pass `sz-commit check` before showing the plan; the user approves before
  `sz-commit apply` runs.
- Repo layout: flat (`bin/`, `skills/`, `config/`) plus an `install.sh` that
  symlinks into `$HOME`. No GNU Stow (revised the same day: Stow requires
  each package to mirror the home tree, which made the repo hard to read).

**Why**
- Grouping and wording need judgment; format, staging scope and attribution
  are invariants, so a script enforces them instead of a prompt.
- A one-time, approved scan works for Nx, other workspaces and single-project
  repos alike; looking scopes up per commit is cheap and deterministic.
- Scopes in `.git/config` keep the team monorepo untouched while this is a
  personal workflow.
- The ticket trailer makes history searchable by ticket
  (`git log --grep PRO-122`, `git log --format='%(trailers:key=Refs)'`)
  without lengthening the subject. `Refs` is one of Linear's non-closing magic
  words, so it never moves an issue's state.
- The cycle is already in the branch name and in Linear, and a ticket can
  move cycles; repeating it in every commit adds noise that can go stale.

**Redo on migration**
- `config/claude-settings.json` (attribution setting, allow/ask/deny rules) is
  Claude Code only. Find the new tool's equivalent attribution switch and
  command-permission rules; until then layers 2 and 3 still hold.
- `disable-model-invocation` in `SKILL.md` is a Claude Code frontmatter key;
  other tools ignore it, so the skill could trigger on its own there.
- `install.sh` knows each tool's skills folder (`~/.claude/skills` for
  Claude Code, `~/.agents/skills` for Codex); a new tool means one more line.
- Plan-mode editing (Ctrl+G) is Claude Code; elsewhere the skill's
  "wait for approval" step is the review point.
- Team step (later): move scopes into a committed file and add a
  `.husky/commit-msg` that calls `sz-commit lint-msg`.
