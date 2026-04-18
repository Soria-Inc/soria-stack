---
name: browse
description: Fast persistent browser automation for Codex using the `$B` binary from `Soria-Inc/soria-stack`. Use when asked to open a page, verify a dive, reproduce a UI bug, capture screenshots, inspect console or network, or import cookies from Arc or Chrome. Prefer this over slower Chrome-first flows for `/browse`.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  preferred_runtime: "$B"
---

# Browse

This is the fast browser path. For `/browse`, prefer the upstream `$B` binary
from `Soria-Inc/soria-stack` and only fall back to Playwright MCP if `$B`
is unavailable and the user explicitly wants a slower fallback.

## Preamble

Run this first in one shell:

```bash
_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
B=""
for candidate in \
  "$_ROOT/browse/vendor/dist/browse" \
  "$_ROOT/plugins/soria-stack/skills/browse/vendor/dist/browse" \
  "$_ROOT/.claude/skills/soria-stack/browse/vendor/dist/browse" \
  "$HOME/.claude/skills/soria-stack/browse/vendor/dist/browse" \
  "$HOME/.claude/skills/browse/vendor/dist/browse"; do
  [ -x "$candidate" ] && B="$candidate" && break
done

if [ -z "$B" ]; then
  echo "NEEDS_SETUP"
  echo "Expected the fast browse binary from https://github.com/Soria-Inc/soria-stack"
  echo "Setup:"
  echo "  if [ -d \"$_ROOT/browse\" ]; then cd \"$_ROOT/browse\" && ./build.sh; fi"
  echo "  # or:"
  echo "  git clone https://github.com/Soria-Inc/soria-stack.git ~/.claude/skills/soria-stack"
  echo "  cd ~/.claude/skills/soria-stack/browse && ./build.sh"
  exit 1
fi

echo "READY: $B"
: "${BROWSE_STATE_FILE:=${_ROOT}/.gstack/state.json}"
export BROWSE_STATE_FILE
export BROWSE_PARENT_PID=0
mkdir -p "$(dirname "$BROWSE_STATE_FILE")"
```

## Why this skill exists

- `$B` is materially faster than Chrome DevTools or other browser-MCP flows.
- It keeps state warm between calls.
- It is the closest match to the original `soria-stack` `/browse` skill.

## Auth bootstrap

Do not try to log in to Clerk headlessly. Import cookies from a real browser.
The default Soria dev URL is `https://dev.soriaanalytics.com` (local vite
pointed at prod DBOS + Clerk via `make dev-https`):

```bash
$B goto https://dev.soriaanalytics.com/
$B cookie-import-browser arc --domain dev.soriaanalytics.com
```

For prod canary or other hosts, swap the domain:

```bash
$B cookie-import-browser arc --domain soriaanalytics.com
```

Verify auth actually stuck:

```bash
$B cookies | grep __session
```

If `__session` is missing, tell the user to sign in in a real Arc or Chrome
tab first, then rerun the import.

If `$B` resolves but fails with `No available port after 5 attempts`, the
Codex shell sandbox is blocking the local socket that `$B` uses for its
background server. In that case, explain that the fast runtime is present but
not runnable in this sandbox and use the Playwright fallback instead.

## Operating rules

1. Chain related actions in one shell invocation so page state is preserved.
2. Snapshot first, then click or fill using the refs it returns.
3. Re-snapshot after navigation or anything that changes the DOM materially.
4. Prefer `$B` for screenshots, console, network, diffing, and auth imports.
5. Only use Playwright MCP as fallback when `$B` is unavailable or missing a
   capability the user explicitly needs.

## Common flows

### Open and inspect

```bash
$B goto https://dev.soriaanalytics.com/dives?dive=my-dive \
  && $B wait --networkidle \
  && $B snapshot -c \
  && $B console \
  && $B network
```

### Capture evidence

```bash
$B screenshot /tmp/dive.png
$B snapshot -a -o /tmp/dive-annotated.png
```

### Reproduce an interaction

```bash
$B goto https://dev.soriaanalytics.com/dives?dive=my-dive
$B snapshot -i
# use the returned refs, then:
$B click @e12
$B snapshot -D
```

### Inspect a vendor site before writing a scraper

```bash
$B goto https://example.com
$B text
$B links
$B forms
$B html
```

## Fallback

If `$B` is unavailable and the user still wants browser work, the plugin ships
Playwright MCP as a slower fallback. Do not silently switch; say that the fast
runtime is missing and ask whether to proceed with the fallback.
