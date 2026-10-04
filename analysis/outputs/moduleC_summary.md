# Module C in plain language: state Medicaid coverage of Wegovy and Zepbound

**Question.** When a state Medicaid program starts covering Wegovy and Zepbound for obesity, how much does use rise, and how fast? What do the first withdrawals suggest?
(Plan: [analysis_plan_moduleC.md](../analysis_plan_moduleC.md), written before any model was run; changes after results are in [deviations.md](deviations.md).)

**Data.** Medicaid prescriptions per 1,000 Medicaid enrollees, 2018 Q1 to 2025 Q3 (CMS State Drug Utilization Data, gross of rebates). The primary analysis uses 44 jurisdictions: 10 treated states and 34 never-treated states; the 7 states with uncertain start dates are excluded from it and appear only in sensitivity 9. Coverage start dates come from state documents
( [coverage_timing_by_state.csv](tables/coverage_timing_by_state.csv), [map](figures/01_coverage_timing_map.png)). Counts under 11 are hidden by CMS; at most 1.0% of
Wegovy/Zepbound prescriptions sit in hidden cells from 2023 Q1 ([chart](figures/04_suppression_share.png)), and I filled them in 20 times at random within the possible range, which changes nothing
([imputation_log.csv](tables/imputation_log.csv)).

## What the estimates are
- **Level.** In 2025 Q3 the 10 covering states averaged 27.7 observed Wegovy/Zepbound prescriptions per 1,000 enrollees; the never-treated states averaged 1.0 including the filled-in hidden cells (0.9 from observed counts alone) ([raw trends](figures/03_raw_trends_by_cohort.png), [baseline](tables/moduleC_for_budget_model.csv)).
- **Overall effect.** Coverage is associated with 12.2 more prescriptions per 1,000 enrollees on average after it begins (95% CI 8.4 to 16.0) ([overall_att.html](tables/overall_att.html)).
- **How fast.** 1.3 (95% CI 0.5 to 2.1) in the first quarter, 11.7 (2.8 to 20.7) after 4 quarters and 17.2 (7.4 to 27.0) after 8 quarters ([event study](figures/10_event_study_primary.png), [table](tables/event_study_primary.csv)).
  Part of the growth reflects the national market growing over the same calendar quarters, since later event times fall in later quarters.
- **Robustness.** Across 14 other specifications the estimate ranges from 10.1 to 14.7 ([chart](figures/11_specification_chart.png), [table](tables/specification_table.html)). A fee-for-service-only version cannot be estimated reliably and is left out.
  A placebo with coverage 4 quarters earlier gives 0.4 (−0.1 to 0.8). An alternative estimator (Sun–Abraham) gives 9.3 (8.2 to 10.4; wild bootstrap 4.5 to 14.2).
  The estimators differ by 2.9: weighting explains about 1.1 of that (11.1 when event times are weighted like Sun–Abraham), and the remaining 1.8 comes from what each compares against ([reconciliation](tables/estimator_reconciliation.csv)).
- **How much parallel-trends violation the result tolerates.** The 95% robust interval for the first 4 quarters stays above zero until the post-period violation is 1.4 times the largest pre-period one ([HonestDiD](figures/12_honestdid.png)).
  Pre-period estimates 4 to 8 quarters before coverage are small and negative (−0.7 to −0.4).
- **Other drugs.** Saxenda 0.2 (−0.3 to 0.7); diabetes GLP-1 products −0.8 (−4.2 to 2.7), a spillover outcome that cannot distinguish substitution from a design problem ([figure](figures/13_secondary_outcomes.png)).

## First withdrawals (descriptive and preliminary)
From 2025 Q4 to 2026 Q1, relative to their all-drug change, Wegovy/Zepbound prescriptions changed −67.2% in California and −90.8% in Pennsylvania (coverage ended 2025-12-31), against a median of +31.9% in the
six continuously covered states ([figure](figures/05_withdrawal_descriptive.png), [table](tables/withdrawal_change_2025Q4_to_2026Q1.csv)). All-drug SDUD prescriptions also fell in most states that quarter, so 2026 Q1 data
are likely incomplete; one post-withdrawal quarter exists for most states, with no model or p-values.

## Two states that look different
- **Rhode Island:** use of about 2 per 1,000 before its 2023 Q4 coverage date was entirely through managed care (fee-for-service 0) ([table](tables/ri_sc_ffsu_mcou_split.csv)); the estimate without Rhode Island is 13.0 (9.1 to 16.9).
- **South Carolina:** uptake is almost all managed care (3.9 per 1,000 in 2025 Q3 versus 0.1 fee-for-service). The start date (2024-11-01) comes from the Milliman SFY 2026 capitation report for the managed care program, which does not say whether fee-for-service covers the drugs.

## What this does not show
Not health outcomes, costs or net prices (SDUD is gross of rebates); the estimate is the change in Medicaid-paid prescriptions, not in total use. The estimand is coverage for weight management over and above access through
other indications (Wegovy's cardiovascular indication from March 2024). With 10 treated states, several cohorts of one state, standard errors are fragile (simultaneous confidence bands are not reliable and are not shown). Data-quality flags: [data_quality_flags_by_state_period.html](tables/data_quality_flags_by_state_period.html).

Reproduce everything: `cd analysis; Rscript run_all.R`. Budget-model inputs: [moduleC_for_budget_model.csv](tables/moduleC_for_budget_model.csv).
