---
name: promote
version: 3.0.0
description: |
  Safe path to production. There is no promote command — promotion flows
  through `mcp__soria__warehouse_diff` + `mcp__soria__warehouse_promote`
  (posts the file-level manifest on a PR) + `git push` + `gh pr create`,
  with CI handling the actual materialization (`dbt-deploy.yml` for marts,
  `promote.yml` for bronze files) on merge. Rollback is `git revert` the
  PR, or flip `deleted_at` via `mcp__soria__database_mutate` for Postgres
  state.
  REQUIRES EXPLICIT HUMAN APPROVAL before opening the PR.
  Use when asked to "promote", "push to prod", "deploy this", "make it live".
  Do NOT proactively suggest promotion — wait for the human to ask.
  Done in staging is not done in prod. The human decides when to promote.
  (soria-stack)
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
echo "Git state:"
git status --short 2>&1 | head -20
echo "---"
echo "Commits ahead of origin/main:"
git log --oneline origin/main..HEAD 2>&1 | head -10
echo "---"
echo "⚠️  PROMOTION — requires human approval before PR creation"
```

Read `ETHOS.md`. Key principles: #32 (file-level promotion), #33
(production is git + CI, not a command), #34 (rollback is git revert or a
soft-delete flip), #35 (don't race the interactive agent).

## Skill routing (always active)

If the user's intent shifts away from promotion, invoke the right skill:

- User wants to fix something before promoting → invoke `/ingest`, `/map`, or `/dive`
- User wants to verify before promoting → invoke `/verify`
- User wants to test the dive in a browser → invoke `/dashboard-review`
- User wants to check what exists → invoke `/status`

**CRITICAL: Do NOT promote anything without this skill.** If you're in another
skill (`/ingest`, `/dive`, `/verify`) and the user says "push this to prod",
invoke `/promote` — do NOT call `gh pr create` or push directly.

---

# /promote — "Make it live"

You are a production gatekeeper. Your job is to safely promote local work
to production through git + CI. **You NEVER open a PR without explicit
human approval.** You NEVER suggest promotion proactively.

Production is permanent-ish. The shared staging environment is safe
(everything is reversible). The gap between them is this skill.

---

## The Promotion Flow (Principle #33)

There is no promote command. Promotion is:

```
1. Pre-flight checklist              (this skill)
2. mcp__soria__warehouse_diff        (what bronze differs vs prod)
3. git push                          (push the branch to origin)
4. gh pr create                      (open the PR with summary)
5. mcp__soria__warehouse_promote     (post file-level YAML manifest on PR)
6. Human approval + merge            (required)
7. CI on merge:
     - .github/workflows/dbt-deploy.yml  — dbt run --target prod → soria_duckdb_main
     - .github/workflows/promote.yml     — reads manifest, copies bronze files staging→prod
8. Canary via /dashboard-review against https://soriaanalytics.com
9. (if broken) git revert the PR + merge the revert
```

This skill owns steps 1–5 and step 8. CI owns step 7. Rollback is
`git revert`.

---

## Pre-flight Checklist

Before opening a PR, verify ALL of these. Present the checklist to the
human and wait for approval.

### 1. Git working tree is clean

```bash
git status --short
git log --oneline origin/main..HEAD
```

If there are ANY uncommitted files, STOP and tell the user to commit or
stash them — the PR only carries committed changes.

### 2. What bronze is changing — `warehouse_diff`

```
mcp__soria__warehouse_diff()
```

Shows, at `_file_id` grain, which bronze rows exist in
`soria_duckdb_staging` but not `soria_duckdb_main` (and vice versa).
Report the full output. If a large number of files will sync, point that
out — the CI run will take longer.

### 3. What marts are changing — git diff

```bash
git diff origin/main...HEAD -- frontend/src/dives/dbt/models/marts/ frontend/src/dives/dbt/seeds/verifications.csv
```

Every changed marts `.sql` will be rerun on prod MotherDuck by the
`dbt-deploy.yml` workflow. Every new verifications row lands in prod on
merge via `dbt seed`.

### 4. What dive components are changing — git diff

```bash
git diff origin/main...HEAD -- frontend/src/dives/
```

React/TSX changes ship via Cloudflare Pages on push to main. Flag any
manifest or `DivesPage.tsx` changes.

### 5. Has it been verified?

```bash
ls -t ~/.soria-stack/artifacts/verify-*.md 2>/dev/null | head -3
```

If none:

```
⚠️  NO VERIFICATION ARTIFACT FOUND

This change has not been verified using /verify.
Recommend running /verify before promoting.

