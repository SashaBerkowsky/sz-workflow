#!/bin/sh
# setup.sh: install, preview, inspect or remove this workflow on this machine.
#
#   ./setup.sh install   [--tool T]                    link bin/ and skills/, register MCP servers
#   ./setup.sh check     [--tool T]                    say what install would do, change nothing
#   ./setup.sh status                                  show what is installed and what is broken
#   ./setup.sh uninstall [--tool T] [--mcp] [--keep-config] [--repo PATH]...
#
#   --tool T        claude, codex or all (default). `all` covers each tool that is
#                   present and skips the others; naming a missing tool is an error.
#   --mcp           uninstall: also remove the MCP servers (default: print the command)
#   --keep-config   uninstall: keep the sz.* settings in each repo
#   --repo PATH     uninstall: also reset this repo's sz.* settings (repeatable)
#
# POSIX sh. Uses only `ln -s`, `readlink` (no flags; present on Linux and
# macOS), `mkdir -p`, `rm` and git. It never overwrites or deletes anything
# that is not a symlink pointing into this repo, except what uninstall says.
#
# What install sets up:
#   bin/*            -> $SZ_BIN_DIR (default ~/.local/bin); shared by every tool
#   skills/<name>/   -> ~/.claude/skills/<name>   claude: needs ~/.claude
#   skills/<name>/   -> ~/.agents/skills/<name>   codex:  needs ~/.codex
#   MCP servers (MCP_SERVERS below), with each tool's own `mcp add`, at user scope
# Links into this repo whose target no longer exists (a renamed skill) are removed.
#
# What a full uninstall (--tool all) also resets, unless --keep-config:
#   the [sz] section of .git/config in every repo listed in
#   ~/.config/sz-workflow/repos (sz-commit adds a repo there when it saves a
#   setting), the repo you run this from, and each --repo; plus the commit-msg
#   hook in those repos if `sz-commit install-hook` wrote it. Then the list itself.

set -eu

REPO=$(cd "$(dirname "$0")" && pwd -P)
BIN_DIR=${SZ_BIN_DIR:-$HOME/.local/bin}
# Same path as in bin/sz-commit (remember_repo); keep them in step.
STATE_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/sz-workflow
REPOS_FILE=$STATE_DIR/repos
# One "name url" per line: remote (streamable HTTP) MCP servers the skills use.
MCP_SERVERS='linear-server https://mcp.linear.app/mcp'
HOOK_MARK='written by `sz-commit install-hook`'
nl='
'

usage() {
  printf 'usage: %s install|check|status|uninstall [--tool claude|codex|all] [--mcp] [--keep-config] [--repo PATH]...\n' "$0" >&2
  exit 2
}
die() { printf '%s: %s\n' "$0" "$*" >&2; exit 2; }

MODE=${1:-}
case $MODE in install | check | status | uninstall) shift ;; *) usage ;; esac
TOOL=all mcp_remove='' keep_config='' extra_repos=''
while [ $# -gt 0 ]; do
  case $1 in
    --tool) [ $# -ge 2 ] || usage; TOOL=$2; shift ;;
    --tool=*) TOOL=${1#--tool=} ;;
    --mcp) mcp_remove=1 ;;
    --keep-config) keep_config=1 ;;
    --repo) [ $# -ge 2 ] || usage; extra_repos="$extra_repos$2$nl"; shift ;;
    --repo=*) extra_repos="$extra_repos${1#--repo=}$nl" ;;
    *) usage ;;
  esac
  shift
done
case $TOOL in claude | codex | all) ;; *) die "--tool must be claude, codex or all, got $TOOL" ;; esac
if [ "$MODE" != uninstall ] && { [ -n "$mcp_remove" ] || [ -n "$keep_config" ] || [ -n "$extra_repos" ]; }; then
  die "--mcp, --keep-config and --repo only apply to uninstall"
fi
if [ "$MODE" = status ] && [ "$TOOL" != all ]; then die "status always covers every tool"; fi

problems=0

# say WORD TEXT: one aligned output line.
say() { printf '%-8s%s\n' "$1" "$2"; }
# bad WORD TEXT: a line on stderr that makes the exit status 1.
bad() { printf '%-8s%s\n' "$1" "$2" >&2; problems=1; }

