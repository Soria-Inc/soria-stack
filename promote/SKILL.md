---
name: promote
version: 2.0.0
description: |
  Safe path to production. There is no `soria promote` command — promotion
  flows through git + CI. This skill orchestrates the pre-flight checks,
  reviews `soria env diff`, creates the PR via `gh`, waits for CI, and
  runs canary checks via /dashboard-review. Documents `soria revert` as the rollback
  safety net.
  REQUIRES EXPLICIT HUMAN APPROVAL before creating the PR.
  Use when asked to "promote", "push to prod", "deploy this", "make it live".
  Do NOT proactively suggest promotion — wait for the human to ask.
  Do NOT promote just because a pipeline is "done" — done in a dev env is
  not done in prod. The human decides when to promote. (soria-stack)
benefits-from: [verify, dashboard-review]
allowed-tools:
  - Read
  - Bash
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: promote"
echo "---"
echo "Active environment:"
soria env status 2>&1 || echo "  (soria CLI not authed — run /env first)"
echo "---"
echo "Git state:"
git status --short 2>&1 | head -20
echo "---"
echo "Commits ahead of origin/main:"
git log --oneline origin/main..HEAD 2>&1 | head -10
echo "---"
echo "⚠️  PROMOTION — requires human approval before PR creation"
```

**Before proceeding:** Read the `soria env status` output. The active env
type must be `dev` or `preview`, NEVER `prod`. Promotion flows FROM dev TO
prod via PR — you don't run this skill while pointing at prod. If the env
is prod, STOP and tell the user to `/env checkout` a dev branch first.

Read `ETHOS.md`. Key principles: #32 (diff-based promotion), #33 (production
is git + CI, not a command), #34 (soria revert is the safety net),
#35 (don't race the interactive agent).

## Skill routing (always active)

If the user's intent shifts away from promotion, invoke the right skill:

- User wants to fix something before promoting → invoke `/ingest`, `/map`, or `/dive`
- User wants to verify before promoting → invoke `/verify`
- User wants to test the dive in a browser → invoke `/dashboard-review`
- User wants to check what exists → invoke `/status`

**CRITICAL: Do NOT promote anything without this skill.** If you're in another
skill (`/ingest`, `/dive`, `/verify`) and the user says "push this to prod",
invoke `/promote` — do NOT call `gh pr create` directly or push to main.

---

# /promote — "Make it live"

You are a production gatekeeper. Your job is to safely promote dev-env work
to production through git + CI. **You NEVER open a PR without explicit human
approval.** You NEVER suggest promotion proactively.

Production is permanent-ish. Dev environments are safe. The gap between them
is this skill.

---

## The Promotion Flow (Principle #33)

There is no `soria promote` command. Promotion is:

```
1. Pre-flight checklist          (this skill)
2. soria env diff                (review what's changing)
3. git push                      (push the branch to origin)
4. gh pr create                  (open the PR with summary)
5. Human approval on the PR      (required)
6. Merge                         (CI runs dbt run --target prod + frontend deploy)
7. Canary via /dashboard-review             (verify on live prod)
8. (if broken) soria revert      (Principle #34 — the safety net)
```

This skill owns steps 1–5 and step 7. CI owns step 6. `soria revert` owns
step 8 (but this skill documents it).

---

## Pre-flight Checklist

Before opening a PR, verify ALL of these. Present the checklist to the human
and wait for approval.

### 1. What environment are we promoting from?

```bash
soria env list
soria env status
```

Report:
- Active env name (must not be `prod`)
- Worktree path
- Current branch (from `git branch --show-current` in the worktree)
- Commits ahead of `origin/main`

### 2. What's changed — `soria env diff`

```bash
soria env diff
```

This is the authoritative change summary. It shows:
- **Code changes** — commits ahead of main, file diffs
- **Data changes** — new scraper runs, published bronze tables, dbt model
  additions/modifications
- **Unpublished files** — any extracted files that haven't made it to bronze yet

Present the full diff output. Point out anything surprising.

### 3. Has it been verified?

Check for a /verify artifact for this env:
```bash
ls -t ~/.soria-stack/artifacts/verify-*.md 2>/dev/null | head -3
```

If none exists:
```
⚠️  NO VERIFICATION ARTIFACT FOUND

This env has not been verified using /verify.
Recommend running /verify before promoting.

Proceed anyway? [requires explicit "yes"]
```

If a verify artifact exists, show the confidence level, semantic check
pass rate, and any caveats.

### 4. Has it been reviewed?

```bash
ls -t ~/.soria-stack/artifacts/dashboard-review-*.md 2>/dev/null | head -3
```

For dive promotions, `/dashboard-review` should have run against the dev env URL and
confirmed:
- Dual-mode load works (Phase 1 + Phase 2)
- Every filter responds correctly
- MethodologyModal and VerifyModal open with real content
- Data matches the warehouse
- Admin vs customer view split respects ENG-1559

If no dashboard-review artifact:
```
⚠️  NO dashboard review ARTIFACT FOUND

Recommend running /dashboard-review before promoting a dive.

Proceed anyway? [requires explicit "yes"]
```

### 5. dbt tests pass

For dives, run the full dbt test suite against the env:

```bash
cd frontend/src/dives/dbt
dbt test --target dev
```

If any test fails, stop and ask the user whether to proceed (answer should
almost always be no).

### 6. Methodology + verify coverage present (Principles #28, #29)

For each dive being promoted, confirm both:

- **Methodology content is surfaced** — grep the dive component for how
  methodology is wired. The pattern varies (inline, sibling file, DivePageHeader
  prop). If the dive has no methodology content at all, it's a shipping blocker.
- **Verify check rows exist** — query the shared verifications table:

  ```bash
  for marts_model in {list of changed marts models}; do
    soria warehouse query "
    SELECT '${marts_model}' AS model, COUNT(*) AS checks
    FROM soria_duckdb_main.main.verifications
    WHERE model = '${marts_model}'
    "
  done
  ```

  Fewer than ~15 rows per model is a shipping blocker.

### 7. Interactive agent check (Principle #35)

The Modal sandbox interactive agent verifies PRs, replies to comments, and
posts investigations to Linear in real time. Before opening a competing PR,
check for active agent runs using signals you can observe without Linear MCP:

```bash
# 1. PR comments on any open PR for this branch
gh pr list --head $(git branch --show-current) --state open --json number,author,comments

# 2. auto-fix branches matching this branch's ENG-ticket
git branch -r | grep -E "auto-fix/"

# 3. Open PRs from the agent's service account
gh pr list --state open --json number,author,title,headRefName
```

Linear inspection is owned by `/ticket`. If the signals above are ambiguous
and you need a deeper agent-run check, **invoke `/ticket`** to run the
Linear query — `/ticket` knows how to recognize active agent runs and will
either defer or return a clean go-ahead.

If any of those return active work that overlaps with what you're about to
promote, **defer to the agent** — report its state and stop. Don't open a
competing PR. Don't comment on the same Linear ticket. Don't touch files
the agent is actively editing.

### 8. Git working tree is clean

```bash
git status --short
```

If there are ANY uncommitted or untracked files in the worktree, STOP and
tell the user to commit or stash them before promoting. Promotion pushes
commits — anything uncommitted will NOT go through the PR and will silently
diverge from prod.

Exceptions where untracked files are OK:
- `dbt/target/` output (should be gitignored)
- `frontend/public/dbt-docs/` (should be gitignored if auto-generated)
- `.soria-env.json` (per-worktree config)

If the user has legitimate work-in-progress they don't want to promote yet,
they should stash it (`git stash push -u -m "WIP"`) and re-apply after.

### 9. Diff-based promotion awareness (Principle #32)

Promotion computes the diff against the env's `cloned_at` snapshot. An empty
env promoted over prod is a no-op — it will NOT wipe prod. But:

- **New rows** in the env are added to prod
- **Modified rows** (updated_at > cloned_at) replace prod rows
- **Deleted rows** (existed at clone time, missing now) are deleted from prod
- **Untouched rows** are left alone

If the user wants to delete rows from prod, they must explicitly delete them
in the env first. Silent deletions via "I just didn't include those" don't
work under diff-based promotion.

---

## ⛔ GATE: HUMAN APPROVAL REQUIRED

Present the pre-flight checklist results:

```
PROMOTION REQUEST
═════════════════

Environment: prickle-bottle → prod
Branch: medicaid-states-dive
Commits ahead: 7
Changed dives: medicaid-states (new), ma-enrollment (modified)

Code changes:
  7 commits ahead of origin/main
  - feat: medicaid states dive + dbt marts + manifest
  - fix: rollup config for ma-enrollment "Other" row
  - ...

Data changes:
  Scrapers: 1 new run (medicaid, 47 files)
  Warehouse: bronze.medicaid_enrollment (materialized, 456,789 rows)
  dbt:    main_marts.medicaid_states — new model (18,340 rows)
          main_marts.ma_enrollment — unchanged (rebuild)
          verifications seed — +18 rows for medicaid_states model

Verification: PASSED (verify-2026-04-10 — HIGH confidence, 96% checks within bounds)
Review:        PASSED (dashboard-review-2026-04-10 — dual-mode load OK, methodology + verify panels populated)
dbt tests:    47/47 pass
Methodology:  ✅ wired into DivePageHeader for both changed dives
Verify rows:  ✅ 18 medicaid_states checks, 24 ma_enrollment checks
Agent runs:   none active on this branch
Diff mode:    Net new (no deletions)

⚠️  This will:
  1. Open a PR via `gh pr create`
  2. Human must merge the PR manually
  3. CI runs `dbt run --target prod` + frontend deploy on merge
  4. Canary via /dashboard-review on the live prod URL
  5. If broken, `soria revert` is the rollback

Proceed with opening the PR? [requires explicit approval: "yes", "open it", "go ahead"]
```

**Do NOT proceed without explicit approval.** Silence is NOT approval.
Ambiguity is NOT approval.

---

## Executing Promotion

After human approval:

### Step 1: Push the branch

```bash
cd {worktree_path}
git push -u origin HEAD
```

If the push fails (diverged, force needed), STOP. Never force-push to main
or a shared branch. Escalate to the user.

### Step 2: Create the PR

```bash
gh pr create --title "promote: {short description}" --body "$(cat <<'EOF'
## Summary

{1-3 bullet points from soria env diff — what's changing}

## Dives changed

- [new] medicaid-states — {one-line description, link to methodology file}
- [modified] ma-enrollment — {one-line description of change}

## Verification

- /verify: HIGH confidence, {N}/{M} verify checks within bounds
- /dashboard-review: dual-mode load OK, methodology + verify panels surfaced
- dbt test: {X}/{Y} pass
- Verify check rows: {N} per changed marts model

## Data changes

{bullet list from soria env diff, data section}

## Rollback

Use `soria revert` if anything breaks. Do not hand-write DELETE statements
or force-push.

---
Filed from /promote skill. Active env: {env_name}.
EOF
)"
```

Capture the PR URL in the output.

### Step 3: Report

```
PROMOTION PR OPENED
═══════════════════

Env: prickle-bottle → origin/main
Branch: medicaid-states-dive
PR: https://github.com/Soria-Inc/soria-2/pull/{N}

Next steps (human):
  1. Review the PR
  2. Merge when ready
  3. CI will run `dbt run --target prod` + frontend deploy
  4. After CI green, invoke /dashboard-review with --env=prod for canary

If the canary fails: `soria revert` — do NOT manually undo.

Status: DONE (PR opened, human owns merge)
```

### Step 4 (after merge): Canary via /dashboard-review

Once the user reports the PR is merged, invoke `/dashboard-review` against the prod
URL to confirm everything landed correctly. This is the final gate.

If the canary fails, report the failure and suggest `soria revert` — do not
attempt to fix inline.

---

## Rollback (Principle #34)

If promotion breaks something, the safety net is:

```bash
soria revert <SOURCE_ENVIRONMENT>
# example:
soria revert medicaid-states
```

The argument is the **name of the environment/branch** whose promote you
want to undo. From the CLI help:

> Revert a previous promote by deleting its rows from the current branch.
> Run this on a dev branch, then merge the PR to propagate the deletes to prod.

So the revert flow is:
1. Branch from main into a new worktree (`soria env branch revert-medicaid`)
2. Run `soria revert medicaid-states` in that worktree — this deletes the
   rows that the medicaid-states promote added
3. Commit whatever changes the revert wrote
4. `git push && gh pr create` — merge sends the deletes to prod

Do **NOT**:
- Hand-write `DELETE FROM prod.{table}` statements
- Force-push to main to erase the merge commit
- Manually drop tables

The revert command is the authoritative reversal. It understands the
diff-based promotion semantics and will only remove rows that were added
or modified by the specific promote.

`--yes` skips confirmation but you should only use it when you've already
reviewed the changes with a dry-run or a manual `soria env diff`.

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/promote-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Promotion Report: [Branch Name]

## Environment
From: [dev env name]
To: prod

## Changed artifacts
[Dives added/modified, dbt models, data tables]

## Pre-flight checklist
- Verification: [PASSED / NOT VERIFIED / PASSED WITH CONCERNS]
- Review: [PASSED / NOT RUN]
- dbt tests: [N/M pass]
- Modals: [populated / missing for X]
- Agent runs: [none / active on PR #Y]
- Diff mode: [net new / includes deletions / mixed]

## PR
URL: [https://github.com/.../pull/N]

## Canary
[After merge — /dashboard-review results against prod URL]

## Outcome
Status: [DONE | DONE_WITH_CONCERNS | BLOCKED]
Lesson: [What was interesting or unexpected]
ARTIFACT
```

---

## Anti-Patterns

1. **Promoting without being asked.** The AI should NEVER suggest or initiate
   promotion. The human decides when to go to prod.

2. **Calling `gh pr create` or `git push` outside this skill.** All promotion
   goes through /promote. If you're in /ingest or /dive and the user says
   "push to prod", invoke this skill — don't run git commands directly.

3. **Promoting without verification.** If /verify hasn't run, warn loudly.
   Don't just promote because the pipeline "looks done."

4. **Promoting without a dashboard review.** For dives, /dashboard-review is the only way to
   confirm the dual-mode load, modals, and filter behavior work in a real
   browser. Don't skip it.

5. **Force-pushing to roll back.** `soria revert` is the rollback. Never
   force-push to main, never manually drop tables, never hand-write DELETE
   statements.

6. **Racing the interactive agent.** If the Modal sandbox interactive agent
   has an active run on the current branch, defer to it. Don't open a
   competing PR.

7. **Assuming merged = done.** CI runs after merge. Only after CI green
   AND /dashboard-review canary pass against prod URL is the promotion truly done.

8. **Silent deletions.** Diff-based promotion (#32) only deletes rows that
   were explicitly deleted in the env. "Not including a row" does not
   delete it from prod. If the user wants to remove rows from prod, they
   must delete them in the env first.
