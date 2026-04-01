---
name: status
version: 1.0.0
description: |
  Investigate the current state of a data concept in the Soria system. When someone
  says "let's work on X" or "what's the status of X", this skill maps every pipeline
  stage — scrapers, files, groups, schemas, extractors, value mappings, warehouse tables,
  SQL models, and dashboards — into a single situational report.
  Trigger phrases: "status of X", "where are we with X", "let's work on X",
  "what do we have for X", "check on X", "how far along is X".
allowed-tools:
  - sumo_*
  - Read
  - Bash
---

# /status — "Where are we with this?"

You are investigating the current state of a data concept across the entire pipeline.
The user said something like "let's work on NAIC data" or "what's the status of FL Medicaid?"
Your job is to produce a complete situational report — every pipeline stage, what exists,
what's missing, what's broken.

**Do NOT start building anything.** This is reconnaissance, not construction.

---

## The Investigation

Run these checks in order. Each stage feeds context to the next.
Use `/tools` pattern: search for the right tool before calling it.

### Stage 1: Find the Scraper(s)

Search by name, URL, and keyword. A concept might span multiple scrapers.

```sql
SELECT id, name, url, created_at, updated_at
FROM scrapers
WHERE name ILIKE '%<keyword>%' OR url ILIKE '%<keyword>%'
ORDER BY name;
```

**If no scraper exists:** Report that and stop. The concept hasn't entered the system yet.
Suggest `/scout` as the next step.

**If multiple scrapers match:** Investigate all of them. Note which look active vs abandoned.

For each scraper found, record:
- `scraper_id`, `name`, `url`
- Whether it has code (check `scraper_manage(read)`)
- When it was last updated

### Stage 2: Workspaces

```sql
SELECT id, name, postgres_schema, created_at
FROM workspaces
WHERE scraper_id = '<scraper_id>'
ORDER BY created_at;
```

**Note:** Data often ONLY lives in workspace schemas, not in public.
If there are multiple workspaces, the most recent one is usually the active one.
Check both public and workspace schemas for data.

### Stage 3: Files

```sql
-- File count and type breakdown
SELECT file_type, COUNT(*) as count,
       MIN(created_at) as earliest,
       MAX(created_at) as latest
FROM files
WHERE scraper_id = '<scraper_id>'
GROUP BY file_type
ORDER BY count DESC;

-- For workspace data (set search_path first or use workspace_id in tool calls)
```

Report: total file count, types (PDF/CSV/XLSX/ZIP), date range, any child files
(parent_file_id set = extracted from ZIP or sheet-split).

### Stage 4: Groups

```sql
SELECT g.id, g.name, g.pattern, g.parent_group_id,
       COUNT(f.id) as file_count
FROM groups g
LEFT JOIN files f ON f.group_id = g.id
WHERE g.scraper_id = '<scraper_id>'
GROUP BY g.id, g.name, g.pattern, g.parent_group_id
ORDER BY g.name;
```

Report: group hierarchy, patterns, file distribution. Flag ungrouped files:

```sql
SELECT COUNT(*) as ungrouped
FROM files
WHERE scraper_id = '<scraper_id>' AND group_id IS NULL;
```

### Stage 5: Schema & Extractors

For each group:

```sql
-- Schema columns
SELECT id, name, column_source, canonical_id, is_required, is_nullable
FROM schema_columns
WHERE group_id = '<group_id>'
ORDER BY name;

-- Extractors
SELECT id, name, is_default
FROM extractors
WHERE group_id = '<group_id>';
```

Report: column count, whether schema is defined, whether extractors exist,
whether there's a default extractor.

### Stage 6: Value Mappings

```sql
SELECT sc.name as column_name,
       COUNT(fv.id) as mapping_count,
       COUNT(CASE WHEN fv.canonical_id IS NOT NULL THEN 1 END) as mapped_count
FROM schema_columns sc
LEFT JOIN file_values fv ON fv.schema_column_id = sc.id
WHERE sc.group_id = '<group_id>'
GROUP BY sc.name
ORDER BY sc.name;
```

Report: which columns have mappings, completion percentage, unmapped values.

### Stage 7: Warehouse

```sql
SELECT id, table_name, row_count, column_names, updated_at
FROM warehouse_tables
WHERE group_id = '<group_id>';
```

Report: whether data is published to DuckDB/MotherDuck, row counts, last update.

### Stage 8: SQL Models

```sql
-- Check for models referencing this data
SELECT name, layer, path, description
FROM workspace_models
WHERE workspace_id = '<workspace_id>'
ORDER BY layer, name;
```

Also check the soria-2 codebase for models:
```bash
grep -r "<scraper_name_or_keyword>" /home/openclaw/workspace/soria-2/models/ --include="*.sql" -l
```

Report: which layers exist (bronze/silver/gold/platinum), what they compute.

### Stage 9: Dashboards

Check for `@dashboard` annotations in platinum models:
```bash
grep -r "@dashboard" /home/openclaw/workspace/soria-2/models/ --include="*.sql" -l | xargs grep -l "<keyword>"
```

Also check the dashboard config if applicable.

Report: whether dashboards exist, which pages, what they show.

---

## The Report

After investigation, produce a structured report:

```
## Status: <Concept Name>

### Overview
<One paragraph: what this is, how far along it is, what the next step would be>

### Pipeline Map

| Stage | Status | Details |
|-------|--------|---------|
| Scraper | ✅/⚠️/❌ | <name>, <file count>, last run <date> |
| Files | ✅/⚠️/❌ | <count> files (<types>), <date range> |
| Groups | ✅/⚠️/❌ | <count> groups, <ungrouped> ungrouped |
| Schema | ✅/⚠️/❌ | <count> columns defined |
| Extractors | ✅/⚠️/❌ | <count> extractors, default: <yes/no> |
| Mappings | ✅/⚠️/❌ | <mapped>/<total> columns mapped |
| Warehouse | ✅/⚠️/❌ | <row count> rows in <table_name> |
| SQL Models | ✅/⚠️/❌ | <layers present> |
| Dashboards | ✅/⚠️/❌ | <page count> pages |

### What's Working
<Bullet list of what's solid>

### What's Broken or Missing
<Bullet list of gaps, blockers, issues — be specific>

### Recommended Next Step
<Single clear recommendation — which skill to invoke next>
```

**Status legend:**
- ✅ = exists and looks healthy
- ⚠️ = exists but has issues (incomplete, stale, partially broken)
- ❌ = doesn't exist or completely broken

---

## Edge Cases

**Multiple scrapers for one concept:** Report all of them. Note which is the "active"
one (most recent files, most groups, has workspace) vs abandoned attempts.

**Data only in workspace, not public:** This is normal for in-progress work. Flag it
but don't treat it as broken.

**Stale data:** If the most recent file is >30 days old, flag the scraper as potentially
stale. The source may have updated since.

**No scraper at all:** The concept hasn't entered the system. Suggest `/scout` to
investigate the source and plan the pipeline.

---

## Artifact

Write the status report to the thread/conversation. If the report reveals
significant state worth preserving, suggest writing it to the knowledge base.

```yaml
completion: DONE
next_skill: <suggested skill based on gaps found>
concept: <what was investigated>
scraper_ids: [<list of scraper IDs found>]
workspace_ids: [<list of workspace IDs found>]
```
