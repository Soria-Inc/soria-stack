#!/usr/bin/env bash
# auto-update.sh — pull soria-stack at most once per day, re-run install.sh
# if anything actually changed.
#
# Wired as a Claude Code SessionStart hook by install.sh. Quiet by default;
# only prints when something updates or when there's an error worth seeing.
# Refuses to clobber local commits — uses --ff-only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PACK_DIR="$(dirname "$SCRIPT_DIR")"

STAMPFILE="$PACK_DIR/.last-auto-update"
TODAY="$(date +%Y-%m-%d)"

# Skip if we already pulled today
if [ -f "$STAMPFILE" ] && [ "$(cat "$STAMPFILE" 2>/dev/null)" = "$TODAY" ]; then
  exit 0
fi

cd "$PACK_DIR"

# Confirm this is a git checkout
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

# Confirm there's an `origin` remote pointed at soria-stack
if ! git config --get remote.origin.url 2>/dev/null | grep -q "soria-stack"; then
  exit 0
fi

# Capture SHA before/after so we know whether anything actually changed
SHA_BEFORE="$(git rev-parse HEAD 2>/dev/null || echo none)"

# Fetch silently, then ff-only pull. If pull fails (local divergence,
# uncommitted changes, etc.), exit cleanly — user fixes manually.
git fetch --quiet origin main 2>/dev/null || { echo "$TODAY" > "$STAMPFILE"; exit 0; }
if ! git pull --ff-only --quiet origin main 2>/dev/null; then
  # Diverged / behind / dirty — leave alone, write stamp so we don't retry
  # on every session start
  echo "$TODAY" > "$STAMPFILE"
  exit 0
fi

SHA_AFTER="$(git rev-parse HEAD 2>/dev/null || echo none)"
echo "$TODAY" > "$STAMPFILE"

# Re-run install.sh if anything changed (picks up new skills, rebuilds
# /browse if its src changed). Suppress noise on success; print on error.
if [ "$SHA_BEFORE" != "$SHA_AFTER" ]; then
  echo "soria-stack: updated ${SHA_BEFORE:0:8} → ${SHA_AFTER:0:8}" >&2
  if [ -x "$PACK_DIR/install.sh" ]; then
    if ! "$PACK_DIR/install.sh" >/dev/null 2>&1; then
      echo "soria-stack: install.sh re-run failed; run it manually" >&2
    fi
  fi
fi