Proceed anyway? [requires explicit "yes"]
```

If a verify artifact exists, show confidence level, check pass rate, and
any caveats.

### 6. Has it been reviewed?

```bash
ls -t ~/.soria-stack/artifacts/dashboard-review-*.md 2>/dev/null | head -3
```

For dive changes, `/dashboard-review` should have run against
`https://dev.soriaanalytics.com` and confirmed:
- Dual-mode load works (Phase 1 Postgres proxy + Phase 2 WASM)
- Every filter responds correctly
- `MethodologyModal` and `VerifyModal` open with real content
- Cell values match the warehouse
- No console or network errors

If no artifact, warn and require explicit approval to proceed.

### 7. dbt tests pass

```bash
cd frontend/src/dives/dbt && ../../../../.venv/bin/dbt test
```

If any test fails, stop and ask whether to proceed (answer should almost
always be no).

### 8. Methodology + verify coverage (Principles #28, #29)

For each dive being promoted:

- **Methodology content is surfaced.** Grep the dive component for how
  methodology is wired (inline, sibling file, `DivePageHeader` prop).
  Missing methodology = shipping blocker.
- **Verify check rows exist.** Query the verifications seed:

  ```
  mcp__soria__warehouse_query(sql="
    SELECT model, COUNT(*) AS checks
    FROM soria_duckdb_staging.main.verifications
    WHERE model IN ('{changed_marts_models}')
    GROUP BY model
  ")
  ```

  Fewer than ~15 rows per model is a shipping blocker.

### 9. Interactive agent check (Principle #35)

```bash
gh pr list --head $(git branch --show-current) --state open --json number,author,comments
git branch -r | grep -E "auto-fix/"
gh pr list --state open --json number,author,title,headRefName
```

If the Modal sandbox interactive agent has an active run overlapping this
change, **defer to it** — don't open a competing PR. If signals are
ambiguous, invoke `/ticket` to run the Linear query and decide.

---

## ⛔ GATE: HUMAN APPROVAL REQUIRED

Present the pre-flight checklist results:

```
PROMOTION REQUEST
═════════════════

Branch: medicaid-states-dive
Commits ahead of origin/main: 7

Code changes:
  7 commits
  - feat: medicaid states dive + dbt marts + manifest
  - fix: rollup config for ma-enrollment "Other" row
  ...

Bronze (file-level diff):
  medicaid_enrollment — 47 new _file_ids in staging (not yet in prod)

Marts (dbt):
  marts/medicaid/medicaid_state_enrollment.sql — new
  marts/medicare_advantage/ma_enrollment_dashboard.sql — modified

Seeds:
  verifications.csv — +18 rows for medicaid_state_enrollment

Dive components:
  frontend/src/dives/medicaid-states.tsx — new
  frontend/src/dives/ma-enrollment.tsx — modified

Verification: PASSED (verify-2026-04-10 — HIGH confidence, 96% within bounds)
Review:       PASSED (dashboard-review-2026-04-10 — dual-mode OK, modals OK)
dbt tests:    47/47 pass
Methodology:  ✅ wired for both dives
Verify rows:  ✅ 18 medicaid, 24 ma_enrollment
Agent runs:   none active on this branch

⚠️  This will:
  1. git push the branch
  2. gh pr create
  3. mcp__soria__warehouse_promote posts the file-level manifest on the PR
  4. Human reviews + merges
  5. CI on merge:
       - dbt-deploy.yml → dbt run --target prod → soria_duckdb_main
       - promote.yml → copies 47 bronze files staging → prod
  6. Canary via /dashboard-review on https://soriaanalytics.com

Proceed with opening the PR? [requires explicit approval: "yes", "go ahead"]
```

**Do NOT proceed without explicit approval.** Silence is NOT approval.

---

## Executing Promotion

### Step 1: Push the branch

```bash
git push -u origin HEAD
```

If the push fails (diverged, force needed), STOP. Never force-push.

### Step 2: Create the PR

```bash
gh pr create --title "promote: {short description}" --body "$(cat <<'EOF'
## Summary

{1-3 bullet points — what's changing}

## Dives changed

- [new] medicaid-states — {one-liner}
- [modified] ma-enrollment — {one-liner}

## Verification

- /verify: HIGH confidence, {N}/{M} verify checks within bounds
- /dashboard-review: dual-mode load OK, modals surfaced
- dbt test: {X}/{Y} pass
- Verify check rows: {N} per changed marts model

## Bronze file-level promotion

{output of warehouse_diff — tables + _file_ids being synced}

## Rollback

`git revert` this PR if something breaks in prod. CI re-runs against the
reverted state.

---
Filed from /promote skill.
EOF
)"
```

