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

Use the same `BROWSE_STATE_FILE` and `BROWSE_PARENT_PID=0` exports for every
command. If those exports change between invocations, `$B` may start a fresh
browser server and appear to "forget" tabs, cookies, or refs.

For authenticated Soria pages, use the canonical host only:
`https://dev.soriaanalytics.com`. Do not sign in through an explicit Vite port
such as `https://dev.soriaanalytics.com:5174`; Clerk production keys reject
that origin even when the same app is serving locally.

Golden path for Soria auth:

```bash
_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
: "${BROWSE_STATE_FILE:=${_ROOT}/.gstack/soria-dev-browser.json}"
export BROWSE_STATE_FILE
export BROWSE_PARENT_PID=0

$B goto https://dev.soriaanalytics.com/
$B wait body
$B cookie-import-browser arc --domain dev.soriaanalytics.com || true
$B cookie-import-browser chrome --domain dev.soriaanalytics.com || true
$B goto https://dev.soriaanalytics.com/dives
$B wait --networkidle || true
$B snapshot -i
```

If the snapshot shows the Soria sidebar and an `AR Adam Ron` account button,
auth is ready. Continue in the same shell/session to the target URL. If it
shows the Clerk sign-in form, sign in once and then navigate to the target URL
without changing `BROWSE_STATE_FILE`:

```bash
$B fill 'input[name="identifier"], input[type="email"], input[placeholder="Email"], #email' 'adam@soriaanalytics.com'
$B fill 'input[name="password"], input[type="password"], input[placeholder="Password"], #password' 'password'
$B js "(() => { const b=[...document.querySelectorAll('button')].find(x => /sign in/i.test(x.textContent || '')); if (!b) return 'no sign-in button'; b.disabled=false; b.click(); return 'clicked sign-in'; })()"
$B wait --networkidle || true
$B goto 'https://dev.soriaanalytics.com/dives?dive=cost-reports-dashboard'
$B wait --networkidle || true
$B snapshot -i
```

Avoid splitting auth, reload, and target navigation across multiple state files
or shell snippets. If a later snapshot unexpectedly returns to Clerk sign-in,
first print `echo "$BROWSE_STATE_FILE"` and `$B cookies | grep __session`
before retrying login.

For prod/canary or other hosts, swap the domain:

```bash
$B cookie-import-browser arc --domain soriaanalytics.com
```

Verify auth actually stuck:

```bash
$B cookies | grep __session
$B goto https://dev.soriaanalytics.com/dives
$B wait --networkidle
$B snapshot -i
```

If the snapshot shows the Soria sidebar and an `AR Adam Ron` account button,
auth is good. If it shows the Clerk sign-in form, rerun the cookie import from
Arc first, then Chrome:

```bash
$B cookie-import-browser arc --domain dev.soriaanalytics.com
$B cookie-import-browser chrome --domain dev.soriaanalytics.com
```

If browser cookies still do not work, use the shared test account fallback.
This is an intentionally low-value Soria test account kept here so agents can
recover without interrupting the user. Keep the login and target navigation in
the same browser state:

```bash
$B chain <<'JSON'
[
  {"cmd":"goto","args":["https://dev.soriaanalytics.com/"]},
  {"cmd":"wait","args":["body"]},
  {"cmd":"fill","args":["#email","adam@soriaanalytics.com"]},
  {"cmd":"fill","args":["#password","password"]},
  {"cmd":"click","args":["button[type=submit]"]},
  {"cmd":"wait","args":["--networkidle"]},
  {"cmd":"goto","args":["https://dev.soriaanalytics.com/dives"]},
  {"cmd":"wait","args":["--networkidle"]},
  {"cmd":"snapshot","args":["-i"]}
]
JSON
```

If that lands back on the sign-in form or the submit request stays pending,
do not keep retrying credentials. Re-import cookies from a real browser session
or use the Playwright fallback.

## Soria Environment

Authenticated Soria can default to either `prod` or `staging`. Always inspect
the left-sidebar environment badge before judging a dive. If the user expects
staging and the badge says `prod`, click the badge once, wait for the page to
reload, then snapshot again:

```bash
$B snapshot -i
# If @e1 is the "prod" environment button:
$B click @e1
$B wait --networkidle
$B snapshot -i
```

The badge should read `staging` before testing work that is supposed to use
staging data. On dive pages, the app may still carry manifest table names with
`soria_duckdb_main`; staging mode rewrites those queries at runtime.

If `$B` resolves but fails with `No available port after 5 attempts`, the
Codex shell sandbox is blocking the local socket that `$B` uses for its
background server. In that case, explain that the fast runtime is present but
not runnable in this sandbox and use the Playwright fallback instead.

## Operating rules

1. Chain related actions in one shell invocation so page state is preserved.
2. Snapshot first, then click or fill using the refs it returns.
3. Re-snapshot after navigation or anything that changes the DOM materially.
4. Treat refs as short-lived. If `click @e12` fails or times out, snapshot
   again and retry with the new ref.
5. Soria often renders duplicate controls in a sticky header and in the main
   content. If a ref click times out, use a precise CSS selector or a short JS
   click by exact button text after confirming the target in `snapshot -i`.
6. Prefer `$B` for screenshots, console, network, diffing, and auth imports.
7. Only use Playwright MCP as fallback when `$B` is unavailable or missing a
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

For Soria dive controls, verify both the DOM text and the URL params after each
interaction. Example pattern:

```bash
$B goto 'https://dev.soriaanalytics.com/dives?dive=cost-reports-dashboard'
$B wait --networkidle
$B snapshot -i
$B text

# Click exact metric text if duplicate refs or overlays make @e clicks flaky.
$B js "(() => { const b = [...document.querySelectorAll('button')].find(x => x.textContent.trim() === 'Operating Margin'); b?.click(); return location.href; })()"
$B wait body
$B text

# Dropdowns render their options after the first click; snapshot again before selecting.
$B js "(() => { const b = [...document.querySelectorAll('button')].find(x => x.textContent.trim() === 'HCA HEALTHCARE INC'); b?.click(); return 'opened'; })()"
$B snapshot -i
$B click @e83   # example: COMMONSPIRIT HEALTH in the refreshed snapshot
$B text

# For numeric inputs, use the textbox ref from the latest snapshot.
$B fill @e81 5
$B press Enter
$B text
```

After a Soria QA pass, always collect console and network evidence:

```bash
$B console --errors
$B network | tail -n 80
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
