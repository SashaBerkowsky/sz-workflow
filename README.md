# sz-workflow

Personal, provider-agnostic AI dev workflow. The repo is organised by what
things are; `install.sh` links them to where each tool looks for them.

```
sz-workflow/
├── README.md
├── decisions.md
├── install.sh                  # links bin/ and skills/ into $HOME
├── bin/
│   └── sz-commit               # validated whole-file commits
├── skills/
│   └── commit-plan/SKILL.md    # one copy, used by Claude Code and Codex
└── config/
    └── claude-settings.json    # merge by hand into ~/.claude/settings.json
```

## Install

Requirements: git, POSIX `sh`, `~/.local/bin` on `PATH`.

```sh
git clone <your remote> ~/sz-workflow
~/sz-workflow/install.sh
```

It creates symlinks only, and is safe to re-run:

| From | To | When |
|---|---|---|
| `bin/*` | `~/.local/bin/` (override with `SZ_BIN_DIR`) | always |
| `skills/<name>/` | `~/.claude/skills/<name>` | `~/.claude` exists (Claude Code) |
| `skills/<name>/` | `~/.agents/skills/<name>` | `~/.codex` exists (Codex) |

It never overwrites a file that is not its own link; it reports a conflict
and exits 1 instead. `install.sh --uninstall` removes only its own links.
Each tool reads skills from its own folder, so the same skill is linked
twice; the repo keeps one copy.

Then, once per machine, merge `config/claude-settings.json` into
`~/.claude/settings.json` (it is not linked because Claude Code also writes to
that file).

Scopes are set up once per clone. The first time you run `/commit-plan` in a
repo with no scopes, the skill scans how the repo is organised (Nx projects,
other workspace packages, or, in a single-project repo, layers or domains),
proposes a scope table, and after you approve saves it with
`sz-commit scope-add`. It is stored in that clone's `.git/config`, so
nothing is added to the repo's files, and later plans just look scopes up
with `sz-commit scope-of`. You can also do it by hand:

```sh
sz-commit scope-add clients-service apps/clients-service
sz-commit scope-add deps package.json pnpm-lock.yaml
sz-commit scope-add ci                  # a scope with no paths
sz-commit scope-of apps/clients-service/src/main.ts   # -> clients-service
sz-commit scope-reset                   # start over
```

The longest matching path wins. `sz-commit check` rejects a commit whose
files all belong to a different scope than the one given, and warns when
they span several.

Other optional settings: `git config sz.ticketPrefix pro` (default `pro`),
`git config sz.headerMax 72` (default 72).

## Commits

Inside Claude Code, run `/commit-plan` (plan mode works well: Ctrl+G opens the
plan in your editor). In Codex, ask for the `commit-plan` skill.

The skill reads `git status` and `git diff`, groups whole files into commits,
validates each with `sz-commit check`, shows you the exact
`sz-commit apply ...` commands and waits. After you approve, it runs them in
order and stops at the first failure.

`sz-commit` is usable without any agent:

```sh
sz-commit config
sz-commit check -t feat -s api -m "validate webhook signature" -- services/api/webhook.ts
sz-commit apply -t feat -s api -m "validate webhook signature" \
  -b "Stripe retries unsigned requests; rejecting them stops duplicate charges." \
  -- services/api/webhook.ts services/api/webhook.test.ts
```

`sz-commit summary 3` prints the last 3 commits, oldest first, each with its
files as a `tree`-style listing (new and deleted files are marked):

```
7b514c0 fix(api): rework handler
└── services
    └── api
        ├── a.ts
        ├── c.ts (new)
        └── lib
            └── b.ts (deleted)
```

What it guarantees:

| Invariant | How |
|---|---|
| `type(scope): subject`, type and scope from a list, header ≤ 72, no trailing period | validated before staging |
| Whole files only, never hunks | it runs `git add -A -- <files>` itself; there is no hunk option |
| Exactly the listed files land in the commit | refuses if anything was already staged; compares the staged set to the list |
| Paths are file names, never globs | `GIT_LITERAL_PATHSPECS=1` |
| `Refs: PRO-<n>` trailer | parsed from `[c<N>/]pro-<n>` branch names; `-r` overrides, `-R` omits |
| No AI co-author trailer or "Generated with" footer | message rejected if it matches |
| Your husky hooks still run | never passes `--no-verify`; on rejection it unstages that commit's files and leaves the working tree as is |

Note on husky: your pre-commit hook runs tests against the whole working
tree, which still holds the changes of the commits that come later in the
plan. A green hook on commit 2 of 5 does not prove commit 2 builds alone.

## AI attribution guard, in layers

1. `config/claude-settings.json` sets `attribution` to empty strings, so
   Claude Code does not add its co-author trailer or PR footer.
   **Claude Code only.** The portable guards are the next two.
2. `sz-commit` rejects messages containing AI attribution. The skill commits
   only through it, and the settings snippet denies `git add` / `git commit`
   to Claude Code. Claude Code's docs say Bash deny rules are not a security
   boundary (`env git commit` would slip past), which is why 1 and 3 exist.
3. The `commit-msg` hook applies the same check (and the header format) to
   every commit, including ones you type yourself. Install it per repo with
   `sz-commit install-hook`, which writes a two-line hook that calls
   `sz-commit lint-msg`. It refuses in repos that set `core.hooksPath`
   (husky does), because git ignores `.git/hooks` there. In your husky
   monorepo, layers 1 and 2 are what protect you until a team-level
   `.husky/commit-msg` exists.

## Lint

```sh
shellcheck -s sh install.sh bin/sz-commit
```

When you first commit the scripts, make sure they are executable in git:
`git add --chmod=+x install.sh bin/sz-commit`.
