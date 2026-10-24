#!/bin/sh
# install.sh: link this repo's files to where the tools look for them.
#
#   ./install.sh [--tool claude|codex|all]               install (safe to re-run)
#   ./install.sh [--tool claude|codex|all] --uninstall   remove what it installed
#
#   --tool  which AI tool to set up skills and MCP servers for (default: all).
#           `all` sets up each tool that is present and skips the others;
#           naming one tool that is not present is an error. bin/ is always linked.
#
# POSIX sh. Uses only `ln -s`, `readlink` (no flags; present on Linux and
# macOS) and `mkdir -p`. It never overwrites or deletes anything that is not
# a symlink pointing into this repo.
#
# MCP servers are the one thing that is not a link: they are registered with
# each AI tool's own `mcp add` command, at user scope, and left alone if a
# server with that name already exists. --uninstall does not remove them (it
# cannot tell whether you added them yourself); it prints the commands.
#
# What gets linked:
#   bin/*            -> $SZ_BIN_DIR (default ~/.local/bin); shared, so a
#                    per-tool --uninstall keeps it
#   skills/<name>/   -> ~/.claude/skills/<name>   claude: needs ~/.claude
#   skills/<name>/   -> ~/.agents/skills/<name>   codex:  needs ~/.codex
#
# MCP servers registered (MCP_SERVERS below), per tool; needs its CLI on PATH:
#   linear-server    https://mcp.linear.app/mcp

set -eu

REPO=$(cd "$(dirname "$0")" && pwd -P)
BIN_DIR=${SZ_BIN_DIR:-$HOME/.local/bin}
MODE=install
TOOL=all
usage() { printf 'usage: %s [--tool claude|codex|all] [--uninstall]\n' "$0" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case $1 in
    --uninstall) MODE=uninstall ;;
    --tool) [ $# -ge 2 ] || usage; TOOL=$2; shift ;;
    --tool=*) TOOL=${1#--tool=} ;;
    *) usage ;;
  esac
  shift
done
case $TOOL in
  claude | codex | all) ;;
  *) printf '%s: --tool must be claude, codex or all, got %s\n' "$0" "$TOOL" >&2; exit 2 ;;
esac

conflicts=0

# wants TOOL: is TOOL selected by --tool?
wants() { [ "$TOOL" = all ] || [ "$TOOL" = "$1" ]; }

# present TOOL LABEL CONDITION...: run CONDITION; when it fails, say so.
# Missing is only an error when that tool was named with --tool.
present() {
  t=$1 label=$2; shift 2
  "$@" && return 0
  if [ "$TOOL" = "$t" ]; then
    printf 'skip    %s: not found\n' "$label" >&2; conflicts=1
  else
    printf 'skip    %s: not found\n' "$label"
  fi
  return 1
}
has_cmd() { command -v "$1" >/dev/null 2>&1; }

# One "name url" per line: remote (streamable HTTP) MCP servers the skills use.
MCP_SERVERS='linear-server https://mcp.linear.app/mcp'

# place SRC DST
place() {
  src=$1 dst=$2
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    if [ "$MODE" = uninstall ]; then
      rm "$dst"; printf 'removed %s\n' "$dst"
    else
      printf 'ok      %s\n' "$dst"
    fi
    return 0
  fi
  [ "$MODE" = uninstall ] && return 0
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    printf 'skip    %s (exists and is not ours; move it and re-run)\n' "$dst" >&2
    conflicts=1
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  printf 'linked  %s -> %s\n' "$dst" "$src"
}

# bin/ is shared by every tool: uninstalling one tool leaves it linked.
if [ "$MODE" = install ] || [ "$TOOL" = all ]; then
  for f in "$REPO"/bin/*; do
    if [ -f "$f" ]; then place "$f" "$BIN_DIR/$(basename "$f")"; fi
  done
fi

# Uninstall removes our links even if the tool itself is gone; place() only
# ever removes a link that points into this repo.
link_claude='' link_codex=''
if [ "$MODE" = uninstall ]; then
  if wants claude; then link_claude=1; fi
  if wants codex; then link_codex=1; fi
else
  if wants claude && present claude '~/.claude (Claude Code skills)' test -d "$HOME/.claude"; then link_claude=1; fi
  if wants codex && present codex '~/.codex (Codex skills)' test -d "$HOME/.codex"; then link_codex=1; fi
fi

for d in "$REPO"/skills/*/; do
  [ -f "$d/SKILL.md" ] || continue
  d=${d%/}
  name=$(basename "$d")
  if [ -n "$link_claude" ]; then place "$d" "$HOME/.claude/skills/$name"; fi
  if [ -n "$link_codex" ]; then place "$d" "$HOME/.agents/skills/$name"; fi
done

# mcp_claude NAME URL: Claude Code. `claude mcp add` exits 1 with
# "already exists" when the name is taken in that scope; that counts as ok.
mcp_claude() {
  if [ "$MODE" = uninstall ]; then
    printf 'keep    Claude Code MCP %s (remove: claude mcp remove -s user %s)\n' "$1" "$1"
    return 0
  fi
  if out=$(claude mcp add -s user --transport http "$1" "$2" 2>&1); then
    printf 'added   Claude Code MCP %s -> %s (log in: /mcp in Claude Code)\n' "$1" "$2"
  else
    case $out in
      *'already exists'*) printf 'ok      Claude Code MCP %s\n' "$1" ;;
      *) printf 'skip    Claude Code MCP %s: %s\n' "$1" "$out" >&2; conflicts=1 ;;
    esac
  fi
}

# mcp_codex NAME URL: Codex. Its docs show `codex mcp add NAME --url URL` and
# `codex mcp list`; `remove` is not documented, so uninstall points to config.toml.
mcp_codex() {
  if [ "$MODE" = uninstall ]; then
    printf 'keep    Codex MCP %s (remove its [mcp_servers.%s] table from ~/.codex/config.toml)\n' "$1" "$1"
    return 0
  fi
  if codex mcp list 2>/dev/null | grep -Eq "(^|[[:space:]])$1([[:space:]]|\$)"; then
    printf 'ok      Codex MCP %s\n' "$1"
  elif out=$(codex mcp add "$1" --url "$2" 2>&1); then
    printf 'added   Codex MCP %s -> %s (log in: codex mcp login %s)\n' "$1" "$2" "$1"
  else
    printf 'skip    Codex MCP %s: %s\n' "$1" "$out" >&2; conflicts=1
  fi
}

mcp_with_claude='' mcp_with_codex=''
if wants claude && present claude 'claude CLI (Claude Code MCP servers)' has_cmd claude; then mcp_with_claude=1; fi
if wants codex && present codex 'codex CLI (Codex MCP servers)' has_cmd codex; then mcp_with_codex=1; fi

while read -r name url; do
  [ -n "$name" ] || continue
  if [ -n "$mcp_with_claude" ]; then mcp_claude "$name" "$url"; fi
  if [ -n "$mcp_with_codex" ]; then mcp_codex "$name" "$url"; fi
done <<EOF
$MCP_SERVERS
EOF

if [ "$MODE" = install ]; then
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) printf 'note: %s is not on PATH; add it in your shell profile\n' "$BIN_DIR" >&2 ;;
  esac
fi

exit "$conflicts"
