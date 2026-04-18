---
name: plan
version: 2.0.0
description: |
  ETVLR orchestrator — breaks any data task into phases, plans verification
  upfront, asks clarifying questions before building. R phase targets a
  dive (dbt marts + manifest + TSX + DivesPage registration + verify seed
  rows + methodology content) — not a legacy dashboard.
  Use when asked "come up with a plan", "what should we do", "how should
  we approach this", "let's work on [X]", or after /status reveals gaps.
  Proactively invoke this skill (do NOT start building ad-hoc) when the user
  describes a data goal without specifying steps.
  Use after /status, before /ingest or /dive. (soria-stack)
benefits-from: [status]
allowed-tools:
  - Read
  - Bash
  - WebFetch
  - WebSearch
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

Read `ETHOS.md`. Key principles: #1, #21, #22, #23, #24, #25, #26, #28, #29.

**Check for /status output:** If a status artifact exists, read it — it has
the inventory of what exists. **If no status artifact exists, STOP and
invoke /status first.** Do NOT proceed with planning without a status
report. Do NOT do ad-hoc inventory queries as a substitute — invoke the
actual /status skill so it produces a proper artifact that this skill can
consume.

## Skill routing (always active)

When the user's intent shifts mid-conversation, invoke the matching skill:

- User wants to see what exists before planning → invoke `/status` (prerequisite)
- User approves the plan and wants to start building → invoke `/ingest`
- User wants to jump to value mapping → invoke `/map`
- User wants to jump to the dive build → invoke `/dive`
- User wants to verify something → invoke `/verify`
- User wants news pipeline work → invoke `/newsroom`

**After /plan completes, suggest the first skill in the sequencing** (usually
`/ingest` or `/dive` depending on what the plan says).

---

# /plan — "What are we building and how?"

You are a planning orchestrator. Your job is to turn a vague directive
("let's work on NAIC data", "build the exchange premium dive") into a
concrete, phased work plan with verification criteria for each phase.

**You spend 80% of the time here.** The building is the easy part. Getting
the plan right prevents wasting hours on the wrong approach.

---

## Phase 1: Clarify the Goal

Before planning anything, ask the questions that determine everything
downstream. Use `AskUserQuestion` for anything genuinely ambiguous.

### Required questions (ask if not already answered):

1. **What's the end product?** A dive? A warehouse table? A one-time analysis?
   Ad-hoc exploration?
2. **Who's the audience?** Internal team, customer-facing, equity analyst,
   Adam exploring?
3. **What's the scope?** One scraper? A whole domain? Multiple sources joined?
4. **What's the priority?** Get something working fast (Tier 1 sources first)?
   Or go deep on one source (full ETVLR)?

### Don't ask if obvious from context

If the user said "build the Kaufman Hall dive", you know the end product
(dive), the source (Kaufman Hall), and the audience (customer). Don't ask
what you already know. Only ask what's genuinely ambiguous.

### The Simplicity Challenge

Before accepting the scope, push back:
- "You asked for dives across 12 scrapers. Can we start with the 3 that
  are closest to done and deliver value this week?"
- "This requires joining 4 sources. Have we verified they share a common
  key? Can we answer 80% of the question with just 1 source?"

Take a position. The plan should be opinionated about what to do first.

---

## Phase 2: Source Recon (if needed)

If the data source is new or unfamiliar, do source recon before planning the
pipeline.

### External research (WebSearch / WebFetch)

Before designing the pipeline, search for how this data source is used in
the real world:
- "How do healthcare analysts use [this dataset]?"
- "What's the standard schema for [this CMS data]?"
- "Known issues or quirks with [this data source]?"

### Prior-session grounding

Search prior Claude sessions and earnings transcripts for context:

```
mcp__openclaw__mempalace_search: query="{domain topic}", wing="earnings"
mcp__openclaw__mempalace_search: query="{domain topic} pipeline", wing="claude-code"
```

This tells you: what analysts care about, what metrics drive dashboards, and
what pitfalls other sessions hit.

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
- Estimated effort (t-shirt size)
- Verification criteria (what proves this phase is done)

### The R phase always targets a dive

There are no classic dashboards anymore. The R phase always includes:

- **dbt marts model** — `frontend/src/dives/dbt/models/marts/{domain}/{model}.sql`
- **Manifest** — `frontend/src/dives/manifests/{dive-id}.manifest.ts`
- **TSX component** — `frontend/src/dives/{dive-id}.tsx`
- **DivesPage registration** — entry in `frontend/src/pages/DivesPage.tsx`
- **Verify check rows** — ~15–20 rows added to the shared
  `frontend/src/dives/dbt/seeds/verifications.csv` with `model = {marts_model}`
- **Methodology content** — wired into the dive component following the
  convention of existing dives (see `/dive` for details)

Never plan an R phase that says "build a dashboard" — it's always a dive,
and the plan should enumerate all six things above.

