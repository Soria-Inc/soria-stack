---
name: dive
version: 1.0.0
description: |
  Build a dive end-to-end — dbt marts SQL + manifest + TSX component +
  DivesPage registration + rows in the shared verifications seed +
  methodology content wired into the dive component. Forces grain-first
  thinking, end-user framing, and the "what question does this answer?"
  conversation before any SQL. Includes data quality survey, SQL review
  checklist, and verify-check authoring.
  Use when asked to "build a dive", "make a dashboard", "write the SQL",
  "create a pivot", "show me the data", "profile this table", "review the
  dive SQL", or "add verify checks".
  Proactively invoke this skill (do NOT write dbt models ad-hoc) when the
  user wants to build or modify a dive. Three Questions must be answered first.
  Use after /ingest or /map, before /verify. (soria-stack)
benefits-from: [ingest, map, parent-map]
allowed-tools:
  - Read
  - Bash
  - Write
  - Edit
  - Glob
  - Grep
  - WebFetch
  - WebSearch
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: dive"
echo "---"
echo "Active environment:"
soria env status 2>&1 || echo "  (soria CLI not authed — run /env first)"
echo "---"
echo "Git state:"
git status --short 2>&1 | head -15 || echo "  (not in a worktree)"
echo "---"
echo "Checking for prior artifacts..."
ls -t ~/.soria-stack/artifacts/ingest-*.md ~/.soria-stack/artifacts/map-*.md 2>/dev/null | head -3
echo "---"
echo "Checking dive filesystem layout..."
ls frontend/src/dives/ 2>/dev/null | head -20
ls frontend/src/dives/dbt/models/marts/ 2>/dev/null
ls frontend/src/dives/dbt/seeds/ 2>/dev/null
```

**Before proceeding:** Read the `soria env status` output. If the active
environment type is `prod`, STOP — dives cannot be authored against prod.
Switch to a dev env via `/env`.

Read `ETHOS.md`. Key principles for /dive: #4, #5, #12, #13, #14, #16, #28, #29, #30, #31.

**Check for prior work:** Read any ingest or map artifacts — they have table
names, schemas, value mapping status, and open questions. If no artifacts
exist, check what tables are available:

```bash
soria warehouse query "SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema IN ('bronze', 'silver', 'gold') ORDER BY 1, 2"
```

If /plan exists, check if it specified R-phase verification criteria.

## Skill routing (always active)

When the user's intent shifts mid-conversation, invoke the matching skill —
do NOT continue ad-hoc:

- User wants to check pipeline status → invoke `/status`
- User wants to fix extraction issues → invoke `/ingest`
- User wants to fix value mappings → invoke `/map`
- User says "verify this", "spot check", "is this correct" → invoke `/verify`
- User wants to see the dive rendered in chat → invoke `/preview`
- User wants to test the dive in a browser → invoke `/dashboard-review`
- User says "push to prod" → invoke `/promote`

**After /dive completes, suggest `/verify`** (Model Verify + Semantic Verify)
and `/preview` to inspect the output.

---

# /dive — "What question does this answer?"

You are a dive designer. Your job is to build the full stack for a dive:
dbt marts model → verify rows in the shared seed → manifest → TSX component
→ methodology content in the component → `DivesPage.tsx` registration.

You NEVER write SQL before answering three questions.

---

## Dive Architecture (what you're building)

Every dive has **five pieces of your own code plus rows in a shared seed
file**, all in the same env's worktree:

```
frontend/src/dives/dbt/models/marts/{domain}/{model}.sql    -- dbt marts SQL
frontend/src/dives/manifests/{dive-id}.manifest.ts          -- data contract
frontend/src/dives/{dive-id}.tsx                            -- React component
frontend/src/pages/DivesPage.tsx                            -- registration entry
frontend/src/dives/dbt/seeds/verifications.csv              -- ADD ROWS HERE for
                                                             --    your dive's checks
                                                             --    (shared seed across
                                                             --    all dives)
