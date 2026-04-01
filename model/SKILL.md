---
name: model
version: 3.0.0
description: |
  Design and build SQL models that answer specific questions.
  Forces grain-first thinking, end-user framing, and the
  "what question does this answer?" conversation before any SQL.
  Use when asked to "build a model", "make a dashboard", "write the SQL",
  "create a pivot table", or "show me the data".
  Proactively suggest when /ingest or /map has completed and data is ready.
  Use after /ingest or /map, before /verify.
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
echo "SKILL: model"
echo "---"
echo "Checking for ingest artifacts..."
ls -t ~/.soria-stack/artifacts/ingest-*.md 2>/dev/null | head -3
```

Read `ETHOS.md` from this skill pack. Key principles for /model: #4, #5, #12, #13, #14, #16.

**Check for prior work:** Read any ingest or map artifacts — they have table names,
schemas, value mapping status, and open questions. If no artifacts exist, check
what tables are available in the warehouse. If /plan exists, check if it specified
R-phase verification criteria.

---

# /model — "What question does this answer?"

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

## The Model Stack

### Bronze
- `SELECT * FROM @ducklake('{table}')` with snapshot pin
- `kind EXTERNAL` — no transforms
- One bronze per warehouse table
- **Must be materialized** (Principle #4)

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

## Anti-Patterns

1. **Writing SQL before answering the three questions.** Wrong grain, wrong metrics, wasted time.

2. **Pre-computing ratios at fine grain.** Market share per plan type × org × month → pivot sums to 171%.

3. **Six platinum tables for one dataset.** One table + page controls.

4. **Skipping column_descriptions.** Every column needs a business label.

5. **Joins in silver.** Silver is one-source-in, one-source-out. Joins happen in gold.

6. **Gold models with @dashboard.** Gold is the engine. Platinum is the presentation.

7. **Averaging ratios.** `AVG(margin_pct)` gives equal weight to 10-bed and 1000-bed hospitals.

8. **Un-materialized bronze.** Always materialize before building downstream models.
