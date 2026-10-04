# Module E plan: payer budget impact model

Written before any Module E result. Changes after results go in `analysis/outputs/deviations.md`.

## Question
What would covering Wegovy and Zepbound for obesity cost a Medicaid programme of 1 million enrollees over five years, and how much do access policy, price and uptake change that?

## Design (ISPOR good practice)
Follows the ISPOR Task Force report "Principles of Good Practice for Budget Impact Analysis II" (Sullivan SD, Mauskopf JA, Augustovski F, et al., Value in Health 2014;17(1):5-14; page saved as `docs/sources/ispor_budget_impact_good_practice_II.*`): explicit perspective, time horizon, target population, scenarios (with and without coverage), cost inputs, uncertainty (one-way and probabilistic), and transparent reporting.
- **Perspective:** a state Medicaid programme (Module C's evidence is Medicaid). A commercial plan would differ (different population, rebates and utilization management).
- **Horizon:** five years, by quarter (20 quarters), reported annually. Plan size 1,000,000 enrollees (a slider in the app).
- **Population:** all Medicaid enrollees (total Medicaid enrollment, item 8a, the same denominator as Module C); the adult share is measured from the warehouse adult-enrollment field (available from 2024 Q3).
- **Scenarios:** coverage versus no coverage; the budget impact is the difference, i.e. the incremental prescriptions that Module C attributes to coverage.

## Core logic (prescription based; real-world persistence is already in the observed uptake)
incremental prescriptions in quarter q = ATT(e) per 1,000 enrollees x (plan size / 1,000) x access-policy multiplier x uptake multiplier, with e = q - 1 for the first nine quarters (Module C dynamic ATT at e = 0 to +8, `moduleC_for_budget_model.csv`: pointwise SEs and CIs). Module C measures observed fills, so discontinuation is already in the uptake: **no trial persistence is applied on top.** Strength: it reflects real-world use. Limitation: it reflects the 2021-2025 market (products, prices, supply, other coverage) and 10 treated states.
- **Quarters 10-20 (years 3-5, beyond e = 8):** three labelled-assumption scenarios: (1) plateau at the e = 8 level; (2) continued growth, the e = 0 to 8 linear trend of the ATT per quarter extended; (3) decline, the effect falling linearly from the e = 8 level to half of it by quarter 20.
- **Note on the effect's growth:** part of Module C's growth with event time reflects national market growth over the same calendar quarters (stated in the hand-off file).

## Costs
- **Gross cost per prescription:** `total_amount_reimbursed / prescriptions` for Wegovy and Zepbound in states with active coverage, by quarter (`mart_sdud_state_quarter_brand`); cross-check: NADAC per unit (`mart_nadac_brand_quarter`) x units per prescription (SDUD units / prescriptions). Both are gross of rebates. The model uses the 2025 level as the central value with the observed range across quarters as the range.
- **Rebates:** net cost = gross x (1 - rebate). Lower bound: the statutory minimum Medicaid rebate for single source and innovator multiple source drugs, 23.1% of the average manufacturer price (Social Security Act section 1927(c)(1)(B), 42 U.S.C. 1396r-8, `docs/sources/uscode_42_1396r8_medicaid_drug_rebate.*`); a rebate can be larger (the greater of that and the AMP-best price difference, plus inflation penalties), and actual state net prices are confidential. Upper bound: the rebate implied by the announced public-programme price (below). Central: the midpoint, labelled an assumption. Never presented as fact.
- **Announced-price scenario (named):** White House fact sheet, November 2025: "State Medicaid programs will also have access to these medications at these prices" with a Medicare price of $245 for Ozempic, Wegovy, Mounjaro and Zepbound (`docs/sources/whitehouse_fact_sheet_mfn_2025-11.*`). Used as a net cost of $245 per monthly prescription, assuming one SDUD prescription is about one month of drug (checked against units per prescription); the document does not say per what unit beyond "per month", and whether state Medicaid net prices equal it is not stated.
- **Access policy:** prior authorization tight versus loose as an uptake multiplier on the observed effect, 0.5 to 1.0 (labelled assumption: Module C cannot estimate PA strictness, and the states differ in criteria).
- **Medical cost offsets:** none in the base case. No offset scenario unless a retrieved published source supports one; none has been retrieved, so none is included.
- **Population check:** implied treated members = prescriptions in a year / purchases per user-year (MEPS 2023-2024: adult users of obesity-labelled incretins averaged 2.7 and 4.4 purchase records in the year, partial years included; the range 2.7 to 12 is used, 12 = monthly purchase all year, an assumption) compared with eligible Medicaid adults in the plan: adults share of Medicaid enrollment (warehouse, measured from 2024 Q3) x the eligible share of adults with Medicaid from Module B (17.8 of 34.3 million, 2021-2023, lower bound). Flag if the implied members exceed the eligible pool.
- **Treated member-years:** prescriptions / 12 (one prescription is about one month), used for cost per incremental treated member-year.
- **Background costs (context only):** MEPS 2023 and 2024 annual spending (total and prescribed medicines) for adults with an E66 obesity condition record and with E11 type 2 diabetes, survey-weighted (`varstr`, `varpsu`, person weight).

## Sensitivity
- **One-way** on every parameter across its range (tornado of the five-year net budget impact): Module C effect (95% CI of every e), uptake multiplier, access-policy multiplier, years 3-5 scenario, gross cost per prescription, rebate, price scenario, plan size is held at 1 million.
- **Probabilistic** (10,000 draws, seed 20261004 + 5000): Module C effects normal(estimate, SE) per event time, **independent across event times (correlation between event times is ignored: the covariance of e = 4 to 8 was not saved; a second run with one common draw, perfect correlation, is reported as the other bound)**; gross cost uniform over the observed range; rebate, PA multiplier and years 3-5 scenario from their ranges. Report the median and 90% interval.
- **Outputs:** annual and five-year budget impact (gross and net), per member per month (PMPM, over all enrollees), cost per incremental treated member-year.

## Figures, app and PDF
Tornado; waterfall from gross cost to net PMPM; five-year cost by scenario; PSA distribution. Shiny app in `app/` (runs locally with `shiny::runApp("app")`; not deployed; `app/DEPLOY.md` has the steps for Posit Connect Cloud or shinyapps.io); static PDF `outputs/budget_impact_scenarios.pdf`.
