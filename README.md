# sz-workflow

Personal, provider-agnostic AI dev workflow. The repo is organised by what
things are; `setup.sh` links them to where each tool looks for them.

```
sz-workflow/
├── README.md
├── setup.sh                    # install, check, status, uninstall
├── bin/
│   ├── sz-commit               # validated whole-file commits
│   └── sz-branch               # find, create or switch to a ticket's branch
├── docs/
│   ├── decisions.md            # decision log
│   └── bin/                    # manuals: every subcommand and flag
│       ├── sz-commit.md
│       └── sz-branch.md
├── skills/                     # one copy each, used by Claude Code and Codex
│   ├── sz-commit/SKILL.md      # group changes into commits (calls bin/sz-commit)
│   ├── sz-work/SKILL.md        # get onto a Linear ticket's branch (calls bin/sz-branch)
│   └── sz-new/SKILL.md         # turn a bug you saw into a Linear ticket
└── config/
    └── claude-settings.json    # merge by hand into ~/.claude/settings.json
```

## Install

Requirements: git, POSIX `sh`, `~/.local/bin` on `PATH`.

```sh
git clone <your remote> ~/sz-workflow
~/sz-workflow/setup.sh check      # see what install would do
~/sz-workflow/setup.sh install    # do it
```

`setup.sh` does everything that touches your machine, one action per
subcommand:

| Command | What it does |
|---|---|
| `setup.sh install` | Link `bin/` and `skills/`, register the MCP servers, and remove links into this repo that no longer point anywhere (a renamed skill). Safe to re-run. |
| `setup.sh check` | Say what `install` would do, without changing anything. |
| `setup.sh status` | Show what is installed, what is missing or broken, the MCP servers' login state, and which repos have `sz` settings. Exits 1 if something needs fixing. |
| `setup.sh uninstall` | Remove what `install` set up and reset the `sz` settings in your repos (see below). |

| Flag | Applies to | Description |
|---|---|---|
| `--tool claude\|codex\|all` | `install`, `check`, `uninstall` | Which AI tool to set up or remove; default `all`. `all` covers each tool it finds and skips the others; naming one tool that isn't there is an error (exit 1). `--tool=claude` works too. |
| `--mcp` | `uninstall` | Also remove the MCP servers. Without it they stay, and the command to remove them is printed: it can't tell whether you added them yourself. |
| `--keep-config` | `uninstall` | Keep the `sz` settings (scopes, ticket prefix) in your repos. |
| `--repo PATH` | `uninstall` | Also reset this repo's `sz` settings. Repeatable. |

What `install` sets up:

| What | Where | For |
|---|---|---|
| `bin/*` (symlinks) | `~/.local/bin/` (override with `SZ_BIN_DIR`) | always |
| `skills/<name>/` (symlinks) | `~/.claude/skills/<name>` | `claude`; needs `~/.claude` |
| `skills/<name>/` (symlinks) | `~/.agents/skills/<name>` | `codex`; needs `~/.codex` |
| MCP server `linear-server` → `https://mcp.linear.app/mcp` | user scope, via `claude mcp add` | `claude`; needs the `claude` CLI |
| MCP server `linear-server` → `https://mcp.linear.app/mcp` | via `codex mcp add` | `codex`; needs the `codex` CLI |

It never overwrites a file that is not its own link; it reports a conflict
and exits 1 instead. If an MCP server with that name is already registered,
it leaves it alone. Each tool reads skills from its own folder, so the same
skill is linked twice; the repo keeps one copy.

After a first install, log in to Linear once per tool: `/mcp` in Claude Code,
`codex mcp login linear-server` in Codex.

**Uninstall.** `setup.sh uninstall` removes only its own links. With
`--tool claude` or `--tool codex` it removes that tool's skills and keeps
what is shared (the `bin/` links and your repo settings). A full uninstall
(`--tool all`, the default) also resets, unless `--keep-config`:

- the `sz` section of `.git/config` (scopes, ticket prefix, header max) in
  every repo `sz-commit` saved a setting in: it adds each one to
  `~/.config/sz-workflow/repos` when it does. Repos set up before that list
  existed are covered if you run uninstall from inside them, or pass them
  with `--repo`;
- the `commit-msg` hook in those repos, only if `sz-commit install-hook`
  wrote it;
- the list itself.

Then, once per machine, merge `config/claude-settings.json` into
`~/.claude/settings.json` (it is not linked because Claude Code also writes to
that file).

Scopes are set up once per clone. The first time you run `/sz-commit` in a
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

The ticket prefix is also set once per clone. If it is not set, the skill
asks you for it and saves it with `sz-commit ticket-prefix sza` (in
`.git/config`; without it `sz-commit` falls back to `pro`).

Other optional setting: `git config sz.headerMax 72` (default 72).

## Commits

Inside Claude Code, run `/sz-commit`. In Codex, ask for the `sz-commit`
skill. The skill and the script share the name: `/sz-commit` is the skill,
which groups and words the commits, and `sz-commit` in a shell is the script
it calls to make them.

The skill reads `git status` and `git diff`, groups whole files into commits,
validates each with `sz-commit check`, then runs the `sz-commit apply ...`
commands in order without asking, and stops at the first failure. It ends
with `sz-commit summary`, so you review the commits as a tree afterwards. If
the branch has no ticket, it first asks whether to reference one. Say "show
me the plan first" when you want to review before anything is committed.

Forgot a file? Make the change, then tell the skill to fold it into the last
run. It runs `sz-commit undo <n>` to put that run's commits back into the
working tree, and plans everything again. `undo` refuses if any of those
commits are pushed.

## sz-commit without an agent

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

## Tickets

Both skills use Linear through its MCP server (`linear-server`, set up by
`setup.sh install`), and change nothing in Linear without asking.

- `/sz-work PRO-3` reads the ticket and what it depends on, then
  creates or switches to its branch with `sz-branch`. If PRO-3 depends on
  PRO-2, it branches from PRO-2's branch (and asks if you are somewhere
  else). If you are on PRO-2's branch and PRO-3 doesn't depend on anything
  yet, it asks whether PRO-3 should build on PRO-2; on yes it makes PRO-3 a
  sub-issue of PRO-2, marks it blocked by PRO-2, and comments on both. It
  then offers to move PRO-3 to In Progress.
- `/sz-new` turns something you saw into a ticket: it looks at the code
  or error you point it to, checks for duplicates, shows you a draft and
  creates it after you approve. The team is the one matching this repo's
  ticket prefix. It then offers to start on it.

`sz-branch` is usable on its own (manual: `docs/bin/sz-branch.md`):

```sh
sz-branch find PRO-3                         # branches for PRO-3
sz-branch check -c 12 -f c12/pro-2 PRO-3     # what switch would do
sz-branch switch -c 12 -f c12/pro-2 PRO-3    # create c12/pro-3 from c12/pro-2
```

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
shellcheck -s sh setup.sh bin/sz-commit bin/sz-branch
```

When you first commit the scripts, make sure they are executable in git:
`git add --chmod=+x setup.sh bin/sz-commit`.
