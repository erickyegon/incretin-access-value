# Module E in plain language: what covering Wegovy and Zepbound could cost a Medicaid programme

**Question.** What would covering Wegovy and Zepbound for obesity cost a Medicaid programme of 1 million enrollees over five years, and how much do access policy, price and uptake change that?
(Plan: [plan_moduleE.md](../plan_moduleE.md), committed before any result; departures in [deviations.md](deviations.md), item 12 is the prior authorization change; method follows the ISPOR budget impact guideline, [saved page](../../docs/sources/ispor_budget_impact_good_practice_II.html).)

**How it works.** The extra prescriptions per 1,000 enrollees per quarter that Module C attributes to coverage (quarters 1 to 9; [inputs](tables/moduleC_for_budget_model.csv)) are scaled to 1 million enrollees and priced.
Module C measures prescriptions actually filled in the ten covering states, under the prior authorization (PA) rules those states actually used (9 of the 10 recorded PA; Tennessee's is not recorded; BMI 30 or more, with BMI 27 to 29 allowed with a weight-related condition, is recorded for Mississippi, North Carolina and Kansas and for Pennsylvania with prescriber-determined candidacy; the other six states' thresholds are not recorded in [the coverage file](../../data/reference/medicaid_obesity_coverage.csv)).
So the central case uses the effect as observed (PA multiplier 1.0, "PA as observed in the 10 covering states"), discontinuation is already in the uptake, and no persistence is added. Tight PA (multiplier 0.5 to 0.75) and loose PA (up to 1.25) are assumptions ([PA scenarios](tables/moduleE_pa_scenarios.csv)). Years 3 to 5 are scenarios (plateau, continued growth, decline).

## Results (central case: plateau, PA as observed, rebate 51.2% = midpoint of 23.1% and 79.3%)
- **Five-year net cost** $161.3 million, **$2.69 per enrollee per month**; gross cost $330.7 million ($5.51 per enrollee per month) before rebates. Net cost by year is $11.4, $30.3 and then $39.9 million a year ([annual table](tables/moduleE_central_annual.csv)).
- **Users.** About 15,900 members a year at the plateau (at the 4.3 purchases per user-year MEPS shows), 5.3% of the 300,900 eligible Medicaid adults in the plan; the model never exceeds the eligible pool.
- **Net cost per user per year** (4.3 fills a year, MEPS, sourced): $2,511. **Net cost per member-year of continuous treatment** (12 fills a year, assumption): $6,943. They answer different questions: the first is what an observed user costs, the second what a member on treatment all year would cost.
- **Probabilistic range** (10,000 draws): median $145.4 million, 90% interval $58.1 million to $319.9 million; if the event-time effects move together, $50.3 million to $347.3 million ([summary](tables/moduleE_psa_summary.csv), [figure](figures/43_psa_distribution.png)).
- **Scenarios** ([table](tables/moduleE_scenario_results.csv), [figure](figures/42_cost_by_scenario.png)): net five-year cost runs from $55.6 million (decline after year 2, rebate of 79.3% implied by $245) to $369.4 million (continued growth, rebate of 23.1%, the statutory minimum).
- **Announced price.** At $245 per monthly prescription (White House fact sheet, November 2025, which says state Medicaid programmes can access the drugs at these prices), the plateau case costs $68.3 million over five years, or $1.14 per enrollee per month.
- **Prior authorization scenarios** (five-year net, central rebate): tight PA 0.5 gives $80.7 million, 0.75 gives $121.0 million, loose PA 1.25 gives $201.6 million.

## What moves the answer ([tornado](figures/40_tornado.png), [waterfall](figures/41_waterfall_pmpm.png))
The widest swings in five-year net cost are the uncertainty in Module C's effect ($63.7 million to $258.9 million) and the rebate ($68.3 million at a 79.3% rebate to $254.3 million at 23.1%). Then come the PA multiplier ($80.7 million at 0.5 to $201.6 million at 1.25), years 3 to 5 ($131.4 million to $234.3 million) and the uptake multiplier ($121.0 million to $201.6 million); the gross cost per prescription matters least ($158.4 million to $170.3 million).

## What is measured and what is assumed ([all inputs](tables/moduleE_assumptions.csv))
Measured: the Module C effects; the gross reimbursement per prescription in covering states, $1,186 (range $1,164 to $1,252; Wegovy about $1,300 and Zepbound about $1,050 in 2025), which agrees with NADAC price times units per prescription to within 3% ([cross-check](tables/moduleE_nadac_crosscheck.csv));
the adult share of enrollment (57.9%) and the eligible share of Medicaid adults (52%, a lower bound, from Module B). Sourced: the 23.1% statutory minimum Medicaid rebate (42 U.S.C. 1396r-8) and the $245 announced price.
Assumed: the rebate between 23.1% and 79.3% (actual net prices are confidential; the central 51.2% is their midpoint), the PA scenarios around the observed 1.0, years 3 to 5, and one prescription being about one month.
No medical cost offsets are included: no published source supporting a five-year offset was retrieved.

## Context: spending of adults with obesity or diabetes (MEPS, [table](tables/moduleE_meps_background_spending.csv))
Mean annual spending per adult with an obesity condition record was $16,139 in 2023 and $22,130 in 2024, and with type 2 diabetes $19,992 and $21,139, against $8,743 and $9,629 for all adults; context only, not the cost of a condition.

## What this does not show
Not a forecast, not net prices, not health outcomes; a commercial plan would differ. SDUD amounts are gross of rebates. The effect comes from ten treated states and may not carry over to other states or later years.

**Tools.** Interactive model: `shiny::runApp("app")` ([DEPLOY.md](../../app/DEPLOY.md) has the deployment steps; it is not deployed). Static fallback: [budget_impact_scenarios.pdf](budget_impact_scenarios.pdf).
