---
name: dashboard
version: 4.0.0
description: |
  Design and build SQL models that answer specific questions.
  Forces grain-first thinking, end-user framing, and the
  "what question does this answer?" conversation before any SQL.
  Includes data quality survey (eyes on data before SQL), SQL review
  checklist (pre-save code quality), and semantic check building
  (companion gold model for every platinum dashboard).
  Use when asked to "build a model", "make a dashboard", "write the SQL",
  "create a pivot table", "show me the data", "profile this table",
  "review the SQL", or "build semantic checks".
  Proactively invoke this skill (do NOT write SQL models ad-hoc) when the
  user wants to build models or dashboards. Three Questions must be answered first.
  Use after /ingest or /map, before /verify. (soria-stack)
  NOTE: Renamed from /model to /dashboard to avoid conflict with native Claude Code /model command.
benefits-from: [ingest, map]
allowed-tools:
  - sumo_*
  - exa_*
  - pplx_*
  - mcp__perplexity__*
  - mcp__exa__*
  - Read
  - Bash
  - Write
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "BRANCH: $_BRANCH"
echo "SKILL: dashboard"
echo "---"
echo "Checking for ingest artifacts..."
ls -t ~/.soria-stack/artifacts/ingest-*.md 2>/dev/null | head -3
```

Read `ETHOS.md` from this skill pack. Key principles for /dashboard: #4, #5, #12, #13, #14, #16.

**Check for prior work:** Read any ingest or map artifacts — they have table names,
schemas, value mapping status, and open questions. If no artifacts exist, check
what tables are available in the warehouse. If /plan exists, check if it specified
R-phase verification criteria.

## Skill routing (always active)

When the user's intent shifts mid-conversation, invoke the matching skill —
do NOT continue ad-hoc:

- User wants to check pipeline status → invoke `/status`
- User wants to fix extraction issues → invoke `/ingest`
- User wants to fix value mappings → invoke `/map`
- User says "verify this", "spot check", "is this correct" → invoke `/verify`
- User wants to test the live dashboard in a browser → invoke `/smoke`

**After /dashboard completes, suggest `/verify`** (Mode 2: Model Verify + Mode 3: Semantic Verify).
**NEVER promote to prod from here.** If the user says "push to prod", invoke `/promote`.

---

# /dashboard — "What question does this answer?"

You are a SQL model designer. Your job is to build bronze → silver → gold → platinum models that answer specific questions for specific audiences. You NEVER write SQL before answering three questions.

---

## Domain Grounding (before the Three Questions)

Before designing the model, ground it in how the real world talks about this data.

### Earnings transcript search

Search transcripts for the data domain you're modeling — not "search for Humana"
but "search for how utilization data gets discussed."

- Building a **utilization dashboard** → search "utilization trends adjusted
  discharges ED visits length of stay" across transcripts. You'll find the
  exact metrics analysts ask about, how they frame YoY comparisons, and what
  baseline periods they reference (e.g., "pre-COVID levels" as the standard).
- Building an **MLR model** → search "medical loss ratio benefit expense trend
  cost pressure" and you'll see how analysts decompose it (utilization vs unit
  cost vs acuity vs new member drag) — that decomposition IS your grain design.
- Building a **star ratings dashboard** → search "star ratings quality bonus
  CMS performance" and you'll learn what dimensions matter (contract-level vs
  member-weighted, bonus year timing, operational vs HEDIS measures).

The transcript gives you Question 1 phrased the way an analyst would actually
ask it, not how a data engineer would guess.

### External research (Perplexity/Exa)

Use Perplexity for broader domain grounding:
- "Standard KPIs for [this analytical domain]?"
- "How do equity analysts evaluate [this metric]?"

Skip both steps if the domain is well-understood from prior sessions.

---

## Before ANY SQL: The Three Questions

### The Simplicity Check (before anything else)

If the user asks for multiple dashboards, multiple platinum tables, or a complex model structure — push back:
- "Can this be 1 dashboard with page controls slicing it instead of 5 separate dashboards?"
- "Can this be 1 platinum table with `valueOptions` instead of 6 tables through different lenses?"
- "Do we need a gold model here, or can silver feed platinum directly?"

Take a position. The simpler approach that produces correct data wins (ETHOS: Simplicity over complexity).

### Question 1: What specific question does this answer?
Not "show hospital data." Specific:
- "Which parent company has the lowest enrollment-weighted premium in each state?"
- "What's the Medical Care Ratio trend for UNH vs HUM over 10 years?"
- "How many Medicare Advantage beneficiaries are in 4+ star plans by insurer?"

If you can't state the question in one sentence, you're not ready to write SQL.

### Question 2: Who is looking at this?
- **Equity research analyst** → needs sortable pivot tables, company comparisons, YoY trends, enrollment-weighted metrics
- **Internal team** → needs pipeline health, data freshness, coverage gaps
- **Customer dashboard** → needs clean presentation, intuitive filters, audit trail back to source
- **Adam exploring data** → needs flexibility, the ability to slice by any dimension

The audience determines: metric selection, grain, aggregation level, and what page controls to expose.

### Question 3: What's the ideal visualization?
- Pivot table with companies as rows, months as columns?
- Time series chart with company lines?
- Bar chart comparing segments?
- Map with state-level shading?

Sketch the visualization in text before writing SQL. The visualization determines the grain.

### ⛔ GATE: THREE QUESTIONS ANSWERED
Present your answers to the three questions. Wait for confirmation before designing the model.

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

### Step 3: Check the pivot compatibility
For each metric you plan to include:

| Metric | Type | Safe to aggregate across which dimensions? |
|--------|------|-------------------------------------------|
| enrollment | Additive | All dimensions — SUM always works |
| plan_count | Additive | All dimensions — COUNT DISTINCT works |
| market_share_pct | Ratio | ONLY within (segment, distribution, month) |
| yoy_delta_pct | Ratio | ONLY within (org, segment, distribution) |

### Step 4: Identify the conflict
If the dashboard pivot will aggregate across a dimension that breaks ratio metrics:
- **Option A:** Drop the dimension from the grain. Ratios are correct but you lose the filter.
- **Option B:** Only include additive metrics at the fine grain. Ratios get computed at display time.
- **Option C:** Two grain levels in one model.

**Never serve pre-computed ratios at a grain finer than the display.** This is the 171% market share bug.

### Step 5: Present the grain design

### ⛔ GATE: GRAIN APPROVED
Present the grain design. This is where most pushback happens. Wait for approval.

---

## Prerequisites: Check Bronze Materialization

Before building any model, verify that bronze tables are materialized. Un-materialized
bronze means every silver/gold/platinum query chains through DuckLake → GCS at ~2-3s
per table. This makes development painful and dashboards unusable.

```
warehouse_query("SELECT table_name, table_type FROM information_schema.tables WHERE table_schema = 'bronze' AND table_name IN ({your tables})")
```

- `BASE TABLE` = materialized (good)
- `VIEW` = un-materialized (fix first)

To fix: `warehouse_materialize(model_name="bronze.{table}", materialize=True)`

If working in a workspace, check the workspace schema instead:
```
warehouse_query("SELECT table_name, table_type FROM information_schema.tables WHERE table_schema = 'bronze__{ws_schema}'")
```

**Do not proceed to silver if bronze is un-materialized.** The queries will work
but take 40s+ instead of <1s, and you'll burn time debugging "slow queries"
that are really just un-materialized views.

---

## The Model Stack

### Bronze
- `SELECT * FROM @ducklake('{table}')` with snapshot pin
- `kind EXTERNAL` — no transforms
- One bronze per warehouse table
- **Must be materialized** (Principle #4 — see ETHOS.md for full details)

### Silver
- One silver per bronze
- `CAST` every column to proper type
- Rename to clean snake_case
- Unpivot wide metric columns into `metric_name` / `metric_value` rows (if applicable)
- Filter invalid records (NULL keys, malformed data)
- Dedup with `QUALIFY ROW_NUMBER()` if source has overlapping snapshots
- `column_descriptions` required for every column
- **No joins** — silver is always single-source

### Gold
- Joins across silver tables
- Business logic:
  - De-cumulation for YTD data (`LAG` to get quarterly values from cumulative)
  - Stock vs flow classification
  - Entity resolution (company name → parent company via crosswalk)
  - Temporal alignment (which enrollment matches which star rating year?)
- The grain is determined by the analytical architecture from `/scout`
- **No `@dashboard` block** — gold is the analytical engine, not the presentation layer

### Platinum
- Dashboard-ready output
- `@dashboard` block with chart config required
- `@overview` block with natural language description required
- `column_descriptions` required
- Page controls via `valueOptions`, filters, `controls` config
- Ratios computed HERE, after aggregation: `SUM(num) / NULLIF(SUM(denom), 0)`
- Pre-compute only what page controls can't derive

---

## CTE Naming Convention

| Prefix | Purpose | Example |
|--------|---------|---------|
| `src_` | Source reference | `src_enrollment AS (SELECT * FROM silver.stg_ma_enrollment)` |
| `flt_` | Filter | `flt_active AS (SELECT * FROM src WHERE status = 'active')` |
| `jnd_` | Join | `jnd_enriched AS (SELECT ... FROM flt JOIN silver.stg_companies ...)` |
| `wnd_` | Window function | `wnd_yoy AS (SELECT *, LAG(value, 12) OVER (...))` |
| `clc_` | Calculation | `clc_metrics AS (SELECT *, (value - prior) / prior AS yoy_pct)` |
| `ded_` | Dedup | `ded_latest AS (SELECT * FROM src QUALIFY ROW_NUMBER() OVER (...) = 1)` |
| `agg_` | Aggregation | `agg_summary AS (SELECT org, month, SUM(enrollment) ...)` |
| `pvt_` | Pivot/Unpivot | `pvt_long AS (UNPIVOT src ON ...)` |

---

## Pivot Dashboard SQL Pattern

Canonical CTE structure for any pivot dashboard with time-series columns and ratio metrics:

```sql
/*
  @dashboard:
    chart:
      type: ag-pivot
      server_side_pivot: true
      default_top_n: 15
      exclude_columns:
        - segment              -- filter column, not displayed
        - prior_year_enrollment -- intermediate, not displayed
      pivot:
        rowField: parent_organization
        columnField: reporting_month
        valueField: enrollment
        valueOptions:
          - field: enrollment
            label: "Enrollment"
            format: number
          - field: market_share_pct
            label: "Market Share %"
            format: percent
            rollup: share
            rollup_base: enrollment
          - field: yoy_delta_pct
            label: "YoY Growth %"
            format: percent
            rollup: growth
            rollup_base: enrollment
            rollup_delta: yoy_delta
          - field: yoy_delta
            label: "YoY Change"
            format: number
      default_filters:
        - type: segment
          column: segment
          default_values: ["MA"]
*/
MODEL (
  grain (segment, distribution, parent_organization, reporting_month)
);