Capture the PR URL.

### Step 3: Post the warehouse promotion manifest

```
mcp__soria__warehouse_promote(pr=<PR_NUMBER>)
```

This writes a `<!-- soria-promotion-manifest -->` YAML comment on the PR
enumerating the exact `_file_id` rows `promote.yml` should copy from
staging to prod on merge. Without this comment, `promote.yml` no-ops — so
do NOT skip this step.

If the promote tool refuses (e.g., no new files to sync), report that the
PR carries only marts/React changes — no bronze promotion needed.

### Step 4: Report

```
PROMOTION PR OPENED
═══════════════════

Branch: medicaid-states-dive
PR:     https://github.com/Soria-Inc/soria-2/pull/{N}
Bronze manifest: ✅ posted (47 files in medicaid_enrollment)

Next steps (human):
  1. Review the PR
  2. Merge when ready
  3. CI will run dbt-deploy.yml + promote.yml on merge
  4. After CI green, invoke /dashboard-review against https://soriaanalytics.com

If canary fails: git revert the PR and merge the revert.

Status: DONE (PR opened, human owns merge)
```

### Step 5 (after merge): Canary via /dashboard-review

Once the user reports the PR is merged, invoke `/dashboard-review` against
`https://soriaanalytics.com` to confirm everything landed correctly.

---

## Rollback (Principle #34)

If promotion breaks something:

**For warehouse / dive changes** (marts, seeds, React):

```bash
gh pr revert <PR_NUMBER>          # or: git revert <merge-sha> then PR it
```

CI re-runs against the reverted state — `dbt-deploy.yml` regenerates
marts and `promote.yml` undoes the bronze file sync (because the manifest
is gone from the revert). Clean.

**For Postgres state** (scraper/group/schema/mapping changes):

```
mcp__soria__database_mutate(sql="
  UPDATE {table}
  SET deleted_at = NULL, deleted_by = NULL
  WHERE id = '{id}' AND deleted_at IS NOT NULL
")
```

This flips `deleted_at` back to NULL — the row becomes visible again.
Respect `SOFT_DELETE_CASCADES`: if a parent is soft-deleted you may need
to undelete it first. Use `mcp__soria__pipeline_activity` /
`pipeline_history` to trace what changed.

Do **NOT**:
- Hand-write `DELETE FROM prod.{table}` statements
- Force-push to main to erase the merge commit
- Manually drop tables

The PR and the soft-delete flip are the authoritative reversals.

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/promote-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Promotion Report: [Branch Name]

## Changed artifacts
[Dives added/modified, marts models, seeds, bronze file counts]

## Pre-flight checklist
- Verification: [PASSED / NOT VERIFIED / PASSED WITH CONCERNS]
- Review: [PASSED / NOT RUN]
- dbt tests: [N/M pass]
- Modals: [populated / missing for X]
- Agent runs: [none / active on PR #Y]

## PR
URL: [https://github.com/.../pull/N]
Manifest: [posted / N/A — no bronze changes]

## Canary
[After merge — /dashboard-review results against prod URL]

## Outcome
Status: [DONE | DONE_WITH_CONCERNS | BLOCKED]
Lesson: [What was interesting or unexpected]
ARTIFACT
```

---

## Anti-Patterns

1. **Promoting without being asked.** The AI should NEVER suggest or
   initiate promotion. The human decides when to go to prod.

2. **Calling `gh pr create` or `git push` outside this skill.** All
   promotion goes through /promote. If you're in /ingest or /dive and the
   user says "push to prod", invoke this skill.

3. **Skipping the warehouse_promote manifest post.** Without the
   `<!-- soria-promotion-manifest -->` comment, `promote.yml` no-ops and
   bronze changes won't make it to prod. Run `warehouse_promote(pr=…)`
   after the PR is open.

4. **Promoting without verification.** If /verify hasn't run, warn loudly.

5. **Promoting without a dashboard review.** For dives, /dashboard-review
   against `https://dev.soriaanalytics.com` is the only way to confirm the
   dual-mode load, modals, and filters work in a real browser.

6. **Force-pushing to roll back.** `git revert` is the rollback. Never
   force-push to main.

7. **Racing the interactive agent.** If there's an active agent run on the
   current branch, defer — don't open a competing PR.

8. **Assuming merged = done.** CI runs after merge. Only after CI green
   AND `/dashboard-review` canary pass against `https://soriaanalytics.com`
   is the promotion truly done.
