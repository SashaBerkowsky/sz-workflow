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

## 2026-10-24 · Commit plan runs without asking; ticket prefix per clone

**Decided**
- `commit-plan` no longer waits for approval of the plan. Once every commit
  passes `sz-commit check`, it applies them and shows `sz-commit summary`
  (the commit tree) and `git status --short`. Asking to see the plan first
  still works.
- The ticket prefix is set once per clone: if `sz-commit config` shows
  `prefix: (not set, ...)`, the skill asks for it and saves it with the new
  `sz-commit ticket-prefix PREFIX` (`.git/config`, letters and digits only).
  The `pro` fallback stays for use without the skill.
- If the branch carries no ticket, the skill asks once per plan whether to
  reference one (`-r PREFIX-<n>` on every commit) or not (`-R`).

**Why**
- The review step was an extra round-trip with no catch: `check` already
  enforces the invariants, the commits are local and easy to undo, and the
  owner reviews the result in the summary tree. Pushing stays manual.
- Personal repos have no tickets (prefix `sza`), work repos use `pro`;
  asking once beats a silent default that is wrong in one of them.
- A dedicated subcommand keeps the rule "skills call scripts" and validates
  the prefix, instead of the skill running `git config` itself.

**Redo on migration**
- In Claude Code, `config/claude-settings.json` keeps `sz-commit apply` on
  `ask`, so each commit can still raise a permission prompt; that is the
  harness, not the skill. The new tool's permission rules need the same
  choice.
- Asking the user for the prefix and ticket uses whatever question
  mechanism the tool has (Claude Code's AskUserQuestion); the skill only
  says "ask".

## 2026-10-24 · docs/ folder, manual for bin/

**Decided**
- A `docs/` folder holds the decision log (`docs/decisions.md`, moved from
  the root) and one man-style manual per script (`docs/bin/<script>.md`):
  one entry per subcommand with what it is for, why it exists and a flag
  table.
- Docs stay out of `bin/`, so `install.sh` keeps linking every file there
  unchanged (a first version put `bin/README.md` next to the script and
  needed an executables-only filter).

**Why**
- Markdown in the repo reads well for the owner and for an LLM session alike,
  needs no build step and shows up on the remote. Real man pages (roff,
  `man sz-commit`) would need a `MANPATH` entry and a second format to keep
  in sync; not worth it for one person.
- The script's header comment stays the short usage; the manual is the long
  form. AGENTS.md requires updating both in the same commit.

**Redo on migration**
- Nothing tool-specific.

## 2026-10-24 · Undo the last commit run

**Decided**
- New `sz-commit undo [--dry-run] N`: a mixed reset of the last N commits,
  so their changes go back to the working tree. It refuses when a commit in
  the range is on a remote-tracking branch, the range contains a merge, or
  the index has staged changes.
- `commit-plan` step 8: when a run missed something, dry-run, undo that
  run's commits and plan everything again.
- Chosen over `git commit --fixup` + `rebase --autosquash`, which needs a
  rebase with an editor workaround and a target commit picked by hand;
  undo-and-replan reuses the grouping the skill already does.

**Why**
- Forgetting a file after a run happens often. A trailing "forgot a file"
  commit is harmless but makes history harder to read.
- Rewriting pushed history is the real risk, so the script checks it
  instead of the prompt. Local history is easy to restore (`git reset
  <hash>`, printed on every undo).

**Redo on migration**
- `Bash(sz-commit undo *)` is on `ask` in `config/claude-settings.json`
  (Claude Code only); the new tool needs the same rule.
- The pushed check reads remote-tracking refs, so it is only as fresh as the
  last `git fetch`.

## 2026-10-24 · Ticket skills, sz-branch, MCP in install.sh

**Decided**
- Two skills instead of branch handling in `/sz-commit`: `sz-work`
  (read a Linear ticket and its dependencies, get onto its branch) and
  `sz-new` (draft a ticket from a problem the user saw, create it after
  approval). `/sz-commit` never changes branches; it points to
  `sz-work`.
- New script `sz-branch` (`find`, `check`, `switch`) does the git part.
  Names are `[c<N>/]<prefix>-<n>`; an existing branch is reused; only plain
  `git switch`, so uncommitted work is never overwritten. It shares
  `sz.ticketPrefix` with `sz-commit` but has no `pro` fallback, so the
  skill asks for the prefix instead of guessing.
- Branching ticket B from ticket A's branch records the dependency in
  Linear, after the user agrees: B becomes a sub-issue of A, is marked
  blocked by A, and both get a comment.
- `sz-new` picks the team whose key matches the repo's prefix, and asks
  when unsure. `sz-work` offers to move the ticket to In Progress.
- Linear access through Linear's official MCP server
  (`https://mcp.linear.app/mcp`), registered by `install.sh` with each
  tool's `mcp add`. Chosen over `schpet/linear-cli` (active, ~1k stars, but
  community-run): the MCP server is Linear's own and documented for both
  Claude Code and Codex.
