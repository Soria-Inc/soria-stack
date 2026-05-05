---
name: dashboard-review
description: |
  Ship-readiness browser QA for a live Soria dive before /promote. Use after
  /dive and /verify, or when asked to review, QA, check, or gate a dashboard.
  Use /browse for browser auth, navigation, screenshots, snapshots, console,
  network, and interaction evidence. Reviews render quality, data correctness,
  controls, methodology/verify content, edge-case formatting, and performance.
  Reports PASS, PASS_WITH_CONCERNS, FAIL, or BLOCKED and routes follow-up to
  /ticket, /diagnose, /dive, or /promote. Never files tickets itself.
allowed-tools:
  - Bash
  - Read
---

# Dashboard Review

Answer one question: is this live dive ready for a customer to use?

This is a browser QA rubric. It is not `/browse`, `/verify`, or `/diagnose`.
Assume `/verify` has handled warehouse correctness; this review checks whether
the live UI presents the right data clearly, completely, and reliably.

## Runtime

Use `/browse` for all browser mechanics: `$B`, auth, cookie import, Soria
environment handling, screenshots, snapshots, console, network, and element
refs. Do not duplicate `/browse` setup or debugging instructions here.

Before reviewing, confirm:

- dive slug
- base URL: `https://dev.soriaanalytics.com` before merge,
  `https://soriaanalytics.com` for prod canary
- expected environment badge: staging pre-merge, prod for canary
- manifest path and warehouse table when available

For staging review, run the `/browse` preflight if available:

```bash
make browse-preflight DIVE=<dive-slug> DATA_ENV=staging
```

If preflight fails, report `BLOCKED`. A rendered page alone is not enough
because browser fallback paths can mask backend or warehouse-query failures.

## Principles

- Review the exact environment the user intends to ship.
- Prefer evidence over impressions: screenshots, snapshots, rendered text,
  console/network logs, seed rows, warehouse rows, and control diffs.
- Separate dashboard defects from test-tool defects; retry stale refs, failed
  waits, and covered clicks with fresh `/browse` evidence.
- Collect all gate evidence before summarizing unless the page cannot be
  reached or authenticated.
- Block promotion for customer-visible wrong numbers, broken controls, missing
  trust content, visible runtime errors, or unusable performance.

## Gates

Run every gate and record PASS, PASS_WITH_CONCERNS, FAIL, or BLOCKED.

### 1. Render

Open the dive with `/browse`. Confirm the URL, environment badge, heading,
primary controls, KPIs/charts/grids, and meaningful data. Save screenshot and
snapshot/text evidence. Capture console and network logs after the page settles.

### 2. Data Correctness

Compare representative rendered values against `verifications.csv` when seed
rows exist and against the live warehouse in the same environment mode the UI
is using. Check entity, period, metric, sign, unit, filter state, and formatting.
Fail material mismatches, sign flips, stale defaults, or UI rows that do not
match the reviewed warehouse path. Mark missing seed or warehouse access as
missing evidence, not confidence.

### 3. Interactivity

Enumerate meaningful controls from the manifest and visible UI. Test click or
change behavior, URL preset/deep-link behavior where relevant, and whether
visible state, URL state, and rendered data update coherently. Capture
before/after evidence. Do not call a control broken from one failed `/browse`
probe; re-snapshot and retry first.

### 4. Methodology And Verify

Open methodology and verify surfaces. They should expose sources, links,
formulas for derived metrics, grain, filters, update cadence, freshness, and
verification or test status when available. Missing or empty trust content
blocks promotion.

### 5. Edge Cases

Scan for quiet trust breakers: `NaN`, `Infinity`, `undefined`, `null`, blank
values, bare `%` or `$`, impossible ratios, missing-period mishandling, totals
that disagree with shown rows, stale values after label changes, excessive
decimals, wrong units, or misleading rounding.

### 6. Performance And Network

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
- blockers only for customer-visible or review-blocking issues
- next step with a concrete skill: `/promote`, `/ticket`, `/diagnose`, or
  `/dive`

Do not file tickets or run downstream skills automatically. Report the evidence
and the recommended next step.
