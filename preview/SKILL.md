---
name: preview
version: 2.0.0
description: |
  Render dashboard output as markdown tables in chat — simulating the frontend
  experience without opening a browser. Shows controls, actual pivot data, and
  a verdict on data quality.
  Use when asked to "show me the dashboard", "what does this look like",
  "preview this", "show me slices", or "review the dashboard output".
  Use after /dashboard or /verify to inspect what was built. (soria-stack)
benefits-from: [dashboard, verify]
allowed-tools:
  - sumo_*
  - AskUserQuestion
---

## Skill routing (always active)

- User wants to fix data → invoke `/verify`
- User wants to rebuild the model → invoke `/dashboard`
- User wants pipeline status → invoke `/status`
- User says "push to prod" → invoke `/promote`

---

# /preview — "Show me the dashboard"

**Read-only.** Query warehouse data, format as markdown tables. Simulate what
the frontend shows. Do not build, fix, or modify anything.

---

## Output Template

Every dashboard preview follows this structure, in this order:

```
## Dashboard N: [Name] (`platinum.table_name`)

**What the user sees:** [1-line grain description]

**Controls:**
| Control | Options | Default |
|---------|---------|---------|
| [filter] | [values] | [default] |

---

**Slice: [Default view name]**
[markdown pivot table — actual data, time as columns when time-series]

**Slice: [2nd key slice]**
[markdown pivot table — actual data]

**Interactions:** [what toggles/tabs exist, what changes when you use them]

**Data quality notes:**
- [specific issue with evidence, or "None found"]

**Verdict:** [1-2 sentences — what's strong, what's weak, usable or not?]
```

---

## Workflow

### 1. Enumerate (if no dashboard named)

```
list_dashboard_pages()
```

Present a numbered list, ask: "Which to preview? All, or specific ones?"

### 2. Read config

```
get_dashboard_page(node_id="...")
```

Extract chart type, controls, grain, and default filters from the `@dashboard`
block. **Do not query yet** — present the Controls table first.

### 3. Query and render

`warehouse_query(SQL)` against the platinum table. ~30 rows for the default
view. Format as a pivot table matching how the dashboard displays it — not a
raw row dump.

**Default view first.** Then 1-2 slices that exercise the controls (e.g.,
regional breakdown, different metric, top-N filter).

```sql
-- Example: last 6 months, top 10 orgs
SELECT parent_organization, reporting_month, enrollment
FROM platinum.ma_enrollment_dashboard
WHERE segment = 'MA'
  AND reporting_month >= (SELECT MAX(reporting_month)
    FROM platinum.ma_enrollment_dashboard) - INTERVAL 5 MONTH
ORDER BY reporting_month, enrollment DESC
LIMIT 50
```

Time-series → time as columns. Single snapshot → entities as rows.

### 4. Verdict

Look at the actual values before writing the verdict. Flag: unusual NULLs,
suspiciously round values, wrong ranges, time coverage gaps. **Never say
"looks good" without evidence.**

### 5. Stop. Wait.

One dashboard at a time. After rendering, stop and offer:

```
Options: show a different slice | go to next dashboard | /verify a value
```

If the user requests a specific filter ("show me Northeast only"), re-query
and re-render.

---

## Anti-Patterns

- **Raw row dumps** — format as pivot tables, not `SELECT * LIMIT 50`
- **Arbitrary slices** — start with the default view, then exercise the controls
- **"Looks good" without evidence** — check the numbers first
- **Auto-advancing** — one dashboard at a time, always stop after each
- **Skipping the controls table** — show it before the first data slice
- **Wrong schema** — if a model artifact exists with `workspace="ws_xxx"`,
  query `platinum__ws_xxx.table`, not `platinum.table`
