---
name: env
version: 1.0.0
description: |
  Manage Soria development environments through the `soria env` CLI.
  Each environment is a git worktree + Neon branch + MotherDuck clone
  bundled under one name. Wraps list, branch (create), checkout, status,
  diff, teardown (soft delete, 7-day grace), and restore.
  Use when asked to "create a dev env", "switch envs", "what am I on",
  "show what's changed", "tear down this branch", "restore my env",
  or "list environments". Run first in every session alongside /tools.
  Read-only for status/list/diff; write ops (branch, teardown, restore)
  ask for confirmation before acting. (soria-stack)
allowed-tools:
  - Read
  - Bash
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: env"
echo "---"
if ! command -v soria >/dev/null 2>&1; then
  echo "ERROR: soria CLI not installed."
  echo "Install from soria-2 repo root: uv tool install --from ./cli soria-cli"
  exit 1
fi
echo "Active environment:"
soria env status 2>&1
echo "---"
echo "All environments:"
soria env list 2>&1 | head -30
echo "---"
echo ".soria-env.json (per-worktree config — read by the MCP proxy on startup):"
cat .soria-env.json 2>/dev/null || echo "  (not set in this worktree)"
```

Read `ETHOS.md`. Key principle: environment awareness is mandatory (CLI-First
Tool Invocation).

## Skill routing (always active)

- User wants pipeline inventory for the current env → invoke `/status`
- User wants to plan work → invoke `/plan`
- User wants to build a pipeline → invoke `/ingest`
- User wants to build a dive → invoke `/dive`
- User wants to promote → invoke `/promote`
- User wants to diagnose a failure → invoke `/diagnose`

---

# /env — "Which sandbox are we in?"

You are the environment manager. Every write-path skill in SoriaStack needs
an active environment, and prod writes need explicit acknowledgment. This
skill wraps the `soria env` CLI subcommands with guardrails.

An environment is three things bundled:
- A **git worktree** (isolated code checkout)
- A **Neon branch** (isolated Postgres database)
- A **MotherDuck clone** (isolated warehouse schemas)

The `soria` CLI manages all three as one unit. Never create them independently.

---

## Operations

### List environments

```bash
soria env list
```

Shows all environments the current user has, with type (dev/preview/prod),
status, and which one is active. Active env is marked with `*`.

Report back as a table:

```
Environments (5 total, 1 active)

| Name              | Type    | Status   | Worktree                          |
|-------------------|---------|----------|-----------------------------------|
| prickle-bottle *  | dev     | active   | ~/.soria/worktrees/prickle-bottle |
| soft-shoe         | dev     | idle     | ~/.soria/worktrees/soft-shoe      |
| pr-742-preview    | preview | building | (remote only)                     |
| prod              | prod    | —        | (remote only)                     |
```

### Show current environment

```bash
soria env status
```

Reports active environment with pipeline state summary: most recent scraper
runs, warehouse freshness, dbt last-run timestamp, any failures.

### Create a new dev environment

```bash
soria env branch              # random name
soria env branch my-feature   # explicit name
```

Creates git worktree + Neon branch + MotherDuck clone. The CLI prints the
worktree path. To actually cd into it, the shell wrapper must be installed
(`soria shell-setup >> ~/.zshrc`).

**Always confirm before creating.** Ask:
- Do you want a random name or something specific?
- Do you want me to `cd` into the new worktree? (Requires shell wrapper.)

After creation, report:
```
Created environment: prickle-bottle
  Worktree:  /Users/you/.soria/worktrees/prickle-bottle
  Neon:      soria-main-prickle-bottle (branched from prod)
  MotherDuck: soria_duckdb__prickle_bottle
Next: cd to the worktree and run `soria env status` to confirm.
```

### Checkout (switch to) an environment

```bash
soria env checkout my-feature
```

Prints the worktree path of the target environment. With the shell wrapper
installed, this acts as a `cd` via `eval`. Without the wrapper, the user
must cd manually.

**Remind the user** if the wrapper isn't set up:
```
soria shell-setup >> ~/.zshrc && source ~/.zshrc
```

### Diff — what changed vs prod

```bash
soria env diff
```

Shows code changes (`git log`) + data changes (Postgres diff, MotherDuck
schema diff, unpublished files) for the current environment against prod.

This is the **primary promotion pre-flight check**. Run it whenever the
user says "what's changed?" or "what am I about to promote?"

Report format:
```
Environment: prickle-bottle → prod

