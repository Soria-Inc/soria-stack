---
name: lessons
version: 4.0.0
description: |
  Data pipeline retrospective — reviews recent pipeline work, identifies patterns
  in what went well and what failed, proposes principle updates to ETHOS.md.
  Reads skill artifacts, searches prior sessions via mempalace, and categorizes
  lessons learned. The continuous improvement loop for SoriaStack.
  Use when asked to "run lessons", "what did we learn", "review recent work",
  "what went wrong", or periodically after a batch of pipeline work. Also use
  when a testing, review, or dev-env lesson affected how Soria work shipped.
  Proactively suggest after completing 3+ Soria sessions without a lessons review. (soria-stack)
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
pivots to active work mid-retro, invoke the right skill:

- User wants to investigate a specific pipeline → invoke `/status`
- User wants to fix something the retro identified → invoke the relevant
  skill (`/ingest`, `/map`, `/dive`, `/verify`) based on what needs fixing
- User wants to plan work based on retro findings → invoke `/plan`
- User wants to fix a testing/review gap → invoke `/test` or `/code-review`
- User wants to fix a branch-local environment/setup gap → invoke `/dev-env`

---

# /lessons — "What did we learn?"

You are running a data pipeline retrospective. Your job is to review recent
work, find patterns in what went well and what failed, and propose improvements
to the team's principles and skills. This is how SoriaStack gets better over
time.

**The core insight:** Every principle in ETHOS.md maps to a session where
the AI violated it and wasted time. New principles should come from the same
source — real sessions, real failures, real corrections.

**Source-of-truth rule:** Lessons that change skill behavior belong in the
canonical `Soria-Inc/soria-stack` repo. Do not leave them stranded in a
branch-local `soria-2` checkout, a generated plugin copy, or a backup under
`~/.claude/skills`. If the current session is not already in the `soria-stack`
repo, locate it before applying approved skill changes.

**Skill edit location rule:** On Adam's machine, edit skills in
`/Users/adamron/.superset/projects/soria-stack`, not directly under
`~/.codex/skills`, `~/.claude/skills`, or app-repo embedded copies. Codex reads
the plugin skill files through symlinks, so existing local `SKILL.md` edits are
live on disk immediately; after GitHub `main` changes, run `git pull` in the
canonical repo. Run `bash install-codex.sh` when adding/removing skills,
changing plugin metadata, or rebuilding `/browse`; use a fresh Codex session if
the update does not appear.

**Routing rule:** Repeated workflow behavior belongs in `soria-stack`.

- repeated test decision -> `soria-stack/test`
- repeated review rule -> `soria-stack/code-review`
- branch dev environment procedure -> `soria-stack/dev-env`
- TP/search runtime helper usage -> `soria-stack/test` or `soria-stack/dev-env`
- executable helper -> app repo `scripts/`

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

For each skill update proposal, identify:
- The target skill (`browse`, `dive`, `ingest`, `verify`, etc.) or the new
  skill name to create
- The evidence that triggered the update
- Whether the change belongs in the Claude-facing skill, the Codex plugin
  wrapper, or both
- Whether any matching lesson is already present in canonical `soria-stack`

Decide whether to update an existing skill or propose a new skill:

- Add to an existing skill when the lesson changes how an existing workflow
  should run, adds a gate, clarifies a known failure mode, or improves a
  trigger description.
- Propose a new skill when the lesson describes a repeatable workflow with its
  own entrypoint, a distinct tool/runtime surface, a separate decision process,
  or a domain that would bloat existing skills.
- Do not create a new skill for one-off context, narrow examples, or guidance
  that belongs as a short rule inside an existing skill.

When proposing a skill change, include the exact target and a reviewable diff:

```text
PROPOSED SKILL CHANGE:
Target: existing skill `<skill>` | new skill `<new-skill>`
Files:
- <skill>/SKILL.md
- plugins/soria-stack/skills/<skill>/SKILL.md

Why this target:
[Why this belongs here instead of another existing skill or a new skill.]

Evidence:
[Session, artifact, screenshot, command output, or user correction.]

Proposed diff:
```diff
[Unified diff or concise patch sketch.]
```
```

For a new skill proposal, include initial frontmatter, the first-pass body,
and which references/scripts/assets it needs. Keep the first version narrow;
prefer a concise `SKILL.md` plus references over a large all-in-one skill.

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
[Each proposal with target existing/new skill, rationale, evidence, and diff]

## MCP Gaps Identified
[`mcp__soria__*` tools skills need that don't exist]

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

1. Locate the canonical `Soria-Inc/soria-stack` checkout. Common local path:
   `/Users/adamron/.superset/projects/soria-stack`. Verify with
   `git remote -v`.
2. Update ETHOS.md with new/refined principles when the lesson is broad.
3. Update relevant SKILL.md files with new gates or anti-patterns.
4. When a skill has both surfaces, update both:
   - Claude-facing: `<skill>/SKILL.md`
   - Codex-facing: `plugins/soria-stack/skills/<skill>/SKILL.md`
5. For new skills, create both the Claude-facing skill directory and the
   Codex-facing wrapper under `plugins/soria-stack/skills/`, unless the skill
   is intentionally Claude-only or Codex-only.
6. Preserve canonical metadata that points at `https://github.com/Soria-Inc/soria-stack`.
   Do not copy repo-local `soria-2` metadata into the canonical skill repo.
7. Review the diff and make sure only approved skill/principle files changed.
8. Commit and push changes with a clear message referencing the retro.

```bash
git add ETHOS.md */SKILL.md plugins/soria-stack/skills/*/SKILL.md
git commit -m "retro: [date range] — [summary of changes]

Evidence from [N] sessions:
- [brief list of what drove each change]"
```

If the lesson was first patched in a branch-local copy, compare that copy
against canonical `soria-stack` and port only the actual lesson. Do not
wholesale overwrite canonical files with embedded copies from another repo.

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/lessons-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Retro Report: [Date Range]

## Sessions Reviewed
[List of artifacts and mempalace hits analyzed]

## Patterns Found
[Categorized findings]

## Changes Applied
[What was actually changed in ETHOS.md and skills]

## Changes Deferred
[What was proposed but not approved, with reasoning]

## MCP Gaps
[`mcp__soria__*` tools skills needed but couldn't call]

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