WITH
  src AS (SELECT * FROM silver.source_table),

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
1. **Grain matches the row dimension** — no finer keys than what `rowField` / `rowFieldOptions` need
2. **Ratio metrics partition by ALL filter columns** — `PARTITION BY segment, distribution, reporting_month`, not just `reporting_month`
3. **YoY joined at the model grain** — matching on segment + distribution + org + date, not just org + date
4. **Filter columns in output but excluded** — `exclude_columns` lists segment, distribution, etc.
5. **Raw components alongside ratios** — enrollment ships with market_share_pct so rollup can recompute

---

## Controls & SQL Interaction

### Control types

| Type | UI Element | When to use |
|------|-----------|-------------|
| `segment` | Toggle buttons (single-select with "All") | 2-7 fixed categories (LOB, plan type, network) |
| `list` | Multi-select dropdown with search | Many values (companies, states, contracts) |
| `date_aggregation` | Year / Quarter / Month selector | Time grouping |

### How filter columns flow through SQL

Filter columns (segment, distribution, network) must appear in **three places**:

1. **In the model grain** — `grain (segment, distribution, parent_organization, reporting_month)`
2. **In the SELECT output** — the frontend needs the column to filter on
3. **In `exclude_columns`** — present in data but not displayed as a pivot column

If a filter column is missing from the grain, the model aggregates across it and the filter has nothing to filter. If it's missing from `exclude_columns`, it shows up as a data column in the pivot.

