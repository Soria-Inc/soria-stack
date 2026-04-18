---
name: tax-policy
description: >
  Use this playbook when the event is federal or state tax legislation,
  Treasury/IRS regulation, or court tax ruling affecting healthcare
  issuer cashflow. The core move is separating the four distinct
  mechanisms — one-time deferred-tax remeasurement, steady-state ETR
  walk, cash-tax trajectory, and NOL/VA dynamics — because they hit
  different lines and different periods. The canonical chart is a
  two-panel: GAAP ETR walk over 3 periods, and cash-tax trajectory
  over the same 3 periods, showing how GAAP and cash diverge.
---

# tax-policy

Tax policy coverage is usually the lowest-effort part of an analyst
note because the reader assumes "rate changes rate, multiply, done."
That misses most of the economics. The four mechanisms — DTA/DTL
remeasurement, steady-state ETR, cash taxes, and NOL carryforward
dynamics — are often opposite-signed, and the stock response depends
on which one the reader focuses on.

## When to apply

- Federal tax legislation signed or moving (TCJA-style corporate rate
  change, IRA §45X / §45V / §48D credits, BEAT / GILTI / FDII).
- Treasury or IRS proposed or final reg (PFIC, §199A, §165 loss rules,
  §163(j) interest limit, §162(m) executive comp cap, §274 meals).
- Treasury notice or revenue ruling.
- State corporate income tax rate change, throwback/throwout rule
  change, or combined-reporting adoption.
- Court rulings on tax (Tax Court, Court of Federal Claims, Circuit
  tax appeals, Supreme Court).
- OECD Pillar 2 / global minimum tax adoption milestones affecting
  a US issuer.

## Core moves

1. **Classify by mechanism.** Every tax event hits one or more of
   these four. Walk each separately:
   - **(a) One-time DTA/DTL remeasurement.** A rate change re-values
     the company's deferred-tax assets and liabilities. The hit is
     a single-period GAAP event, cash-flow-neutral. A net DTA company
     (like most healthcare services businesses with pre-tax losses in
     early growth) gets hurt by a rate CUT; a net DTL company helped.
   - **(b) Steady-state GAAP ETR change.** The new rate applies
     ongoing — this is the multi-period impact most analysts focus on.
   - **(c) Cash-tax trajectory.** GAAP taxes ≠ cash taxes. NOLs, R&D
     credits, §163(j) deferrals, and §174 capitalization create a
     multi-year gap. A policy change might hit GAAP ETR next quarter
     while cash taxes don't change for 3 years.
   - **(d) NOL / valuation-allowance dynamics.** Rate changes flow
     through existing NOLs (valuation at new rate), and often
     trigger VA releases or establishments. §382 can cap usability.

2. **Show the ETR walk.** Guide-in ETR vs. GAAP ETR vs. cash-tax ETR,
   for the past two full years, the current year, and the next two.
   The walk reveals which of the four mechanisms is actually moving
   the stock.

3. **Map to specific 10-K/10-Q line items.** The DTA/DTL remeasurement
   size comes directly from the tax footnote's DTA/DTL table. NOL
   carryforward balance is disclosed. VA is disclosed. Pull each
   number from the filing, not from an estimate.

4. **Separate the announce-vs-enacted timeline.** Under ASC 740,
   deferred-tax remeasurement happens in the period the legislation
   is ENACTED, not when it's effective. If signed December 2026 with
   a January 2027 effective date, the Q4 2026 print carries the
   remeasurement hit. Get the enactment-date math right.

5. **State conformity.** State corporate taxes (rates and base) vary
   in how they conform to federal. Rolling-conformity states
   auto-adopt; fixed-conformity states require state-legislative
   action. A federal change doesn't flow to the effective combined
   rate instantly — some states take a year or more. Name the
   conformity regime for each material state of operations.

## The canonical chart

Two-panel horizontal arrangement:

- **Panel 1 (GAAP ETR walk).** Stacked column by year: federal
  statutory rate at the base, state stack, FTC stack, R&D credit
  stack, NOL/VA stack, other. Total effective rate as the top line.
  Years: last year actual, current year pre-change, current year
  post-change, next year projected. The reader sees where the delta
  lives.

- **Panel 2 (cash-tax trajectory).** Line chart by year: GAAP tax
  expense vs. cash taxes paid vs. guided cash taxes. The gap
  between lines is the deferred/NOL dynamic. Reader sees whether
  cash-tax change lags GAAP-ETR change and by how much.

## Traps

- **Don't confuse the 21% statutory rate change with 21-point ETR
  change.** Healthcare issuers routinely run 15–19% ETRs because
  of R&D credits, FDII, and tax-loss harvesting in international
  ops. A statutory rate cut from 21 to 18 doesn't move a 17% ETR
  to 14% — it moves it to ~15% after the partial pass-through.
- **Don't ignore the GILTI/FDII/BEAT interactions.** The base
  erosion and foreign-income rules are deeply intertwined with
  statutory rate. A rate change without a BEAT change has
  nonlinear effects on multinationals.
- **Don't ignore ASC 740 tax-reserve releases.** A tax-law change
  can release UTBs (uncertain tax benefits) that were reserved under
  the prior regime. The release hits current-period GAAP taxes as
  a benefit, not an ongoing rate change.
- **Don't double-count the DTA remeasurement as a permanent
  earnings hit.** It's a single-period GAAP event. Pro-forma
  adjusted earnings typically exclude it, and comps will too.
  Quote the company's likely pro-forma treatment if its past
  disclosures are consistent.
- **Don't miss §382 on M&A-in-flight.** A pending deal with a
  target that has NOLs creates §382 limits upon closing; a tax-law
  change that alters §382 base year or interest rates affects the
  post-close utilization schedule.
