---
name: ticket
version: 2.0.0
description: |
  File a structured Linear ticket from a pipeline session. Captures context
  from what just happened — errors, workarounds, tool failures — so the ticket
  has enough for an engineer to act on without re-discovering the problem.
  Use when you hit a bug, find unexpected behavior, need a feature, or discover
  work you didn't expect. Can be invoked mid-session from any skill.
  Proactively suggest this skill (do NOT file ad-hoc) when the user says
  "file a ticket", "this needs a ticket", "make an issue for this", or when
  /diagnose disposition is Ticket. (soria-stack)
allowed-tools:
  - mcp__linear__*
  - mcp__openclaw__mempalace_search
  - Read
  - Bash
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: ticket"
echo "---"
echo "Active environment:"
soria env status 2>&1 || echo "  (soria CLI not authed — read-only skill, continue)"
echo "---"
echo "Recent ticket artifacts:"
ls -t ~/.soria-stack/artifacts/ticket-*.md 2>/dev/null | head -3 || echo "  (none)"
```

Read `ETHOS.md` from this skill pack. Key principle: unexpected work → ticket → keep moving.

## Skill routing (always active)

/ticket is a side-quest — it should be fast and return the user to their flow:

- After filing, suggest returning to the skill they came from
- If the user wants to fix the issue now → invoke `/diagnose` or `/ingest`
- If the user wants to check related pipeline state → invoke `/status`

---

# /ticket — "File this before I forget"

You are a ticket writer. Your job is to capture enough context that an engineer
can act on this issue without re-discovering it. **Context over format.**
A ticket with real repro steps and root cause hints is worth ten with perfect markdown.

**This skill owns all Linear writes.** Other skills (like `/diagnose`) invoke
`/ticket` rather than calling `mcp__linear__save_issue` directly. That keeps
Linear credentials contained to one skill and makes ticket quality consistent.

---

## Step 1: Gather Context

Before writing anything, collect what you know. Most of this is already
in the conversation — don't ask the user to repeat it.

### From the current session
- **What happened?** The error, unexpected behavior, or missing capability.
- **What was the user trying to do?** The pipeline stage, CLI invocation, and parameters.
- **What was the workaround?** If they found one, capture it.
- **What's the root cause hypothesis?** If `/diagnose` ran, use its findings.
- **Active environment?** Include the output of `soria env status` — which
  env the bug was seen in matters for reproduction.

### From Linear (required — always check)
```
mcp__linear__list_issues(
  team="Engineering",
  query="{keywords from the issue}",
  limit=10
)
```

Check for:
- **Exact duplicate** → STOP. Tell the user. Offer to add a comment with fresh context instead.
- **Related open ticket** → Note it. Will link in the description.
- **Closed ticket, same bug** → Flag as regression. New ticket, reference the old one.

Also check for **active interactive agent runs** — if the Modal sandbox
interactive agent is already investigating this issue, defer to it:

```
mcp__linear__list_issues(
  team="Engineering",
  state="in_progress",
  limit=20
)
# Scan results for auto-fix / agent labels
```

If the agent is on it, STOP filing and tell the user — don't create a
competing ticket.

### From mempalace (when useful)
If the issue feels familiar — "I've seen this before" — check:
```
mcp__openclaw__mempalace_search(
  query="{description of the problem}",
  room="problem",
  n_results=5
)
```

Prior session context can reveal: how many times this has been hit, prior
workarounds, whether it was supposed to be fixed.

---

## Step 2: Classify

| Type | Signal | Priority default |
|------|--------|-----------------|
| **CLI bug** | `soria` CLI returns wrong result, crashes, or silently fails | P2 (High) |
| **Data quality** | Extraction/mapping produces wrong values | P2 (High) |
| **Silent failure** | Command says OK but nothing happened | P2 (High) |
| **Dive breakage** | Dive won't load, shows NaN, WASM stuck, manifest drift | P2 (High) |
| **Missing feature** | Can't do X, need Y | P3 (Normal) |
| **Performance** | Slow, timeout, cold start | P3 (Normal) |
| **Schema mismatch** | Column/table doesn't exist where expected | P3 (Normal) |
| **Infrastructure** | Neon/MotherDuck/DBOS Cloud/Cloudflare Workers issues | P2-P3 |
| **DX papercut** | Confusing error message, bad default, missing docs | P4 (Low) |

Tell the user: "This looks like a **CLI bug** — I'll file it as P2 High."
Let them override before filing.

---

## Step 3: Write the Ticket

### Scale depth to severity

**P1-P2 (Urgent/High) — full treatment:**

```
## Bug