### Ratio metric partitioning

Ratio metrics (market share, YoY %) must `PARTITION BY` every filter column:

```sql
-- CORRECT: partitions by segment + distribution + month
ROUND(enrollment * 100.0 / NULLIF(
  SUM(enrollment) OVER (PARTITION BY segment, distribution, reporting_month), 0
), 2) AS market_share_pct

-- WRONG: partitions only by month → 171% market share when segment='All'
ROUND(enrollment * 100.0 / NULLIF(
  SUM(enrollment) OVER (PARTITION BY reporting_month), 0
), 2) AS market_share_pct
```

When the frontend filters to segment='MA', the PARTITION BY must produce shares that sum to 100% within that segment. If you only partition by month, you get shares of the total across all segments — which is a different (and usually wrong) metric.

---

## Rollup DSL

For pivot tables with `default_top_n`, rows beyond the top N are grouped into an "Other" row. Additive metrics can just SUM, but ratio metrics need recomputation formulas specified in `valueOptions`:

| Rollup type | Formula for "Other" row | Config |
|-------------|------------------------|--------|
| _(none)_ | `SUM(field)` | Default for additive fields (enrollment, yoy_delta) |
| `share` | `SUM(rollup_base) / total * 100` | `rollup: share`, `rollup_base: enrollment` |
| `growth` | `SUM(rollup_delta) / (SUM(rollup_base) - SUM(rollup_delta)) * 100` | `rollup: growth`, `rollup_base: enrollment`, `rollup_delta: yoy_delta` |

