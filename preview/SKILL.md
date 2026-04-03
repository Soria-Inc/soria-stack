---
name: preview
version: 1.0.0
description: |
  Render dashboard data as formatted markdown tables in chat — simulating
  the frontend experience without opening a browser. Shows controls bar,
  available slices, and pivot table output for each dashboard page.
  Use when asked to "show me the dashboard", "what does this dashboard look like",
  "preview this", "show me slices", "what data does this show",
  or "review the dashboard output".
  Use after /dashboard or /verify to inspect what was built. (soria-stack)
benefits-from: [dashboard, verify]
allowed-tools:
  - sumo_*
  - Read
  - Bash
  - AskUserQuestion
---

## Preamble (run first)

```bash
mkdir -p ~/.soria-stack/artifacts
echo "SKILL: preview"
echo "---"
echo "Checking for dashboard artifacts..."
ls -t ~/.soria-stack/artifacts/model-*.md 2>/dev/null | head -3 || echo "  (none)"
```

**Check for prior work:** If a model artifact exists, read it — it has the
platinum table name and controls config. If none, use `list_dashboard_pages`
to enumerate what's available.

## Skill routing (always active)

- User wants to fix data that looks wrong → invoke `/verify`
- User wants to rebuild the model → invoke `/dashboard`
- User wants to check pipeline status → invoke `/status`
- User says "push to prod" → invoke `/promote`

---

# /preview — "Show me the dashboard"

You are rendering dashboard output as markdown tables in chat. Your job is to
show the human exactly what someone using the frontend would see — controls,
slices, actual numbers — without them having to open a browser.

**This is a read-only skill.** You query warehouse data and format it. You do
not build, fix, or modify anything.

---

## Step 1: Enumerate Dashboards

If no specific dashboard was named, list what's available:

```
list_dashboard_pages()
```

Present a numbered list:
```
Available dashboards:
1. platinum.utilization_overview — Hospital utilization trends (national + regional)
2. platinum.mssp_program_overview — MSSP ACO program, 12-year trend
3. platinum.ma_enrollment_dashboard — Medicare Advantage enrollment by org/plan
...
```

Ask: "Which dashboard(s) do you want to preview? All of them, or specific ones?"

---

## Step 2: Read the Dashboard Config

For each target dashboard, get its page config:

```
get_dashboard_page(node_id="...")
```

Extract from the `@dashboard` block:
- **Chart type** (pivot, bar, line, map)
- **Controls** — filters, value toggles, `valueOptions`, `top_n`
- **Grain** — what each row represents
- **Default filters** — what the user sees first

**Do not query yet.** First present the controls bar so the human knows what
interactions are available.

### Controls bar format

Show the controls as a code block simulating the UI:

```
Controls:
  [Metric ▼: Enrollment | Market Share % | YoY Growth %]
  [Segment ▼: MA | MAPD | PDP]  [Distribution ▼: Individual | Group]
  [Network ▼: All | HMO | PPO | PFFS]  [Org ▼: All | ...]
  [Date Range ▼: All time | Last 12 mo | Last 24 mo]

Default view: Metric=Enrollment, Segment=MA, Distribution=Individual, Network=All
```

---

## Step 3: Query and Render Each Slice

For each meaningful slice of the dashboard, run a `warehouse_query` against
the platinum table and render as a markdown pivot table.

### How to pick slices

1. **Start with the default view** — what the user sees when they first open it
2. **Show 2-3 additional slices** that demonstrate the controls are working
   (e.g., a regional breakdown, a different metric, a top-N filter)
3. **Don't show every possible combination** — pick the ones that tell the story

### Query pattern

```sql
-- Default view: latest N months, top 10 orgs by enrollment
SELECT parent_organization, reporting_month, enrollment
FROM platinum.ma_enrollment_dashboard
WHERE segment = 'MA' AND distribution = 'Individual'
  AND reporting_month >= (SELECT MAX(reporting_month) FROM platinum.ma_enrollment_dashboard) - INTERVAL 5 MONTH
ORDER BY reporting_month, enrollment DESC
LIMIT 50
```

### Pivot table format

Show as a markdown table with time as columns when it's a time-series:

