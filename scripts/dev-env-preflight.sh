#!/usr/bin/env bash
# dev-env-preflight.sh — what's running on this machine right now.
#
# Reports port collisions, sibling worktrees with `make run-dev` going,
# and MotherDuck clone bindings BEFORE you spin up another dev stack.
# Read-only — never kills processes, never deletes anything. Just tells
# you what's there so you don't clobber it.
# Also flags zombie processes — Soria-shaped processes (vite, node soria,
# python soria) holding ports that aren't tracked in any worktree's
# .dev/*.pid files. Suggests a kill command; doesn't actually kill.
#
# Invoked by the /dev-env skill (Phase 0). Also useful standalone:
#   $ bash ~/.claude/skills/soria-stack/scripts/dev-env-preflight.sh
#
# Output: human-readable status block. Exit 0 always (informational).

set -uo pipefail

THIS_PATH="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
THIS_DB="$(grep -E '^MOTHERDUCK_STAGING_DATABASE=' "$THIS_PATH/.env" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | head -c 60)"

# Build a space-separated list of pids tracked by any worktree's
# .dev/frontend.pid / .dev/backend.pid (only alive pids).
TRACKED_PIDS="$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}' | while read -r wt; do
  for f in "$wt/.dev/frontend.pid" "$wt/.dev/backend.pid"; do
    pid="$(cat "$f" 2>/dev/null)"
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && echo "$pid"
  done
done | tr '\n' ' ')"

echo "=== dev-env preflight ==="
echo "this worktree:  $THIS_PATH"
echo "this DB:        ${THIS_DB:-<not set>}"
echo ""

# --- Ports in use across the typical Soria range ---
echo "ports in use (Soria range 5173-5180 / 8900-8910):"
ports_found=0
zombies_found=0
for port in 5173 5174 5175 5176 5177 5178 5179 5180 8900 8901 8902 8903 8904 8905 8906 8907 8908 8909 8910; do
  pid="$(lsof -ti :"$port" 2>/dev/null | head -1)"
  [ -z "$pid" ] && continue
  ports_found=$((ports_found + 1))
  cmd="$(ps -p "$pid" -o command= 2>/dev/null | head -c 70)"
  cwd="$(lsof -p "$pid" 2>/dev/null | awk '$4=="cwd" {print $9; exit}' | head -c 60)"
  echo "  :$port  pid=$pid  $cmd"
  [ -n "$cwd" ] && echo "         cwd: $cwd"

  # Zombie check: pid not in any worktree's tracked pids AND cmd looks Soria-shaped
  is_tracked=false
  for tp in $TRACKED_PIDS; do
    if [ "$tp" = "$pid" ]; then is_tracked=true; break; fi
  done
  is_soria=false
  case "$cmd $cwd" in
    *vite*|*node*soria*|*python*soria*|*python*-m*soria*|*uvicorn*soria*|*dbos*|*soria-2*|*/soria/*) is_soria=true ;;
  esac
  if [ "$is_tracked" = false ] && [ "$is_soria" = true ]; then
    echo "         ⚠ zombie — Soria-shaped but no worktree's .dev/*.pid owns it"
    echo "         kill: kill $pid"
    zombies_found=$((zombies_found + 1))
  fi
done
[ "$ports_found" = 0 ] && echo "  (none — all ports free)"
echo ""

# --- Sibling worktrees with running dev servers ---
echo "sibling worktrees with make run-dev:"
siblings_found=0
git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}' | while read -r wt; do
  [ "$wt" = "$THIS_PATH" ] && continue
  fpid="$(cat "$wt/.dev/frontend.pid" 2>/dev/null)"
  bpid="$(cat "$wt/.dev/backend.pid" 2>/dev/null)"
  fpid_alive=""
  bpid_alive=""
  [ -n "$fpid" ] && kill -0 "$fpid" 2>/dev/null && fpid_alive="alive"
  [ -n "$bpid" ] && kill -0 "$bpid" 2>/dev/null && bpid_alive="alive"
  [ -z "$fpid_alive$bpid_alive" ] && continue
  siblings_found=$((siblings_found + 1))
  branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  db="$(grep -E '^MOTHERDUCK_STAGING_DATABASE=' "$wt/.env" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | head -c 60)"
  echo "  $wt  ($branch)"
  [ -n "$fpid_alive" ] && echo "    frontend pid=$fpid alive"
  [ -n "$bpid_alive" ] && echo "    backend  pid=$bpid alive"
  [ -n "$db" ] && echo "    DB=$db"
done
# (subshell for-loop counter doesn't propagate; if no output between header and next echo, none found)
echo ""

# --- MotherDuck clone collisions across worktrees ---
echo "MotherDuck clones referenced across worktrees:"
all_dbs="$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}' | \
  while read -r wt; do
    grep -E '^MOTHERDUCK_STAGING_DATABASE=' "$wt/.env" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | head -c 60 | xargs -I{} echo "  $wt  {}"
  done)"
echo "$all_dbs"
# Detect duplicates
dup="$(echo "$all_dbs" | awk '{print $2}' | sort | uniq -d)"
if [ -n "$dup" ]; then
  echo ""
  echo "  ⚠  duplicate clone names detected: $dup"
  echo "     two worktrees write to the same MotherDuck DB → races/clobbering"
fi
echo ""

# --- Summary ---
echo "=== summary ==="
if [ "$ports_found" = 0 ]; then
  echo "ports: free"
else
  echo "ports: $ports_found in use across Soria range"
  [ "$zombies_found" -gt 0 ] && echo "       ⚠ $zombies_found zombie(s) flagged — see kill commands above"
fi
if [ -z "$dup" ]; then
  echo "DBs:   no clone collisions across worktrees"
else
  echo "DBs:   ⚠  collision on '$dup'"
fi
echo ""
echo "(read-only — fix or proceed manually. nothing has changed.)"
