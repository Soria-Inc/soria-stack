---
name: smoke
version: 1.0.0
description: |
  Adversarial browser QA for live dashboards. Opens a headless browser,
  clicks every page control, and verifies data loads, controls respond,
  and values make sense. Tries to BREAK the dashboard.
  Use when asked to "test the dashboard", "QA this", "check the controls",
  "click through it", or "does the UI work".
  Use after /dashboard builds and deploys a dashboard. (soria-stack)
benefits-from: [dashboard, verify]
allowed-tools:
  - sumo_*
  - Read
  - Bash
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "BRANCH: $_BRANCH"
echo "SKILL: smoke"
echo "---"

B=~/.claude/skills/gstack/browse/dist/browse
if [ -x "$B" ]; then
  echo "BROWSE: ready"
else
  echo "BROWSE: not found — run: cd ~/.claude/skills/gstack && ./setup"
  exit 1
fi
```

Read `ETHOS.md` from this skill pack if not already loaded.

## Skill routing (always active)

- Data values look wrong → invoke `/verify` (Mode 3: Semantic)
- Dashboard SQL needs fixing → invoke `/dashboard`
- Infrastructure issue (504, timeout) → invoke `/diagnose`

---

# /smoke — "Click everything"

You are an adversarial QA tester. You are trying to BREAK the dashboard, not
confirm it works. Click the weird combinations. Filter to a single company.
Toggle rapidly. Look for empty states, NaN values, stale data, controls that
do nothing.

---

## Step 1: Navigate and Orient

If the dashboard requires auth, import cookies first:

```bash
$B cookie-import-browser
```

Navigate to the dashboard:

```bash
$B goto https://soria-2.soriaanalytics.com/dashboards
```

Once on the dashboard page:

```bash
$B snapshot -i                          # all interactive elements with @e refs
$B screenshot /tmp/dashboard-initial.png  # baseline screenshot
$B console                              # check for JS errors
```

Identify: metric toggles, segment/filter controls, the data table (loaded?
how many rows?), any errors.

## Step 2: Enumerate Controls

Build a control map from the snapshot:

```
Controls found:
  Metric:    [@e3 Enrollment] [@e4 Market Share %] [@e5 YoY Growth %]
  LOB:       [@e7 All] [@e8 MA] [@e9 PDP]
  Geo Level: [@e10 All] [@e11 County] [@e12 MSA] [@e13 National]
```

## Step 3: Click Every Control

Work through one group at a time, resetting to defaults between groups:

```bash
$B click @e8                   # click "MA"
$B snapshot -D                 # diff — what changed?
$B screenshot /tmp/lob-ma.png
```

**For each click, check:**
- Did the table update? (snapshot diff shows data changes)
- Is the table empty? (0 rows = broken filter or missing data)
- Did any JS error fire? (`$B console`)
- Did the active toggle visually change?

**Adversarial combinations** — after individual controls work:
- Smallest slice: single company + single segment + single geo level
- "All" on everything: can it handle the full data volume?
- Rapid toggles: click metric → immediately click segment → race conditions?

## Step 4: Inspect the Data

```bash
$B snapshot -s "table"         # scope snapshot to the data table
```

**Red flags:**
- Market share > 100% or < 0%
- YoY growth showing NaN, Infinity, or blanks
- "Other" row with nonsensical ratio values (847% market share)
- Missing months or gaps in the time series
- Values that don't change when you switch metrics (stale render)
- Total row doesn't match sum of visible rows

## Step 5: Cross-Reference (optional)

Query the warehouse for the same slice and compare against the browser:

```sql
SELECT parent_organization, enrollment, market_share_pct
FROM platinum.{dashboard_model}
WHERE segment = 'MA' AND reporting_month = '{latest}'
ORDER BY enrollment DESC LIMIT 10
```

Mismatches mean: wrong table, pivot computing differently, or stale cache.

## Step 6: Report

```
Dashboard QA: [Name]
URL: https://soria-2.soriaanalytics.com/[path]

Controls tested:
  OK  Metric toggles (4/4) — all update the table
  OK  LOB (3/3) — MA, PDP, All load data
  ERR Geo Level — "County" shows empty table (0 rows)
  OK  Top N — changes visible rows correctly

Data checks:
  OK  Market share sums to ~100% for default view
  ERR "Other" row shows 347% market share — missing rollup annotation
  OK  Enrollment values match warehouse within 0.1%

JS errors: 0

Verdict: FUNCTIONAL with 1 data issue.
```

Attach screenshot PNGs showing issues.

## Workflow Summary

```
$B cookie-import-browser                     # auth (once)
$B goto <dashboard-url>                      # navigate
$B snapshot -i && $B console                 # orient + errors
for each control: $B click → $B snapshot -D  # test controls
$B snapshot -s "table"                       # read data values
warehouse_query(compare SQL)                 # cross-reference
report with screenshots                      # verdict
```
