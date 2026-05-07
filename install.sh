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

# Phase 3: build the /browse skill's vendored binary if needed.
# The browse binary is a compiled Bun CLI (src lives in browse/vendor/).
# It's idempotent — skips the build if dist/browse is newer than src/.
if [ -x "$SCRIPT_DIR/browse/build.sh" ]; then
  browse_bin="$SCRIPT_DIR/browse/vendor/dist/browse"
  src_newest="$(find "$SCRIPT_DIR/browse/vendor/src" -type f -newer "$browse_bin" 2>/dev/null | head -1 || true)"
  if [ ! -x "$browse_bin" ] || [ -n "$src_newest" ]; then
    echo ""
    echo "Building /browse binary (bun + playwright)..."
    if "$SCRIPT_DIR/browse/build.sh"; then
      echo "  built: $browse_bin"
    else
      echo "  WARNING: /browse build failed. /browse skill will not work until built." >&2
      echo "  Fix and re-run: $SCRIPT_DIR/browse/build.sh" >&2
    fi
  fi
fi

# Phase 4: register the auto-update hook in ~/.claude/settings.json so
# soria-stack pulls latest at most once per day on Claude Code session start.
# Idempotent — re-running install.sh won't double-register.
AUTO_UPDATE="$SCRIPT_DIR/scripts/auto-update.sh"
if [ -x "$AUTO_UPDATE" ]; then
  if command -v python3 >/dev/null 2>&1; then
    if python3 - "$AUTO_UPDATE" <<'PYEOF_INSTALL'
import json, os, sys
from pathlib import Path

target = sys.argv[1]
settings_path = Path.home() / ".claude" / "settings.json"
settings_path.parent.mkdir(parents=True, exist_ok=True)

if settings_path.exists():
    with settings_path.open() as f:
        try:
            settings = json.load(f)
        except json.JSONDecodeError:
            print(f"WARNING: {settings_path} is not valid JSON; skipping hook install", file=sys.stderr)
            sys.exit(1)
else:
    settings = {}

hooks = settings.setdefault("hooks", {}).setdefault("SessionStart", [])

# Idempotency: skip if any existing entry already references this exact script
for entry in hooks:
    for h in entry.get("hooks", []):
        if h.get("command") == target:
            print(f"  hook already registered for {target}")
            sys.exit(0)

hooks.append({
    "matcher": "*",
    "hooks": [{"type": "command", "command": target}]
})

with settings_path.open("w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

print(f"  registered SessionStart hook -> {target}")
PYEOF_INSTALL
    then
      :
    fi
  else
    echo "  WARNING: python3 not found; cannot register auto-update hook." >&2
    echo "  Manually add this to ~/.claude/settings.json hooks.SessionStart:" >&2
    echo "    {\"matcher\": \"*\", \"hooks\": [{\"type\": \"command\", \"command\": \"$AUTO_UPDATE\"}]}" >&2
  fi
fi

echo "Done."
