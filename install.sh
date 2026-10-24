#!/bin/sh
# install.sh: link this repo's files to where the tools look for them.
#
#   ./install.sh             create the links (safe to re-run)
#   ./install.sh --uninstall remove the links this script created
#
# POSIX sh. Uses only `ln -s`, `readlink` (no flags; present on Linux and
# macOS) and `mkdir -p`. It never overwrites or deletes anything that is not
# a symlink pointing into this repo.
#
# What gets linked:
#   bin/*            -> $SZ_BIN_DIR (default ~/.local/bin)
#   skills/<name>/   -> ~/.claude/skills/<name>   if ~/.claude exists (Claude Code)
#   skills/<name>/   -> ~/.agents/skills/<name>   if ~/.codex exists  (Codex)

set -eu

REPO=$(cd "$(dirname "$0")" && pwd -P)
BIN_DIR=${SZ_BIN_DIR:-$HOME/.local/bin}
MODE=install
case ${1:-} in
  '') ;;
  --uninstall) MODE=uninstall ;;
  *) printf 'usage: %s [--uninstall]\n' "$0" >&2; exit 2 ;;
esac

conflicts=0

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

for f in "$REPO"/bin/*; do
  if [ -f "$f" ]; then place "$f" "$BIN_DIR/$(basename "$f")"; fi
done

for d in "$REPO"/skills/*/; do
  [ -f "$d/SKILL.md" ] || continue
  d=${d%/}
  name=$(basename "$d")
  if [ -d "$HOME/.claude" ]; then place "$d" "$HOME/.claude/skills/$name"; fi
  if [ -d "$HOME/.codex" ]; then place "$d" "$HOME/.agents/skills/$name"; fi
done

if [ "$MODE" = install ]; then
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) printf 'note: %s is not on PATH; add it in your shell profile\n' "$BIN_DIR" >&2 ;;
  esac
fi

exit "$conflicts"
