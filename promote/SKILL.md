---
name: promote
version: 1.0.0
description: |
  Promote workspace data and SQL models to production. This is the ONLY path
  to production — do NOT promote ad-hoc, do NOT create prod views directly,
  do NOT run workspace_manage(promote) outside this skill.
  REQUIRES EXPLICIT HUMAN APPROVAL before every promotion.
  Use when asked to "promote", "push to prod", "deploy this", "make it live".
  Do NOT proactively suggest promotion — wait for the human to ask.
  Do NOT promote just because a pipeline is "done" — done in workspace is not
  done in prod. The human decides when to promote. (soria-stack)
allowed-tools:
  - sumo_*
  - Read
  - Bash
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: promote"
echo "---"
echo "⚠️  PRODUCTION PROMOTION — requires human approval at every step"
```

Read `ETHOS.md` from this skill pack.

## Skill routing (always active)

If the user's intent shifts away from promotion, invoke the right skill:

- User wants to fix something before promoting → invoke `/ingest`, `/map`, or `/dashboard`
- User wants to verify before promoting → invoke `/verify`
- User wants to check what exists → invoke `/status`

**CRITICAL: Do NOT promote anything without this skill.** If you're in another
skill (/ingest, /dashboard, /verify) and the user says "push this to prod", invoke
/promote — do NOT call workspace_manage(promote) directly.

---

# /promote — "Make it live"

You are a production gatekeeper. Your job is to safely promote workspace data
and SQL models to production. **You NEVER promote without explicit human
approval.** You NEVER suggest promotion proactively.

Production is permanent. Workspace is safe. The gap between them is this skill.

---

## Pre-flight Checklist

Before promoting anything, verify ALL of these. Present the checklist to the
human and wait for approval.

### 1. What's being promoted?

```
workspace_manage(operation="read", workspace_id="...")
```

Report:
- Workspace name and ID
- Type: scraper workspace (has data) or SQL-only (models only)
- What models exist (list bronze/silver/gold/platinum)
- What data is published (table names, row counts)

### 2. Has it been verified?

Check for a /verify artifact for this workspace. If none exists:

```
⚠️ NO VERIFICATION ARTIFACT FOUND

This workspace has not been verified using /verify.
Recommend running /verify before promoting.

Promote anyway? [requires explicit "yes"]
```

If a verify artifact exists, show the confidence level and any caveats.

### 3. Dependency order check

Models must promote in order: **bronze → silver → gold → platinum.**

If the workspace has silver models that reference bronze, confirm bronze
exists in prod (or is being promoted in this batch):

```
Dependency check:
- silver.stg_enrollment references bronze.enrollment → ✅ exists in prod
- gold.enrollment_enriched references silver.stg_enrollment → ⚠️ silver only in workspace
  → Must promote silver first, then gold
```

### 4. Known blockers

Check for these common issues before promoting:
- **warehouse_materialize schema resolution:** If workspace silver references
  workspace bronze (not prod bronze), materialization will use wrong data.
  Fix: promote bronze first, verify it materialized, then promote silver.
- **warehouse_query LIMIT on DDL:** Cannot create views through warehouse_query
  (appends LIMIT to DDL). Use workspace_manage(promote) which handles this correctly.
- **Stale workspace clone:** If the workspace was created days ago, the
  MotherDuck clone may be outdated. Check freshness.

### 5. Materialization state check

Promotion can **lose materialization.** If a workspace model has
`is_materialized=false` (the default) but the prod version was materialized as
a TABLE, promoting overwrites the prod `SqlModelCode` record and creates a VIEW
where there was a TABLE. This makes prod queries slow.

**Before promoting, check prod materialization state:**
```
warehouse_query("SELECT table_name, table_type FROM information_schema.tables WHERE table_schema = 'bronze'")
```

If any bronze models are `BASE TABLE` in prod, note them. After promotion,
re-materialize to restore the TABLE:
```
warehouse_materialize(model_name="bronze.{table}", materialize=True)
```

Report materialization state in the pre-flight checklist so the human can
decide whether to re-materialize after promotion.

---

## ⛔ GATE: HUMAN APPROVAL REQUIRED

Present the pre-flight checklist results:

```
PROMOTION REQUEST
═════════════════

