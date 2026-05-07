---
name: dashboard-review
description: |
  Ship-readiness browser QA for a Soria dive in Codex. Use when the user wants a
  live dive reviewed, QA'd, critiqued, or checked before promotion, including
  headless Playwright screenshots, render checks, data correctness,
  interactivity, methodology, edge cases, performance evidence, and the Soria
  good-dive grammar: analytical contract, time columns, dense parent/sub-metric
  rows, Top N + Other + Total cohorts, chart/table pairing, information density,
  and domain vocabulary.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: dashboard-review/SKILL.md
  variant: codex
---

# Dashboard Review

Codex adaptation of the `Soria-Inc/soria-stack` `/dashboard-review` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting. Then read the canonical skill at
[../../../../dashboard-review/SKILL.md](../../../../dashboard-review/SKILL.md);
it contains the review gates and Soria good-dive grammar.

## Focus

- live dive QA against `https://dev.soriaanalytics.com` before merge or
  `https://soriaanalytics.com` for prod canary
- actual rendered screenshots first; code and data checks explain or verify
  what the screenshots show
- headless Playwright evidence for render, interactivity, correctness, and
  performance
- cross-check rendered values against the `verifications.csv` seed and the
  live warehouse via `mcp__soria__warehouse_query`
- final gate before `/promote`

## Codex Runtime Rules

- Use plain Playwright headlessly when browser QA is needed. Do not open visible
  browser windows or panes.
- Prefer existing authenticated Playwright storage/profile when available.
- Do not start, restart, or reconfigure frontend/backend unless the user
  explicitly asks. If the target is down, report `TARGET_DOWN`.
- Save screenshots and a compact JSON report under
  `.dev/playwright/<review-name>/` when working in a repo.
- Keep live browser concurrency modest; parallelize screenshot analysis rather
  than opening many tabs at once.
- Separate tool/runtime failures from dashboard failures.
- Do not silently file tickets from here; hand off to `ticket` or `diagnose`.