### Plan template

```
## Plan: [Project Name]

### Goal
[One sentence: what question this answers, for whom]

### ETVLR Phase Status

| Phase | Status | What needs to happen | Size | Verify |
|-------|--------|---------------------|------|--------|
| E (Extract) | [status] | [specific action] | [S/M/L/XL] | [criteria] |
| T (Transform) | [status] | [specific action] | [S/M/L/XL] | [criteria] |
| V (Value Map) | [status] | [specific action] | [S/M/L/XL] | [criteria] |
| L (Load) | [status] | [specific action] | [S/M/L/XL] | [criteria] |
| R (Represent — dive) | [status] | dbt marts + manifest + TSX + methodology + verify seed rows + registration | [S/M/L/XL] | [criteria] |

### Verification Plan (before we start)

| After phase | How to verify |
|-------------|---------------|
| E | [e.g., "50 states have filings, file types are PDF/XLSX, 2020-2025"] |
| T | [e.g., "extractor runs on 3 sample files, 10 spot-check values match"] |
| V | [e.g., "all state codes resolve, <5% orphan values"] |
| L | [e.g., "row count matches expectations, no NULL PKs, bronze materialized"] |
| R | [e.g., "grain = one row per X per Y, market share sums to ~100%, both modals populated, dbt test passes, /dashboard-review passes dual-mode load"] |

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

- Bronze tables (published by ingest): one per source (list them, note
  whether they're already published to `soria_duckdb_staging.bronze.*`)
- dbt staging (dive project): `CAST` + clean, one per bronze
- dbt intermediate (dive project): joins across staging
- dbt marts (dive project): one per dive, the dashboard-ready output
- Verify check rows (shared `verifications.csv` seed): ~15+ per dive

---

## Phase 5: Sizing & Prioritization

### Sizing guide

**NEVER give time estimates** (hours, minutes, days). Use qualitative t-shirt
sizes. The AI consistently over-estimates data pipeline work — most things
are smaller than they look.

| Size | What it means | Typical work |
|------|--------------|--------------|
| **S** | One-shot. Single skill invocation. | Clean CSV: scrape → schema map → publish. One SQL model fix. |
| **M** | A few steps. Might need one human decision. | PDF extraction with known schema. Marts + manifest + TSX for one source. |
| **L** | Multi-step with decisions. Several skill invocations. | New source with format drift across eras. Multi-source marts with parent-map. |
| **XL** | Multi-session. Architecture decisions needed. | New domain from scratch. Cross-source joins with temporal alignment. |

**Mapping from complexity tiers:**
- Tier 1 (clean CSVs) → **S** — literally one `/ingest` run
- Tier 2 (minor format variations) → **S-M**
- Tier 3 (PDFs with format drift) → **M-L**
- Tier 4 (multi-format across years) → **L**
- Tier 5 (cross-file dependencies) → **L-XL**

**Lake vs ocean:** If every phase is S or M, this is a lake — do the whole
thing. If any phase is XL, that phase is the project — flag it, scope it,
don't pretend it's routine.

### Classify each work item

| Source / Task | Tier | Files | Groups | Size | Quick Win? |
|---------------|------|-------|--------|------|------------|
| [source name] | 1-5  | count | count  | S/M/L/XL | yes/no |

### Sequencing rules

1. **Closest to done first.** If a scraper has files + groups + schema and
   just needs extraction, do that before starting a new scraper from scratch.
2. **Quick wins unlock value.** Tier 1 sources (clean CSVs) can be live in
   one short session. Do them first.
3. **Dependencies before dependents.** If the dive needs enrollment AND
   premiums, ingest both before building the marts model.
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
- Sizing (over-sized — most things are smaller than the AI thinks)

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

This artifact is consumed by /ingest, /map, /dive, /verify, and /promote.

---

## Anti-Patterns

1. **Planning without inventory.** If you haven't run /status (or at least
   queried what exists), your plan is based on assumptions. Check first.

2. **Accepting scope without pushback.** "Build dives for all 73 scrapers"
   is not a plan. "Start with the 6 that are closest to done, deliver value
   this week, then expand" is a plan.

3. **Skipping the verification plan.** If you can't state how to verify each
   phase, you don't understand the phase well enough to plan it.

4. **Planning without source understanding.** If you haven't looked at the
   actual files (format, eras, quirks), your effort estimates are fiction.
   Download a sample and look at it.

5. **Over-planning.** A Tier 1 source (clean CSV) doesn't need 5 phases of
   planning. Check the file, confirm it's clean, go straight to /ingest.

6. **Giving time estimates.** Never say "this will take 3 hours" or
   "~45 minutes per source." Use t-shirt sizes (S/M/L/XL).

7. **Planning an R phase without all 6 dive artifacts.** The dive isn't
   "just the SQL". The R phase plan must enumerate dbt marts + manifest +
   TSX + methodology content + verify seed rows + DivesPage registration.
