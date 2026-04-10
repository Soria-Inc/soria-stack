#!/usr/bin/env bash
# install.sh — symlink every soria-stack skill into the parent skills dir
# so Claude Code discovers them as top-level skills.
#
# Claude Code reads skills from flat top-level directories in the skills
# parent (typically ~/.claude/skills/). A pack like soria-stack is a git
# clone; each of its skill subdirectories needs a symlink in the parent
# so it shows up in the /skill dropdown.
#
# This script is idempotent: run it any time after `git pull` to pick up
# new skills, remove stale symlinks pointing at deleted skills, and repoint
# symlinks whose targets have moved.
#
# Usage:
#   # Run from the pack root (recommended)
#   cd ~/.claude/skills/soria-stack && ./install.sh
#
#   # Or via absolute path
#   bash ~/.claude/skills/soria-stack/install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PACK_NAME="$(basename "$SCRIPT_DIR")"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

echo "soria-stack installer"
echo "====================="
echo "Pack:   $SCRIPT_DIR"
echo "Parent: $PARENT_DIR"
echo ""

if [ ! -d "$PARENT_DIR" ]; then
  echo "ERROR: parent dir does not exist: $PARENT_DIR" >&2
  exit 1
fi

cd "$PARENT_DIR"

created=0
updated=0
removed=0
skipped=0

# Phase 1: create or update symlinks for every skill directory in the pack.
# A "skill directory" is a direct child of the pack that contains a SKILL.md.
for skill_path in "$SCRIPT_DIR"/*/; do
  [ -f "$skill_path/SKILL.md" ] || continue
  skill_name="$(basename "$skill_path")"
  target="$PACK_NAME/$skill_name"
  link="$skill_name"

  if [ -L "$link" ]; then
    current="$(readlink "$link")"
    if [ "$current" = "$target" ]; then
      continue  # already correct
    fi
    ln -sfn "$target" "$link"
    printf '  updated: %s -> %s (was %s)\n' "$link" "$target" "$current"
    updated=$((updated + 1))
  elif [ -e "$link" ]; then
    printf '  skipped: %s exists and is not a symlink\n' "$link"
    skipped=$((skipped + 1))
  else
    ln -s "$target" "$link"
    printf '  created: %s -> %s\n' "$link" "$target"
    created=$((created + 1))
  fi
done

# Phase 2: clean up stale symlinks that point into this pack but whose
# target no longer exists (e.g. a skill was removed from the pack).
for link in *; do
  [ -L "$link" ] || continue
  current="$(readlink "$link")"
  case "$current" in
    "$PACK_NAME/"*)
      skill_name="${current#"$PACK_NAME"/}"
      if [ ! -e "$SCRIPT_DIR/$skill_name/SKILL.md" ]; then
        rm "$link"
        printf '  removed: %s (stale — target %s no longer exists)\n' "$link" "$current"
        removed=$((removed + 1))
      fi
      ;;
  esac
done

echo ""
echo "Summary: $created created, $updated updated, $removed removed, $skipped skipped"
echo "Done."
