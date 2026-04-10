---
name: status
version: 2.0.0
description: |
  Pipeline reconnaissance — investigate what exists for a concept in our system.
  Drives through `soria` CLI (env status, list, file show, group show, db query,
  warehouse query) plus filesystem walks of the dives project.
  Use when asked "what's the status of", "what do we have for", "let's work on [X]",
  or when the user names a scraper, env, or data domain.
  Proactively invoke this skill (do NOT query pipeline state ad-hoc) when the
  user mentions a data concept, scraper, or asks about pipeline progress.
  Use before /plan. This is read-only — never modify anything. (soria-stack)
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: status"
echo "---"
echo "Active environment:"
soria env status 2>&1 || echo "  (soria CLI not authed — run /env first)"
echo "---"
echo "Git state in worktree:"
git status --short 2>&1 | head -15 || echo "  (not in a worktree)"
```

Read `ETHOS.md`. Key principle: #24 (inventory before action).

## Skill routing (always active)

This skill is read-only recon. If the user's intent shifts:

- User wants to plan next steps after seeing status → invoke `/plan`
- User wants to start building/scraping → invoke `/ingest` (suggest `/plan` first)
- User wants to map values → invoke `/map`
- User wants to build a dive → invoke `/dive`
- User wants to verify data → invoke `/verify`
- User wants news pipeline work → invoke `/newsroom`

**After /status completes, the most common next step is `/plan`.** Suggest it.

---

# /status — "What do we have?"

You are a pipeline investigator. Your job is to walk through every stage of
the data pipeline for a given concept and report what exists, what's missing,
and what's broken. **You never modify anything — this is read-only
reconnaissance.**

---

## How It Works

The user gives you a keyword, scraper name, env name, or domain concept
(e.g., "NAIC data", "FL Medicaid", "Kaufman Hall", "star ratings"). You
investigate in order.

### Stage 0: Current environment

```bash
soria env status
```

Report the active env's summary. This frames everything else — the user is
looking at state within this env, not prod.

### Stage 1: Find the scraper(s)

```bash
soria list | grep -i {keyword}
soria scraper --help   # reference
```

If no scrapers match, try broader searches. Report what you find or that
nothing exists.

### Stage 2: Files

For each scraper, check what's been downloaded:

```bash
soria db query "
SELECT file_type, COUNT(*) as count,
       MIN(created_at)::date as oldest, MAX(created_at)::date as newest
FROM files WHERE scraper_id = '{id}'
GROUP BY file_type
"
```

Report: file count, types, date range. Flag if scraper exists but has 0
files (never been run) or if `last_run_at` is stale (>30 days).

### Stage 3: Groups

```bash
soria group list --scraper {scraper_name}
soria group show {group_id}   # for detail on a specific group
```

Report: group names, file counts per group, ungrouped file count. Flag if
files exist but 0 groups (needs organization).

### Stage 4: Schema

For each group, check if a schema is defined:

```bash
soria schema read --group {group_id}
```

Report: column count, column names, whether mappings exist.

### Stage 5: Extractors / Schema Mappings

Two paths depending on file type:

- **PDF/Excel groups:** Check extractors:
  ```bash
  soria extractor list --scraper {scraper_name}
  ```
  Report extractor name, whether it's been run, how many files have child CSVs.

- **CSV groups:** Check schema mappings:
  ```bash
  soria schema mappings-read {group_id}
  ```
  Report how many source columns are mapped vs unmapped.

### Stage 6: Value Mappings

For groups with extracted data, check value mapping status:

```bash
soria value read --group {group_id}
```

Report: which columns have canonicals, how many values are mapped vs unmapped.
Flag columns with >10% unmapped values.

### Stage 7: Warehouse

Check what's published:

```bash
soria warehouse status --group {group_id}
soria warehouse query "SELECT table_name, table_type FROM information_schema.tables WHERE table_schema = 'bronze' AND table_name ILIKE '%{keyword}%'"
```

Report: table names, types (BASE TABLE vs VIEW), row counts via:
```bash
soria warehouse query "SELECT COUNT(*) FROM bronze.{table}"
```

Flag un-materialized tables (type=VIEW).

### Stage 8: SQL Models + Dives

Check what models exist in the upstream warehouse and in the dives dbt project:

```bash
# Upstream models (platform's SQLMesh)
soria model list | grep -i {keyword}

# Dive dbt models (frontend/src/dives/dbt)
find frontend/src/dives/dbt/models -name "*{keyword}*" 2>/dev/null
```

Report: which layers exist (bronze/silver/gold in upstream, staging/
intermediate/marts in the dives dbt project), model names.

### Stage 9: Dives (filesystem + git state)

Walk the dives filesystem AND check git state — a dive that's uncommitted
is pipeline state too.

```bash
# Registered dives in DivesPage
grep -E "id: \"" frontend/src/pages/DivesPage.tsx 2>/dev/null

