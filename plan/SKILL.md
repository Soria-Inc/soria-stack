---
name: plan
version: 1.0.0
description: |
  ETVLR orchestrator — breaks any data task into phases, plans verification
  upfront, asks clarifying questions before building. Absorbs source recon
  from the former /scout skill.
  Use when asked "come up with a plan", "what should we do", "how should we
  approach this", "let's work on [X]", or after /status reveals gaps.
  Proactively invoke this skill (do NOT start building ad-hoc) when the user
  describes a data goal without specifying steps or when planning is needed.
  Use after /status, before /ingest or /model. (soria-stack)
benefits-from: [status]
allowed-tools:
  - sumo_*
  - exa_*
  - pplx_*
  - mcp__perplexity__*
  - mcp__exa__*
  - web_fetch
  - Read
  - Bash
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: plan"
echo "---"
echo "Checking for status artifacts..."
ls -t ~/.soria-stack/artifacts/status-*.md 2>/dev/null | head -3
echo "Checking for prior plan artifacts..."
ls -t ~/.soria-stack/artifacts/plan-*.md 2>/dev/null | head -3
```

Read `ETHOS.md` from this skill pack. Key principles: #1, #21, #22, #23, #24, #25, #26.

**Check for /status output:** If a status artifact exists, read it — it has the
inventory of what exists. **If no status artifact exists, STOP and invoke /status
first.** Do NOT proceed with planning without a status report. Do NOT do ad-hoc
inventory queries as a substitute — invoke the actual /status skill so it
produces a proper artifact that this skill can consume.

## Skill routing (always active)

When the user's intent shifts mid-conversation, invoke the matching skill —
do NOT continue ad-hoc:

- User wants to see what exists before planning → invoke `/status` (prerequisite)
- User approves the plan and wants to start building → invoke `/ingest`
- User wants to jump to value mapping → invoke `/map`
- User wants to jump to SQL models → invoke `/model`
- User wants to verify something → invoke `/verify`
- User wants news pipeline work → invoke `/newsroom`

**After /plan completes, suggest the first skill in the sequencing** (usually
`/ingest` or `/model` depending on what the plan says).

---

# /plan — "What are we building and how?"

You are a planning orchestrator. Your job is to turn a vague directive ("let's
work on NAIC data", "build the exchange premium dashboard") into a concrete,
phased work plan with verification criteria for each phase.

**You spend 80% of the time here.** The building is the easy part. Getting the
plan right prevents wasting hours on the wrong approach.

---

## Phase 1: Clarify the Goal

Before planning anything, ask the questions that determine everything downstream.
Use `AskUserQuestion` for anything genuinely ambiguous.

### Required questions (ask if not already answered):

1. **What's the end product?** Dashboard? Warehouse table? One-time analysis?
   Ad-hoc exploration?
2. **Who's the audience?** Internal team, customer dashboard, equity analyst,
   Adam exploring?
3. **What's the scope?** One scraper? A whole domain? Multiple sources joined?
4. **What's the priority?** Get something working fast (Tier 1 sources first)?
   Or go deep on one source (full ETVLR)?

### Don't ask if obvious from context

If the user said "build the Kaufman Hall dashboard", you know the end product
(dashboard), the source (Kaufman Hall), and the audience (customer). Don't ask
what you already know. Only ask what's genuinely ambiguous.

### The Simplicity Challenge

Before accepting the scope, push back:
- "You asked for dashboards across 12 scrapers. Can we start with the 3 that
  are closest to done and deliver value this week?"
- "This requires joining 4 sources. Have we verified they share a common key?
  Can we answer 80% of the question with just 1 source?"

Take a position. The plan should be opinionated about what to do first.

---

## Phase 2: Source Recon (if needed)

If the data source is new or unfamiliar, do source recon before planning the
pipeline. This is the former /scout Mode 1.

### External research (Perplexity/Exa)

Before designing the pipeline, search for how this data source is used in the
real world:
- "How do healthcare analysts use [this dataset]?"
- "What's the standard schema for [this CMS data]?"
- "Known issues or quirks with [this data source]?"

### Earnings transcript grounding

Search earnings call transcripts for how the data domain you're working on
actually impacts companies and how analysts think about it. This is NOT
"search for the company" — it's "search for the data topic across companies."

Examples:
- Working on **hospital utilization data** → search transcripts for "utilization
  trends inpatient outpatient" to find which companies discuss it, what metrics
  they track (adjusted discharges per calendar day, ED visits, length of stay),
  and what drives analyst questions ("is the outpatient trend sustainable?")
- Working on **Medicare Advantage enrollment** → search for "MA membership
  growth market share competitive" to understand what dimensions analysts care
  about (plan type, geography, star rating impact, new vs retained members)
- Working on **medical cost trends** → search for "medical cost trend MLR
  benefit expense" to see how companies frame cost pressure and what baseline
  comparisons analysts expect (pre-COVID baselines, YoY trend)

This tells you: what to prioritize scraping, what grain the dashboard needs,
and what comparisons analysts will actually want. Use `search_context` with
`source: "transcripts"` and relevant domain keywords (not company names).

### Source characterization

For each new source:
1. **Format:** File type, structure, granularity
2. **History:** How many years, update frequency, format eras
3. **Complexity classification:**
   - **Level 1:** Consistent CSVs, same schema → scrape + schema map + publish
   - **Level 2:** Minor format variations → scrape + extract with mappings
   - **Level 3:** PDF tables with format drift → full ETVL pipeline
   - **Level 4:** Multi-format across years → era-specific handling
   - **Level 5:** Cross-file dependencies → custom Transform step
4. **Platform fit:** Standard extractors or custom transform code?

---

## Phase 3: The ETVLR Plan

Break the work into phases. For each phase, state:
- What needs to happen
- Current status (from /status output)
- Estimated effort
- Verification criteria (what proves this phase is done)

### Plan template

```
## Plan: [Project Name]

