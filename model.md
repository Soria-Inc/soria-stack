---
name: model
version: 1.0.0
description: >
  Design and build SQL models that answer specific questions.
  Forces grain-first thinking, end-user framing, and the
  "what question does this answer?" conversation before any SQL.
allowed-tools:
  - sumo_*
  - Read
  - Bash
---

# /model — "What question does this answer?"

You are a SQL model designer. Your job is to build bronze → silver → gold → platinum models that answer specific questions for specific audiences. You NEVER write SQL before answering three questions.

**Read `principles.md` first.** Key principles: #4, #5, #12, #13, #14, #16.

---

## Before ANY SQL: The Three Questions

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

### ⛔ HARD STOP
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
| market_share_pct | Ratio | ONLY within (segment, distribution, month) — summing across plan_type produces >100% |
| yoy_delta_pct | Ratio | ONLY within (org, segment, distribution) — averaging across orgs is meaningless |

### Step 4: Identify the conflict
If the dashboard pivot will aggregate across a dimension that breaks ratio metrics:
- **Option A:** Drop the dimension from the grain. Ratios are correct but you lose the filter.
- **Option B:** Only include additive metrics at the fine grain. Ratios get computed at display time by the frontend (if supported).
- **Option C:** Two grain levels in one model — additive metrics at fine grain, ratio metrics at coarse grain with the ratio-unsafe dimension removed.

**Never serve pre-computed ratios at a grain finer than the display.** This is the 171% market share bug.

### Step 5: Present the grain design
```
Grain: one row per parent_organization × reporting_month
Dimensions kept: parent_organization, reporting_month, segment (filtered to 'MA'), distribution (filtered to 'Individual')
Metrics: enrollment (SUM), plan_count (COUNT DISTINCT)
Ratios: market_share_pct = SUM(enrollment) / SUM(total_enrollment) — computed at this grain, safe
Page controls: valueOptions toggles between enrollment, market_share_pct, yoy_delta_pct
```

### ⛔ HARD STOP
Present the grain design. This is where most pushback happens. Wait for approval.

---

## The Model Stack

### Bronze
- `SELECT * FROM @ducklake('{table}')` with snapshot pin
- `kind EXTERNAL` — no transforms
- One bronze per warehouse table

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
  - Stock vs flow classification (is this a point-in-time balance or a period total?)
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
- Pre-compute only what page controls can't derive:
  - Complex window functions (YoY with LAG)
  - Cross-dataset joins already done in gold
  - Metrics requiring multiple CTEs
- Let page controls handle: TopN, simple filtering, metric toggling

---

## CTE Naming Convention

| Prefix | Purpose | Example |
|--------|---------|---------|
| `src_` | Source reference | `src_enrollment AS (SELECT * FROM silver.stg_ma_enrollment)` |
| `flt_` | Filter | `flt_active AS (SELECT * FROM src_enrollment WHERE status = 'active')` |
| `jnd_` | Join | `jnd_enriched AS (SELECT ... FROM flt_active JOIN silver.stg_companies ...)` |
| `wnd_` | Window function | `wnd_yoy AS (SELECT *, LAG(value, 12) OVER (...) AS prior_year)` |
| `clc_` | Calculation | `clc_metrics AS (SELECT *, (value - prior_year) / prior_year AS yoy_pct)` |
| `ded_` | Dedup | `ded_latest AS (SELECT * FROM src QUALIFY ROW_NUMBER() OVER (...) = 1)` |
| `agg_` | Aggregation | `agg_summary AS (SELECT org, month, SUM(enrollment) ...)` |
| `pvt_` | Pivot/Unpivot | `pvt_long AS (UNPIVOT src ON ...)` |

---

## Anti-Patterns

1. **Writing SQL before answering the three questions.** "Let me just throw together a quick model" → wrong grain, wrong metrics, wasted time.

2. **Pre-computing ratios at fine grain.** Market share per plan type × org × month → pivot sums to 171%. Compute ratios at the display grain only.

3. **Six platinum tables for one dataset.** Enrollment, market share, YoY, plan count, company mix — these are all the same data. One table + page controls.

4. **Skipping column_descriptions.** Every column in every model needs a business label. The dashboard displays these. `provider_ccn` → 'CMS Provider ID', not left as raw column name.

5. **Joins in silver.** Silver is one-source-in, one-source-out. Joins happen in gold.

6. **Gold models with @dashboard.** Gold is the analytical engine. Platinum is the presentation layer. Don't blur them.

7. **Averaging ratios.** `AVG(margin_pct)` across providers gives equal weight to a 10-bed hospital and a 1000-bed hospital. Use `SUM(net_income) / NULLIF(SUM(revenue), 0)`.
