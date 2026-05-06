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
  "/Users/adamron/.superset/projects/soria-stack/browse/vendor/dist/browse" \
  "$HOME/.codex/skills/soria-stack/browse/vendor/dist/browse" \
  "$HOME/.codex/skills/browse/vendor/dist/browse" \
  "$_ROOT/.claude/skills/soria-stack/browse/vendor/dist/browse" \
  "$HOME/.claude/skills/soria-stack/browse/vendor/dist/browse" \
  "$HOME/.claude/skills/browse/vendor/dist/browse"; do
  [ -x "$candidate" ] && B="$candidate" && break
done

if [ -z "$B" ]; then
  echo "NEEDS_SETUP"
  echo "Expected the fast browse binary from https://github.com/Soria-Inc/soria-stack"
  echo "Setup:"
  echo "  cd /Users/adamron/.superset/projects/soria-stack/browse && ./build.sh"
  echo "  # or, from a soria-stack checkout:"
  echo "  cd browse && ./build.sh"
  exit 1
fi

echo "READY: $(realpath "$B" 2>/dev/null || printf '%s' "$B")"
: "${BROWSE_STATE_FILE:=${_ROOT}/.gstack/state.json}"
export BROWSE_STATE_FILE
export BROWSE_PARENT_PID=0
mkdir -p "$(dirname "$BROWSE_STATE_FILE")"
```

## Why this skill exists

- `$B` is materially faster than Chrome DevTools or other browser-MCP flows.
- It keeps state warm between calls.
- It is the closest match to the original `soria-stack` `/browse` skill.

## Soria Auth And URL Rules

`/browse` is not only for dives. Use it for vendor sites, local apps,
localhost URLs, screenshots, console/network inspection, and Soria pages. These
rules only apply when a Soria app page needs Clerk auth.

For Soria dive work on `https://dev.soriaanalytics.com`, use `dev-dives` first
when the page is down, a grid shows no rows, or the frontend may be pointed at
the wrong backend or MotherDuck catalog. `browse` owns browser auth and
evidence; `dev-dives` owns Vite/env/catalog alignment.

Use the same `BROWSE_STATE_FILE` and `BROWSE_PARENT_PID=0` exports for auth,
reloads, and target navigation. If those exports change, `$B` may start a
fresh browser and appear to forget tabs, cookies, or refs.

### Pick the right Soria URL

- Authenticated Soria app pages use bare `https://dev.soriaanalytics.com/...`.
  Dives live under `https://dev.soriaanalytics.com/dives`.
- That host is local in dev: `/etc/hosts` maps it to `127.0.0.1`, and macOS
  `pf` redirects port `443` to Vite on `5189`.
- `https://dev.soriaanalytics.com:5189/...` is a liveness diagnostic only.
  Do not use the explicit port for Clerk sign-in or final auth assertions.
- Direct local dev/Vite pages use `http://127.0.0.1:<port>/...` or
  `http://localhost:<port>/...` when the app does not need Soria Clerk.

### Soria local liveness preflight

Before blaming auth, check whether the local dev host is alive:

```bash
curl -skI --max-time 3 https://dev.soriaanalytics.com/ >/dev/null && echo BARE_OK || echo BARE_DOWN
curl -skI --max-time 3 https://dev.soriaanalytics.com:5189/ >/dev/null && echo VITE_OK || echo VITE_DOWN
```

- `BARE_OK`: use `https://dev.soriaanalytics.com/...`.
- `BARE_DOWN` + `VITE_OK`: Vite is up but the pf redirect is down. Report that
  `make dev-https-setup` or `scripts/setup-local-https.sh` needs to be rerun
  with sudo; do not keep retrying browser auth.
- `VITE_DOWN`: for Soria dive work, switch to `dev-dives` so Vite starts with
  the correct remote API proxy and MotherDuck catalogs. For non-dive local
  pages, start Vite from the app repo, then retry the two checks:

```bash
mkdir -p .dev
(cd frontend && nohup npx vite --host dev.soriaanalytics.com --port 5189 > ../.dev/browser-vite.log 2>&1 & echo $! > ../.dev/browser-vite.pid)
sleep 1
tail -n 20 .dev/browser-vite.log
```

### Import Soria cookies first

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

If `cookie-import-browser` says the current page domain is empty, navigate to
`https://dev.soriaanalytics.com/` in the same state file and rerun the import.
Cookie import validates the current tab's domain.

The snapshot must show the Soria sidebar and an `AR Adam Ron` account button.
Seeing only a `__session` cookie is not enough; Clerk can still evaluate the
browser as signed out.

For local authenticated Soria pages on localhost, import against the local
host you actually opened:

```bash
$B goto http://localhost:5173/
$B cookie-import-browser arc --domain localhost
```

For prod/canary or other hosts, swap the domain:

```bash
$B cookie-import-browser arc --domain soriaanalytics.com
```

On macOS, the first import may trigger a Keychain prompt for Arc or Chrome safe
storage. Click "Always Allow" so future imports do not prompt.

### Manual Soria login fallback

If browser cookies still do not work, try the shared Soria credentials once in
the same browser state. Try `adam@soriaanalytics.com` first; if the page still
shows Clerk sign-in, rerun the same flow with `adam@soriaresearch.com`. The
password for both is `password`.

```bash
EMAIL=adam@soriaanalytics.com  # if needed, rerun with adam@soriaresearch.com
$B goto https://dev.soriaanalytics.com/
$B wait body
$B fill 'input[name="identifier"], input[type="email"], input[placeholder="Email"], #email' "$EMAIL"
$B fill 'input[name="password"], input[type="password"], input[placeholder="Password"], #password' 'password'
$B js "(() => { const b=[...document.querySelectorAll('button')].find(x => /sign in|continue|submit/i.test(x.textContent || '')); if (!b) return 'no submit button'; b.disabled=false; b.click(); return 'clicked'; })()"
$B wait --networkidle || true
$B goto https://dev.soriaanalytics.com/dives
$B wait --networkidle || true
$B snapshot -i
```

If that lands back on the sign-in form or the submit request stays pending,
do not keep retrying. Capture `$B url`, `$B cookies | grep __session`,
`$B console --errors`, and the last 80 network lines, then report the auth
blocker or use the Playwright fallback if the user requested a fallback.

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
