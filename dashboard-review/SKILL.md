---
name: dashboard-review
description: |
  Ship-readiness review for a dive. Runs six gates end-to-end against a live
  dive (dev.soriaanalytics.com or soriaanalytics.com), collects evidence, produces one
  aggregated report. This is the gate before /promote — if it passes, the
  dive is safe for customers. Checks: render (Phase 1 Postgres proxy + Phase 2
  WASM), data correctness (rendered values vs the verifications seed AND
  vs the warehouse), interactivity (every control mutates state), methodology
  + verify modals (ETHOS #29), edge cases (nulls / NaN / market share > 100%),
  performance (TTFP, TTW, no 4xx/5xx, no retry storms). Use after /dive
  finishes, before /promote. Use when asked to "review the dashboard", "QA
  this dive", "check this dive before shipping", "run the dive gates". Hands
  off to /ticket or /diagnose if a gate fails — never files tickets itself.
allowed-tools:
  - Bash
  - Read
---

## Preamble (run first)

```bash
# 1. Confirm /browse is ready.
_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
B=""
for candidate in \
  "$_ROOT/.claude/skills/soria-stack/browse/vendor/dist/browse" \
  "$HOME/.claude/skills/soria-stack/browse/vendor/dist/browse" \
  "$HOME/.claude/skills/browse/vendor/dist/browse"; do
  [ -n "$candidate" ] && [ -x "$candidate" ] && B="$candidate" && break
done
[ -z "$B" ] && { echo "BLOCKED: /browse binary not built. Run the /browse skill's build.sh."; exit 0; }
: "${BROWSE_STATE_FILE:=${_ROOT:-$HOME}/.gstack/state.json}"
export BROWSE_STATE_FILE
export BROWSE_PARENT_PID=0       # see /browse preamble — prevents server self-terminate
mkdir -p "$(dirname "$BROWSE_STATE_FILE")"
echo "browse: $B"

# 2. Gate 2 Check B (warehouse cross-ref) needs `mcp__soria__warehouse_query`
#    to work. Skip this shell probe — verify at runtime by running a trivial
#    query and bailing if it errors.

# 3. Assert $B is signed in. cookie-import succeeds silently even when Arc is
#    signed out (imports 13 cookies with __client_uat=0 but no __session).
if ! $B cookies 2>/dev/null | grep -q '"__session"'; then
  echo "BLOCKED: no __session cookie — run /browse auth bootstrap (Arc sign-in + cookie-import-browser)."
  echo "Do NOT try to fill the Clerk form from \$B — it will 429."
  exit 0
fi

# 4. Artifact dir.
mkdir -p ~/.soria-stack/artifacts
```

Ask the user for the **dive id** (required — matches the manifest filename
without extension, e.g. `naic-kpis-by-company`) and the **base URL** (default
`https://dev.soriaanalytics.com` for local dev-https, or
`https://soriaanalytics.com` for prod canary). Do not guess.

If the dive isn't reachable (curl fails), report BLOCKED with exact
instructions: `make dev-https` from the soria-2 repo root. Don't try to
start the server yourself.

If the dive loads but shows the Clerk sign-in form in Gate 1, report BLOCKED
and point the user at `/browse`'s auth bootstrap section — sign in Arc/Chrome,
`$B cookie-import-browser arc --domain dev.soriaanalytics.com`.

## What this skill is (and isn't)

| | /verify | /dashboard-review |
|--|---|---|
| Asks | "Is the warehouse data correct?" | "Does the UI surface the warehouse data correctly, completely, and cleanly enough for a hedge-fund customer?" |
| Evidence | seed comparisons, sum checks, external corroboration | rendered values match seed AND warehouse; every control mutates state; modals present with real content; no edge-case formatting bugs; perf within budget |

`/dashboard-review` assumes `/verify` has already passed for this dive's
warehouse table. It's checking the UI-to-warehouse bridge, not the warehouse.

## Anti-patterns (read before every run)

1. **Don't declare "broken" during WASM warmup.** The dive loads in two
   phases: Postgres proxy first paint (~500ms), then WASM takes over
   (~20s). If Phase 1 shows data, the dive is not broken — WASM is just
   warming. Only declare FAIL after observing Phase 2 complete (or time out).
2. **Bucket warmup warnings separately from runtime errors.** Clerk dev-keys
   warning, AG Grid Enterprise license warning, MotherDuck `MD_EVENT`
   `unassociated response` messages during init are noise. Runtime errors
   after the page settles are real.
3. **Empty grid with an active filter ≠ broken** if that filter legitimately
   has zero rows in the warehouse. Always cross-check against
   `mcp__soria__warehouse_query` before filing a bug.
4. **Declare "FAIL" only on customer-visible defects.** Formatting bugs,
   wrong numbers, missing modals, console errors that fire on first paint,
   controls that do nothing. Cosmetic warnings in dev mode are not FAILs.
5. **Never silence `$B click` output.** Playwright click timeouts look like
   silent no-ops if you pipe to `/dev/null`, which produces invalid "N
   identical snapshots = interactivity broken" reports. Always capture the
   click output and treat `Operation timed out: click: Timeout Nms exceeded`
   as an explicit evidence row — NOT as a dive bug, at least not until you
   retry with a `tail -1` ref (see Gate 3 ref extraction rule).
6. **macOS-safe timing.** `date +%s%3N` is GNU-only and silently yields
   garbage on macOS. For millisecond timing use
   `python3 -c 'import time; print(int(time.time()*1000))'` or stick to
   second-granularity `date +%s`.
7. **Identical-hashes-across-matrix is a TEST signal, not a dive signal.**
   If every post-click snapshot hashes the same, the overwhelming prior is
   that every click failed (see anti-pattern #5) — not that every control
   in the dive is dead. Re-run with a `tail -1` ref before declaring FAIL.

## Gate plan — run all, aggregate at the end

Do not stop on a failed gate. Collect evidence for all six, then produce the
report. This is the product of the skill.

### Gate 1 — Render (dual-mode contract)

Confirms the dive actually loads and shows data, not just chrome. Because
dives use dual-mode loading, this gate captures TWO phases separately. If
Phase 1 shows data but Phase 2 doesn't, that's a WASM upgrade bug. If Phase
1 is blank after 5s, that's a Postgres proxy failure — hand off to
`/diagnose`.

Probe (chain in one shell so `$B` state doesn't reset):
```bash
OUT=~/.soria-stack/artifacts/dashboard-review-$DIVE
mkdir -p $OUT

# Phase 1: Postgres proxy first paint (~500ms)
$B goto "$BASE_URL/dives?dive=$DIVE" \
  && $B wait --load \
  && sleep 1 \
  && $B screenshot $OUT/gate1-phase1.png \
  && $B snapshot -c > $OUT/gate1-phase1-snap.txt \
  && $B text > $OUT/gate1-phase1-text.txt

# Phase 2: WASM warmup (~20s). Wait for network idle, then a full 30s settle:
# some dives don't fire the first WASM query until 10-15s in, so networkidle
# alone can fire before the grid is actually populated.
$B wait --networkidle \
  && sleep 30 \
  && $B screenshot $OUT/gate1-phase2.png \
  && $B snapshot -c > $OUT/gate1-phase2-snap.txt \
  && $B text > $OUT/gate1-phase2-text.txt \
  && $B console > $OUT/gate1-console.log \
  && $B network > $OUT/gate1-network.log
```

Pass criteria:
- URL is the dive URL (not `/sign-in`).
- Phase 1 snap contains the dive heading + at least the KPI row.
- Phase 2 snap contains grid rows (> 0 data rows).
- `console` has no error-level messages after Phase 2 settles (warmup
  warnings excluded per anti-pattern #2).
- No request in `network.log` returned ≥ 400.
- Phase 1 < 5s, Phase 2 < 30s (elapsed from goto).

If Phase 1 shows data but Phase 2 is empty: WASM upgrade is dropping rows.
Check for `MotherDuckSDKProvider` remounting in console. Classic cause:
COOP/COEP headers firing a full page reload on navigation, or the provider
scoped below the router.

Known failure modes to call out if observed:
- **Stuck loading spinner** → WASM client failing silently. Check
  `VITE_MOTHERDUCK_TOKEN` in the frontend `.env` (Cameron's personal token
  may have expired; use the service token).
- **20s every navigation** → `MotherDuckSDKProvider` unmounting on route
  change (COOP/COEP headers, or provider scoped below the router).
- **Shared DB not attached** → local preview ignoring `REQUIRED_DATABASES`;
  dive references `md:_share/soria_duckdb/...` that's never attached.
- **Page loads but chart region is empty** → `useDiveData` query returning
  [] because the manifest's `table` name doesn't exist at that scope.

### Gate 2 — Data correctness

Two independent checks: (a) rendered vs verify seed, (b) rendered vs live
warehouse. The seed proves the dive matches an external benchmark. The
warehouse cross-reference catches stale cache, stale dbt run, or a
manifest pointing at the wrong table.

**Check A — rendered vs `verifications.csv` seed**:
- Read `frontend/src/dives/dbt/seeds/verifications.csv` → filter `model == <marts table from manifest>`.
- If 0 rows: record `BLOCKED: no seed rows — ETHOS #28 violation` and skip
  to Check B.
- Else: for ~5 representative rows (top companies × key metric × key
  period), extract the rendered value from the dive and diff.
- Tolerance: < 0.5% absolute relative drift unless seed bounds are explicit.

**Check B — rendered vs warehouse**:
- From the manifest: read `table` (the marts model).
- Query the warehouse with the same filter state the UI has applied. When
  reviewing against `dev.soriaanalytics.com` (prod backend), query
  `soria_duckdb_main.*` to match what the UI sees:
  ```
  mcp__soria__warehouse_query(sql="
    SELECT <primary_entity>, <time_column>, <metric_column>
    FROM <marts_table>
    WHERE <lob_column> = '<active LOB>'
    ORDER BY <metric_column> DESC LIMIT 10
  ")
  ```
- Diff top-5 rendered rows against top-5 warehouse rows. Mismatch means:
  stale dbt run, session cache poison, manifest pointing at the wrong
  table, or the dive applying silent client-side filters.

Pass: both checks clean.
PASS_WITH_CONCERNS: ≤ 10% of values drift 0.5–2% OR Check A blocked but B clean.
FAIL: any value drifts > 2%, any sign is flipped, any top-5 row mismatch between UI and warehouse, or both checks blocked/failed.

Known failure modes:
- **Wrong denominator** → MLR = `SUM(medical_claims) / NULLIF(SUM(premiums_earned), 0)`
  but Sigma / CMS use `premiums_written`. UNH FEHB showed 98.7% vs. 93.6%.
  Fix in the staging/intermediate SQL, not the dive.
- **Ratio averaged before aggregation** (ETHOS #12) → market share > 100%
  because "All" distribution double-counted Individual + Group rows.
- **Saved default filter not applied** → manifest wrote
  `default_values: ["Individual"]` but loaded page shows "All". Usually a
  manifest-to-dive registration mismatch; check `DivesPage.tsx`.
- **Sanity breach** → NAIC commercial enrollment for all Blues = 8M (too low
  by order of magnitude), total Medicaid ≠ ~90M per CMS. Flag any metric
  that's > 2x off the rough industry ground truth the user named in the
  dive brief.

### Gate 3 — Interactivity

Every control the manifest declares must cause a visible, correct data
change. Read the manifest to enumerate controls, don't guess from the UI.

Probe per control:
```bash
$B snapshot -c > /tmp/pre.log
$B click @eN                         # capture output — do NOT pipe to /dev/null
sleep 5                              # enough for WASM query + re-render
$B snapshot -c > /tmp/post.log
diff /tmp/pre.log /tmp/post.log | head -20
```

**Ref extraction rule — PREFER THE LAST MATCH, not the first.** React dives
routinely render the same control twice (primary `DiveControlBar` at the top
+ sticky `StickyDiveHeader` below). The primary copy is often covered by the
sticky header and Playwright times out clicking it. The sticky copy is the
one users actually interact with. Use `tail -1` on the grep, or a fallback
cascade: try each ref in order, move on as soon as one succeeds.

```bash
# Wrong — targets the broken primary bar.
REF=$(grep -E '\[button\] "'"$LABEL"'"' $SNAP | head -1 | grep -oE '@e[0-9]+')
# Right — targets the working sticky bar.
REF=$(grep -E '\[button\] "'"$LABEL"'"' $SNAP | tail -1 | grep -oE '@e[0-9]+')
```

**Surface click failures — never silence.** `$B click $REF > /dev/null 2>&1`
will hide Playwright timeouts and produce an invalid "N snapshots all match"
report. Parse the click output for `Timeout` / `Operation timed out` and
record each as its own evidence row (see anti-patterns below).

**Shell-escape special characters in manifest labels.** Labels like
`"Affiliated $"` / `"Non-Affiliated $"` break shell regex expansion. Either
`\Q...\E` the label, consume the manifest's `key` field instead of `label`,
or use `grep -F` for fixed-string matching on the whole label bracket.

**Test both entry paths for every control** — URL preset AND click mutation.
A dive may ship with a working click path but a broken URL-preset reader
(or vice versa). Example observed: `?metric=medical_expense_per_member`
produces an empty grid on first load, while clicking the same metric button
works. Same code, different paths.

```bash
# URL preset: navigate with the param set, check the grid renders.
$B goto "$BASE_URL/dives?dive=$DIVE&metric=$KEY"
# Click mutation: navigate without, then click.
$B goto "$BASE_URL/dives?dive=$DIVE" && $B click "$REF"
```

Pass: every manifest control produces a non-empty diff in the rendered data
region via BOTH paths, with no click timeouts.

Known failure modes:
- **Duplicate control bars with only sticky clickable** — primary bar buttons
  in the a11y tree time out; only `tail -1` ref works. Often caused by
  sticky header overlapping the primary with higher z-index and
  `pointer-events: auto`.
- **URL-preset reader diverges from click handler** — one path sets state
  that the grid actually consumes, the other doesn't.
- **Half-wired control** — segment "add" handler updated `activeSegments`
  state but `ChartSegments` was never rendered and `activeSpecialFilters`
  was never passed to `DynamicFilters`. Clicks looked ignored, pills never
  appeared.
- **Stale closure** — `selectedItems` out of sync with `metricSortedItems`.
  "Other" row didn't appear until we stopped depending on the intermediate.
- **HMR lag** — filter change didn't reach the backend because Vite didn't
  rebuild the `useMemo` closure. User saw "filter doesn't work"; hard reload
  would have fixed it.
- **ENG-1317** — sort only applies to current page, not full dataset.
- **ENG-1336** — TopN doesn't work with pivot tables.
- **ENG-1017** — search filter leaks across tabs.

**Self-audit before reporting Gate 3 FAIL**: if every matrix snapshot hashes
identically AND every click emitted a timeout, that's a TEST-failure signal,
not a dive-failure signal. Re-extract refs using `tail -1` and re-run before
filing anything. Reporting a false interactivity FAIL wastes engineering time.

### Gate 4 — Methodology & verify modals (ETHOS #29)

Every dive must answer "how is this built?" and "how do we know it's right?"
from the UI alone.

Probe:
```bash
# Same duplicate-control caveat as Gate 3 — use tail -1 for the sticky copy.
METH_REF=$(grep '\[button\] "Methodology"' $SNAP | tail -1 | grep -oE '@e[0-9]+')
VER_REF=$(grep  '\[button\] "Verify"'      $SNAP | tail -1 | grep -oE '@e[0-9]+')

# If no Verify button exists in the tree at all, FAIL immediately — the dive
# is shipping without the /verify modal contract (ETHOS #29).
[ -z "$VER_REF" ] && echo "FAIL: no Verify button in a11y tree"

$B click "$METH_REF"
sleep 2
$B text > /tmp/methodology.txt
$B snapshot -c | grep -iE "source|formula|grain|cadence|update" | head -20
$B screenshot ~/.soria-stack/artifacts/dashboard-review-$DIVE-methodology.png
# Repeat for verify modal.
```

Confirm the modal actually opened: compare post-click snapshot size to the
pre-click snapshot. Identical byte size = click didn't open anything (same
class of bug as Gate 3 — you probably targeted the broken duplicate).

Pass: methodology content lists sources (with URLs), metric formulas, grain,
update cadence. Verify modal shows recent `last_dbt_run` + `last_dbt_test`
timestamps (populated by the `vite-dbt-sync` Vite plugin).

Known failure modes:
- **Missing methodology** — dive shipped opaque; customer goes back to
  primary source to double-check. Michael Ha and Nephron both asked
  explicitly for methodology surfacing. This class of omission blocks the
  trust contract, not a cosmetic concern.
- **Stale verify timestamps** — `last_dbt_run` older than the warehouse
  data's freshness window. Either the Vite plugin didn't run or the
  production dbt job failed silently.
- **Formulas missing for derived metrics** — per ETHOS #19, derived metrics
  (MCR, market share %, YoY growth) are the hardest to audit. If the
  modal just names the metric without the formula, that's a FAIL.

### Gate 5 — Edge cases (data red flags)

The quiet formatting/null-handling bugs that erode trust cell-by-cell.

Probe:
- Walk the rendered grid via `snapshot` and `text`.
- Grep for each red flag below across the full grid text.
- Spot-check a known-sparse row (UPMC, small Medicaid carriers skip some
  quarters). Expected: `—` for missing periods, clean formatting otherwise.

**Data red-flags checklist** — any one of these is FAIL:
- Ratio / percentage values > 100% or < 0% where that's nonsensical
  (market share, MLR, affiliated %).
- `NaN`, `Infinity`, `undefined`, `null` rendered as a visible string.
- Bare `%` or `$` sign with no number (ENG-1340 pattern).
- Empty string in a value cell where `—` is expected.
- "Other" rollup / totals row with nonsensical ratio (e.g. 847% market share
  from aggregating pre-computed percentages — ETHOS #12).
- Total row doesn't match sum of visible rows (within expected rounding).
- Missing months / quarters in a time series without explicit `—`
  placeholder.
- Values unchanged after toggling a metric (stale render, ETHOS #30 adjacent).
- Decimal-place misalignment (YoY +21% when value is +2.1% — formatter
  divided once too few times).

Known failure modes:
- **ENG-1340** — empty pivot cells showed bare `%` instead of `—`.
  `formatMetricValue` appended `%` to null-ish AG Grid aggregation output.
- **Missing period handling** — UPMC had `—` for 3 non-reporting quarters;
  chart lines need to break cleanly, not render at y=0.
- **Extraction error passthrough** — CHIP 2013-02 `performance_bonus_balance`
  was wrong upstream but rendered silently. If the dive displays a value
  the verify seed doesn't bound, flag it.
- **Stale render** — toggling metric changes the header label but cells
  still show the prior metric's values (cache keyed on wrong input).

### Gate 6 — Performance & network hygiene (ETHOS #30)

Dual-mode load contract: Postgres proxy first paint fast, WASM upgrade
under a budget. No console noise, no retry loops.

Probe:
```bash
$B network > /tmp/gate6-net.log
# Count status codes
awk '{print $2}' /tmp/gate6-net.log | sort | uniq -c | sort -rn
# Flag any URL with > 10 occurrences
awk '{print $3}' /tmp/gate6-net.log | sort | uniq -c | awk '$1>10' | sort -rn
# Extract TTFP + TTW from console timing logs if the dive emits them
grep -iE "first paint|wasm ready|duckdb.*ready" /tmp/gate6-net.log
```

Pass: zero 4xx/5xx, zero URLs with >10 hits in a single page load, TTFP < 5s,
TTW < 30s.

Known failure modes:
- **4,322-hit 404 storm** — exchange-rate-review-state-matrix page retried
  a dead endpoint without backoff. Any URL with >10 hits is this class.
- **52s cold start** — Modal deploys lose the MotherDuck connection; first
  dashboard request races the warmup thread, reading 5700 catalog entries.
  Seen as a single very slow `/pages` request.
- **45s distinct query** — NAIC distinct on `lob` column was unindexed; DBOS
  Cloud proxy 502'd before it completed.
- **500 storm** — crash loop + queue backup; filter bar requests pile up
  behind stuck workflows. If Gate 6 finds ≥ 5 5xx in the page load, treat
  as FAIL regardless of Gate 1 passing.

## Report format

Write to `~/.soria-stack/artifacts/dashboard-review-<dive>-<YYYYMMDD-HHMM>.md`:

```markdown
## Dashboard review: <dive>
Run: <timestamp>
URL tested: <full URL — dev.soriaanalytics.com or soriaanalytics.com>
Dive manifest: frontend/src/dives/<dive>.manifest.ts
Marts table: <schema.table from manifest>

## Overall: PASS | PASS_WITH_CONCERNS | FAIL

## Gates
### Gate 1 — Render: PASS
  TTFP=1.2s, TTW=18s, 0 console errors, 0 failed requests
  Screenshot: dashboard-review-<dive>-gate1.png

### Gate 2 — Data: FAIL
  UnitedHealth Group · Medicare · Dec 2025 membership
    expected 16,306,873 (verifications.csv row 142, source=NAIC 2025 Q4)
    rendered 16,340,000  — 0.2% drift, WITHIN tolerance
  Elevance Health · Individual · YoY Growth · Dec 2025
    expected +2.1% (seed row 118)
    rendered +21.0% — DECIMAL PLACE BUG
  4 of 5 spot checks passed.

### Gate 3 — Interactivity: PASS_WITH_CONCERNS
  Metric picker: works (6/6 buttons change chart)
  LOB picker: works (10/10)
  TopN input: responds but pagination control is non-interactive
  Methodology/Verify buttons: covered in Gate 4

### Gate 4 — Methodology: PASS / Verify modal: PASS
  Methodology lists: NAIC 2025 statutory filings, grain = parent co × quarter × LOB,
    update cadence = quarterly, formula for Market Share % is stated correctly.
  Verify modal: last_dbt_run = 2026-04-12 09:14, last_dbt_test = same, PASS.

### Gate 5 — Edge cases: PASS
  14 `—` cells rendered correctly. No bare `%`/`$`/`NaN` observed. UPMC
  sparse row handled correctly.

### Gate 6 — Performance: PASS
  0 4xx/5xx, top repeated URL = 3 hits (expected). TTFP=1.2s, TTW=18s.

## Recommendations
- FAIL Gate 2 → file via /ticket: "Elevance YoY decimal place bug in marts
  model or dive formatter — divides by 100 once too few times."
- PASS_WITH_CONCERNS Gate 3 → file via /ticket: "TopN pagination control
  non-interactive."
- Do not /promote until Gate 2 failure is resolved and re-run.

## Outcome
Status: FAIL
Blocker: decimal place bug misrepresents YoY growth by 10x. Hedge fund
customer would read +21% as a material growth story rather than flat.
```

## Handoffs

- **Gate 2 FAIL** → suggest `/ticket` with the expected vs actual table, and
  `/diagnose` if the user wants to chase it live.
- **Gate 1 or 6 FAIL with infra flavor** (401, 5xx storm, stuck WASM) →
  suggest `/diagnose` first, then `/ticket` if infra-side.
- **Gate 4 FAIL** → route back to `/dive` to wire the modals; don't ticket
  (it's author-resolvable).
- **Gate 5 FAIL** on a formatter bug → `/ticket` with the offending cell +
  screenshot + affected metric.

Never file tickets or run `/diagnose` yourself. Report, suggest, hand back.

## Outcome section (skill self-footer)

End every run with:
```
Status: PASS | PASS_WITH_CONCERNS | FAIL | BLOCKED | NEEDS_CONTEXT
Artifact: <path>
Next: <concrete next skill + argument>
```
