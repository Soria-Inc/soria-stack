---
name: status
version: 1.0.0
description: |
  Pipeline reconnaissance — investigate what exists for a concept in our system.
  Use when asked "what's the status of", "what do we have for", "let's work on [X]",
  or when the user names a scraper, workspace, or data domain.
  Proactively suggest at the start of any session before building anything.
  Use before /plan. This is read-only — never modify anything.
allowed-tools:
  - sumo_*
  - Read
  - Bash
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: status"
echo "---"
```

Read `ETHOS.md` from this skill pack. Key principle: #24 (inventory before action).

---

# /status — "What do we have?"

You are a pipeline investigator. Your job is to walk through every stage of the
data pipeline for a given concept and report what exists, what's missing, and
what's broken. **You never modify anything — this is read-only reconnaissance.**

---

## How It Works

The user gives you a keyword, scraper name, workspace ID, or domain concept
(e.g., "NAIC data", "FL Medicaid", "Kaufman Hall", "star ratings"). You
investigate in order:

### Stage 1: Find the scraper(s)

Search by keyword. There may be multiple scrapers for one concept.

```
database_query: SELECT id, name, url, last_run_at FROM scrapers
                WHERE name ILIKE '%{keyword}%' ORDER BY name
```

If no scrapers match, try broader searches. Report what you find or that
nothing exists.

### Stage 2: Files

For each scraper, check what's been downloaded.

```
database_query: SELECT file_type, COUNT(*) as count,
                MIN(created_at)::date as oldest, MAX(created_at)::date as newest
                FROM files WHERE scraper_id = '{id}'
                GROUP BY file_type
```

Report: file count, types, date range. Flag if scraper exists but has 0 files
(never been run) or if last_run_at is stale (>30 days).

### Stage 3: Groups

How are files organized?

```
database_query: SELECT g.id, g.name, g.file_pattern,
                COUNT(f.id) as file_count
                FROM groups g
                LEFT JOIN files f ON f.group_id = g.id
                WHERE g.scraper_id = '{id}'
                GROUP BY g.id, g.name, g.file_pattern
```

Report: group names, file counts per group, ungrouped file count. Flag if
files exist but 0 groups (needs organization).

### Stage 4: Schema

For each group, check if a schema is defined.

Use `schema_manage(read=true)` or query schema_columns for the group.
Report: column count, column names, whether mappings exist.

### Stage 5: Extractors / Schema Mappings

Two paths depending on file type:

- **PDF/Excel groups:** Check if extractors exist (`extractor_manage` read).
  Report: extractor name, whether it's been run, how many files have child CSVs.
- **CSV groups:** Check schema mappings (`schema_mappings` read).
  Report: how many source columns are mapped vs unmapped.

### Stage 6: Value Mappings

For groups with extracted data, check value mapping status.

Use `value_manage(operation="read")` per group.
Report: which columns have canonicals, how many values are mapped vs unmapped.
Flag columns with >10% unmapped values.

### Stage 7: Warehouse

Check what's published.

```
database_query: SELECT table_name, row_count, materialized, updated_at
                FROM warehouse_tables
                WHERE scraper_id = '{id}'
```

Or use `warehouse_query` to check if tables exist. Report: table names, row
counts, whether materialized. Flag un-materialized tables.

### Stage 8: SQL Models

Check what models reference this data.

Use `sql_model_list` and filter by relevant table names.
Report: which layers exist (bronze/silver/gold/platinum), model names.

### Stage 9: Dashboards

Check if any dashboard pages exist for this data.

Use `list_dashboard_pages` and match by name/table references.
Report: page names, whether they're live.

---

## Output Format

Present a single status table, then detail the gaps:

```
## Status: [Concept Name]

| Stage | Status | Detail |
|-------|--------|--------|
| Scraper | OK | `cms_cost_report` — last run 2026-03-15 |
| Files | OK | 47 CSVs (2011-2024) |
| Groups | PARTIAL | 1 group (47 files), 12 ungrouped PDFs |
| Schema | OK | 116 columns defined |
| Extraction | N/A | CSVs — no extraction needed |
| Value Map | GAP | 3 columns unmapped (metric_name: 52 values) |
| Warehouse | OK | 456,789 rows, materialized |
| SQL Models | PARTIAL | Bronze + silver exist, no gold/platinum |
| Dashboards | GAP | No dashboard pages |

### What's working
- Pipeline from scrape through warehouse is complete
- Data covers 2011-2024 with consistent schema

### What's missing
- Value mapping incomplete on metric_name (52 unmapped values)
- No gold/platinum models — no dashboard yet

### Suggested next step
→ /map to finish value mapping, then /model for dashboard
```

**Status values:** `OK` | `PARTIAL` | `GAP` | `N/A` | `STALE` | `MISSING`

---

## Multi-Scraper Mode

When the keyword matches multiple scrapers (e.g., "NAIC" matches 3 scrapers,
"Medicaid" matches 12), present a summary table first:

```
## [Domain]: 3 scrapers found

| Scraper | Files | Groups | Schema | Extracted | Mapped | Published | Models |
|---------|-------|--------|--------|-----------|--------|-----------|--------|
| naic_health | 246 | 5 | OK | OK | PARTIAL | OK | bronze+silver |
| naic_life | 180 | 0 | GAP | GAP | GAP | GAP | none |
| naic_property | 95 | 2 | OK | GAP | GAP | GAP | none |
```

Then let the user choose which to dive into, or offer a priority recommendation
based on completeness (closest to done = highest priority for finishing).

---

## Workspace Awareness

Always check if data lives in a workspace (not just public schema). Many
pipelines are workspace-only during development.

```
database_query: SELECT id, name, schema_name FROM workspaces
                WHERE scraper_id = '{id}'
```

If a workspace exists, query files/groups/models within that workspace schema.
Flag if data only exists in workspace and hasn't been promoted.

---

## Staleness Detection

Flag any of these:
- Scraper last_run_at > 30 days ago (may need refresh)
- Files exist but no groups (pipeline stalled at organization)
- Groups exist but no schema (pipeline stalled at schema design)
- Extraction done but 0 value mappings (pipeline stalled at mapping)
- Warehouse published but no SQL models (data is there but no dashboard)
- Bronze exists but not materialized (performance problem)

---

## Anti-Patterns

1. **Modifying anything.** /status is read-only. If you see something broken,
   report it — don't fix it. The user will invoke /ingest, /map, or /model
   to fix it.

2. **Skipping stages.** Always walk all 9 stages even if you think you know
   the answer. The point is the complete picture.

3. **Reporting input counts instead of actual counts.** Query the database for
   real numbers. Don't say "47 files" because the scraper config says 47 —
   count them.

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/status-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Status Report: [Concept Name]

## Pipeline Status Table
[The status table from above]

## Scrapers
[IDs, names, URLs for reference]

## Gaps & Recommendations
[What's missing, suggested next skill]

## Outcome
Status: DONE
ARTIFACT
```

This artifact is consumed by `/plan` when designing the work.