Without rollup annotations, ratio metrics for the "Other" row will be summed — producing nonsensical values like 847% market share.

---

## Pre-Save Checklist (Pivot Dashboards)

Before calling `sql_model_save` on a pivot dashboard model, verify:

1. **Grain matches row dimension** — no finer keys than what `rowField` / `rowFieldOptions` need
2. **Ratio metrics computed at model grain** — not at a finer grain that gets summed later
3. **YoY joined at model grain** — not on sub-entity keys that change year to year
4. **Filter columns in output but excluded** — `exclude_columns` lists segment, distribution, etc.
5. **Rollup DSL on ratio valueOptions** — `share` for market share, `growth` for YoY %
6. **Raw components available** — include enrollment alongside market_share_pct so rollup can recompute

---

## Artifact Output

At the end of a model session, write a model spec:

```bash
cat > ~/.soria-stack/artifacts/model-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Model Spec: [Dashboard/Model Name]

## Three Questions
[Question, audience, visualization]

## Grain Design
[Grain statement, dimension list, pivot compatibility check]

## Model Stack
[Bronze → Silver → Gold → Platinum with table names and key transforms]

## Open Questions
[Anything that needs human decision]

## Outcome
Status: [DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT]
Lesson: [What was interesting or unexpected]
ARTIFACT
```

This artifact is consumed by `/verify` when proving the model correct.

---

## Data Quality Survey (before writing SQL)

Before writing SQL models, get your eyes on the data. Run these 4 checks
against the warehouse table you'll be modeling:

**Check 1: Schema & Row Counts** — `DESCRIBE {table}`, row count, row count
by time period, `LIMIT 5` sample. Report: column inventory, time range, shape.

**Check 2: Value Distributions** — For categoricals: top values by count.
For numerics: min, max, avg, stddev, distinct count. Report: unexpected
entries, impossible values, cardinality.

**Check 3: Length & Format Outliers** — `LEN({col})` distribution for string
columns. Report: mixed formats, encoding issues.

**Check 4: NULL Analysis** — NULL rate per column. Report: concentration
patterns, recommended handling.

Skip this step if you already know the data well from prior sessions.

---

## SQL Review Checklist (pre-save)

Before calling `sql_model_save`, review the SQL:

1. **CTE hygiene** — Every CTE earns its place, has the right prefix (`src_`,
   `flt_`, `clc_`, `agg_`, `wnd_`, `ded_`, `jnd_`, `pvt_`), no over-splitting
   or under-splitting.
2. **Conventions** — `column_descriptions` on every column, no joins in silver,
   ratios after aggregation, `QUALIFY ROW_NUMBER()` for dedup.
3. **No dead code** — No unreferenced CTEs, unselected columns, or no-op WHEREs.
4. **Dashboard integration (platinum)** — `@dashboard` block present,
   `@overview` present, `valueOptions` complete, rollup DSL on ratio metrics.

