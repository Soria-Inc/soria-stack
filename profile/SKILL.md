---
name: profile
version: 2.0.0
description: |
  Data profiling — inspect raw data before writing SQL models. Runs 4 parallel
  checks on a warehouse table: schema + row counts, value distributions,
  length/format outliers, and NULL analysis. Outputs a data quality report
  with recommended WHERE clauses and CASE expressions for the silver model.
  Use when asked to "profile this table", "what does the data look like",
  "inspect the data", "check data quality", or before writing any silver SQL model.
  Proactively suggest when /ingest has published to bronze and the user is about to
  start /model work.
  Use after /ingest, before /model.
benefits-from: [ingest]
allowed-tools:
  - sumo_*
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
echo "SKILL: profile"
echo "---"
echo "Checking for ingest artifacts..."
ls -t ~/.soria-stack/artifacts/ingest-*.md 2>/dev/null | head -3
```

Read `ETHOS.md` from this skill pack. Key principle for /profile: #10 (validate with your eyes, not just code).

---

# /profile — "What does this data actually look like?"

You are a data quality inspector. Your job is to look at the raw data before anyone writes SQL against it. You run systematic checks and produce a report that tells the model builder exactly what to watch out for.

This is the "eyes on the data" step. Row counts passing doesn't mean the data is right.

---

## When to Run

- **Before `/model`** — profile the bronze table before writing silver SQL
- **After `/ingest` Gate 6** — verify what was published to the warehouse
- **On request** — "what does this table look like?" or "check data quality on X"

---

## The 4 Checks

Run all 4 checks in parallel when possible. Each check is independent.

### Check 1: Schema & Row Counts

```sql
-- Column inventory
DESCRIBE {table};

-- Row counts
SELECT COUNT(*) AS total_rows FROM {table};

-- Row count by a time dimension (if one exists)
SELECT {time_col}, COUNT(*) AS rows
FROM {table}
GROUP BY 1
ORDER BY 1;

-- Sample rows
SELECT * FROM {table} LIMIT 5;
```

**Report:**
- Total columns and their types
- Total rows
- Row count distribution over time — is it growing? Stable? Suspicious gaps?
- Sample data — what does an actual row look like?

### Check 2: Value Distributions

For each column (or a representative sample if >50 columns):

```sql
-- Top values for categorical/string columns
SELECT {col}, COUNT(*) AS cnt
FROM {table}
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;

-- Min/max/avg/stddev for numeric columns
SELECT
  MIN({col}) AS min_val,
  MAX({col}) AS max_val,
  AVG({col}) AS avg_val,
  STDDEV({col}) AS stddev_val,
  COUNT(DISTINCT {col}) AS distinct_count
FROM {table};
```

**Report:**
- Top values for categorical columns — any unexpected entries? Casing issues?
- Numeric ranges — any impossible values? (negative enrollment, >100% ratios, revenue in wrong denomination)
- Distinct counts — is cardinality what you'd expect?

### Check 3: Length & Format Outliers

For string columns:

```sql
-- Length distribution
SELECT
  LEN({col}) AS str_len,
  COUNT(*) AS cnt
FROM {table}
GROUP BY 1
ORDER BY 1;

-- Values that don't match the dominant pattern
-- (e.g., if most values are 5-digit zip codes, find the non-5-digit ones)
```

**Report:**
- Statistically unusual string lengths (potential data quality issues)
- Values that don't match the dominant format (mixed formats, OCR errors, encoding issues)
- Flag specific values that need investigation

### Check 4: NULL Analysis

```sql
-- NULL rate per column
SELECT
  COUNT(*) AS total,
  COUNT({col1}) AS non_null_col1,
  ROUND(100.0 * (COUNT(*) - COUNT({col1})) / COUNT(*), 1) AS null_pct_col1,
  -- repeat for each column
FROM {table};

-- NULL patterns — are NULLs concentrated in certain rows/time periods?
SELECT {time_col}, COUNT(*) AS total,
  SUM(CASE WHEN {col} IS NULL THEN 1 ELSE 0 END) AS null_count
FROM {table}
GROUP BY 1
ORDER BY 1;
```

**Report:**
- NULL rate per column — which columns have NULLs and how many?
- NULL concentration — are NULLs random or systematic? (e.g., "all 2011-2013 rows have NULL for metric_x" = the column didn't exist in that era)
- Recommended handling: filter, coalesce, or flag

---

## Output: Data Quality Report

Present findings as a structured report:

```
DATA QUALITY REPORT: {table_name}
═══════════════════════════════════════

## Summary
- Rows: 456,789
- Columns: 116 (14 dimensions, 102 metrics)
- Time range: 2011-2024
- Row count trend: increasing (expected — more providers over time)

## Issues Found

### 🔴 Critical
- Column `net_revenue`: values range from -5M to 50B — possible denomination mixing
  (some rows in thousands, others in raw dollars)
  Recommendation: CHECK source files for denomination markers

### 🟡 Warning
- Column `state_code`: 3 rows have value "XX" — likely placeholder
  Recommendation: WHERE state_code != 'XX' in silver
- NULL rate on `rural_urban`: 12% NULL, concentrated in 2011-2014
  Recommendation: COALESCE(rural_urban, 'Unknown') in silver

### 🟢 Clean
- All dimension columns (provider_ccn, hospital_name, etc.): 0% NULL, consistent formats
- Numeric metrics: reasonable ranges, no obvious outliers beyond net_revenue

## Recommended Silver Transforms
- CAST(net_revenue AS DOUBLE) — but verify denomination first
- WHERE state_code NOT IN ('XX', '')
- COALESCE(rural_urban, 'Unknown')
```

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/profile-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Profile Report: [Table Name]

## Summary
[Row count, column count, time range, overall health]

## Issues
[Critical / Warning / Clean, with specific columns and recommendations]

## Recommended Silver Transforms
[Specific WHERE, CAST, COALESCE recommendations for the silver model]

## Outcome
Status: [DONE | DONE_WITH_CONCERNS]
Lesson: [What was interesting or unexpected about this data]
ARTIFACT
```

This artifact is consumed by `/model` when designing silver SQL.

---

## Anti-Patterns

1. **Skipping profiling and going straight to SQL.** The model builder discovers data quality issues mid-query, wastes time debugging SQL when the problem is in the data.

2. **Only checking row counts.** 456,789 rows doesn't tell you that 3% of them have revenue in thousands while 97% have it in raw dollars.

3. **Ignoring NULL patterns.** "12% NULL" is fine. "12% NULL, all concentrated in files from 2011-2013 because that column didn't exist yet" is critical context for the model.

4. **Not surfacing the denomination question.** The single most common data quality issue in financial data. If numbers span 4+ orders of magnitude, ask: are some in thousands? Millions? Always flag.
