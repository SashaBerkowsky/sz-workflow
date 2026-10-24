# One-time scope setup

Run this only when `sz-commit config` shows no scopes, or when the user asks
to redo the scopes. The result is saved in the clone's `.git/config`, so
later commit plans just look scopes up with `sz-commit scope-of`.

## 1. Find out how the repo is organised

Look, in this order, and stop at the first that applies:

1. **Nx** (`nx.json` exists): run `npx nx show projects`, then
   `npx nx show project <name> --json` for each and read its `root`.
   One scope per project, mapped to its root. Drop an `@org/` prefix from
   the name.
2. **Other workspaces**: `pnpm-workspace.yaml`, `workspaces` in
   `package.json`, `turbo.json`, `go.work`, a `[workspace]` in `Cargo.toml`,
   or a `settings.gradle` with several `include`s. One scope per package,
   mapped to its folder.
3. **A single project**: there is no service boundary, so pick another
   criterion from the folder structure: layers (`api`, `db`, `ui`), domains
   (`billing`, `auth`), or app vs. infra vs. docs. Prefer a few broad scopes
   (three to eight) that a reader of `git log` would recognise; a scope per
   folder is too fine.

Also add scopes without paths for changes that cut across everything, such
as `deps` (lockfiles, dependency bumps), `ci` and `repo` (root config). Map a
root file to a scope only when it clearly belongs to one (for example
`package.json` and the lockfile to `deps`).

## 2. Propose and wait

Show a table of scope, paths, and one line on why, plus the criterion you
chose and any folders you left unmapped. Wait for the user to approve or
edit it.

## 3. Save

Run one `sz-commit scope-add NAME [PATH...]` per approved scope, with paths
relative to the repo root. Finish with `sz-commit config` and show the
result.

If scopes already exist and the user asked to redo them, run
`sz-commit scope-reset` first, only after they approve the new table.