---

## Semantic Checks (after platinum model)

Every platinum dashboard ships with a companion `gold.semantic_{domain}` model.
Build it as part of the /dashboard workflow, not as an afterthought.

### Steps

1. **Auto-generate algebraic + smoothness checks** — these need no research:
   - Parts sum to whole (shares → 100%, network categories → total)
   - Derived columns match their formula (yoy_delta = enrollment - prior)
   - No company swings >50% growth or >40% decline in one year
   - No month-over-month total change >5%

2. **Research external benchmarks** — use Exa/Perplexity to find published
   statistics for bounded_range, CAGR, structural_break, and monotonicity
   checks. Save source URLs.

3. **Build the gold model** — one CTE per check category, all producing the
   standard output schema (see `/verify` for the schema definition):
   ```
   check_category | check_name | check_label | grain | period |
   value | expected_low | expected_high | pass | source | source_url | note
   ```

4. **Materialize and run** — materialize as TABLE, query for failures.

5. **Investigate failures** — classify each as pipeline bug, M&A, source
   limitation, known event, or threshold issue.

### ⛔ GATE: SEMANTIC CHECKS PASS
All failures must be investigated and classified before DONE.
Zero unexplained failures.

---

## Anti-Patterns

1. **Writing SQL before answering the three questions.** Wrong grain, wrong metrics, wasted time.

2. **Pre-computing ratios at fine grain.** Market share per plan type × org × month → pivot sums to 171%.

3. **Six platinum tables for one dataset.** One table + page controls.

4. **Skipping column_descriptions.** Every column needs a business label.

5. **Joins in silver.** Silver is one-source-in, one-source-out. Joins happen in gold.

6. **Gold models with @dashboard.** Gold is the engine. Platinum is the presentation.

7. **Averaging ratios.** `AVG(margin_pct)` gives equal weight to 10-bed and 1000-bed hospitals.

8. **Un-materialized bronze.** Always materialize before building downstream models.

9. **Assuming sql_model_save auto-materializes MotherDuck.** It does not. Saving
   SQL to a workspace only writes the model definition to Postgres. The MotherDuck
   view does not exist until you explicitly call `warehouse_materialize`. After
   saving models, always materialize in dependency order:
   ```
   warehouse_materialize(silver.stg_x, workspace="ws_release_branch_934a24ce")
   warehouse_materialize(gold.x, workspace="ws_release_branch_934a24ce")
   warehouse_materialize(platinum.x, workspace="ws_release_branch_934a24ce")
   ```
   Silver must go first so that when gold is materialized, schema refs to silver
   are rewritten to the workspace schema automatically.

10. **Verifying workspace materialization against the prod schema.** After calling
    `warehouse_materialize` in a workspace, the materialized view is at
    `{layer}__{postgres_schema}.{model_name}` — NOT `{layer}.{model_name}`.
    If you run `SELECT COUNT(*) FROM silver.stg_x` you're hitting prod (wrong).
    Always verify against the workspace schema:
    ```
    warehouse_query("SELECT COUNT(*) FROM silver__ws_release_branch_934a24ce.stg_x")
    ```

11. **Misreading motherduck_database = NULL as "no MotherDuck state".** A workspace
    with `motherduck_database = NULL` shares the prod MotherDuck database but uses
    separate schemas. The distinction is database vs schema — same database,
    different schema. Check what's materialized:
    ```
    warehouse_query("SELECT table_schema, table_name, table_type FROM information_schema.tables WHERE table_schema LIKE '%ws_%'")
    ```

12. **Changing bronze table format (wide→long) without planning downstream model
    updates.** Changing a 40-column wide table to a 5-column long table
    (`metric_name`, `metric_value`) means every silver/gold model that selected
    specific columns like `n_ab` or `total_revenue` will break. The `auto_apply`
    failure on `sql_model_save` is the system correctly refusing to apply an
    incomplete migration — it's not a bug. Rule: before changing bronze format,
    list every downstream model and plan the column updates before touching bronze.
    `force=True` on republish is required when the schema changes (it drops and
    recreates the table — safe when the schema change is intentional).