wants() { [ "$TOOL" = all ] || [ "$TOOL" = "$1" ]; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

# present TOOL LABEL CONDITION...: missing is only an error when that tool
# was named with --tool.
present() {
  t=$1 label=$2; shift 2
  "$@" && return 0
  if [ "$TOOL" = "$t" ]; then bad skip "$label: not found"; else say skip "$label: not found"; fi
  return 1
}

# ---- links ------------------------------------------------------------------

ours() { [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]; }

# place SRC DST
place() {
  src=$1 dst=$2
  case $MODE in
    install | check)
      if ours "$dst" "$src"; then say ok "$dst"; return 0; fi
      if [ -e "$dst" ] || [ -L "$dst" ]; then bad skip "$dst (exists and is not ours; move it and re-run)"; return 0; fi
      if [ "$MODE" = check ]; then say link "$dst -> $src"; return 0; fi
      mkdir -p "$(dirname "$dst")"
      ln -s "$src" "$dst"
      say linked "$dst -> $src"
      ;;
    uninstall)
      if ours "$dst" "$src"; then rm "$dst"; say removed "$dst"; fi
      ;;
    status)
      if ours "$dst" "$src"; then say ok "$dst"
      elif [ -e "$dst" ] || [ -L "$dst" ]; then bad other "$dst (exists, not linked to this repo)"
      else bad missing "$dst"
      fi
      ;;
  esac
}

# broken DIR: links in DIR that point into this repo at something that no
# longer exists (a renamed or deleted script or skill). They are ours, so
# install and uninstall remove them.
broken() {
  [ -d "$1" ] || return 0
  for l in "$1"/* "$1"/.[!.]*; do
    [ -L "$l" ] || continue
    t=$(readlink "$l")
    case $t in "$REPO"/*) ;; *) continue ;; esac
    [ -e "$t" ] && continue
    case $MODE in
      install | uninstall) rm "$l"; say removed "$l (broken: $t is gone)" ;;
      check) say remove "$l (broken: $t is gone)" ;;
      status) bad broken "$l -> $t (gone; ./setup.sh install removes it)" ;;
    esac
  done
}

do_bin() {
  for f in "$REPO"/bin/*; do
    if [ -f "$f" ]; then place "$f" "$BIN_DIR/$(basename "$f")"; fi
  done
  broken "$BIN_DIR"
}

do_skills() { # do_skills DIR
  for d in "$REPO"/skills/*/; do
    [ -f "$d/SKILL.md" ] || continue
    d=${d%/}
    place "$d" "$1/$(basename "$d")"
  done
  broken "$1"
}

# ---- MCP servers ------------------------------------------------------------

# mcp_claude NAME URL. `claude mcp add` exits 1 with "already exists" when the
# name is taken in that scope; that counts as ok. `get` health-checks the
# server, so status needs a network round trip.
mcp_claude() {
  case $MODE in
    install)
      if out=$(claude mcp add -s user --transport http "$1" "$2" 2>&1); then
        say added "Claude Code MCP $1 -> $2 (log in: /mcp in Claude Code)"
      else
        case $out in
          *'already exists'*) say ok "Claude Code MCP $1" ;;
          *) bad skip "Claude Code MCP $1: $out" ;;
        esac
      fi
      ;;
    check)
      if claude mcp get "$1" >/dev/null 2>&1; then say ok "Claude Code MCP $1"; else say add "Claude Code MCP $1 -> $2"; fi
      ;;
    status)
      if out=$(claude mcp get "$1" 2>&1); then
        st=$(printf '%s\n' "$out" | sed -n 's/^ *Status: *//p')
        say ok "Claude Code MCP $1 (${st:-status unknown})"
      else
        bad missing "Claude Code MCP $1"
      fi
      ;;
    uninstall)
      if [ -z "$mcp_remove" ]; then
        say keep "Claude Code MCP $1 (remove: ./setup.sh uninstall --mcp, or claude mcp remove -s user $1)"
      elif claude mcp remove -s user "$1" >/dev/null 2>&1; then
        say removed "Claude Code MCP $1"
      else
        say keep "Claude Code MCP $1 (not registered at user scope)"
      fi
      ;;
  esac
}

# mcp_codex NAME URL. Codex's docs show `codex mcp add NAME --url URL` and
# `codex mcp list`. `codex mcp remove` is not in its docs, so uninstall tries
# it and falls back to pointing at config.toml.
mcp_codex() {
  listed=''
  if codex mcp list 2>/dev/null | grep -Eq "(^|[[:space:]])$1([[:space:]]|\$)"; then listed=1; fi
  case $MODE in
    install)
      if [ -n "$listed" ]; then say ok "Codex MCP $1"
      elif out=$(codex mcp add "$1" --url "$2" 2>&1); then say added "Codex MCP $1 -> $2 (log in: codex mcp login $1)"
      else bad skip "Codex MCP $1: $out"
      fi
      ;;
    check) if [ -n "$listed" ]; then say ok "Codex MCP $1"; else say add "Codex MCP $1 -> $2"; fi ;;
    status) if [ -n "$listed" ]; then say ok "Codex MCP $1"; else bad missing "Codex MCP $1"; fi ;;
    uninstall)
      if [ -z "$listed" ]; then return 0; fi
      if [ -z "$mcp_remove" ]; then
        say keep "Codex MCP $1 (remove: ./setup.sh uninstall --mcp)"
      elif codex mcp remove "$1" >/dev/null 2>&1; then
        say removed "Codex MCP $1"
      else
        bad keep "Codex MCP $1 (remove its [mcp_servers.$1] table from ~/.codex/config.toml)"
      fi
      ;;
  esac
}

