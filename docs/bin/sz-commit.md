# sz-commit manual

Manual for `bin/sz-commit`, in the style of a man page: one entry per
subcommand. Each script in `bin/` has its own page in `docs/bin/`.

The short usage lives in the script's header comment. When a flag changes,
update the script and this page in the same commit.

- [sz-commit](#sz-commit)
  - [config](#sz-commit-config)
  - [check](#sz-commit-check)
  - [apply](#sz-commit-apply)
  - [summary](#sz-commit-summary)
  - [scope-add](#sz-commit-scope-add)
  - [scope-of](#sz-commit-scope-of)
  - [scope-reset](#sz-commit-scope-reset)
  - [ticket-prefix](#sz-commit-ticket-prefix)
  - [undo](#sz-commit-undo)
  - [lint-msg](#sz-commit-lint-msg)
  - [install-hook](#sz-commit-install-hook)

---

## sz-commit

**Validated, whole-file commits in the form `type(scope): subject`.**

### Synopsis

```
sz-commit config
sz-commit check -t TYPE -s SCOPE -m SUBJECT [-b PARAGRAPH]... [-B] [-r ID | -R] -- PATH...
sz-commit apply -t TYPE -s SCOPE -m SUBJECT [-b PARAGRAPH]... [-B] [-r ID | -R] -- PATH...
sz-commit summary [N]
sz-commit scope-add NAME [PATH...]
sz-commit scope-of PATH...
sz-commit scope-reset
sz-commit ticket-prefix PREFIX
sz-commit undo [--dry-run] N
sz-commit lint-msg FILE
sz-commit install-hook
```

Run with no arguments (or an unknown subcommand) to print the usage.

### Description

`sz-commit` is the only way the `/sz-commit` skill commits. The agent passes
the variable parts (type, scope, subject, why, files); the script checks them
and does all staging and committing itself. That way the rules hold even when
the prompt is ignored:

- the header is `type(scope)[!]: subject`, with type and scope from a list,
  at most 72 characters and no trailing period;
- whole files only, and exactly the files listed (there is no hunk option);
- paths are literal file names, never globs (`GIT_LITERAL_PATHSPECS=1`);
- a `Refs: PREFIX-<n>` trailer comes from the branch name;
- no AI attribution (co-author trailers, "Generated with" footers, session
  links) can get into a message;
- repo hooks (husky) always run; `--no-verify` is never passed.

POSIX `sh`, with only POSIX options of `sed`, `grep`, `tr`, `sort` and
`awk`, so it behaves the same on Linux and macOS.

### Configuration

All settings live in the clone's `.git/config`; nothing is written to the
work tree.

| Key | Written by | Default | Meaning |
|---|---|---|---|
| `sz.scope` | `scope-add` | none | Allowed scope names (multi-valued). Commits are refused while none exist. |
| `sz.scopePath` | `scope-add` | none | `NAME PATH` entries mapping files to scopes (multi-valued). A path ending in `/` is a folder. |
| `sz.ticketPrefix` | `ticket-prefix` | `pro` | Ticket prefix, read from branches `[c<N>/]<prefix>-<n>[-...]`. |
| `sz.headerMax` | `git config` by hand | `72` | Longest header allowed, in characters. |
| `sz.type` | `git config --add` by hand | `build chore ci docs feat fix perf refactor revert style test` | Replaces the default type list (multi-valued). |

### Exit status

| Code | Meaning |
|---|---|
| `0` | Success. |
| `1` | Refused or failed. One line starting with `sz-commit:` on stderr says why. |
| `2` | No subcommand, or an unknown one; the usage is printed. |

---

<a id="sz-commit-config"></a>
### sz-commit config

```
sz-commit config
```

**What it's for:** prints everything a commit gets validated against, so you
or the skill can plan commits without guessing.

**Why it exists:** it is the skill's first step. It shows whether the
one-time setup (scopes, ticket prefix) still needs doing, and which ticket
the branch carries.

Takes no flags. Output, one field per line:

| Field | Shows |
|---|---|
| `types:` | Allowed commit types. |
| `scopes:` | Allowed scopes (empty means setup has not run). |
| `prefix:` | The saved ticket prefix, or `(not set, default pro)`. |
| `branch:` | Current branch, or `(detached)`. |
| `ticket:` | Ticket parsed from the branch, e.g. `SZA-12`; empty if the branch does not match. |
| `max:` | Header length limit. |
| `path:` | One line per mapping: `scope <- path`. |

---

<a id="sz-commit-check"></a>
### sz-commit check

```
sz-commit check -t TYPE -s SCOPE -m SUBJECT [-b PARAGRAPH]... [-B] [-r ID | -R] -- PATH...
```

**What it's for:** a dry run of [`apply`](#sz-commit-apply). It runs every
validation `apply` does and prints the header it would write, but stages and
commits nothing.

**Why it exists:** so a plan can be proven valid before any commit lands.
The skill runs it for every commit first; a plan never stops halfway through
because of a typo in commit 3.

On success it prints `ok: <header> (<n> file(s))`, plus `Refs: <id>` if a
trailer would be added.

| Flag | Argument | Required | Description |
|---|---|---|---|
| `-t` | `TYPE` | yes | Conventional commit type. Must be in the type list (`sz-commit config`). |
| `-s` | `SCOPE` | yes | Scope. Must be a configured scope. If every listed file maps to one *other* scope, it is refused; if they span several, you get a warning. |
| `-m` | `SUBJECT` | yes | Subject line: one line, not empty, no leading space, no trailing period. The whole header must fit in `sz.headerMax`. |
| `-b` | `PARAGRAPH` | no | A body paragraph about *why*. Repeat it for more paragraphs; they are joined with a blank line. |
| `-B` | | no | Breaking change: adds `!` after the scope, e.g. `feat(api)!: ...`. |
| `-r` | `ID` | no | Ticket for the `Refs` trailer, instead of the one from the branch. Must be `PREFIX-<number>` for the configured prefix (any case). |
| `-R` | | no | No `Refs` trailer. Wins over `-r`. |
| `--` | | recommended | Ends the flags; everything after it is a path. |
| `PATH...` | | yes | Files relative to the repo root, as `git status --porcelain` prints them. Each must have changes. Directories are refused; list their files. |

It is also refused if the index already has staged changes, or if the message
contains AI attribution.

If you pass neither `-r` nor `-R` and the branch carries no ticket, it warns
and goes ahead without a trailer.

```sh
sz-commit check -t fix -s api -m "reject unsigned webhooks" -- services/api/webhook.ts
```

---

<a id="sz-commit-apply"></a>
### sz-commit apply

```
sz-commit apply -t TYPE -s SCOPE -m SUBJECT [-b PARAGRAPH]... [-B] [-r ID | -R] -- PATH...
```

**What it's for:** makes one commit of exactly the listed files, with a
message built from the flags.

**Why it exists:** the agent never runs `git add` or `git commit`. This is
the one place where staging and committing happen, so its guarantees hold
no matter who calls it.

The flags are the same as [`check`](#sz-commit-check). After the same
validations it:

1. stages the files whole (`git add -A -- PATH...`), including deletions;
2. compares what got staged with the list and, if they differ, unstages and
   refuses;
3. commits with the repo's hooks running. If a hook rejects the commit, it
   unstages the files and leaves the working tree as it was.

On success it prints `committed <hash> <header>`.

```sh
sz-commit apply -t feat -s api -m "validate webhook signature" \
  -b "Stripe retries unsigned requests; rejecting them stops duplicate charges." \
  -- services/api/webhook.ts services/api/webhook.test.ts
```

---

<a id="sz-commit-summary"></a>
### sz-commit summary

```
sz-commit summary [N]
```

**What it's for:** lists the last `N` commits, oldest first, each with its
files as a `tree`-style listing. New files are marked `(new)` and deleted
ones `(deleted)`.

**Why it exists:** it is how you review what the skill committed. One look
shows whether files ended up in the right commits.

| Argument | Default | Description |
|---|---|---|
| `N` | `1` | How many commits to show, counting back from `HEAD`. A positive integer. |

```
7b514c0 fix(api): rework handler
└── services
    └── api
        ├── a.ts
        ├── c.ts (new)
        └── lib
            └── b.ts (deleted)
```

---

<a id="sz-commit-scope-add"></a>
### sz-commit scope-add

```
sz-commit scope-add NAME [PATH...]
```

**What it's for:** allows the scope `NAME` and, optionally, maps files or
folders to it.

**Why it exists:** scopes are set up once per clone (the skill's `setup.md`
proposes them). After that, scopes are looked up, not guessed, and `check`
can refuse a scope that contradicts the mapping. The mapping is stored in
`.git/config`, so a shared repo is left untouched.

| Argument | Required | Description |
|---|---|---|
| `NAME` | yes | Scope name: letters, digits, `.`, `_`, `-`, starting with a letter or digit. |
| `PATH...` | no | Existing files or folders relative to the repo root. Folders match everything under them. Leave it out for a cross-cutting scope with no files of its own (`ci`, `deps`). |

Running it again with the same entries is harmless; duplicates are not
added. When several mappings match a file, the longest path wins.

```sh
sz-commit scope-add clients-service apps/clients-service
sz-commit scope-add deps package.json pnpm-lock.yaml
sz-commit scope-add ci
```

---

<a id="sz-commit-scope-of"></a>
### sz-commit scope-of

```
sz-commit scope-of PATH...
```

**What it's for:** prints the scope each file belongs to, one
`scope<TAB>path` line per file, with `-` when no mapping covers it.

**Why it exists:** the skill groups commits by scope. One call for all
changed files replaces guessing from folder names.

| Argument | Required | Description |
|---|---|---|
| `PATH...` | yes | Paths relative to the repo root. They do not need to exist. |

```sh
$ sz-commit scope-of apps/clients-service/src/main.ts README.md
clients-service	apps/clients-service/src/main.ts
-	README.md
```

---

<a id="sz-commit-scope-reset"></a>
### sz-commit scope-reset

```
sz-commit scope-reset
```

**What it's for:** deletes every scope and mapping for this clone
(`sz.scope`, `sz.scopePath`).

**Why it exists:** for when the repo's layout changes and you want to redo
setup from scratch. The skill runs it only after you approve a new scope
table.

Takes no arguments. Prints `scopes cleared`.

---

<a id="sz-commit-ticket-prefix"></a>
### sz-commit ticket-prefix

```
sz-commit ticket-prefix PREFIX
```

**What it's for:** saves the ticket prefix for this clone. Branches named
`[c<N>/]<prefix>-<n>[-...]` then get a `Refs: <PREFIX>-<n>` trailer.

**Why it exists:** repos differ (`pro` at work, `sza` for personal
projects). When `config` shows `prefix: (not set, ...)`, the skill asks you
for the prefix and saves it here instead of running `git config` itself.
Without a saved prefix, `sz-commit` uses `pro`.

| Argument | Required | Description |
|---|---|---|
| `PREFIX` | yes | Letters and digits, starting with a letter. Saved lowercase; the trailer is uppercase. |

```sh
$ sz-commit ticket-prefix sza
ticket prefix: sza (branches [c<N>/]sza-<n> get Refs: SZA-<n>)
```

---

<a id="sz-commit-undo"></a>
### sz-commit undo

```
sz-commit undo [--dry-run] N
```

**What it's for:** takes the last `N` commits out of the branch and puts
their changes back in the working tree, uncommitted. Nothing is lost: the
files stay as they are, and the old commits can be restored with the
`git reset <hash>` line it prints (git's reflog keeps them for a while too).

**Why it exists:** you ran a commit plan, then noticed a file you forgot or
a change you still wanted in those commits. Undoing the run and planning
again gives complete commits instead of a trailing "forgot a file" commit.
The script, not the prompt, makes sure only local history is rewritten.

| Flag / argument | Required | Description |
|---|---|---|
| `--dry-run` | no | Only list the commits that would be undone, and run every check. Must come before `N`. |
| `N` | yes | How many commits to undo, counting back from `HEAD`. A positive integer, at most the number of commits on the branch. |

It refuses, without changing anything, when:

- any of the commits is on a remote-tracking branch, i.e. already pushed
  (as far as your last `git fetch` knows);
- the range contains a merge commit;
- something is already staged.

Undoing every commit on the branch is allowed; the files then show as
untracked, the way they were before the first commit.

```sh
$ sz-commit undo --dry-run 2
  9127551 feat(commit): commit without plan approval and ask for ticket prefix
  72a1bc7 docs(repo): move decision log to docs and add sz-commit manual
ok: would undo 2 commit(s) above
$ sz-commit undo 2
  ...
undid 2 commit(s); their changes are back in the working tree
to restore them: git reset 72a1bc7
```

---

<a id="sz-commit-lint-msg"></a>
### sz-commit lint-msg

```
sz-commit lint-msg FILE
```

**What it's for:** checks an existing commit message file against the same
rules `apply` uses: header format, type and scope, length, no AI
attribution.

**Why it exists:** it is what the `commit-msg` hook calls, so commits you
type yourself are held to the same format. Lines starting with `#` are
ignored, the way git's default cleanup ignores them. Messages git writes
itself (`Merge ...`, `Revert "..."`, `fixup!`, `squash!`, `amend!`) only get
the attribution check.

| Argument | Required | Description |
|---|---|---|
| `FILE` | yes | Path to the message file (the hook passes `.git/COMMIT_EDITMSG`). |

---

<a id="sz-commit-install-hook"></a>
### sz-commit install-hook

```
sz-commit install-hook
```

**What it's for:** writes a two-line `commit-msg` hook into this repo's
`.git/hooks` that runs [`lint-msg`](#sz-commit-lint-msg).

**Why it exists:** it is the third layer of the attribution guard. It also
covers commits made without `sz-commit`. The hook only calls `sz-commit`,
so it never goes out of date, and it fails closed: if `sz-commit` cannot be
found, the commit is rejected.

Takes no arguments. It refuses, without changing anything, when:

- the repo sets `core.hooksPath` (husky does), because git then ignores
  `.git/hooks`;
- a `commit-msg` hook already exists. It never overwrites one.