```

The dive is **not done** until:
- The marts model is in git and `dbt run` materializes it successfully
- The manifest references the marts model and all filter values exist in the data
- The component imports `useDiveData(manifest, filters)` and uses
  `useDiveVerifications({model_name})` to surface verify checks
- The component is registered in `DivesPage.tsx`
- At least ~15–20 rows have been added to `seeds/verifications.csv` with
  `model = '{your_marts_model}'` (one check row per metric × parent × period
  combination you care about)
- `dbt seed` has refreshed the verifications table
- Methodology content is visible through the dive's DivePageHeader or
  MethodologyModal integration (see "Methodology content" below)

**IMPORTANT — check main vs. your worktree:** The entire
`frontend/src/dives/` ecosystem is new work. It exists in the `sticky-danger`
branch but may or may not be merged to main yet. Before editing, run
`ls frontend/src/dives/` — if the directory doesn't exist, you may be on
main and need to branch from sticky-danger (ask the user).

## Git discipline

Every file you touch in this skill is git-tracked. Commit in logical chunks:

| Milestone | Commit |
|---|---|
| After `dbt run` succeeds for the new marts model | `dive({id}): add {domain} marts model` |
| After the manifest + TSX component exist and build | `dive({id}): add manifest + component` |
| After DivesPage registration | `dive({id}): register in DivesPage` |
| After verifications.csv rows added + `dbt seed` | `dive({id}): add verify checks` |
| After methodology content wired up | `dive({id}): add methodology content` |

Run `git status --short` before each commit to see what you changed. Don't
include unrelated edits in dive commits — keep the scope tight so
`soria env diff` and PR review stay readable.

## Iterative dev loop

For iterating on a single dive in isolation (without running the full
frontend app), sticky-danger has a `dives-preview/` scaffold — a minimal
Vite app that renders one dive at a time against a local MotherDuck
connection. If `dives-preview/` exists in your worktree, the loop is:

```bash
cd dives-preview
cp .env.example .env        # populate MOTHERDUCK_TOKEN
npm install && npm run dev
# edit dive.tsx to re-export your target dive
# open http://localhost:5173
```

Otherwise, use the full frontend dev server (`cd frontend && npm run dev`)
and navigate to `/dives/{your-dive-id}`.

---

## Domain Grounding (before the Three Questions)

Before designing the model, ground it in how the real world talks about this data.

### Earnings transcript and meeting search

Search prior sessions and transcripts for how the data domain is discussed:

```
mcp__openclaw__mempalace_search: query="utilization trends adjusted discharges", wing="earnings"
mcp__openclaw__mempalace_search: query="MLR medical loss ratio", wing="granola"
```

This tells you the exact metrics analysts ask about, how they frame YoY
comparisons, and what baseline periods they reference.

### External research (WebSearch / WebFetch)

Use `WebSearch` and `WebFetch` for broader domain grounding:
- "Standard KPIs for [this analytical domain]?"
- "How do equity analysts evaluate [this metric]?"
- "What's the published benchmark for [this rate]?"

Skip both steps if the domain is well-understood from prior sessions.

---

## Before ANY SQL: The Three Questions

### The Simplicity Check (before anything else)

If the user asks for multiple dives, multiple marts models, or a complex
structure — push back:
- "Can this be 1 dive with filter controls slicing it instead of 5 separate dives?"
- "Can this be 1 marts model with filter dimensions instead of 6 models?"
- "Do we need a gold model here, or can silver feed marts directly?"

Take a position. The simpler approach that produces correct data wins.

### Question 1: What specific question does this answer?
Not "show hospital data." Specific:
- "Which parent company has the lowest enrollment-weighted premium in each state?"
- "What's the Medical Care Ratio trend for UNH vs HUM over 10 years?"
- "How many Medicare Advantage beneficiaries are in 4+ star plans by insurer?"

If you can't state the question in one sentence, you're not ready to write SQL.

### Question 2: Who is looking at this?
- **Equity research analyst** → sortable pivot tables, company comparisons,
  YoY trends, enrollment-weighted metrics
- **Internal team** → pipeline health, data freshness, coverage gaps
- **Customer dashboard** → clean presentation, intuitive filters, audit trail
- **Adam exploring data** → flexibility, slice by any dimension

The audience determines: metric selection, grain, aggregation level, and
which filters to expose in the manifest.

### Question 3: What's the ideal visualization?
- Pivot table with companies as rows, months as columns?
- Time series chart with company lines?
- Bar chart comparing segments?
- Map with state-level shading?
- KPI cards + comparison table?

Sketch the visualization in text before writing SQL. The visualization
determines the grain and the shared primitives you'll reuse:

- `DiveGrid` — AG-Grid-based table with hierarchical rows
- `DiveKPIRow` — top-of-page KPI cards
- `DiveControlBar` — filter controls bound to manifest filters
- `DivePageHeader` — title, subtitle, last-updated
- `DiveUSMap` — state-level map
- `StickyDiveHeader` — sticky header for long-scroll dives
- `MethodologyModal` — per-element information button
- `VerifyModal` — semantic check results + provenance

### ⛔ GATE: THREE QUESTIONS ANSWERED
Present your answers to the three questions. Wait for confirmation before
designing the model.

---

## The Grain Design Step

This is the hardest part. Get this wrong and everything downstream is broken.

### Step 1: Define the grain
State it explicitly:
```
One row = one [parent_organization] per [reporting_month] per [segment]
```

### Step 2: List all dimensions in the grain
```
Dimensions in grain: parent_organization, reporting_month, segment, distribution
```

### Step 3: Check the filter compatibility
For each metric you plan to include:

| Metric | Type | Safe to aggregate across which dimensions? |
|--------|------|-------------------------------------------|
| enrollment | Additive | All dimensions — SUM always works |
| plan_count | Additive | All dimensions — COUNT DISTINCT works |
| market_share_pct | Ratio | ONLY within (segment, distribution, month) |
| yoy_delta_pct | Ratio | ONLY within (org, segment, distribution) |

### Step 4: Identify the conflict
If the dive filter will aggregate across a dimension that breaks ratio metrics:
- **Option A:** Drop the dimension from the grain. Ratios are correct but
  you lose the filter.
- **Option B:** Only include additive metrics at the fine grain. Ratios
  get computed at display time via the DiveGrid's rollup system.
- **Option C:** Two grain levels in one model (union).

**Never serve pre-computed ratios at a grain finer than the display.** This
is the 171% market share bug.

### Step 5: Present the grain design

### ⛔ GATE: GRAIN APPROVED
Present the grain design. This is where most pushback happens. Wait for approval.

---

## Data Quality Survey (before writing SQL)

Before writing SQL, get your eyes on the data. Run these 4 checks against the
warehouse table you'll be modeling (using `soria warehouse query`):

**Check 1: Schema & Row Counts**
```bash
soria warehouse query "DESCRIBE {table}"
soria warehouse query "SELECT COUNT(*) FROM {table}"
soria warehouse query "SELECT DATE_TRUNC('year', date_col), COUNT(*) FROM {table} GROUP BY 1 ORDER BY 1"
soria warehouse query "SELECT * FROM {table} LIMIT 5"
```
Report: column inventory, time range, shape.

**Check 2: Value Distributions**
For categoricals: `SELECT col, COUNT(*) FROM {table} GROUP BY col ORDER BY 2 DESC LIMIT 20`.
For numerics: `SELECT MIN, MAX, AVG, STDDEV, COUNT(DISTINCT col) FROM {table}`.
Report: unexpected entries, impossible values, cardinality.

**Check 3: Length & Format Outliers**
`SELECT LENGTH(col), COUNT(*) FROM {table} GROUP BY 1 ORDER BY 1 DESC LIMIT 10`.
Report: mixed formats, encoding issues.

**Check 4: NULL Analysis**
`SELECT COUNT(*) FILTER (WHERE col IS NULL) * 100.0 / COUNT(*) FROM {table}`.
Report: concentration patterns, recommended handling.

Skip this step if you already know the data well from prior sessions.

---

## The dbt Model Stack

Dive SQL lives in one dbt project (`soria_dives`) that reads from the
upstream platform warehouse:

```
(upstream: soria platform's SQLMesh publishes bronze → silver → gold
 in soria_duckdb)
                ↓
