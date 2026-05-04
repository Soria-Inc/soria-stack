---
name: dive
description: Build or revise a dive end-to-end in Codex — dbt marts SQL, manifest, TSX component, DivesPage registration, verification rows, and methodology content. Use for new dives, major dive refactors, or deep review of an existing dive.
metadata:
  source_repo: https://github.com/Soria-Inc/soria-stack
  upstream_skill: dive/SKILL.md
  variant: codex
---

# Dive

Codex adaptation of the `Soria-Inc/soria-stack` `/dive` skill.

Read [../../references/codex-adapter.md](../../references/codex-adapter.md)
before acting.

## Focus

- dbt marts SQL under `frontend/src/dives/dbt/models/marts/...`
  (layers: staging → intermediate → marts; no upstream SQLMesh)
- manifests at `frontend/src/dives/manifests/{id}.manifest.tsx` — **`.tsx`**
  because the `methodology` field is JSX. Manifest owns `title`, `overview`,
  `methodology`, `table`, `modelId`, `verificationModel`, `columns`,
  `metrics`, `filters`, `defaultTopN`. Manifest `table` values should use
  the prod-looking catalog name (`soria_duckdb_main.main_marts...`); the
  frontend rewrites that catalog to staging when the environment badge is on
  staging.
- React components at `frontend/src/dives/{id}.tsx`. Compose
  `DiveShell` + `useDiveData(manifest, filters)` + `useDiveParam` (URL
  state) + `useDiveVerifications(manifest.verificationModel)` +
  `pivotRows` + `DiveGrid` / `DiveKPIRow` / `DiveSection`.
- DivesPage registration, rows in the shared `verifications.csv` seed
- grain-first design, not just visual assembly
- data survey via `mcp__soria__warehouse_query` before writing SQL

## Reusable Dive Design Principles

- Treat a dive as a consistent analytical instrument, not a collection of
  unrelated charts.
- Prefer a stable page pattern: KPI row, selected-row chart, then a pivot
  table.
- Tables should usually put time on the column axis and the primary dimension
  on rows.
- Use URL state for every meaningful control and selected row.
- When a table row represents an entity, clicking it should update the
  selected entity and redraw the chart.
- Default the selected entity to the first meaningful ranked row, not a
  hardcoded company unless product context requires it.
- For company or entity comparisons, prefer Top N cohorts on a stable size
  metric, plus `Other` and `Industry Total` where applicable.
- Keep ranking basis separate from displayed metric. Avoid ranking by noisy
  ratios like margin or mix percentage unless that is explicitly the analysis.
- Compute `Other`, totals, and ratios from summed numerators and denominators;
  do not average percentages.
- Suppress empty or meaningless rows. Avoid tables with many blanks, single
  low-value rows, or rows that do not add analytical value.
- Hide controls with only one meaningful option. Do not add redundant toggles
  or dropdowns when row click already controls selection.
- Use tree or pivot rows for subdimensions such as product mix, payer mix,
  rating bucket mix, or revenue category mix while preserving time as columns.
- KPIs should be view-specific and should explain the selected row or the
  market context, not reuse generic headline numbers.
- Charts should focus on the selected row, use the simplest legible visual
  form, and match existing dive styling.
- Build grain-first: model the analytical grain in dbt before composing React
  views.
- Prefer separate narrow marts or normalized semantic marts over pushing
  complex cohort/math logic into React.
- Verification rows should cover key totals, formula denominators, and known
  anchor values before the dive is considered ready.

## Notes

- Methodology lives in the manifest as JSX. `DiveShell` surfaces it; don't
  put it in the component.
- `useDiveData` hides the dual-mode load (Postgres proxy → WASM). Don't
  branch on mode in the component.
- Local `dbt run` writes to `soria_duckdb_staging`. Prod target is absent
  from committed `profiles.yml`; CI injects it on PR merge.
- Do **not** "fix" a dive manifest by changing `soria_duckdb_main` to
  `soria_duckdb_staging`. `use-dive-query.ts` intentionally rewrites
  `soria_duckdb_main` to the selected data environment. A local/staging dive
  should therefore have a manifest table like
  `soria_duckdb_main.main_marts.some_dive`, while the actual query hits
  `soria_duckdb_staging.main_marts.some_dive` when the EnvironmentBadge is
  set to staging.
- If a dive works in staging but `soria_duckdb_main.main_marts.<model>` is
  missing, that is expected before promotion. Treat prod absence as a
  promotion/build state, not evidence that the staging dive is wired wrong.
- **Iteration loop:** local `dbt run` → open `dev.soriaanalytics.com` →
  click the `EnvironmentBadge` (amber/green pill) to **staging** to see
  your changes; toggle back to **prod** for the customer view. Default is
  prod. The badge sends `X-SQLMESH-ENV` (legacy name; not SQLMesh-related).
- Use `preview` for in-chat output or `dashboard-review` for live UI proof
  after implementation.
- Use mempalace when available for domain definitions or prior design context.
