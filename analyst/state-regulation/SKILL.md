---
name: state-regulation
description: >
  Use this playbook when the event is a state statute, regulation,
  ballot measure, AG action, or commissioner order affecting healthcare
  issuers. The core move is sibling-state extrapolation — a policy
  adopted in one state is a preview of adoption in the 4–12 states with
  similar politics and insurance-market structure. The canonical chart
  is a state-adoption map or a state-count timeline with the adopted
  state and sibling states called out.
---

# state-regulation

State-level healthcare regulation moves stocks through two channels:
direct impact on exposed revenue in that state, and forward-looking
read-across to peer states that tend to follow. Most analysts miss the
second channel, which is usually the bigger one. A law passed in
California or New York doesn't bind Texas, but it does meaningfully
raise the probability that Massachusetts, Illinois, Washington, New
Jersey, Oregon, and Colorado adopt similar language within 18 months.

## When to apply

- State legislature passes healthcare statute (enacted or on the way
  to the governor's desk).
- State Department of Insurance / DOI order or rule (rate approval,
  formulary, prior-auth, network-adequacy).
- State Attorney General action — lawsuit filed, settlement, consent
  decree against a PBM, insurer, hospital system.
- State ballot measure qualifying, on the ballot, or certified.
- State executive order by a governor.
- State Medicaid agency waiver filing (1115, 1915) or waiver approval/
  denial by CMS.
- State-based marketplace policy (formulary, network, subsidy) change.

## Core moves

1. **Identify the reference class.** Not every state is a bellwether.
   California tends to be followed by NY, MA, WA, OR, NJ, IL, CO. Texas
   is followed by FL, GA, AZ, TN, MO. Colorado health-policy laws
   (prescription drug board, public option) have a different following
   because CO is a laboratory state. Name the 4–8 most-likely-to-follow
   states for THIS specific policy type. Don't just say "this is a
   blue-state policy."

2. **Sibling-state extrapolation.** For each of the siblings, name the
   nearest-analog legislation currently pending, already introduced, or
   in an active committee-study phase. If you can find 3 pending bills
   that copy language from the enacted state, you have a 12-month
   adoption forecast.

3. **Direct-impact estimate in the adopting state.** Walk the economics
   for the state: state-level population × penetration × affected
   revenue × margin impact. For state-level policy, the 10-Q segment
   disclosures are almost never granular enough — use the companies'
   annual state-by-state filings with NAIC (for insurers) or state DOI
   rate filings (for rate-regulated lines), or CMS public use files.

4. **Read-across discounting.** The sibling-state impact is probability-
   weighted by adoption probability AND timing. A CA law passed today
   that 5 sibling states "will probably" adopt over 18–36 months is not
   5× the CA impact — it's ~1.5–2.5× at NPV, applying 40–60% probability
   and 15–30% discount per year.

5. **What changed about the political path.** A statute that passed a
   chamber but was vetoed is a data point. A statute that the governor
   signed vs. a statute that became law without signature vs. a statute
   that got a ballot-measure override are all different political
   signals about durability.

## The canonical chart

US state map (choropleth) colored by status: (dark) enacted, (medium)
pending in legislature, (light) bills introduced or actively studied,
(uncolored) nothing pending. Annotate the adopting state with the
effective date; annotate the top 3 sibling states with the
bill number and date.

Alternative: time-series state count (cumulative adoptions on Y-axis,
month on X-axis) with the current state highlighted and the next
4–8 sibling-state bills projected as a forecast band. This is better
when the map understates the momentum (e.g., early stage of adoption
wave where only 2 states have acted).

## Traps

- **Don't count states that can't enact this.** Dillon's Rule states,
  preemption issues, and constitutional limits actually block
  adoption in some states regardless of political will. ERISA
  preemption, in particular, carves out most PBM regulation from
  state action for self-insured plans.
- **Don't let prior state laws double-count.** If three states already
  did this, the new state is incremental — the exposed revenue for
  national players is only the state that just enacted, not the
  cumulative four.
- **Don't use national membership data to estimate state-level
  impact.** National MA enrollment is 30M; the state in question might
  have 1.2M. Get the state-specific number from CMS Geographic
  Variation or NAIC state filings.
- **Don't forget cost-sharing limits are often retroactive.** A state
  insulin cap signed in October is usually effective Jan 1 — that's
  10 weeks, not 52, of partial-year impact for the current fiscal.