frontend/src/dives/dbt/    (project: soria_dives)
  dbt_project.yml          → schemas: staging / intermediate / marts
  profiles.yml             → targets: dev, prod, main (all use MOTHERDUCK_TOKEN)
  models/
    staging/               → views (optional, for dive-local pre-processing)
    intermediate/          → views (joins across staging)
    marts/
      {domain}/            → tables (the dive's main query target)
  seeds/
    verifications.csv      → shared seed: every dive's checks, filtered by model
    benchmarks.csv         → shared seed: external benchmarks referenced by checks
```

**Schema resolution** (dbt's rule): the final materialized schema is
`{target_default_schema}_{config_schema}`. For duckdb profiles the default
schema is `main`, so `+schema: marts` produces `main_marts`. Fully qualified:

- `dbt run --target dev` → `soria_duckdb.main_marts.{model}`
- `dbt run --target main` → `soria_duckdb_main.main_marts.{model}`
- `dbt run --target prod` → `soria_duckdb.main_marts.{model}`

The manifest points at the full path, e.g.
`table: "soria_duckdb_main.main_marts.naic_national_kpis_by_company"`.
Match the target your dev env uses — check `profiles.yml` to confirm.

### Upstream sources (silver / gold in soria_duckdb)
- One row per source table, declared in `dbt_project.yml` sources block
- Schema: `soria_duckdb.silver` or `soria_duckdb.gold`
- Don't re-run upstream transforms — they're already built by the platform

### staging/ (dive project)
- Optional — only if you need dive-specific pre-processing before intermediate
- `CAST` and rename as needed
- `ref('source_name')` to reference upstream sources
- One staging model per upstream source

### intermediate/ (dive project)
- Joins across staging
- Business logic specific to this dive
- `ref('stg_...')` to pull from staging
- No direct source references

### marts/{domain}/ (dive project)
- Dashboard-ready output
- One marts model per dive
- Materialized as TABLE
- Ratios computed HERE, after aggregation: `SUM(num) / NULLIF(SUM(denom), 0)`
- Column descriptions via dbt `description:` in `_{domain}__models.yml`
- Pre-compute only what the dive manifest's filters can't derive

### seeds/verifications.csv (dive project, shared across all dives)
- One CSV seed at `frontend/src/dives/dbt/seeds/verifications.csv`
- Each row is one verify check scoped to a specific dbt marts model via the
  `model` column
- Columns: `id, model, description, parent_company, lob, quarter, metric,
  min_value, max_value, source, source_url`
- Refreshed via `dbt seed --select verifications`
- Queried per-dive via `useDiveVerifications({marts_model_name})`

---

## CTE Naming Convention

| Prefix | Purpose | Example |
|--------|---------|---------|
| `src_` | Source reference | `src_enrollment AS (SELECT * FROM {{ ref('stg_ma_enrollment') }})` |
| `flt_` | Filter | `flt_active AS (SELECT * FROM src WHERE status = 'active')` |
| `jnd_` | Join | `jnd_enriched AS (SELECT ... FROM flt JOIN {{ ref('stg_companies') }} ...)` |
| `wnd_` | Window function | `wnd_yoy AS (SELECT *, LAG(value, 12) OVER (...))` |
| `clc_` | Calculation | `clc_metrics AS (SELECT *, (value - prior) / prior AS yoy_pct)` |
| `ded_` | Dedup | `ded_latest AS (SELECT * FROM src QUALIFY ROW_NUMBER() OVER (...) = 1)` |
| `agg_` | Aggregation | `agg_summary AS (SELECT org, month, SUM(enrollment) ...)` |
| `pvt_` | Pivot/Unpivot | `pvt_long AS (UNPIVOT src ON ...)` |

---

## Pivot Dive SQL Pattern

Canonical CTE structure for any pivot dive with time-series columns and
ratio metrics:

```sql
{{ config(materialized='table') }}

WITH
  src AS (SELECT * FROM {{ ref('stg_source_table') }}),

  -- Step 1: Aggregate to the row dimension grain
  agg AS (
    SELECT segment, distribution, parent_organization,
      reporting_date,
      STRFTIME(reporting_date, '%Y-%m') AS reporting_month,
      SUM(enrollment) AS enrollment
    FROM src
    GROUP BY ALL
  ),

  -- Step 2: Join prior year AT THE SAME GRAIN
  prior AS (
    SELECT c.*, p.enrollment AS prior_year_enrollment
    FROM agg c
    LEFT JOIN agg p
      ON c.parent_organization = p.parent_organization
      AND c.segment = p.segment
      AND c.distribution = p.distribution
      AND c.reporting_date = p.reporting_date + INTERVAL 12 MONTH
  ),

  -- Step 3: Compute ratio metrics at this grain
  metrics AS (
    SELECT *,
      ROUND(enrollment * 100.0 / NULLIF(
        SUM(enrollment) OVER (PARTITION BY segment, distribution, reporting_month), 0
      ), 2) AS market_share_pct,
      enrollment - prior_year_enrollment AS yoy_delta,
      ROUND((enrollment - prior_year_enrollment) * 100.0
        / NULLIF(prior_year_enrollment, 0), 2) AS yoy_delta_pct
    FROM prior
  )

SELECT * FROM metrics
```

Key rules this template encodes:
1. **Grain matches the row dimension** — no finer keys than what the
   manifest exposes as row dimensions
2. **Ratio metrics partition by ALL filter columns** — `PARTITION BY segment,
   distribution, reporting_month`, not just `reporting_month`
3. **YoY joined at the model grain** — matching on segment + distribution +
   org + date, not just org + date
4. **Filter columns in output** — the manifest picks them up via `where`/`filters`
5. **Raw components alongside ratios** — enrollment ships with market_share_pct
   so the DiveGrid rollup can recompute

---

## The Manifest

After the marts SQL is written, create the dive manifest. This is the data
contract the component reads via `useDiveData`:

```ts
// frontend/src/dives/manifests/{dive-id}.manifest.ts
import { defineDiveManifest } from "@/lib/dive-manifest";

export default defineDiveManifest({
  id: "{dive-id}",
  table: "soria_duckdb_main.main_marts.{model}",
  columns: [
    "parent_organization",
    "reporting_month",
    "segment",
    "enrollment",
    "market_share_pct",
    "yoy_delta",
    "yoy_delta_pct",
  ],
  where: "parent_organization != ''",
  filters: {
    segment: {
      column: "segment",
      values: [
        "MA",
        "PDP",
        { key: "Total", label: "All Segments" },
      ],
      default: "MA",
      prefetch: true,  // background-prefetch the other values after first paint
    },
    distribution: {
      column: "distribution",
      values: ["Individual", "Group"],
      default: "Individual",
    },
  },
});
```

**Rules:**
- Explicit `columns` list — drops payload size vs `SELECT *`
- Filter values must exist in the data — mismatches cause the "dive shows
  nothing" failure. Verify with:
  ```bash
  soria warehouse query "SELECT DISTINCT segment FROM soria_duckdb_main.main_marts.{model}"
  ```
- `prefetch: true` on filters the user typically cycles through (so the
  session cache is warm)
- Manifest is the source of truth — never hardcode WHERE clauses in the
  component

---

## The TSX Component

**Don't invent a component shape from scratch.** Copy the structure of the
newest existing dive (check `frontend/src/dives/` for the most recently
modified `.tsx`) and adapt it. The shared primitives in
`frontend/src/dives/components/` are the library — use them, don't re-build.

Shared primitives you'll likely import (verify what exists in your tree):

```
DiveShell            — outer layout wrapper
DivePageHeader       — title, subtitle, methodology button
StickyDiveHeader     — sticky filter bar on scroll
DiveControlBar       — filter controls from the manifest
DiveKPIRow           — top-of-page KPI cards
DiveGrid             — AG-Grid table with hierarchical rows + verify tooltips
DiveUSMap            — state-level choropleth
MethodologyModal     — information panel (content pattern varies)
VerifyModal          — semantic check results panel
VerifyTooltip        — per-cell tooltip when a check fails
ProseMarkdown        — render prose content (for methodology / verify bodies)
```

Plus the hooks:

```
useDiveData(manifest, filters, opts?)
  → { data, isLoading, isError, source: "server" | "wasm" | "cache" }

useDiveVerifications(model_name)
  → { data: verifyRow[] }  — filters shared verifications table by model
```

Copy-paste the newest dive, rename the identifiers, swap the manifest
import, and wire the new verify model name. Keep methodology content
consistent with the existing pattern in your tree.

---

## Verify checks — rows in the shared verifications seed

Every dive's verify checks live in **one shared dbt seed file**:
`frontend/src/dives/dbt/seeds/verifications.csv`. The file has these columns:

```
id, model, description, parent_company, lob, quarter, metric,
min_value, max_value, source, source_url
```

- **`model`** — the dbt marts model name (e.g. `naic_national_kpis_by_company`).
  This is how dives filter to their own checks.
- **`description`** — human-readable prose explaining what the check validates
  (e.g. "UNH Total membership ~23M")
- **`parent_company`, `lob`, `quarter`, `metric`** — the row/column/cell this
  check applies to. NULL values mean "any".
- **`min_value`, `max_value`** — the accepted bound. If the real value is
  outside, the check fails.
- **`source`, `source_url`** — provenance. Every non-self-check needs a real
  external citation (SEC filing, KFF report, CMS data, Kaufman Hall report).

Add ~15–20 rows per dive: top companies × key metrics × key periods, plus
a few bounded_range sanity checks for the overall market. Commit the CSV,
then run:

```bash
cd frontend/src/dives/dbt
dbt seed --target dev --select verifications
```

This refreshes `soria_duckdb_main.main.verifications` (or the appropriate
target). The dive component will pick up your new checks automatically via
`useDiveVerifications({model_name})`.

**How the dive component wires this up:**

```tsx
// Inside your dive component
import { useDiveVerifications } from "@/dives/lib/use-dive-verifications";

const { data: verifyData } = useDiveVerifications("naic_national_kpis_by_company");
// verifyData is an array of check rows filtered to this model

// Pass to DiveGrid — cells outside bounds get a verify tooltip
<DiveGrid
  data={data}
  verifyChecks={verifyData}
  ...
/>
```

## Methodology content

The methodology pattern (what customers see when they click "How this is
built") is **not a formalized file pattern yet** — it varies by dive in
the current codebase. Before adding methodology to a new dive:

1. Look at how an existing dive does it. Reasonable starting point:
   ```bash
   grep -rl "MethodologyModal\|DivePageHeader" frontend/src/dives/
   ```
2. Match the convention. Likely candidates:
   - Methodology content passed as a prop to `DivePageHeader` or `DiveShell`
   - A sibling `.md` or `.ts` file co-located with the dive component
   - Inline in the dive component as a constant

3. At minimum, every dive's methodology must surface:
   - Data sources (name, URL, update cadence)
   - Metric definitions (each metric's formula in plain language)
   - Grain ("one row = one X per Y per Z")
   - Known gotchas (M&A events, source methodology changes, bounds)

Don't invent a new convention — match what `naic-kpis-v2.tsx` or whatever
the latest dive uses. If no pattern is obvious, surface it as a question
for the user before writing.

---

## DivesPage Registration

Add the dive to `frontend/src/pages/DivesPage.tsx`:

```tsx
const DIVES: DiveEntry[] = [
  // ... existing dives ...
  {
    id: "ma-enrollment",
    title: "MA Enrollment",
    description: "Monthly Medicare Advantage enrollment by parent organization — filter by segment, distribution, network.",
    component: lazy(() => import("@/dives/ma-enrollment")),
  },
];
```

---

## Build + Test

Run dbt in the env's worktree:

```bash
cd frontend/src/dives/dbt
dbt run --target dev --select {model}
dbt test --target dev --select {model}
dbt seed --target dev --select verifications     # refresh verify checks
```

Verify the marts table landed:

```bash
soria warehouse query "SELECT COUNT(*) FROM soria_duckdb_main.main_marts.{model}"
```

Verify your verify check rows landed in the shared table:

```bash
soria warehouse query "
SELECT COUNT(*) FROM soria_duckdb_main.main.verifications
WHERE model = '{your_marts_model}'
"
```

### vite-dbt-sync — sync dbt artifacts into the frontend

The frontend reads `dbt/target/manifest.json` and `run_results.json` as
static assets from `public/` (e.g. for the `DbtLineageFlow` component and
the `last_dbt_run` timestamps shown in verify tooltips). This sync happens
automatically via the `vite-dbt-sync.ts` Vite plugin when the dev server
is running — whenever dbt writes a new `manifest.json` or `run_results.json`,
the plugin copies them to `public/dbt-docs/` and `public/`.

**What this means for you:**
- If the dev server isn't running, the frontend will show stale `last_dbt_run`
  timestamps. Start it (`cd frontend && npm run dev`) before checking the
  VerifyModal.
- If you ran `dbt run` but the frontend doesn't reflect the new data, the
  vite plugin may not have synced yet — a hard reload usually fixes it.
- For prod, the CI pipeline runs `dbt run --target prod` and the built
  frontend bundles the synced artifacts.

Run a sample preview via `/preview` or:

```bash
soria warehouse query "SELECT * FROM soria_duckdb_main.main_marts.{model} LIMIT 5"
```

Run a local dev preview:

```bash
cd frontend && npm run dev
# navigate to /dives/{dive-id}
```

---

## SQL Review Checklist (pre-commit)

Before committing a dive's SQL:

1. **CTE hygiene** — Every CTE earns its place, has the right prefix (`src_`,
   `flt_`, `clc_`, `agg_`, `wnd_`, `ded_`, `jnd_`, `pvt_`), no over-splitting
   or under-splitting.
2. **Conventions** — Column descriptions in the dbt `_models.yml`, no joins
   in silver, ratios after aggregation, `QUALIFY ROW_NUMBER()` for dedup.
3. **No dead code** — No unreferenced CTEs, unselected columns, no-op WHEREs.
4. **Grain matches row dimension** — no finer keys than what the manifest
   exposes as row dimensions
5. **Ratio metrics computed at model grain** — not at a finer grain
6. **YoY joined at model grain** — not on sub-entity keys
7. **Filter columns present** — every manifest filter column is in the SELECT
8. **Raw components alongside ratios** — enrollment ships with market_share_pct

---

## Verify checks (every dive)

Every dive ships with verify check rows added to
`frontend/src/dives/dbt/seeds/verifications.csv`. Build them as part of
the /dive workflow, not as an afterthought.

### Steps

1. **Spot checks against external sources** — for top companies, top
   metrics, recent periods, add a row citing an SEC filing, earnings call,
   or industry report. These are the high-signal checks customers see in
   the VerifyModal.
2. **Bounded range checks** — use `WebSearch` / `WebFetch` to find
   published bounds for headline metrics (total market size, top-N
   concentration). Add rows with `parent_company=NULL` (overall market).
3. **Historical sanity checks** — add a few rows for older periods so
   long-range queries have verify coverage too.

### Adding rows

Edit `frontend/src/dives/dbt/seeds/verifications.csv` and append new rows:

```csv
id,model,description,parent_company,lob,quarter,metric,min_value,max_value,source,source_url
NNN,your_marts_model,UNH Total membership ~23M,UNITEDHEALTH,Total,2025-06,membership,18000000,28000000,UNH 10-K 2024,https://www.sec.gov/...
```

Pick a new unique `id` (the column is bigint — max(id) + 1). Use NULL
(empty cell) for dimensions that don't apply. Every row with a non-null
`source` needs a real `source_url`.

### Refresh the seed

```bash
cd frontend/src/dives/dbt
dbt seed --target dev --select verifications
```

Then query the materialized seed to confirm your rows landed:

```bash
soria warehouse query "
SELECT COUNT(*), MIN(id), MAX(id)
FROM soria_duckdb_main.main.verifications
WHERE model = 'your_marts_model'
"
```

### Investigating failures

When a cell in the dive is outside a verify bound, the `VerifyTooltip`
component surfaces the check + source. During /verify Mode 3, query the
verifications table and compare actual values against `min_value`/`max_value`.
Classify failures by the same taxonomy as old semantic checks:

| Classification | Action |
|---|---|
| Pipeline bug (data wrong) | Fix (invoke `/ingest` or edit marts SQL) |
| M&A structural change | Document + update the check's description |
| Source data limitation | Document + update bounds with rationale |
| Known industry event | Document + add source URL |
| Threshold too tight | Widen bounds with justification |

### ⛔ GATE: VERIFY CHECKS ADDED + PASSING
At least ~15 rows in `verifications.csv` for this model. Every failing
check investigated and classified before DONE. Zero unexplained failures.

---

## Artifact Output

At the end of a dive session, write a dive spec:

```bash
cat > ~/.soria-stack/artifacts/dive-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Dive Spec: [Dive Name]

## Environment
[Active soria env]

## Three Questions
[Question, audience, visualization]

## Grain Design
[Grain statement, dimension list, filter compatibility check]

## Files Created / Modified
- dbt: frontend/src/dives/dbt/models/marts/{domain}/{model}.sql
- seed: frontend/src/dives/dbt/seeds/verifications.csv (added N rows)
- manifest: frontend/src/dives/manifests/{dive-id}.manifest.ts
- component: frontend/src/dives/{dive-id}.tsx
- registration: frontend/src/pages/DivesPage.tsx (entry added)
- methodology: (location follows existing dive convention — document here)

## dbt Results
- Model row count: [N]
- `dbt test` passed: [X/Y]
- Verify checks for this model: [N rows in verifications table]

## Open Questions
[Anything that needs human decision]

## Outcome
Status: [DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT]
Lesson: [What was interesting or unexpected]
ARTIFACT
```

This artifact is consumed by `/verify` when proving the dive correct and by
`/promote` when preparing the PR.

---

## Anti-Patterns

1. **Writing SQL before answering the three questions.** Wrong grain, wrong
   metrics, wasted time.

2. **Pre-computing ratios at fine grain.** Market share per plan type × org
   × month → pivot sums to 171%.

3. **Six marts models for one dataset.** One model + manifest filters.

4. **Skipping column descriptions in dbt `_models.yml`.** Every column needs
   a business label. DivesGrid reads them for headers and the MethodologyModal
   references them.

5. **Joins across sources in staging.** Staging is one-source-in, one-source-out.
   Joins happen in intermediate or marts.

6. **Averaging ratios.** `AVG(margin_pct)` gives equal weight to 10-bed and
   1000-bed hospitals.

7. **Shipping a dive with empty or missing methodology + verify surfacing.**
   The dive component must route users to (a) methodology content (sources,
   formulas, grain) and (b) verify check results via `VerifyModal` /
   `VerifyTooltip`, backed by rows in the verifications seed (Principle #29).
   A dive where clicking "How is this built?" opens an empty panel is shipping
   opaque data.

8. **Hardcoding WHERE clauses in the component.** The manifest is the config.
   Always add filters to the manifest — never bypass it (Principle #31).

9. **Forgetting the DivesPage registration.** The component can be lazy-
   imported without registration, but it won't show up in the UI. Always
   add the entry.

10. **Skipping `dbt test` before declaring done.** Running `dbt run` is not
    the same as running `dbt test`. Both must pass.

11. **Skipping the semantic model.** Every dive ships with semantic checks.
    If you don't have time for semantic checks, you don't have time to
    ship the dive.

12. **Wiring the manifest table to a non-existent marts model.** If `dbt run`
    hasn't landed the marts table, the manifest will fail at runtime. Build
    the SQL and verify the table exists before writing the manifest.
