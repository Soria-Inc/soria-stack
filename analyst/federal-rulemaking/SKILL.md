---
name: federal-rulemaking
description: >
  Use this playbook when the event is a federal NPRM, Final Rule, rate
  notice, advisory, or significant agency guidance from CMS, FDA, HHS,
  Treasury, FTC, or SEC affecting healthcare issuers. The job is to
  compute the Final-vs-Proposed delta, set the number against its
  multi-cycle reference class, and translate to per-company $/EPS. The
  canonical chart is the multi-cycle history (advance vs. final, or
  proposed vs. final) with the current cycle on the right edge.
---

# federal-rulemaking

Federal rulemakings move stocks because they change the unit economics
of a regulated line of business — Medicare Advantage, Part D, 340B,
Medicaid DSH, HIX risk-adjustment, hospital wage index, ambulatory
payment classifications, device-reimbursement codes, PBM transparency,
etc. The event itself is a document; the note's value is turning the
document into FY cashflow the reader can compare to consensus.

## When to apply

- CMS Advance or Final Rate Notice (MA, Part D, ESRD, SNF, IRF, IPPS,
  OPPS, HHA, hospice).
- HHS / CMS NPRM or Final Rule in the Federal Register.
- FDA proposed rule or guidance document (device classification, tobacco,
  drug-compounding, lab-developed tests, 510(k) modernization).
- Treasury / IRS proposed or final regs with healthcare-specific impact
  (IRA drug pricing, §45V, §45X, §48D, NOL limits, §162(m)).
- FTC or SEC proposed or final rules touching PBMs, non-competes,
  hospital M&A reporting, PE disclosure.
- Agency sub-regulatory guidance (CMS State Medicaid Director letters,
  FDA Q&A, HHS OIG advisory opinions) that re-interprets an existing rule.

## Core moves

1. **Final vs. Proposed delta.** The alpha is the delta between the
   advance/proposed and the final. A rule that finalized as proposed is
   lower-information than a rule that moved. Name the delta in basis
   points (or the rule's native unit) and name WHICH comment letters
   moved it. If the agency cited industry comments in the preamble,
   quote the sentence and link the specific comment.

2. **Multi-cycle reference class.** A number in isolation is noise. The
   signal is the trajectory. For rate notices: show advance-vs-final for
   the last 3–5 cycles AND prior-admin vs. current-admin to separate
   cyclical policy drift from idiosyncratic. For NPRMs that reset an
   existing program: compare scope/threshold/rate against the version
   being replaced and against the version two revisions back.

3. **Per-company $/EPS.** Translate the rule to dollars per affected
   issuer. The walk is rate × exposed revenue × margin × (1 − ETR) ÷
   diluted shares. Show the math in a numbered footnote with each
   operand linked to its primary source (10-K segment disclosure, CMS
   enrollment file, Q2 shares outstanding). Do this for every ticker
   that's material — not just the obvious one. Don't do it for tickers
   where the exposure is rounding-error.

4. **Comment-period → effective-date clock.** Final rules have an
   effective date; NPRMs have a comment period followed by a final rule
   with its own effective date. Name the date. If the rule is finalized
   under the Congressional Review Act window, flag the joint-resolution
   risk.

5. **What the preamble actually said about industry.** Agency preambles
   frequently give away signal about the next cycle (CMS saying "we
   received extensive comment on X and will consider it in the CY20XX+1
   rulemaking" is a dated forward commitment). Mine the preamble — don't
   just read the rule text.

## The canonical chart

Multi-cycle bar or line chart: one bar per cycle, two series per cycle
(advance vs. final, or proposed vs. final, depending on rule type). The
current cycle is the rightmost pair. The reader sees at a glance whether
this cycle's agency "pullback" (delta from advance to final) is large
or small by historical standards.

For rules without a multi-cycle structure (one-off NPRMs), use a
per-company dot plot of $/EPS impact, ticker on Y-axis, $/EPS on X-axis,
reference-line at $0.

## Traps

- **Don't quote the rule's rate in isolation.** 2.48% means nothing
  without 0.09% (the advance) and 3.32% / 4.97% (the prior two admins'
  finals). The comparison IS the insight.
- **Don't assume the company's guidance-exclusion means the impact is
  zero.** The company said "excludes impact of new rule." You should
  estimate the impact from the rule's own RIA + the company's segment
  disclosure. The exclusion is a choice to strip noise from guidance,
  not a statement about the economics.
- **Don't confuse rate increase with revenue impact.** A 2.48% payment-
  rate increase on a business with a 3.2% medical trend is still
  negative unit margin. Name the delta to trend, not just the raw rate.
- **Don't treat RIA numbers as ground truth.** Agency Regulatory Impact
  Analyses chronically understate effects because they omit behavioral
  responses and cost-sharing cascades. Compare the RIA to an independent
  estimate (MedPAC, CBO, a trade association's actuarial brief) and
  show both.