# Manifest files
ls frontend/src/dives/manifests/*.manifest.ts 2>/dev/null

# Component files (top-level .tsx, not the components/ directory)
ls frontend/src/dives/*.tsx 2>/dev/null

# Marts models
find frontend/src/dives/dbt/models/marts -name "*.sql" 2>/dev/null

# Verify check rows for each dive's marts model
soria warehouse query "
SELECT model, COUNT(*) AS check_count
FROM soria_duckdb_main.main.verifications
GROUP BY model
ORDER BY check_count DESC
"

# Git state of the dive filesystem — anything uncommitted?
git status --short -- frontend/src/dives/ 2>/dev/null
git status --short -- frontend/src/pages/DivesPage.tsx 2>/dev/null
```

Match against the keyword. Report: registered dive names, manifest +
component presence, marts model existence, verify check count, and **git
state** (uncommitted / committed not pushed / clean).

Flag incomplete dives:
- Component exists but no manifest
- Manifest exists but no component
- Component + manifest exist but `<15` rows in verifications for that model
- Component registered in DivesPage but the import target doesn't exist
- Marts model exists but no dive uses it
- Dive files modified but not committed (will be lost on env teardown)
- Dive files committed but not pushed (will be lost on env teardown, though
  committed to local git history)

---

## Output Format

Present a single status table, then detail the gaps:

```
## Status: [Concept Name]
## Environment: [active soria env]

| Stage | Status | Detail |
|-------|--------|--------|
| Scraper | OK | `cms_cost_report` — last run 2026-03-15 |
| Files | OK | 47 CSVs (2011-2024) |
| Groups | PARTIAL | 1 group (47 files), 12 ungrouped PDFs |
| Schema | OK | 116 columns defined |
| Extraction | N/A | CSVs — no extraction needed |
| Value Map | GAP | 3 columns unmapped (metric_name: 52 values) |
| Warehouse | OK | 456,789 rows, materialized |
| SQL Models | PARTIAL | silver + gold in upstream, no dbt marts yet |
| Dives | GAP | No dive registered for this domain |

### What's working
- Pipeline from scrape through warehouse is complete
- Data covers 2011-2024 with consistent schema

### What's missing
- Value mapping incomplete on metric_name (52 unmapped values)
- No marts model or dive yet

### Suggested next step
→ /map to finish value mapping, then /dive to build the dive
```

**Status values:** `OK` | `PARTIAL` | `GAP` | `N/A` | `STALE` | `MISSING`

---

## Multi-Scraper Mode

When the keyword matches multiple scrapers (e.g., "NAIC" matches 3 scrapers,
"Medicaid" matches 12), present a summary table first:

```
## [Domain]: 3 scrapers found

| Scraper | Files | Groups | Schema | Extracted | Mapped | Published | Models | Dives |
|---------|-------|--------|--------|-----------|--------|-----------|--------|-------|
| naic_health | 246 | 5 | OK | OK | PARTIAL | OK | bronze+silver | 2 |
| naic_life | 180 | 0 | GAP | GAP | GAP | GAP | none | 0 |
| naic_property | 95 | 2 | OK | GAP | GAP | GAP | none | 0 |
```

Then let the user choose which to dive into, or offer a priority recommendation
based on completeness.

---

## Environment Awareness

All state you report is scoped to the **active env**. If the user asks
"what's the status of X in prod?", they need to switch envs first via
`/env checkout prod`, then re-run /status. Don't query prod from a dev env.

---

## Staleness Detection

Flag any of these:
- Scraper `last_run_at` > 30 days ago (may need refresh)
- Files exist but no groups (pipeline stalled at organization)
- Groups exist but no schema (pipeline stalled at schema design)
- Extraction done but 0 value mappings (pipeline stalled at mapping)
- Warehouse published but no dive (data is there but no user-facing product)
- Bronze exists but not materialized (performance problem)
- Dive registered but marts model missing (`dbt run` never succeeded)
- Dive component exists but no methodology/verify meta files (Principle #29 violation)

---

## Anti-Patterns

1. **Modifying anything.** /status is read-only. If you see something broken,
   report it — don't fix it.

2. **Skipping stages.** Always walk all 10 stages (including env + dives)
   even if you think you know the answer. The point is the complete picture.

3. **Reporting input counts instead of actual counts.** Query the database for
   real numbers. Don't say "47 files" because the scraper config says 47 —
   count them.

4. **Forgetting the env context.** Everything you report is within one env.
   Always prefix with the active env name.

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/status-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Status Report: [Concept Name]

## Environment
[Active soria env]

## Pipeline Status Table
[The status table from above]

## Scrapers
[IDs, names, URLs for reference]

## Dives
[Registered dives matching the keyword + completeness]

## Gaps & Recommendations
[What's missing, suggested next skill]

## Outcome
Status: DONE
ARTIFACT
```

This artifact is consumed by `/plan` when designing the work.
