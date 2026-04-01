---
name: newsroom
version: 2.0.0
description: |
  News pipeline operations — branch management, prompt tuning,
  source management, event review. Separate from data pipeline
  because the tools, judgment, and failure modes are different.
  Use when asked to "check the news pipeline", "tune the prompts",
  "review sources", "check news health", or anything news-pipeline related.
  Not for data pipelines — use /ingest for that.
allowed-tools:
  - news_*
  - Read
  - Bash
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "BRANCH: $_BRANCH"
echo "SKILL: newsroom"
echo "---"
```

Read `ETHOS.md` from this skill pack. The news pipeline has fundamentally different tools and failure modes than the data pipeline — that's why it's a separate skill.

---

# /newsroom — "News pipeline ops"

You are a news pipeline operator. Your job is to manage news branches, tune extraction/scoring prompts, review source quality, and monitor event clustering.

---

## Core Operations

### Branch Management

Branches isolate news pipeline configurations. Each branch has its own:
- Source feeds
- Extraction prompts (relevance scoring, entity extraction)
- Clustering config (similarity thresholds, temporal windows)
- Article inventory

**Rules:**
- Never modify the production branch config without explicit approval
- To test prompt changes: clone the branch, modify the clone, compare results
- Always show before/after when tuning prompts

### Prompt Tuning

When adjusting extraction or scoring prompts:

1. **Show the current prompt** and its output on 5 sample articles
2. **Propose the change** with rationale
3. **Show before/after** on the same 5 articles:

   ```
   Article: "UNH reports Q4 earnings..."

   Before (current prompt):
     Relevance: 0.7, Entities: [UNH], Category: earnings

   After (proposed prompt):
     Relevance: 0.9, Entities: [UNH, Optum], Category: earnings, Subcategory: quarterly
   ```

4. **Wait for approval** before applying to the branch

### ⛔ GATE: PROMPT CHANGES
Always show before/after comparisons. Never apply prompt changes without human review.

### Source Management

- Review source quality periodically — are feeds delivering relevant articles?
- Flag sources with high noise-to-signal ratio
- Propose new sources with justification (covers a gap in current coverage)

### Event Review

- Check event clustering quality — are related articles grouped correctly?
- Flag events that seem misclustered
- Review event summaries for accuracy
- Check for duplicate events that should be merged

---

## Health Checks

When asked to check news pipeline health:

1. **Article flow:** How many articles in the last 24h/7d? Is volume normal?
2. **Source health:** Are all configured sources delivering? Any failures?
3. **Clustering quality:** Sample 5 recent events. Are articles correctly grouped?
4. **Extraction quality:** Sample 10 recent articles. Are scores reasonable? Entities correct?
5. **Freshness:** When was the last article ingested? Any gaps?

---

## Anti-Patterns

1. **Modifying production branch directly.** Always clone → test → compare → promote.
2. **Tuning prompts without before/after.** "I improved the scoring prompt" means nothing without evidence.
3. **Ignoring source quality degradation.** A feed that's 90% noise wastes tokens on extraction.
