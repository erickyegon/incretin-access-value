# Module E in plain language: what covering Wegovy and Zepbound could cost a Medicaid programme

**Question.** What would covering Wegovy and Zepbound for obesity cost a Medicaid programme of 1 million enrollees over five years, and how much do access policy, price and uptake change that?
(Plan: [plan_moduleE.md](../plan_moduleE.md), committed before any result; departures in [deviations.md](deviations.md); method follows the ISPOR budget impact guideline, [saved page](../../docs/sources/ispor_budget_impact_good_practice_II.html).)

**How it works.** The extra prescriptions per 1,000 enrollees per quarter that Module C attributes to coverage (quarters 1 to 9; [inputs](tables/moduleC_for_budget_model.csv)) are scaled to 1 million enrollees and priced.
Because Module C measures prescriptions actually filled, discontinuation is already in the uptake and no trial persistence is added; the estimate reflects the 2021–2025 market. Years 3 to 5 are scenarios (plateau, continued growth, decline).

## Results (central case: plateau, prior authorization multiplier 0.75, midpoint rebate)
- **Five-year net cost** $121.0 million, **$2.02 per enrollee per month**; gross cost $248.0 million ($4.13 per enrollee per month) before rebates. Year by year the net cost is $8.6, $22.7 and then $29.9 million a year ([annual table](tables/moduleE_central_annual.csv)).
- **Treated members.** About 11,900 members a year at the plateau (at the 4.3 purchases per user-year MEPS shows), 4% of the 300,900 eligible Medicaid adults in the plan; the model never exceeds the eligible pool.
- **Cost per incremental treated member-year** $6,943 net (a prescription taken as one month of drug).
- **Probabilistic range** (10,000 draws): median $118.3 million, 90% interval $46.7 million to $265.2 million; if the event-time effects move together, $40.7 million to $286.7 million ([summary](tables/moduleE_psa_summary.csv), [figure](figures/43_psa_distribution.png)).
- **Scenarios** ([table](tables/moduleE_scenario_results.csv), [figure](figures/42_cost_by_scenario.png)): net five-year cost runs from $41.7 million (decline after year 2, rebate implied by $245) to $277.1 million (continued growth, statutory-minimum rebate).
- **Announced price.** At $245 per monthly prescription (White House fact sheet, November 2025, which says state Medicaid programmes can access the drugs at these prices), the plateau case costs $51.2 million, or $0.85 per enrollee per month.

## What moves the answer ([tornado](figures/40_tornado.png), [waterfall](figures/41_waterfall_pmpm.png))
The two widest swings are the uncertainty in Module C's effect ($47.8 million to $194.2 million) and the rebate ($51.2 million at the rebate implied by $245 to $190.7 million at the 23.1% statutory minimum). Then come the prior authorization multiplier ($80.7 million to $161.3 million), years 3 to 5 ($98.6 million to $175.7 million) and the uptake multiplier; the gross cost per prescription matters least ($118.8 million to $127.7 million).

## What is measured and what is assumed ([all inputs](tables/moduleE_assumptions.csv))
Measured: the Module C effects; the gross reimbursement per prescription in covering states, $1,186 (range $1,164 to $1,252; Wegovy about $1,300 and Zepbound about $1,050 in 2025), which agrees with NADAC price times units per prescription to within 3% ([cross-check](tables/moduleE_nadac_crosscheck.csv));
the adult share of enrollment (57.9%) and the eligible share of Medicaid adults (52%, a lower bound, from Module B). Sourced: the 23.1% statutory minimum Medicaid rebate (42 U.S.C. 1396r-8) and the $245 announced price.
Assumed: the rebate between those two (actual net prices are confidential), the prior authorization multiplier (0.5 to 1.0), years 3 to 5, and one prescription being about one month.
No medical cost offsets are included: no published source supporting a five-year offset was retrieved.

## Context: spending of adults with obesity or diabetes (MEPS, [table](tables/moduleE_meps_background_spending.csv))
Mean annual spending per adult with an obesity condition record was $16,139 in 2023 and $22,130 in 2024, and with type 2 diabetes $19,992 and $21,139, against $8,743 and $9,629 for all adults; context only, not the cost of a condition.

## What this does not show
Not a forecast, not net prices, not health outcomes; a commercial plan would differ. SDUD amounts are gross of rebates. The effect comes from ten treated states and may not carry over to other states or later years.

**Tools.** Interactive model: `shiny::runApp("app")` ([DEPLOY.md](../../app/DEPLOY.md) has the deployment steps; it is not deployed). Static fallback: [budget_impact_scenarios.pdf](budget_impact_scenarios.pdf).