- Skill names share the `sz-` prefix and stay short: `sz-work` (start a
  ticket), `sz-new` (file one), and `commit-plan` renamed to `sz-commit`,
  the same name as the script it calls. Earlier entries keep the old names.
- `install.sh --tool claude|codex|all` (default `all`) picks which tool to
  set up. `bin/` is shared, so a per-tool uninstall keeps it. MCP servers
  are never removed by uninstall; it prints the command.

**Why**
- Starting a ticket and filing one are separate moments with different
  questions; keeping them out of `/sz-commit` keeps that skill about
  commits.
- Where to branch from is judgment (it depends on Linear data), so the
  skill decides; naming, reuse and not losing work are invariants, so the
  script enforces them.
- Recording a branch-from as both sub-issue and blocked-by was the owner's
  choice: it shows up in Linear from either ticket.

**Redo on migration**
- The skills name Linear features (sub-issue, blocked by, comments,
  status), not MCP tool names, since Linear does not document those. Check
  the new tool can reach the same MCP server.
- `install.sh` uses `claude mcp add -s user --transport http` and
  `codex mcp add NAME --url`; Codex's `mcp remove` is not documented, so
  uninstall points to `~/.codex/config.toml`. A new tool needs its own pair.
- `disable-model-invocation` in the new skills is Claude Code only.
- Not yet verified: that the Linear MCP server can read and set relations
  (blocked by) and parents. The skills say to report and hand over the text
  if it can't.

## 2026-10-24 · setup.sh replaces install.sh

**Decided**
- One script, `setup.sh`, with subcommands: `install`, `check` (preview),
  `status` and `uninstall`, sharing `--tool claude|codex|all`. Rejected: a
  Makefile (second language, awkward options, the script would still do the
  work), a `setup/` folder with separate install and uninstall scripts
  (mirror-image logic that drifts apart), and keeping `install.sh
  --uninstall` (each new action becomes another flag).
- `install` and `uninstall` remove broken links into this repo (a renamed
  skill left `~/.claude/skills/commit-plan` dangling); `status` reports them.
- A full uninstall resets the `sz` section of `.git/config` and removes the
  `commit-msg` hook `sz-commit install-hook` wrote, in every repo on
  `~/.config/sz-workflow/repos`, the current repo and each `--repo`.
  `--keep-config` skips it. `sz-commit` adds a repo to that list whenever it
  saves a setting there.
- `uninstall --mcp` removes the MCP servers; without it they stay.

**Why**
- Subcommands match `sz-commit` and `sz-branch`, so there is one shape to
  learn, and `check` gives the installer the preview mode AGENTS.md asks of
  every script.
- Repo settings live in each clone, so without a list nothing can find
  them to undo. The list is in the user's config, not in any work tree.
- The owner asked for uninstall to reset the repo settings too.

**Redo on migration**
- MCP add/remove commands per tool, as before. `codex mcp remove` is not in
  Codex's docs; uninstall tries it and points to `~/.codex/config.toml` if
  it fails.
- Not verified on macOS or under `dash` (not installed here), and not
  linted (`shellcheck` not installed).


## 2026-10-24 · /sz-pr opens a PR for the current ticket

**Decided**
- A new skill, `skills/sz-pr/`, drafts the PR and runs `git push` and
  `gh pr create` only after the user approves the exact commands. No
  `bin/sz-pr` script: the owner saw no need, so the title format and the
  no-attribution rule are enforced only by the skill's wording, against the
  "deterministic mechanisms for invariants" principle. The title reuses
  `sz-commit config` (types, header max) and `sz-commit scope-of`.
- The base is the branch the work was built on: a blocking or parent
  ticket's branch while its PR is open (a stacked PR), otherwise the
  default branch.
- The description follows the repo's PR template when there is one, else a
  Summary / Changes / Notes shape, and ends with `Refs: <ticket>`.
- Notes and plans: repos differ (this one has none), so the skill always
  looks, in common note and plan folders and files, tracked or gitignored,
  and uses only those that mention the ticket, its parent or a sub-issue.
  If none match, it uses the session, the commits and the ticket.
- The body goes to `gh pr create --body-file -` through a quoted heredoc,
  so no temp file is written to the work tree.

**Why**
- Hand-written PRs didn't follow the commit standard or the repo's
  template (SZA-6).
- A stacked PR keeps the diff to this ticket's changes when it builds on an
  unmerged one, as `sz-work` allows.

**Redo on migration**
- `gh` is GitHub only; another forge needs its own CLI (`glab mr create`
  for GitLab) and its own template locations.
- Template locations are from GitHub's docs (root, `docs/`, `.github/`,
  or a `PULL_REQUEST_TEMPLATE/` folder in those). The docs don't say
  whether names are case-sensitive, so the skill matches in any case.
- `disable-model-invocation` and the permission rules in
  `config/claude-settings.json` (`gh pr view`/`list` allowed,
  `git push -u origin` and `gh pr create` on ask) are Claude Code only.
- If no-attribution in PRs ever needs a hard guarantee, that is the point
  to add a script with a `check` mode after all.
