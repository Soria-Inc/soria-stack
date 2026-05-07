---
name: dashboard-review
description: |
  Ship-readiness QA for a live Soria dive before /promote. Use after /dive and
  /verify, or when asked to review, QA, check, critique, or gate a dashboard.
  Reviews the rendered analyst experience with browser screenshots, console and
  network evidence, data spot checks, interaction checks, methodology/verify
  content, performance, and the Soria good-dive grammar: analytical contract,
  time columns, dense parent/sub-metric rows, Top N + Other + Total cohorts,
  chart/table pairing, information density, and domain vocabulary. Reports PASS,
  PASS_WITH_CONCERNS, FAIL, or BLOCKED and routes follow-up to /ticket,
  /diagnose, /dive, or /promote. Never files tickets itself.
allowed-tools:
  - Bash
  - Read
---

# Dashboard Review

Answer one question: is this live dive ready for a customer to use?

Review what the analyst actually sees. Screenshot evidence comes first; code,
warehouse, and manifest evidence explain or verify what the screenshot shows.
Do not give abstract UI advice without rendered evidence.

## Runtime

Before reviewing, identify:

- dive slug
- base URL: `https://dev.soriaanalytics.com` before merge,
  `https://soriaanalytics.com` for prod canary
- expected environment badge: staging pre-merge, prod for canary
- manifest path and warehouse table when available

Browser rules:

- Use the existing target the user asked to review. Do not start, restart, or
  reconfigure the frontend/backend unless the user explicitly asks.
- If the target is down, report `TARGET_DOWN` with the URL and probe result.
- Use a headless browser. Never open visible browser windows during review.
- Prefer the project's authenticated browser state/profile when available.
- Keep live browser concurrency modest. Parallelism belongs mostly at the
  screenshot-analysis level, not by opening a large number of pages/tabs.
- Save screenshots and a small machine-readable run report under
  `.dev/playwright/<review-name>/` when working in a repo, or under the
  artifact directory named below when not.

Use the local browser runtime that is available in the agent environment:

- In Codex, prefer plain headless Playwright for navigation, waits,
  screenshots, console, and network evidence.
- In Claude environments with `/browse`, use `/browse` if it is the configured
  browser runtime.
- Do not turn this skill into browser setup debugging. If auth/runtime is
  broken, report `BLOCKED` and the missing condition.

For staging review, run preflight if the repo provides it:

```bash
make browse-preflight DIVE=<dive-slug> DATA_ENV=staging
```

If preflight fails, report `BLOCKED`. A rendered page alone is not enough:
browser fallback paths can mask backend or warehouse-query failures.

## Required Evidence

Collect:

- default-view screenshot after the page settles
- screenshot for each primary analysis/tab
- at least one representative non-default slice
- console errors, runtime overlays, failed network requests, shimmers, blank
  states, and loading states
- render timing for each captured slice
- visible row counts or table evidence where possible
- warehouse or verification-seed checks for key headline/table numbers

Immediate fail if the screenshot shows:

- Vite/runtime overlay
- blank page
- permanent loading indicator
- broken chart or table
- data error toast
- obvious text overlap or unusable controls
- chart/table mismatch on the same metric, period, or selected row

## Good Dive Grammar

Evaluate whether the dive follows the Soria analyst grammar.

### 1. Analytical Contract

The title, subtitle, controls, context numbers, chart, and table should answer
one clear analytical question. Identify:

- subject
- grain
- cohort logic
- time basis
- selected entity/geography
- source or method caveat when relevant

If the reviewer cannot write the page's analytical contract in one sentence
from the screenshot, the view is not good enough yet.

### 2. Time Columns

Tables should usually put time across columns. Rows should represent companies,
parents, states, contracts, regions, facilities, products, or metric groups.
This makes trends scan horizontally and keeps the page compact.

### 3. Dense Parent Rows

Use parent rows with expandable sub-metric rows when the view needs multiple
related measures:

- `Company -> Membership / Market Share / YoY`
- `Contract -> Rating / Enrollment / Contribution`
- `Region -> Revenue / Beds / Share`
- `Parent -> Metric components`

Avoid low-density views where each small metric gets its own sparse table,
card, or chart.

### 4. Parent Concept

Every view should have a stable parent object: company, parent organization,
state, market, contract, facility chain, segment, or region. The page should
make that object obvious.

### 5. Top N + Other + Total