[1-2 sentences: what's broken and what it affects]

## Environment

Active env: [from soria env status]
soria CLI version: [soria --version]

## Reproduction

1. [Exact CLI invocation or sequence that triggers the issue]
2. [Parameters used]
3. [What was returned — quote the actual error or misleading response]

## Expected

[What should happen]

## Actual

[What happens instead]

## Root Cause (if known)

[What /diagnose found, or best hypothesis with evidence]

## Workaround

[Current workaround if one exists, or "None — blocks pipeline work"]

## Context

[Why this matters — what pipeline work was blocked, how many sessions
have hit this, related tickets]

---
_Filed from /ticket skill during Claude Code session_
```

**P3-P4 (Normal/Low) — concise:**

```
## What

[1-2 sentences: the issue or request]

## Context

[When this comes up, what the workaround is, why it matters]

## Done when

- [ ] [Concrete acceptance criteria]

---
_Filed from /ticket skill during Claude Code session_
```

---

## Step 4: File It

```
mcp__linear__save_issue(
  title="[component]: short description",
  team="Engineering",
  description="...",
  priority={1-4},
  labels=[{matching labels}]
)
```

**Title conventions:**
- `[soria CLI]: env diff doesn't detect data changes in bronze`
- `[Extraction]: LLM truncates output on PDFs > 20 pages`
- `[Warehouse]: soria warehouse materialize silently no-ops on VIEW/TABLE conflict`
- `[Dive]: manifest filter values out of sync with marts data`
- `[DBOS Cloud]: PG wire protocol 30s timeout on complex dive queries`
- `[Event relay]: Durable Object drops notify events under load`

**After filing:**
- Report the issue ID (e.g., `ENG-1500`) to the user
- If a related ticket was found, link them

---

## Step 5: Artifact & Return

```bash
cat > ~/.soria-stack/artifacts/ticket-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Ticket Filed: [ISSUE-ID] — [Title]

Environment: [active soria env]
Type: [CLI bug | Data quality | Silent failure | Dive breakage | Feature | Performance | Schema | Infrastructure | DX]
Priority: [P1-P4]
Related: [linked ticket IDs or "none"]
Duplicate check: [CLEAR | DUPLICATE OF XXX | REGRESSION OF XXX | AGENT ALREADY HANDLING]

## What was filed
[1-2 sentence summary]

## Outcome
Status: DONE
ARTIFACT
```

Then: "Ticket filed. Back to /[previous skill]?"

---

## Anti-Patterns

1. **Filing without checking Linear first.** Always search for duplicates.
   Creating the 3rd ticket for the same bug wastes everyone's time.

2. **Asking the user to describe the problem.** You were there. The error,
   the CLI invocation, the parameters — it's all in the conversation. Capture
   it yourself, then confirm with the user.

3. **Over-formatting a P4.** A low-priority DX papercut doesn't need
   reproduction steps and root cause analysis. Scale depth to severity.

4. **Filing and forgetting.** Always produce the artifact — it's how /lessons
   picks up ticket patterns later.

5. **Blocking the user's flow.** /ticket should take < 2 minutes. Gather,
   classify, write, file, return. Don't turn a quick ticket into a
   20-minute investigation — that's /diagnose's job.

6. **Using vague titles.** "[soria]: thing is broken" is useless.
   Name the specific command/component and the specific behavior.

7. **Racing the interactive agent.** If the Modal sandbox interactive agent
   is already investigating this issue (active Linear run with agent/auto-fix
   label), defer to it. Don't file a competing ticket.

8. **Filing tickets for things the CLI doesn't yet expose.** If a skill
   needs a `soria` command that doesn't exist, that's a CLI gap — file it,
   but classify as "Missing feature" P3, not "CLI bug".
