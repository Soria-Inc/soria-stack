---
name: legal-ruling
description: >
  Use this playbook when the event is a court decision, MDL verdict,
  settlement, consent decree, or injunction affecting healthcare
  issuers. The core move is the parallel-overhang table — mapping the
  ruling's scope against the set of companies with analogous exposure
  not bound by this ruling but persuaded by it. The canonical chart is
  the parallel-overhang table itself, ordered by impact per entity.
---

# legal-ruling

Court decisions move stocks in two layers: the direct impact on the
defendant(s) bound by the judgment, and the overhang on peers whose
analogous exposures become more likely to result in adverse judgment.
The second layer is where the stock move is usually mis-priced —
analysts under-weight it for rulings that bind few defendants and
over-weight it for rulings with narrow fact patterns.

## When to apply

- Circuit Court opinion (9th, DC, 11th, 5th are most-active in
  healthcare).
- District Court ruling on a motion (especially summary judgment,
  motion to dismiss, or Daubert).
- MDL bellwether verdict or global settlement.
- Settlement / consent decree (SEC, DOJ, OIG, state AG).
- Class certification or decertification order.
- Supreme Court cert grant, cert denial, or merits opinion.
- International arbitration award if the exposed party is a material
  healthcare issuer.

## Core moves

1. **Default zoom is industry, not company.** A ruling that voids a
   state law, narrows an agency's authority, or reshapes a common-law
   doctrine affects the whole industry operating under that regime.
   The most-exposed ticker is a secondary point, not the headline.
   Lead with `Court ruling preserves [industry] [mechanism]`, not
   `[Ticker]'s win`. Only zoom to single-ticker framing when the
   event's economics are ≥60% concentrated in that name — typical
   examples: a settlement that only one defendant signed, a ruling
   against a specific product that only one company sells. The
   canonical failure mode here was the AB 290 / DaVita note: the
   9th Circuit voided a California dialysis rate-cap statute that
   affected the entire industry, and the draft spent 8 revisions
   titled `DaVita's AB 290 "Win" Protects a Precedent` before landing
   at `Court ruling preserves dialysis industry's highest-margin
   revenue channel`. The second title is what the PM wanted; the
   first buried the read-through by fixating on the most-exposed
   ticker.

2. **Scope map — who is directly bound.** Name the defendants. Name
   the jurisdiction (Circuit, District, state). A 9th Circuit
   opinion binds AK, AZ, CA, HI, ID, MT, NV, OR, WA, plus Guam/NMI. An
   MDL verdict binds only the plaintiffs in that case. A consent
   decree binds only the signing parties. The scope is the floor.

3. **Parallel-overhang table.** For every peer with analogous exposure,
   list: (a) company ticker, (b) analog exposure scope (how many cases,
   how many products, how many years), (c) rough $ exposure at
   settlement-grade valuation, (d) "bound / persuaded / uncorrelated"
   classification. The ruling binds the defendants; it persuades
   same-Circuit peers; it is cited by other-Circuit peers but not
   controlling. Quantify the persuasion discount — 50–80% of the
   direct-hit value for same-Circuit, 15–35% for other-Circuit.

4. **Reversibility.** Name the appeal path with dates. Circuit opinion
   → petition for rehearing en banc (14-day clock) → cert petition
   (90 days). District court adverse ruling → interlocutory appeal if
   the judge certifies, otherwise wait for final judgment. Settlement
   → approval by court after fairness hearing (30–90 days). The
   reversibility probability × time-to-finality is an embedded option
   in the stock price.

5. **Damages vs. reserve gap.** If the defendant had reserved for this
   outcome at the prior 10-Q, the hit is near-zero to EPS — it just
   drawn down reserves. If the verdict exceeds reserves, the marginal
   dollar hits EPS. Look at the 10-Q loss-contingency note and name
   the reserve number explicitly.

6. **Precedent-citation timeline.** For opinions, grep Westlaw (or
   scholar-grade proxy) for how many subsequent opinions cited the
   original within the last analogous ruling cycle. 3+ citations in
   12 months means the case is traveling; 0 means it was an
   idiosyncratic fact pattern.

## The canonical chart

Parallel-overhang table, not a chart. Columns: Ticker | Analog
exposure | Probability of adverse outcome (bound / persuaded /
uncorrelated) | Dollar exposure at settlement-grade | Reserved |
Net-of-reserve EPS impact. Sort descending by net-of-reserve EPS
impact. This table is usually what the buy-side wants.

If a chart is required: waterfall of dollar-exposure (tickers on
X-axis, bars colored by bound/persuaded/uncorrelated, height = net-
of-reserve exposure). Reserved amounts shown as a dashed negative
overlay.

## Traps

- **Don't conflate scope with impact.** A narrow 9th Circuit ruling
  that binds 2 defendants may still cause an 8% sector move because
  the read-across precedent is large. Conversely, a wide DC Circuit
  ruling that sounds huge may bind no live cases.
- **Don't trust the plaintiffs' bar's damages number.** The $X
  billion figure quoted in the article is usually the demand, not
  the likely award. Use a midpoint of demand-vs-defense-estimate
  weighted by the Daubert ruling's narrative.
- **Don't ignore the Government's amicus posture.** If the DOJ filed
  an amicus in favor of the prevailing side, the cert path is much
  harder (SCOTUS defers to the SG). Name the DOJ position.
- **Don't assume settlement ends the exposure.** Settlements
  frequently cover only a named set of claims. Read the release
  language. Remaining exposures after settlement are sometimes MORE
  material than the settled ones, because the cap is now calibrated.
- **Don't ignore the judge who wrote it.** A 9th Circuit opinion by
  Judge Smith (frequently reversed by SCOTUS) is less durable than
  one by Judge Jones (rarely reversed). This is fuzzy; still worth
  a sentence.
