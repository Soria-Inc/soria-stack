---
name: smoke
version: 2.0.0
description: |
  Adversarial browser QA for live dives. Opens a headless browser, handles
  Clerk login, navigates to /dives/{id}, waits through the dual-mode load
  (Postgres proxy first paint → WASM warmup), clicks every DiveControlBar
  filter, tests MethodologyModal and VerifyModal buttons, and tries to
  BREAK the dive.
  Use when asked to "test the dive", "QA this", "check the controls",
  "click through it", or "does the UI work".
  Use after /dive builds a dive and it lands in the current env. (soria-stack)
benefits-from: [dive, verify]
allowed-tools:
  - Read
  - Bash
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: smoke"
echo "---"
echo "Active environment:"
soria env status 2>&1 || echo "  (soria CLI not authed — run /env first)"
echo "---"

B=~/.claude/skills/gstack/browse/dist/browse
if [ -x "$B" ]; then
  echo "BROWSE: ready"
else
  echo "BROWSE: not found — run: cd ~/.claude/skills/gstack && ./setup"
  exit 1
fi
```

Read `ETHOS.md`. Key principles: #10 (validate with your eyes), #29 (every
dive ships with MethodologyModal + VerifyModal), #30 (dual-mode loading).

## Skill routing (always active)

- Data values look wrong → invoke `/verify` (Mode 3: Semantic)
- Dive SQL needs fixing → invoke `/dive`
- Infrastructure issue (504, timeout, load stuck) → invoke `/diagnose`

---

# /smoke — "Click everything, try to break it"

You are an adversarial QA tester. You are trying to BREAK the dive, not
confirm it works. Click the weird combinations. Filter to a single company.
Toggle rapidly. Look for empty states, NaN values, stale data, controls that
do nothing, modals that don't open, WASM cold starts confused for breakage.

---

## Step 1: Identify the dive + URL

If the user didn't name a dive, list them:

```bash
ls frontend/src/dives/*.tsx
```

Or check the registered dives:

```bash
grep -E "id: \"" frontend/src/pages/DivesPage.tsx
```

The URL pattern is `{app_base}/dives/{id}`. The app base depends on the env:
- Local dev: `http://localhost:5173/dives/{id}`
- Preview env: `https://{env}.soriaanalytics.com/dives/{id}`
- Prod: `https://app.soriaanalytics.com/dives/{id}`

Always report which URL you're testing.

## Step 2: Handle Clerk auth

All dives require Clerk login. Import cookies from the user's real browser:

```bash
$B cookie-import-browser
```

If the user is an admin, test both admin and customer views (admin sees
search + related news, customers don't per ENG-1559). Ask the user if they
want to test one role or both.

## Step 3: Navigate and Orient

```bash
$B goto {dive_url}
$B screenshot /tmp/dive-initial.png  # baseline screenshot
```

### Dual-mode loading contract

The dive loads in two phases. **Do not declare "broken" until both phases
have been observed.**

```bash
# Phase 1: Postgres proxy first paint (~500ms)
$B wait-for "table, .dive-grid, [data-testid='dive-grid']" --timeout 5000
$B screenshot /tmp/dive-first-paint.png

# Phase 2: WASM upgrade (~20s)
$B wait-for-network-idle --timeout 25000
$B screenshot /tmp/dive-wasm-warm.png

# Check console for errors
$B console
```

Compare the three screenshots. If Phase 1 shows data but Phase 2 is stuck
or empty, that's a WASM upgrade bug. If Phase 1 is blank after 5s, that's
a Postgres proxy failure (invoke `/diagnose`).

## Step 4: Enumerate Controls

```bash
$B snapshot -i                          # all interactive elements with @e refs
```

Build a control map from the snapshot — look for `DiveControlBar`,
`StickyDiveHeader`, and filter button groups:

```
Controls found:
  Segment:       [@e3 MA] [@e4 PDP] [@e5 Total]
  Distribution:  [@e7 Individual] [@e8 Group]
  Metric toggle: [@e10 Enrollment] [@e11 Market Share %] [@e12 YoY Growth %]

Modal buttons:
  Methodology:   [@e20 "How this is built"]
  Verify:        [@e21 "How we verify"]
```

Also check for `DiveKPIRow` cards and `DivePageHeader` if present.

## Step 5: Click Every Control

Work through one group at a time, resetting to defaults between groups:

```bash
$B click @e4                   # click "PDP"
$B wait-for-network-idle --timeout 3000
$B snapshot -D                 # diff — what changed?
$B screenshot /tmp/segment-pdp.png
```

**For each click, check:**
- Did the grid update? (snapshot diff shows data changes)
- Is the grid empty? (0 rows = manifest filter drift or missing data)
- Did any JS error fire? (`$B console`)
- Did the active toggle visually change?
- Did the data source indicator (if shown) change from "server" to "wasm" or "cache"?

**Adversarial combinations** — after individual controls work:
- Smallest slice: single company + single segment + single distribution
- "All" on everything: can it handle the full data volume?
- Rapid toggles: click filter → immediately click another → race conditions?
- Refresh in the middle: does the session cache survive a reload?

## Step 6: Test the Modals (Principle #29)

Every dive ships with MethodologyModal and VerifyModal. Click each:

```bash
$B click @e20                         # Methodology button
$B wait-for ".modal, [role='dialog']" --timeout 2000
$B screenshot /tmp/methodology-open.png

# Check the modal has content
$B snapshot -s ".modal"
# Look for: sources section, metrics section, grain, update cadence
# Empty or placeholder content = shipping blocker

$B press Escape
$B click @e21                         # Verify button
$B wait-for ".modal, [role='dialog']" --timeout 2000
$B screenshot /tmp/verify-open.png

# Check the verify panel has real content
$B snapshot -s ".modal"
# Look for: verify check rows rendered (or VerifyTooltip hovering over cells),
# last dbt run timestamp (from vite-dbt-sync), external sources list

$B press Escape
```

**Both modals must open, must have real content, and must close cleanly.**
Missing or placeholder modals are a shipping blocker.

## Step 7: Inspect the Data

```bash
$B snapshot -s "[data-testid='dive-grid'], .dive-grid, table"
```

**Red flags:**
- Market share > 100% or < 0%
- YoY growth showing NaN, Infinity, or blanks
- "Other" rollup row with nonsensical ratio values (847% market share)
- Missing months or gaps in the time series
- Values that don't change when you toggle metrics (stale render)
- Total row doesn't match sum of visible rows
- Filter value drift: selected filter returns 0 rows even though the filter
  exists in the manifest

## Step 8: Cross-Reference with Warehouse

Query the marts table directly and compare against what the browser shows:

```bash
soria warehouse query "
SELECT parent_organization, reporting_month, enrollment, market_share_pct
FROM soria_duckdb_main.main_marts.{model}
WHERE segment = 'MA' AND distribution = 'Individual'
  AND reporting_month = '2026-03'
ORDER BY enrollment DESC LIMIT 10
"
```

Mismatches mean: stale dbt run, session cache poison, or manifest pointing at
the wrong table.

## Step 9: Admin vs Customer View Split (ENG-1559)

If the user is testing both roles, log out and back in as customer:

```bash
$B click "[data-testid='user-menu']"
$B click "[data-testid='logout']"
$B cookie-import-browser  # re-import as customer
$B goto {dive_url}
```

**Customer view should NOT show:**
- Search (admin-only)
- Related news / related dashboards sidebar
- SQL error details (hidden from non-admins per #726)
- Any admin-only filters or controls

## Step 10: Report

```
Dive QA: [Name]
URL: {dive_url}
Environment: [active soria env]
Roles tested: [admin / customer / both]

Load phases:
  Phase 1 (PG proxy): ✅ first paint at ~420ms, data visible
  Phase 2 (WASM):     ✅ warmed at ~18s, source switched to "wasm"

Controls tested:
  ✅ Segment (3/3) — MA, PDP, Total all update the grid
  ✅ Distribution (2/2) — Individual, Group work
  ✅ Metric toggle (3/3) — Enrollment, Market Share %, YoY Growth %
  ❌ Distribution=Group — empty grid (manifest drift — 'Group' has 0 rows)

Modals:
  ✅ MethodologyModal opens, populated with 4 sources and 5 metrics
  ❌ VerifyModal opens but "last_dbt_test" is null — missing vite-dbt-sync run

Data checks:
  ✅ Market share sums to ~100% for default view
  ✅ Enrollment values match warehouse within 0.1%
  ❌ "Other" rollup row shows 347% market share — missing rollup config

Admin vs customer split (ENG-1559):
  ✅ Admin sees search + related news
  ✅ Customer does not see search or related

JS errors: 0 (after warmup), 1 during warmup (cosmetic — known issue)

Verdict: FUNCTIONAL with 3 issues:
  1. Distribution=Group manifest drift → /dive (update manifest values list)
  2. VerifyModal missing dbt timestamps → run `dbt run` + vite-dbt-sync
  3. "Other" rollup bug → /dive (add rollup config to DiveGrid)
```

Attach screenshot PNGs.

---

## Workflow Summary

```
$B cookie-import-browser                          # auth (once per role)
$B goto {dive_url}                                # navigate
$B wait-for "dive-grid" + snapshot + console      # Phase 1 check
$B wait-for-network-idle                          # Phase 2 check
$B snapshot -i                                    # control enumeration
for each control: $B click → wait → snapshot -D   # test controls
$B click methodology → screenshot → close         # modal check
$B click verify → screenshot → close              # modal check
soria warehouse query {compare SQL}                # cross-reference
(optional) log out → re-login as other role       # admin/customer split
report with screenshots                           # verdict
```

---

## Anti-Patterns

1. **Declaring "broken" during WASM cold start.** Phase 1 must complete
   first. If Phase 1 shows data, the dive is not broken — WASM is just warming.

2. **Skipping the modal checks.** Every dive ships with MethodologyModal +
   VerifyModal (Principle #29). A dive without them is shipping opaque data.

3. **Not cross-referencing with the warehouse.** Browser values match what
   the marts table actually contains? If not, you have a stale cache, a
   stale dbt run, or a session cache bug.

4. **Not testing both roles.** Admin-only features leaking to customers is
   a real bug (ENG-1559). Test both.

5. **Reporting JS errors without distinguishing warmup from runtime.** WASM
   compilation fires some warnings during warmup that aren't real errors.
   Report them separately.

6. **Forgetting to screenshot the baseline.** Without a baseline, you can't
   diff. Every test run needs a `/tmp/dive-initial.png`.

7. **Rushing through the controls.** Adversarial means try to break it.
   Click rapidly, toggle while loading, use the smallest filter combo.
   Don't just verify the happy path.