Code changes:
  2 commits ahead of origin/main
  - feat: medicaid states dive + dbt marts + manifest
  - fix: sql model review on stg_medicaid_enrollment

Data changes:
  Scrapers: 1 new run (medicaid, 47 files)
  Warehouse: bronze.medicaid_enrollment (materialized, 456,789 rows)
  dbt: soria_dives.marts.medicaid_enrollment — new model
  Unpublished files: 0

Ready to promote: YES (but run /verify first)
```

### Teardown (soft delete)

```bash
soria env teardown my-feature
```

Soft-deletes an environment with a 7-day grace period. The worktree, Neon
branch, and MotherDuck clone become unreachable but are not destroyed until
the grace period expires.

### ⛔ GATE: teardown confirmation

NEVER run teardown without explicit confirmation. **Before asking**, check
the worktree for uncommitted changes:

```bash
# cd into the worktree of the env being torn down
cd $(soria env checkout {name} 2>/dev/null | tail -1) 2>/dev/null || echo "(cannot locate worktree)"
git status --short
git log --oneline origin/main..HEAD 2>/dev/null | head -10
```

If there are uncommitted changes OR unpushed commits, surface them in the
confirmation:

```
⚠️  Environment: my-feature has UNSAVED WORK

Uncommitted changes (will be PERMANENTLY LOST on teardown):
  M  frontend/src/dives/medicaid-states.tsx
  ?? frontend/src/dives/manifests/medicaid-states.manifest.ts

Unpushed commits (will be lost unless you push first):
  a1b2c3d feat: medicaid states dive + dbt marts

Recommendation: commit + push before teardown, OR cancel and save your work.
```

Then the confirmation:

```
About to teardown environment: my-feature

This will soft-delete:
  Worktree:  /Users/you/.soria/worktrees/my-feature
  Neon:      soria-main-my-feature
  MotherDuck: soria_duckdb__my_feature

7-day grace period — use `soria env restore my-feature` to undo within 7 days.
The worktree and its uncommitted changes are NOT restored by `restore` —
only the Neon branch and MotherDuck clone.

Proceed? [requires explicit "yes" or "teardown it"]
```

### Restore (undo teardown)

```bash
soria env restore my-feature
```

Reverses a teardown within the 7-day grace period. Report success or
explain why it failed (expired, typo, wrong account).

---

## Prod acknowledgment

If the user asks to switch to prod, require acknowledgment:

```
⚠️  You're switching to the PROD environment.

This means:
  - Any write-path skill (/ingest, /map, /dive, /promote) will affect
    production data and customer-facing dashboards
  - Writes are gated per-skill; most skills will refuse prod writes
    unless you explicitly acknowledge again at that skill

Are you sure you want to switch to prod? [requires "yes, prod"]
```

---

## Anti-Patterns

1. **Running teardown without confirmation.** 7-day grace period is not
   an excuse to act without asking. The worktree may have uncommitted work.
2. **Assuming the shell wrapper is installed.** After `soria env checkout`
   or `soria env branch`, always remind the user if they're not in the new
   worktree yet.
3. **Silent prod switches.** Never switch to prod without explicit
   acknowledgment. Never write to prod without re-acknowledging at the
   write-path skill.
4. **Manipulating git worktrees, Neon branches, or MotherDuck clones
   directly.** Always go through `soria env` — those three resources are
   managed as one unit.
5. **Running a write-path skill without confirming env first.** Every
   write-path skill's preamble should check `soria env status`. If the env
   is unset, the skill should refuse to proceed until `/env` is invoked.

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/env-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Environment: [name]

## Action
[list / status / branch / checkout / diff / teardown / restore]

## State
Active: [name]
Type: [dev | preview | prod]
Worktree: [path]
Neon branch: [name]
MotherDuck clone: [name]

## Outcome
Status: [DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT]
ARTIFACT
```
