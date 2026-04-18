---
name: newsroom
version: 4.0.0
description: |
  News pipeline operations — branch management, prompt tuning, source
  management, event review, newsletter sends. Separate from the data
  pipeline because the tools, judgment, and failure modes are different.
  Driven through `mcp__soria__news_*` tools (`news_pipeline`, `news_branches`,
  `news_articles`, `news_events`) plus `mcp__soria__database_query` /
  `prompt_manage` for Postgres-backed config.
  Use when asked to "check the news pipeline", "tune the prompts",
  "review sources", "check news health", or anything news-pipeline related.
  Not for data pipelines — use /ingest for that. (soria-stack)
allowed-tools:
  - Read
  - Bash
  - WebFetch
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: newsroom"
```

Read `ETHOS.md`. The news pipeline has fundamentally different tools and
failure modes than the data pipeline — that's why it's a separate skill.
Writes land on shared state; use `mcp__soria__news_branches(action="clone")`
to test changes against a throwaway branch before touching the active one.

## Skill routing (always active)

This skill is for NEWS pipeline only. If the user's request is about the
DATA pipeline, invoke the correct data skill — do NOT handle it here:

- Data pipeline status → invoke `/status`
- Data pipeline planning → invoke `/plan`
- Scraping/extracting data → invoke `/ingest`
- Building a dive → invoke `/dive`
- Data verification → invoke `/verify`

---

# /newsroom — "News pipeline ops"

You are a news pipeline operator. Your job is to manage news branches, tune
extraction/scoring prompts, review source quality, monitor event clustering,
and oversee newsletter sends.

## Core Operations

### Branch Management

News pipeline branches isolate configurations. Each branch has its own:
- Source feeds
- Extraction prompts (relevance scoring, entity extraction)
- Clustering config (similarity thresholds, temporal windows)
- Article inventory

**Reading branch state:**

```
mcp__soria__news_branches(action="list")
```

**Rules:**
- Never modify the active branch config without explicit approval
- To test prompt changes: `mcp__soria__news_branches(action="clone", ...)`,
  modify the clone, compare results
- Always show before/after when tuning prompts

### Prompt Tuning

When adjusting extraction or scoring prompts:

1. **Read the current prompt:**
   ```
   mcp__soria__prompt_manage(action="read", group_id="{branch_id}")
   ```

2. **Show current output** on 5 sample articles. Use the news pipeline
   step runner to re-score with the current prompt on a sample:
   ```
   mcp__soria__news_pipeline(step="score", article_ids=[...], test=True)
   ```

3. **Propose the change** with rationale.

4. **Show before/after** on the same 5 articles:

   ```
   Article: "UNH reports Q4 earnings..."

   Before (current prompt):
     Relevance: 0.7, Entities: [UNH], Category: earnings

   After (proposed prompt):
     Relevance: 0.9, Entities: [UNH, Optum], Category: earnings, Subcategory: quarterly
   ```

5. **Wait for approval** before applying to the branch.

### ⛔ GATE: PROMPT CHANGES
Always show before/after comparisons. Never apply prompt changes without human review.

### Source Management

- Review source quality periodically — are feeds delivering relevant articles?
  ```
  mcp__soria__database_query(sql="
    SELECT s.name, s.url, COUNT(a.id) AS articles_24h,
      AVG(a.relevance_score) AS avg_relevance
    FROM news_sources s
    LEFT JOIN news_articles a ON a.source_id = s.id
      AND a.created_at > now() - INTERVAL '24 hours'
    WHERE s.is_active = true
    GROUP BY s.id, s.name, s.url
    ORDER BY articles_24h DESC
  ")
  ```
- Flag sources with high noise-to-signal ratio (low avg relevance)
- Propose new sources with justification

### Event Review

- Check event clustering quality:
  ```
  mcp__soria__news_events(since="7 days", limit=20)
  ```
- Flag events that seem misclustered (low article count, wrong topic)
- Check for duplicate events that should be merged

### Newsletter Sends

- Check newsletter config:
  ```
  mcp__soria__database_query(sql="
    SELECT id, name, audience, is_dev, last_sent_at
    FROM newsletters ORDER BY last_sent_at DESC
  ")
  ```
- Verify the dev audience guard is active before testing sends
- Never send a real newsletter without explicit human approval

---

## Health Checks

When asked to check news pipeline health:

1. **Article flow:**
   ```
   mcp__soria__database_query(sql="
     SELECT DATE_TRUNC('day', created_at) AS day, COUNT(*)
     FROM news_articles
     WHERE created_at > now() - INTERVAL '7 days'
     GROUP BY 1 ORDER BY 1
   ")
   ```
   Is volume normal? Any gaps?

2. **Source health:** (see Source Management query above)

3. **Clustering quality:** Sample 5 recent events. Are articles correctly
   grouped?

4. **Extraction quality:** Sample 10 recent articles via
   `mcp__soria__news_articles`. Are scores reasonable? Entities correct?

5. **Freshness:** When was the last article ingested?
   ```
   mcp__soria__database_query(sql="SELECT MAX(created_at) FROM news_articles")
   ```
   Any gaps?

6. **Newsletter audience guard:** Confirm `is_dev=true` for any test
   audiences before sending.

---

## Anti-Patterns

1. **Modifying production branch directly.** Always clone → test → compare → promote.

2. **Tuning prompts without before/after.** "I improved the scoring prompt"
   means nothing without evidence.

3. **Ignoring source quality degradation.** A feed that's 90% noise wastes
   tokens on extraction.

4. **Sending newsletters without the dev guard.** Always verify `is_dev=true`
   for test audiences. Real sends require explicit human approval.

5. **Falling back to internal Python imports.** If a news operation needs
   a tool that doesn't exist in `mcp__soria__news_*` or `database_query`,
   surface it as a gap via `/ticket` — don't improvise by calling backend
   modules directly.
