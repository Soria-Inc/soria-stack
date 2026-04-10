---
name: lessons
version: 4.0.0
description: |
  Data pipeline retrospective — reviews recent pipeline work, identifies patterns
  in what went well and what failed, proposes principle updates to ETHOS.md.
  Reads skill artifacts, searches prior sessions via mempalace, and categorizes
  lessons learned. The continuous improvement loop for SoriaStack.
  Use when asked to "run lessons", "what did we learn", "review recent work",
  "what went wrong", or periodically after a batch of pipeline work.
  Proactively suggest after completing 3+ pipeline sessions without a lessons review. (soria-stack)
allowed-tools:
  - Read
  - Bash
  - Write
  - ToolSearch
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: lessons"
echo "---"
echo "Active environment:"
soria env status 2>&1 || echo "  (soria CLI not authed — read-only skill, continue)"
echo "---"
echo "Recent artifacts (last 20):"
ls -t ~/.soria-stack/artifacts/*.md 2>/dev/null | head -20
echo "---"
echo "Artifact count by skill:"
ls ~/.soria-stack/artifacts/ 2>/dev/null | sed 's/-[0-9].*$//' | sort | uniq -c | sort -rn
```

**Load mempalace search** — this skill relies on
`mcp__openclaw__mempalace_search` which is a deferred tool at session start.
If it hasn't been loaded yet in this session, load its schema now via
ToolSearch before running Phase 1:

```
ToolSearch: "select:mcp__openclaw__mempalace_search"
```

Read `ETHOS.md`. This skill exists to keep ETHOS.md accurate and current.

## Skill routing (always active)

/lessons is a periodic skill, not part of the main ETVLR chain. If the user
pivots to active pipeline work mid-retro, invoke the right skill:

- User wants to investigate a specific pipeline → invoke `/status`
- User wants to fix something the retro identified → invoke the relevant
  skill (`/ingest`, `/map`, `/dive`, `/verify`) based on what needs fixing
- User wants to plan work based on retro findings → invoke `/plan`

---

# /lessons — "What did we learn?"

You are running a data pipeline retrospective. Your job is to review recent
work, find patterns, and propose improvements to the team's principles and
skills. This is how SoriaStack gets better over time.

**The core insight:** Every principle in ETHOS.md maps to a session where
the AI violated it and wasted time. New principles should come from the same
source — real sessions, real failures, real corrections.

---

## Phase 1: Gather Evidence

Three sources of evidence, in order of reliability:

### Source A: Skill Artifacts

Read all recent artifacts from `~/.soria-stack/artifacts/`. Each artifact has:
- Which skill ran
- What was built
- What gates were passed
- Completion status (DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT)
- Lessons learned (if the skill logged them)

```bash
find ~/.soria-stack/artifacts/ -name "*.md" -mtime -14 -exec cat {} \;
```

Categorize each artifact:
- **Clean run** — all gates passed, DONE status
- **Course correction** — human pushed back at a gate, AI adjusted
- **Failure** — BLOCKED or significant issues found
- **Near miss** — verification caught something that would have been bad

### Source B: Prior Session Transcripts (mempalace)

Search for recent data pipeline sessions:

```
mcp__openclaw__mempalace_search: query="pipeline extraction dive marts", wing="claude-code", n_results=15
mcp__openclaw__mempalace_search: query="diagnose silent failure", wing="claude-code", n_results=10
mcp__openclaw__mempalace_search: query="manifest drift", wing="claude-code", n_results=5
```

Look for:
- Moments where the human corrected the AI ("no, don't do that", "that's wrong", "simplify this")
- Repeated patterns (the same type of error happening across sessions)
- Time wasted on approaches that didn't work
- Insights that aren't yet captured in ETHOS.md

### Source C: Meetings / Decisions

Search for relevant meeting context:

```
mcp__openclaw__mempalace_search: query="{domain topic}", wing="granola", n_results=5
```

Look for:
- Decisions made in conversation that should be principles
- Complaints about data quality or pipeline behavior
- Requests that revealed gaps in the current skills

---

## Phase 2: Analyze Patterns

Group findings into categories:

### What Went Well
- Which principles prevented errors? (e.g., "Test on 3 caught a format change")
- Which gates caught issues? (e.g., "Gate 2 schema review — human caught a derivable column")
- What skills worked as designed?

### What Failed
- Where did the AI go wrong despite having the principles?
- What types of errors recurred?
- Where did humans have to intervene repeatedly?

### What's Missing
- Were there situations where no principle applied?
- Were there judgment calls that the AI made poorly?
- Are there patterns from recent sessions that should be codified?

### Metrics (if artifacts have enough data)

| Metric | Value | Trend |
|--------|-------|-------|
| Pipelines completed | N | — |
| Clean runs (no course corrections) | N (%) | — |
| Gate that caught most issues | Gate N | — |
| Most common correction type | [type] | — |
| Verification tier that found issues | Tier N | — |
| Dive failures by category (manifest drift, modal missing, dbt test fail) | counts | — |

---

## Phase 3: Propose Updates

Based on the analysis, propose concrete changes:

### ETHOS.md Updates
- **New principles** — patterns from real sessions that should be codified
- **Refined principles** — existing principles that need clarification
- **Deprecated patterns** — principles that no longer apply

Format proposals as:
```
PROPOSED ADDITION to ETHOS.md:

### N. [Principle name]
[Principle text]

Evidence: [Which session(s) this came from]
Would have prevented: [What specific error this addresses]
```

### Skill Updates
- **New gates needed** — places where the AI should stop but doesn't
- **Gates to soften** — places where the AI stops unnecessarily
- **New anti-patterns** — failure modes to document
- **Description refinements** — better resolver triggers
- **CLI surface gaps** — commands skills need that don't exist in `soria` yet

### Open Questions
- Decisions that came up in sessions but weren't resolved
- Patterns that might be principles but need more evidence
- Areas where the team disagrees

---

## Phase 4: Present & Decide

Present the retro as a structured report:

```
RETRO REPORT: [Date Range]
═══════════════════════════════════════

## Summary
[N pipelines, M sessions, key numbers]

## Highlights
[What went well — be specific]

## Issues
[What failed or needed correction — with evidence]

## Proposed ETHOS.md Changes
[Each proposal with evidence and reasoning]

## Proposed Skill Changes
[Each proposal with evidence]

## CLI Gaps Identified
[soria CLI commands skills need that don't exist]

## Open Questions
[Unresolved decisions for the team]
```

### ⛔ GATE: RETRO REVIEW
Present the report. Do NOT auto-commit any changes to ETHOS.md or skill files.
Wait for the human to approve specific proposals. Some proposals may be
rejected or modified — that's the point.

---

## Phase 5: Apply Approved Changes

After the human approves specific proposals:

1. Update ETHOS.md with new/refined principles
2. Update relevant SKILL.md files with new gates or anti-patterns
3. Commit changes with clear message referencing the retro

```bash
git add ETHOS.md */SKILL.md
git commit -m "retro: [date range] — [summary of changes]

Evidence from [N] sessions:
- [brief list of what drove each change]"
```

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/lessons-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Retro Report: [Date Range]

## Environment
[Active soria env]

## Sessions Reviewed
[List of artifacts and mempalace hits analyzed]

## Patterns Found
[Categorized findings]

## Changes Applied
[What was actually changed in ETHOS.md and skills]

## Changes Deferred
[What was proposed but not approved, with reasoning]

## CLI Gaps
[soria commands skills needed but couldn't call]

## Outcome
Status: DONE
ARTIFACT
```

---

## Anti-Patterns

1. **Running retro without evidence.** Don't philosophize about what might
   go wrong. Use real artifacts and real session transcripts.

2. **Proposing principles from one incident.** One failure isn't a pattern.
   Wait for 2-3 instances before proposing a new principle. Flag it as
   "emerging pattern" instead.

3. **Auto-committing changes.** The retro proposes. The human decides. Always.

4. **Ignoring what went well.** Principles that prevented errors are just as
   important to document as new failures. They validate the system is working.

5. **Ignoring CLI surface gaps.** If skills keep needing a `soria` command
   that doesn't exist, that's a signal for the CLI team. Surface it in the
   retro so it becomes a ticket.
