---
name: preview
version: 4.0.0
description: |
  Render a dive as markdown tables in chat — simulating the frontend experience
  without opening a browser. Reads the dive manifest, builds SQL from it,
  queries MotherDuck via `mcp__soria__warehouse_query`, and formats the
  output as pivot tables matching what the dive displays. Queries
  `soria_duckdb_staging` by default (where local `dbt run` landed) so you
  see your uncommitted work.
  Read-only. Use when asked to "show me the dive", "what does this look like",
  "preview this", "show me slices", or "review the dive output".
  Use after /dive or /verify to inspect what was built. (soria-stack)
benefits-from: [dive, verify]
allowed-tools:
  - Read
  - Bash
  - Glob
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: preview"
```

Read `ETHOS.md`. Preview is read-only — no writes.

## Skill routing (always active)

- User wants to fix the data → invoke `/verify` then `/diagnose` or `/ingest`
- User wants to rebuild the dive → invoke `/dive`
- User wants pipeline status → invoke `/status`
- User says "push to prod" → invoke `/promote`

---

# /preview — "Show me the dive"

**Read-only.** Read the dive manifest, build SQL from its `{table, columns,
where, filters}`, query MotherDuck via `mcp__soria__warehouse_query`,
format as markdown tables matching how the dive displays in the browser.

The manifest points at `soria_duckdb_main.main_marts.*` (prod). For
local iteration, rewrite the query to `soria_duckdb_staging.main_marts.*`
so you see what your local `dbt run` just landed. Note this in the output.

Do not build, fix, or modify anything.

---

## Output Template

Every dive preview follows this structure, in this order:

```
## Dive: [Name] (`{id}`)

**Marts model:** `soria_duckdb_staging.main_marts.{model}` (local)
**Manifest points at:** `soria_duckdb_main.main_marts.{model}` (prod, post-merge)

**What the user sees:** [1-line grain description from manifest or dive component]

**Controls (from manifest):**
| Filter | Values | Default | Prefetch |
|--------|--------|---------|----------|
| segment | MA, PDP, Total | MA | yes |
| distribution | Individual, Group | Individual | no |

---

**Slice: [Default view name]**
[markdown pivot table — actual data, time as columns when time-series]

**Slice: [2nd key slice]**
[markdown pivot table — actual data]

**Interactions:** [what the DiveControlBar exposes, what changes when you toggle]

**Data quality notes:**
- [specific issue with evidence, or "None found"]

**Methodology:** [1-line summary — inspect the dive component for where methodology content lives; report "missing" if not surfaced]
**Verify:** [count of rows in `soria_duckdb_staging.main.verifications` WHERE model = '{marts_model}', or "missing" if 0]

**Verdict:** [1-2 sentences — what's strong, what's weak, usable or not?]
```

---

## Workflow

### 1. Enumerate (if no dive named)

Walk the dives directory:

```bash
ls frontend/src/dives/*.tsx 2>/dev/null
ls frontend/src/dives/manifests/*.manifest.ts 2>/dev/null
```

Present a numbered list. Ask: "Which to preview? All, or specific ones?"

### 2. Read the manifest

```bash
cat frontend/src/dives/manifests/{dive-id}.manifest.ts
```

Extract `table`, `columns`, `where`, `filters`, `groupBy`. Present the Controls
table before running any query.

### 3. Build SQL from the manifest

The manifest is the contract. Build SQL exactly how `useDiveData` would:

```sql
SELECT {columns joined with comma}
FROM {table}
WHERE {where clause}
  AND {filter_column_1} = '{default_value_1}'
  AND {filter_column_2} = '{default_value_2}'
  [GROUP BY {groupBy}]
ORDER BY [primary time/entity column]
LIMIT 50
```

### 4. Query and render

```
mcp__soria__warehouse_query(sql="{built SQL, rewriting table to soria_duckdb_staging.main_marts.*}")
```

Format as a pivot table matching how the dive displays it — not a raw row
dump. Time-series → time as columns. Single snapshot → entities as rows.

### 5. Render alternate slices

After the default view, render 1-2 slices that exercise the manifest filters:

```
mcp__soria__warehouse_query(sql="SELECT ... WHERE segment = 'PDP' ORDER BY ... LIMIT 50")
```

### 6. Check methodology surface + verify check count

```bash
# Methodology — the pattern varies; check the dive component for how it's wired
grep -l "methodology\|Methodology" frontend/src/dives/{dive-id}.tsx 2>/dev/null
```

```
# Verify check count for this dive's marts model
mcp__soria__warehouse_query(sql="
  SELECT COUNT(*) FROM soria_duckdb_staging.main.verifications
  WHERE model = '{marts_model_name}'
")
```

Missing methodology surface or zero verify checks is a shipping blocker
(Principle #28, #29). Flag in the verdict section.

### 7. Verdict

Look at the actual values before writing the verdict. Flag: unusual NULLs,
suspiciously round values, wrong ranges, time coverage gaps. **Never say
"looks good" without evidence.**

### 8. Stop. Wait.

One dive at a time. After rendering, stop and offer:

```
Options: show a different slice | go to next dive | /verify a value | /dashboard-review in browser
```

If the user requests a specific filter ("show me PDP only"), re-query and re-render.

---

## Handling manifest/data drift

If the SQL fails with a "column does not exist" error or a filter value
returns 0 rows, the manifest is out of sync with the data. Don't fix it
here — preview is read-only. Report the drift and suggest `/dive` to
update the manifest or `/ingest` to fix the upstream data:

```
⚠️  Manifest/data drift detected

The manifest filter `segment` includes value "Dual" but the marts table
has no rows where segment = 'Dual'. This will render as an empty pivot.

Fix via /dive (update the manifest) or /ingest (if the upstream should
include 'Dual' rows).
```

---

## Anti-Patterns

- **Raw row dumps** — format as pivot tables, not `SELECT * LIMIT 50`
- **Arbitrary slices** — start with the default manifest view, then exercise
  filters
- **"Looks good" without evidence** — check the numbers first
- **Auto-advancing** — one dive at a time, always stop after each
- **Skipping the controls table** — show it before the first data slice
- **Guessing SQL** — always derive SQL from the manifest file, not from
  assumptions about the dive
- **Ignoring missing methodology/verify meta** — a dive without those is
  incomplete; flag it in the verdict
- **Writing to the warehouse** — this skill is read-only. No
  `mcp__soria__warehouse_manage`, no `dbt run`, no manifest edits. Report
  drift, don't fix it.