```
**Slice: Enrollment — National by Organization (MA, Individual, last 6 months)**

| Parent Organization  | 2025-10 | 2025-11 | 2025-12 | 2026-01 | 2026-02 | 2026-03 |
|---------------------|---------|---------|---------|---------|---------|---------|
| UnitedHealth         | 7.49M   | 7.55M   | 7.61M   | 7.65M   | 7.66M   | 7.67M   |
| Humana               | 5.18M   | 5.19M   | 5.19M   | 5.19M   | 5.20M   | 5.20M   |
| CVS / Aetna          | 3.99M   | 4.01M   | 4.04M   | 4.06M   | 4.07M   | 4.07M   |
| Centene              | 2.53M   | 2.57M   | 2.61M   | 2.63M   | 2.64M   | 2.65M   |
| Kaiser               | 2.25M   | 2.26M   | 2.27M   | 2.27M   | 2.28M   | 2.28M   |
```

For non-time-series (single snapshot):

```
**Slice: Market Share % — By State (MA, Individual, 2026-03)**

| State | UnitedHealth | Humana | CVS/Aetna | Centene | Other |
|-------|-------------|--------|-----------|---------|-------|
| FL    | 28.1%       | 22.4%  | 11.3%     | 8.9%    | 29.3% |
| TX    | 31.2%       | 15.6%  | 14.7%     | 12.1%   | 26.4% |
```

---

## Step 4: Data Quality Notes

After the tables, flag anything that looks off:

```
Data quality notes:
- PY2013 earned savings inflated ($833M vs CMS $315M) — EarnShrSavings column had gross amounts
- 2014-2020 savings rates show 0.0% — percent-formatted values were stripped
- PY2022+ has two-sided risk counts; earlier years have NULLs for risk_model column

Verdict: Strong for 2021-2024. Older years have enrollment data but some financial gaps.
```

Flag: unusual NULLs, values that are suspiciously round, ranges that seem wrong,
gaps in time coverage, or anything a domain expert would notice.

**Don't say "looks good" without checking.** Look at the actual values before
writing a verdict.

---

## Step 5: Invite Interaction

After each dashboard, offer to drill down:

```
Dashboard rendered. Options:
- Show a different slice ("show me Northeast only", "top 5 by market share", "switch to YoY growth")
- Go to next dashboard
- Check a specific value ("verify that UNH 7.67M for 2026-03")
```

If the human asks for a specific interaction (e.g., "show me Florida only"),
re-query with those filters and re-render the table.

---

## One-at-a-Time Rule

Always go one dashboard at a time. After rendering a dashboard and its slices,
stop and wait. Don't auto-advance to the next one. The human may want to
interact with what they just saw.

---

## ⛔ GATE: PREVIEW COMPLETE

After the human has seen enough, ask:
- "Does the data look right? Any values you want to verify?"
- If they say something looks off → invoke `/verify`
- If they say it's good → note that it's ready for `/promote`

---

## Artifact Output

```bash
cat > ~/.soria-stack/artifacts/preview-$(date +%Y%m%d-%H%M%S).md << 'ARTIFACT'
# Dashboard Preview: [Name]

## Dashboards Reviewed
[List of dashboard node_ids]

## Slices Shown
[Which slices were rendered and what they showed]

## Data Quality Notes
[What was flagged, what looked clean]

## Outcome
Status: [DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT]
Lesson: [What was unexpected or worth remembering]
ARTIFACT
```

---

## Anti-Patterns

1. **Showing raw warehouse dumps.** Don't `SELECT * LIMIT 50` and paste it. Format
   it as a pivot table that matches how the dashboard would display it. The point
   is to simulate the frontend, not dump rows.

2. **Picking arbitrary slices.** Start with the default view, then show slices
   that exercise the controls. Don't pick random filter combinations.

3. **Saying "data looks correct" without evidence.** Look at the numbers. Flag
   anything suspicious before writing the verdict.

4. **Auto-advancing through all dashboards.** One at a time. Stop after each one.
   The human may want to interact with it.

5. **Skipping the controls bar.** Show the controls before the first table. The
   human needs to know what filters and toggles exist before they can ask for
   specific slices.

6. **Querying prod when in a workspace context.** If the model artifact says
   `workspace="ws_xxx"`, query `platinum__ws_xxx.dashboard_name`, not
   `platinum.dashboard_name`. Same rule as everywhere else.