do_mcp() { # do_mcp claude|codex
  while read -r name url; do
    [ -n "$name" ] || continue
    "mcp_$1" "$name" "$url"
  done <<EOF
$MCP_SERVERS
EOF
}

# ---- repo settings ----------------------------------------------------------

# repos_to_reset: the tracked list, the repo we run from, and --repo; one per
# line, each a work tree top level, without duplicates.
repos_to_reset() {
  {
    if [ -f "$REPOS_FILE" ]; then cat "$REPOS_FILE"; fi
    git rev-parse --show-toplevel 2>/dev/null || true
    printf '%s' "$extra_repos"
  } | while IFS= read -r r; do
    [ -n "$r" ] || continue
    top=$(git -C "$r" rev-parse --show-toplevel 2>/dev/null) || { say skip "$r (not a git repo any more)"; continue; }
    printf '%s\n' "$top"
  done | awk '!seen[$0]++'
}

# The hook path depends on the repo (worktrees, core.hooksPath ignored here
# because install-hook refuses those repos).
reset_repo() {
  if [ -n "$(git -C "$1" config --get-regexp '^sz\.' 2>/dev/null || true)" ]; then
    git -C "$1" config --remove-section sz
    say reset "$1 (sz.* settings: scopes, ticket prefix)"
  fi
  hook=$(cd "$1" && git rev-parse --git-path hooks/commit-msg 2>/dev/null || true)
  case $hook in '' | /*) ;; *) hook="$1/$hook" ;; esac
  if [ -n "$hook" ] && [ -f "$hook" ] && grep -Fq "$HOOK_MARK" "$hook"; then
    rm "$hook"
    say removed "$hook"
  fi
}

do_config() {
  case $MODE in
    status)
      if [ ! -f "$REPOS_FILE" ]; then say none "no repos with sz settings recorded"; return 0; fi
      while IFS= read -r r; do
        [ -n "$r" ] || continue
        if ! git -C "$r" rev-parse --git-dir >/dev/null 2>&1; then say gone "$r (in $REPOS_FILE, no longer a repo)"; continue; fi
        p=$(git -C "$r" config --get sz.ticketPrefix 2>/dev/null || echo '-')
        n=$(git -C "$r" config --get-all sz.scope 2>/dev/null | wc -l | tr -d ' ')
        say repo "$r (prefix $p, $n scopes)"
      done < "$REPOS_FILE"
      ;;
    uninstall)
      if [ -n "$keep_config" ]; then say keep "repo settings (--keep-config)"; return 0; fi
      repos_to_reset | while IFS= read -r r; do reset_repo "$r"; done
      if [ -f "$REPOS_FILE" ]; then rm "$REPOS_FILE"; say removed "$REPOS_FILE"; fi
      rmdir "$STATE_DIR" 2>/dev/null || true
      ;;
  esac
}

# ---- main -------------------------------------------------------------------

while IFS= read -r r; do
  [ -n "$r" ] || continue
  git -C "$r" rev-parse --git-dir >/dev/null 2>&1 || die "--repo $r is not a git repo"
done <<EOF
$extra_repos
EOF

# bin/ and repo settings are shared by every tool: a per-tool uninstall keeps them.
if [ "$MODE" != uninstall ] || [ "$TOOL" = all ]; then do_bin; fi

if [ "$MODE" = install ] || [ "$MODE" = check ]; then
  if wants claude && present claude '~/.claude (Claude Code skills)' test -d "$HOME/.claude"; then do_skills "$HOME/.claude/skills"; fi
  if wants codex && present codex '~/.codex (Codex skills)' test -d "$HOME/.codex"; then do_skills "$HOME/.agents/skills"; fi
  if wants claude && present claude 'claude CLI (Claude Code MCP servers)' has_cmd claude; then do_mcp claude; fi
  if wants codex && present codex 'codex CLI (Codex MCP servers)' has_cmd codex; then do_mcp codex; fi
else
  # status and uninstall look at both tools' folders whether or not the tool
  # is still installed; place() and broken() only touch our own links.
  if wants claude && { [ "$MODE" = uninstall ] || [ -d "$HOME/.claude" ]; }; then do_skills "$HOME/.claude/skills"; fi
  if wants codex && { [ "$MODE" = uninstall ] || [ -d "$HOME/.codex" ]; }; then do_skills "$HOME/.agents/skills"; fi
  if wants claude && has_cmd claude; then do_mcp claude; fi
  if wants codex && has_cmd codex; then do_mcp codex; fi
fi

if [ "$MODE" = status ] || { [ "$MODE" = uninstall ] && [ "$TOOL" = all ]; }; then do_config; fi

if [ "$MODE" = install ]; then
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) printf 'note: %s is not on PATH; add it in your shell profile\n' "$BIN_DIR" >&2 ;;
  esac
fi

exit "$problems"