Workspace: [name] ([id])
Type: [scraper / SQL-only]

Models to promote:
  - bronze.X (VIEW)
  - silver.stg_X (VIEW)
  - gold.X_enriched (VIEW)

Data to promote:
  - [table_name]: [row_count] rows
  - (or "SQL-only — no data rows")

Materialization:
  - bronze.X is currently [TABLE/VIEW] in prod
  - [If TABLE: will need re-materialization after promotion]
  - [If VIEW: no action needed]

Verification: [PASSED / NOT VERIFIED / PASSED WITH CONCERNS]
Dependencies: [ALL MET / ISSUES — list them]
Blockers: [NONE / list them]

⚠️  This will overwrite production models/data.
    Proceed? [waiting for explicit approval]
```

**Do NOT proceed without "yes", "go ahead", "promote it", or equivalent.**
Silence is NOT approval. Ambiguity is NOT approval.

---

## Executing Promotion

After human approval:

### Step 1: Promote the workspace

```
workspace_manage(operation="promote", workspace_id="...")
```

This copies SQL models from workspace to prod (workspace_id=NULL), dumps
models to disk, and runs SQLMesh apply.

### Step 2: Verify promotion landed

After promotion completes, check that models exist in prod:

```
sql_model_list() — filter for the promoted model names, confirm workspace_id is NULL
```

Check that views materialized in MotherDuck:
```
warehouse_query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'silver'")
```

### Step 3: Spot-check prod data

Query a few values from the prod views to confirm they match what was in
the workspace:

```
warehouse_query("SELECT COUNT(*) FROM silver.stg_X")
```

Compare against the workspace row count. If they don't match, flag it immediately.

### Step 4: Report results

```
PROMOTION COMPLETE
══════════════════

Workspace: [name] → PROMOTED
Models promoted: [count] (bronze: X, silver: X, gold: X, platinum: X)
Data promoted: [row counts or "SQL-only"]
Prod verification:
  - Models in prod: ✅
  - Views materialized: ✅
  - Row count match: ✅ / ⚠️ [explain difference]

Status: DONE / DONE_WITH_CONCERNS
```

---

## Rollback

If promotion breaks something:

1. **SQL models:** The previous version still exists in Postgres (versions are
   append-only). To rollback, you'd need to re-promote the previous workspace
   or manually revert the sql_models records.
2. **Data:** Workspace data doesn't overwrite prod data — it creates new tables.
   Old prod tables are still there unless explicitly dropped.
3. **Views:** SQLMesh manages view lifecycle. Re-applying from a previous state
   reverts the views.

**Rollback is not automated.** If something goes wrong, escalate to the human
with a clear description of what broke and what the options are.

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/promote-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Promotion Report: [Workspace Name]

## What was promoted
[Models, data, row counts]

## Pre-flight checklist
[Verification status, dependency check, blockers]

## Results
[What landed in prod, verification results]

## Outcome
Status: [DONE | DONE_WITH_CONCERNS | BLOCKED]
Lesson: [What was interesting or unexpected]
ARTIFACT
```

---

## Anti-Patterns

1. **Promoting without being asked.** The AI should NEVER suggest or initiate
   promotion. The human decides when to go to prod.

2. **Calling workspace_manage(promote) outside this skill.** All promotion
   goes through /promote. If you're in /ingest or /dashboard and the user says
   "push to prod", invoke this skill — don't call the tool directly.

3. **Promoting without verification.** If /verify hasn't run, warn loudly.
   Don't just promote because the pipeline "looks done."

4. **Promoting in wrong dependency order.** Silver before bronze = silver
   reads stale prod bronze data. Always bronze → silver → gold → platinum.

5. **Assuming promotion = done.** Always verify after promotion — check models
   exist in prod, views materialized, row counts match.
