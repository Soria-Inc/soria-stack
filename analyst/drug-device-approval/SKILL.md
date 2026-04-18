---
name: drug-device-approval
description: >
  Use this playbook when the event is an FDA approval, Complete Response
  Letter (CRL), label expansion, advisory-committee vote (ODAC, EMDAC,
  etc.), or post-market action against a healthcare issuer's product.
  The core move is the label-vs-trial delta — what the FDA granted
  against what the Phase 3 read supported — which drives peak-sales
  potential and the analyst-model delta. The canonical chart is the
  per-indication peak-sales waterfall, with the approved indication(s)
  in full bars and deferred/rejected ones in dotted outline.
---

# drug-device-approval

Drug and device approvals move stocks because they resolve a specific
binary (approved / not) against an embedded option in the price. The
easy analyst error is treating approval as a uniform good — as if
"approved" means the same thing regardless of label. What matters is
the label: the indication, line of therapy, patient population,
safety/REMS carve-outs, and any DCV (Dear Clinician Letter) companion
requirements.

## When to apply

- FDA Drug approval (NDA, BLA, sBLA), ANDA, 510(k), PMA, De Novo.
- FDA Complete Response Letter (CRL).
- FDA label expansion (sBLA / sNDA) or label update (REMS change,
  boxed warning add/remove).
- Advisory committee vote (ODAC, EMDAC, AADPAC, GIDAC, etc.) —
  binding on FDA is weak but prices move anyway.
- FDA-issued breakthrough / accelerated approval / priority review
  designation.
- Post-market action: market withdrawal, recall, REMS modification,
  FDA warning letter.
- Patent litigation outcome that modifies approval timing.

## Core moves

1. **Label-vs-trial delta.** Pull the approved label. Compare to the
   Phase 3 inclusion/exclusion criteria that supported it. An approval
   that's narrower than the trial (e.g., 2L+ only when the trial
   tested 1L too) cuts the addressable patient pool by a defined
   fraction. An approval with a REMS/boxed warning adds friction. Name
   the delta in patient-population units, not vague words.

2. **Peak-sales walk.** For approvals: diagnosed prevalence × treatment
   rate × drug-share in the approved line × WAC × GTN × (1 − loss-of-
   exclusivity year discount). Every operand gets a primary-source
   footnote: prevalence from a peer-reviewed epidemiology paper, the
   company's own 10-K, or CMS Medicare utilization files; WAC from
   RED Book or the company's price announcement; GTN from prior-launch
   analogs disclosed in 10-K. Don't use street peak-sales estimates
   as inputs — use them as a calibration check.

3. **CRL type, not just "CRL".** There are three buckets:
   - **Clinical CRL.** FDA wants new data. 12–36 month delay. Often
     requires a new trial. Treat as LOE-style revenue impairment until
     the resubmission.
   - **CMC/manufacturing CRL.** FDA wants process fixes. 3–9 month
     delay. No new clinical data. Lower-impact.
   - **Labeling CRL.** FDA wants label changes (carve-out, warning).
     30–90 day delay. Lowest-impact.
   Mis-classifying CRL type is the most common drug-approval note
   error.

4. **AdComm vote interpretation.** The vote isn't binding, but the
   briefing document is. If the FDA's own briefing doc was critical
   and the vote went negative, approval probability drops to ~15%. If
   the briefing doc was supportive and the vote went negative on
   narrow issues, probability is 50–60%. If the briefing doc AND vote
   were supportive, probability is 85%+. Quote the briefing-doc
   language.

5. **Competitive context.** A first-in-class approval vs. a me-too in
   a crowded class are different events. Name the competitor labels,
   launch dates, and pricing. A me-too approval with 3 prior entrants
   at lower WAC has near-zero incremental sales opportunity unless the
   safety profile is materially better.

6. **Launch readiness signals.** On approval day, the company has
   usually (a) issued a press release, (b) trained a sales force, (c)
   filed patent dosing/formulation protections. Check for (d) an
   NDA-to-commercial-launch track record — companies that habitually
   launch within 60 days of approval differ meaningfully from those
   that take 6+ months.

## The canonical chart

Per-indication peak-sales waterfall. X-axis = the distinct indications
evaluated in the approval package (or the distinct lines of therapy).
Y-axis = probability-weighted peak-sales dollars. Solid bars for
approved; dashed outlines for deferred / rejected. A total-peak
bar on the right summing all approved indications.

Alternative for CRLs: timeline with prior CRLs in the class (last
5–10 years), color-coded by CRL type, with median resubmission-to-
approval time as a reference line. The reader sees how this CRL
compares to class base rates.

Alternative for label-expansion events: before-and-after addressable
patient population, showing the incremental patients the label change
unlocks.

## Traps

- **Don't ignore the Prescribing Information's "Limitations of Use"
  section.** This carves out patient subgroups the drug is NOT
  approved for — frequently a large fraction of what analysts assumed.
- **Don't use the unadjusted ORR or PFS number from the PR as-is for
  launch modeling.** The label's description of efficacy is what
  payers + prescribers read. If the PR led with ORR and the label
  led with PFS, the commercial positioning is different.
- **Don't assume an AdComm vote is the decision.** The FDA can and
  does over-ride AdComms (both ways). Weight it, don't finalize on
  it.
- **Don't ignore the REMS program cost.** A REMS with ETASU
  (restrictive distribution) shaves 10–30% off peak sales through
  prescribing friction. Deduct it explicitly.
- **Don't forget the label's indication-vs-mechanism split.** A
  drug approved for ONE indication in a mechanism class where 3 more
  indications are in late-stage is priced on the full pipeline, not
  the approved label alone. The correct note scopes to today's label
  but annotates the option value of the pipeline.
