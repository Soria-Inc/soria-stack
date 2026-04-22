---
name: framing-axes
description: >
  Use this skill in Phase 1.5 on EVERY event to pressure-test your first-
  instinct frame against orthogonal categorical axes. The core move is a
  checklist of splits — partisan, geographic, payer-mix, cycle-timing,
  size, ownership structure — that you should try to see if the real
  insight is the split itself rather than the event. The canonical
  output is a list of 3-5 candidate framings, each named against a
  different axis, with the best-fit one picked and the runner-up noted.
---

# framing-axes

Most event types — policy, legal, rate, M&A — can be framed along more
than one axis. The Lead's recurring failure mode is committing to the
first axis that comes to mind (usually "who's exposed?") when the real
insight is a different split the first-pass analysis didn't consider.
This skill is a checklist of categorical axes to try before writing
briefs.

## When to apply

Always. Phase 1.5 of every event, without exception. Takes 2 minutes
and prevents the "wrong frame, 20 rounds of revision" failure mode.

## Core move

For the event at hand, run through the axes below. For each one, ask:
"if the insight were that the event splits on THIS axis, what would the
title say?" Write that title down as a candidate framing. Then pick the
one the data best supports. Do NOT just pick the axis that sounds most
analytical — pick the one the data actually supports.

## The axes

1. **Partisan.** Does this split on state party control, administration
   party, or congressional-majority lines? Red-state adoption vs blue-
   state adoption. Republican-led rulemaking vs Democrat-led. Use this
   when the event names multiple states or when a federal action is
   party-coded (e.g. CMS rate notice under this admin vs prior).

2. **Geographic.** Does this split on coastal/interior, urban/rural,
   census region, Medicaid-expansion/non-expansion, or CMS region?
   Use this when state-level variation matters more than national
   averages (most Medicaid events, most rate-filing events, most
   certificate-of-need and scope-of-practice events).

3. **Payer-mix exposure.** Does this split on MA-heavy vs Medicaid-heavy
   vs commercial-heavy vs exchange-heavy? When the same regulation hits
   different payer lines differently, the companies' payer mix is the
   insight. Run this for any CMS action, any ACA action, any Medicaid
   managed-care action.

4. **Zoom level (one-name / subsector / mechanism).** See `read_skill(
   "mechanism-vs-event")` for the mechanism angle. The one-name vs
   subsector call is a zoom choice: single-ticker framing is only right
   when economics are ≥60% concentrated in that ticker. Most policy /
   legal / rate events are subsector stories, not one-name stories.

5. **Market-cap tier.** Does this split on mega-cap vs mid-cap vs
   small-cap? Mega-caps can absorb regulatory hits that crater small-
   caps. Run this for any event with a fixed-dollar compliance cost, any
   reimbursement cut with a hard floor, any ruling with minimum-damages
   exposure.

6. **For-profit vs non-profit.** Does this split on ownership structure?
   For-profit hospitals face certificate-of-need and disproportionate-
   share funding differently than non-profits. Run this for any
   hospital-payment event, any 340B-related event, any tax-policy
   event.

7. **Vertically-integrated vs carved-out.** Does this split on whether
   the affected line is integrated into a parent (UNH + Optum, CVS +
   Aetna + Caremark, CI + Evernorth) or free-standing? Vertically-
   integrated players can absorb hits on one leg via uplifts on another;
   free-standing players can't. Run this for any PBM event, any
   managed-care event, any IDN-related event.

8. **Cycle timing.** Does this split on early-cycle vs late-cycle
   positioning? Rate-cycle events hit companies differently depending
   on whether their current book is re-priced, pending re-pricing, or
   just re-priced. Medicaid redetermination events hit differently by
   state redetermination schedule. Run this for any cycle-driven event.

9. **Size of exposure (concentrated vs diversified).** Does this split
   on whether exposed revenue is concentrated in one state / one
   product / one payer line vs spread across many? Concentrated
   exposures produce asymmetric moves. Run this for any state-level
   action, any product-specific action, any single-payer-line action.

10. **Durability / reversibility.** Does this split on whether the
    affected regime is durable (statute, Supreme Court precedent) vs
    reversible (admin action, circuit split, consent decree)? Durable
    events price differently than reversible ones. Run this for any
    legal / regulatory event where the appeal path or sunset clock is
    short.

## The canonical output

Phase 1.5 should produce a scratchpad like:

```
Candidate framings:
1. One-ticker (ELV is 60% HIP book) — too narrow, event affects all MCOs
2. Subsector exposure (MCOs bear cost) — obvious, no new info
3. Partisan (red states pick strict, blue states loose) — 7 states now acted, party split is 5-2
4. Mechanism (paperwork not work drives disenrollment) — Arkansas evidence strong
5. Timing (3-month maximum vs 6/12-month alternatives) — narrow axis, boring

Pick: #3 (partisan). Runner-up: #4 (mechanism), mention in Between the lines.
```

Write this down in your head (or as a brief draft) before dispatching
associates. The associates' briefs should be written to surface evidence
that validates OR kills your chosen frame — not to do open-ended
research.

## Traps

- **Don't pick the most analytical-sounding axis.** Pick the one the
  data supports. "Cycle timing" sounds clever but if the event affects
  all payers simultaneously, it's not the right axis.
- **Don't skip this phase on "obvious" events.** Earnings prints, rate
  notices, and M&A closes all have multiple valid framings. The
  "obvious" frame for an M&A close is "acquirer-target", but the real
  insight is often "what did they NOT buy" or "who's now the
  standalone competitor with the weakest position."
- **Don't pick more than one.** The temptation to cover two axes (e.g.
  "partisan AND mechanism") produces 90+ character titles. Pick one;
  the second-best goes in `Between the lines` or `Reality check`, not
  the title.
