# sz-branch manual

Manual for `bin/sz-branch`, in the style of a man page: one entry per
subcommand. Each script in `bin/` has its own page in `docs/bin/`.

The short usage lives in the script's header comment. When a flag changes,
update the script and this page in the same commit.

- [sz-branch](#sz-branch)
  - [find](#sz-branch-find)
  - [check](#sz-branch-check)
  - [switch](#sz-branch-switch)

---

## sz-branch

**Find, create or switch to the branch for a ticket.**

### Synopsis

```
sz-branch find TICKET
sz-branch check  [-c CYCLE] [-f FROM] TICKET
sz-branch switch [-c CYCLE] [-f FROM] TICKET
```

Run with no arguments (or an unknown subcommand) to print the usage.

### Description

`sz-branch` is how the `sz-work` skill gets you onto a ticket's
branch. The skill decides *which* ticket and *where to branch from* (it
reads ticket dependencies in Linear); the script does the git part and
refuses anything risky:

- branch names follow `[c<N>/]<prefix>-<n>`, the same names `sz-commit`
  reads the `Refs` ticket from;
- an existing branch for the ticket is reused, never duplicated;
- it only runs plain `git switch`, so uncommitted changes come along and git
  refuses instead of overwriting them. It never stashes, resets or deletes.

A branch belongs to a ticket when its name is `<prefix>-<n>`, optionally
with a cycle in front (`c12/`) and anything after a dash (`-fix-login`).
So for `PRO-3`: `pro-3`, `c12/pro-3` and `pro-3-fix-login` match;
`pro-31` does not.

POSIX `sh`, with only POSIX options of `sed`, `grep` and `tr`, so it behaves
the same on Linux and macOS.

### Configuration

| Key | Written by | Default | Meaning |
|---|---|---|---|
| `sz.ticketPrefix` | `sz-commit ticket-prefix` | none | Ticket prefix, shared with `sz-commit`. Unlike `sz-commit`, there is no `pro` fallback: with no prefix saved, every subcommand refuses and says how to set one. The skill then asks you. |

### Exit status

| Code | Meaning |
|---|---|
| `0` | Success, including "already on that branch". |
| `1` | Refused or failed. One line starting with `sz-branch:` on stderr says why; git's own message comes first when git refused. |
| `2` | No subcommand, or an unknown one; the usage is printed. |

---

<a id="sz-branch-find"></a>
### sz-branch find

```
sz-branch find TICKET
```

**What it's for:** lists the branches that belong to a ticket, local ones
first, then remote-tracking ones.

**Why it exists:** `sz-work` uses it to find the branch of the ticket
another ticket depends on (to branch from it), and to see whether a
ticket already has a branch.

| Argument | Required | Description |
|---|---|---|
| `TICKET` | yes | `<PREFIX>-<n>` for the saved prefix, any case (`PRO-3`, `pro-3`). |

Prints nothing when there is no branch.

```sh
$ sz-branch find PRO-7
local   c13/pro-7
remote  origin/c13/pro-7
```

---

<a id="sz-branch-check"></a>
### sz-branch check

```
sz-branch check [-c CYCLE] [-f FROM] TICKET
```

**What it's for:** a preview of [`switch`](#sz-branch-switch). It runs every
check `switch` does and says what it would do, without changing anything.

**Why it exists:** the skill shows you this line before asking whether to
go ahead, so you see the exact branch name and starting point first.

Flags are the same as `switch`. It prints one of:

```
ok: would create c12/pro-3 from pro-2 (8a43d4c add login form)
ok: would switch to existing branch c12/pro-3
ok: would create c13/pro-7 tracking origin/c13/pro-7
already on c12/pro-3
```

followed by `uncommitted changes would come along` when the working tree
has changes.

---

<a id="sz-branch-switch"></a>
### sz-branch switch

```
sz-branch switch [-c CYCLE] [-f FROM] TICKET
```

**What it's for:** puts you on the ticket's branch:

1. If a local branch for the ticket exists, it switches to it.
2. Otherwise, if exactly one remote branch exists, it creates a local branch
   that tracks it.
3. Otherwise it creates `[c<CYCLE>/]<prefix>-<n>` from `FROM` (or from
   where you are now) and switches to it.

**Why it exists:** so starting a ticket is one checked step instead of
remembering the naming convention and the right base branch.

| Flag / argument | Argument | Required | Description |
|---|---|---|---|
| `-c` | `CYCLE` | no | Cycle number. A new branch is named `c<CYCLE>/<prefix>-<n>`. Ignored when the branch already exists. |
| `-f` | `FROM` | no | Branch or commit to create the new branch from. Default: where you are now. Refused when the ticket already has a branch, so an existing branch is never moved. |
| `TICKET` | | yes | `<PREFIX>-<n>` for the saved prefix, any case. |

It refuses, without changing anything, when:

- no ticket prefix is saved for the repo;
- the ticket does not use the saved prefix;
- several local (or remote) branches match the ticket: it lists them, and
  you pick;
- `FROM` is not a branch or commit;
- git refuses the switch, usually because an uncommitted file would be
  overwritten.

```sh
$ sz-branch switch -c 12 -f c12/pro-2 PRO-3
created c12/pro-3 from c12/pro-2 and switched to it
```