Competitive views should usually use fixed Top N cohort logic with `Other` and
`Total` rollups. The ranking basis should be clear, usually latest-period size,
enrollment, beds, revenue, or the relevant domain denominator.

### 6. Information Density

Good dives should feel efficient. Low row-count views are usually a smell unless
the view is intentionally:

- a selected-entity detail
- a map
- a methodology/lineage view
- a genuinely small decomposition

### 7. Chart Summary, Table Truth

The chart should summarize the selected row, Top N cohort, geography, or primary
comparison. The table should be the dense audit surface. The chart and table
must agree on metric, period, and selected row.

### 8. Controls Hierarchy

Controls should be grouped by analytical role:

- `Analysis`
- geography/scope
- segment/LOB/product
- parent/entity/state/market
- metric/category
- mode/value vs YoY
- Top N/cohort

Use segmented controls when options are few and should expand horizontally. Use
dropdowns for high-cardinality choices. Controls should change grain, cohort,
metric, or mode; they should not be decoration.

### 9. First-Viewport Productivity

The first viewport should contain:

- title/subtitle
- control system
- context metrics when useful
- primary chart/map
- beginning of the dense table

Avoid dead space before the analyst reaches data.

### 10. Domain Vocabulary

Labels should sound like the underlying business, not generic BI. Prefer labels
such as `Capitation share of premiums`, `Affiliated share of spend`,
`Gap to 4-star cutpoint`, `Revenue per bed`, `Parent company`, or
`State exposure` when those are the actual concepts.

## Gates

Run every gate and record PASS, PASS_WITH_CONCERNS, FAIL, or BLOCKED.

### 1. Render

Confirm URL, environment badge, heading, primary controls, context metrics,
charts/maps/grids, and meaningful data. Save screenshot and text/snapshot
evidence. Capture console and network logs after the page settles.

### 2. Data Correctness

Compare representative rendered values against `verifications.csv` when seed
rows exist and against the live warehouse in the same environment mode the UI
is using. Check entity, period, metric, sign, unit, filter state, and formatting.
Fail material mismatches, sign flips, stale defaults, or UI rows that do not
match the reviewed warehouse path. Mark missing seed or warehouse access as
missing evidence, not confidence.

### 3. Analyst Grammar

Apply the Good Dive Grammar. Fail material problems in analytical contract,
time-column structure, parent/sub-metric density, Top N + Other + Total logic,
chart/table agreement, first-viewport productivity, or information density.

### 4. Interactivity

Enumerate meaningful controls from the manifest and visible UI. Test click or
change behavior, URL preset/deep-link behavior where relevant, and whether
visible state, URL state, and rendered data update coherently. Capture
before/after evidence. Do not call a control broken from one stale probe;
re-snapshot and retry first.

### 5. Methodology And Verify

Open methodology and verify surfaces. They should expose sources, links,
formulas for derived metrics, grain, filters, update cadence, freshness, and
verification or test status when available. Missing or empty trust content
blocks promotion.

### 6. Edge Cases

Scan for quiet trust breakers: `NaN`, `Infinity`, `undefined`, `null`, blank
values, bare `%` or `$`, impossible ratios, missing-period mishandling, totals
that disagree with shown rows, stale values after label changes, excessive
decimals, wrong units, or misleading rounding.

### 7. Performance And Network

After the page settles, flag failed authenticated requests, repeated 4xx/5xx,
client exceptions that affect the UI, retry storms, slow first usable render,
or interactions that hang in a loading state.

## Outcome

- `PASS`: all gates are clean and evidence is captured.
- `PASS_WITH_CONCERNS`: minor non-blocking issues are documented with why they
  do not block shipping.
- `FAIL`: at least one customer-visible issue blocks promotion.
- `BLOCKED`: auth, runtime, preflight, missing context, or missing data access
  prevents a fair review.

## Report

Write the report to:

```text
~/.soria-stack/artifacts/dashboard-review-<dive>-<YYYYMMDD-HHMM>.md
```

Include:

- run timestamp, URL, environment, manifest, and warehouse table
- overall outcome
- evidence artifact paths
- one concise line per gate
- findings ordered by severity, with evidence and concrete fix direction
- what works and should be preserved
- blockers only for customer-visible or review-blocking issues
- next step with a concrete skill: `/promote`, `/ticket`, `/diagnose`, or
  `/dive`

Do not file tickets or run downstream skills automatically. Report the evidence
and the recommended next step.