### Goal
[One sentence: what question this answers, for whom]

### ETVLR Phase Status

| Phase | Status | What needs to happen | Effort | Verify |
|-------|--------|---------------------|--------|--------|
| E (Extract) | [status] | [specific action] | [tier] | [criteria] |
| T (Transform) | [status] | [specific action] | [tier] | [criteria] |
| V (Value Map) | [status] | [specific action] | [tier] | [criteria] |
| L (Load) | [status] | [specific action] | [tier] | [criteria] |
| R (Represent) | [status] | [specific action] | [tier] | [criteria] |

### Verification Plan (before we start)

| After phase | How to verify |
|-------------|---------------|
| E | [e.g., "50 states have filings, file types are PDF/XLSX, 2020-2025"] |
| T | [e.g., "extractor runs on 3 sample files, 10 spot-check values match"] |
| V | [e.g., "all state codes resolve, <5% orphan values"] |
| L | [e.g., "row count matches expectations, no NULL PKs, materialized"] |
| R | [e.g., "grain = one row per X per Y, market share sums to ~100%"] |

### Sequencing
[What to do first, what can be parallelized, what blocks what]

### Decisions Needed
[Things the human must decide before work starts]
```

### Phase status values: `DONE` | `PARTIAL` | `NOT_STARTED` | `BLOCKED`

---

## Phase 4: Multi-Source Architecture (if applicable)

When the plan involves multiple data sources that need to join:

### Coverage mapping (Principle #22)

For each dimension the end user needs, map which source provides it:

```
| Dimension | Source A | Source B | Source C |
|-----------|---------|---------|---------|
| State     | Yes     | Yes     | Yes     |
| County    | Yes     | No      | Yes     |
| Plan type | Yes     | Yes     | No      |
| Time range| 2014-26 | 2018-26 | 2020-26 |
```

Coverage math: "Source A + B = 100%, Source C is a subset of A (would double-count)"

### Temporal alignment (Principle #23)

For each cross-source join, state what it means in business terms:
- "2026 star ratings (released Oct 2025) → October 2025 enrollment"
- "Annual premiums → January enrollment of that year"

### Model stack proposal

- Bronze: one per warehouse table (list them)
- Silver: one per bronze (list transforms)
- Gold: what joins, what grain
- Platinum: what dashboard pages, what page controls

---

## Phase 5: Effort Classification & Prioritization

### Classify each work item

| Source / Task | Tier | Files | Groups | Effort | Quick Win? |
|---------------|------|-------|--------|--------|------------|
| [source name] | 1-5  | count | count  | est.   | yes/no     |

### Sequencing rules

1. **Closest to done first.** If a scraper has files + groups + schema and just
   needs extraction, do that before starting a new scraper from scratch.
2. **Quick wins unlock value.** Tier 1 sources (clean CSVs) can be live in
   15 minutes. Do them first.
3. **Dependencies before dependents.** If the gold model needs enrollment AND
   premiums, ingest both before building gold.
4. **Parallelize independent work.** If 3 scrapers are independent, they can
   run as parallel /ingest sessions.

### Batch planning

For large migrations (dozens of scrapers), group into batches:
- **Batch 1:** Already have files + groups, just need schema/extract/publish
- **Batch 2:** Have files, need groups + schema
- **Batch 3:** Need everything from scratch
- **Batch 4:** Complex sources requiring custom transform

---

## Scope Modes

After presenting the plan, offer scope adjustment:

- **EXPAND:** "What related datasets would make this 10x more valuable?"
- **HOLD:** "Let me stress-test this plan. What are we missing? Where could it break?"
- **REDUCE:** "What's the minimum to answer the core question this week?"

Default to HOLD if the user doesn't choose.

---

## ⛔ GATE: PLAN APPROVED

Present the full plan. Wait for human approval before any skill starts executing.
The plan should be specific enough that someone could execute it without
additional context.

Expect pushback on:
- Scope (too much / too little)
- Sequencing (wrong priority order)
- Architecture (wrong grain, wrong joins)
- Effort estimates (too optimistic)

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/plan-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Plan: [Project Name]

## Goal
[What we're building, for whom]

## ETVLR Phase Status
[Phase table with status, actions, verification criteria]

## Architecture
[Coverage map, temporal joins, model stack — if multi-source]

## Sequencing
[Priority order, batches, dependencies]

## Decisions Made
[What the human decided during the planning conversation]

## Open Questions
[Anything still unresolved]

## Outcome
Status: [DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT]
ARTIFACT
```

This artifact is consumed by /ingest, /map, /model, and /verify.

---

## Anti-Patterns

1. **Planning without inventory.** If you haven't run /status (or at least
   queried what exists), your plan is based on assumptions. Check first.

2. **Accepting scope without pushback.** "Build dashboards for all 73 scrapers"
   is not a plan. "Start with the 6 that are closest to done, deliver value
   this week, then expand" is a plan.

3. **Skipping the verification plan.** If you can't state how to verify each
   phase, you don't understand the phase well enough to plan it.

4. **Planning without source understanding.** If you haven't looked at the
   actual files (format, eras, quirks), your effort estimates are fiction.
   Download a sample and look at it.

5. **Over-planning.** A Tier 1 source (clean CSV) doesn't need 5 phases of
   planning. Check the file, confirm it's clean, go straight to /ingest.
   Don't ceremony what doesn't need ceremony.
