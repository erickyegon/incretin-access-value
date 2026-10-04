# Module C analysis plan (pre-specified)

Written before any model is run. Results must follow this plan; any change after seeing results is logged as a deviation with its reason
in `analysis/outputs/deviations.md`. Data: the approved warehouse marts only (`mart_did_panel`, `mart_sdud_cells_for_imputation`,
`mart_sdud_state_quarter_long`), read through `get_mart()`.

## Question

When a state Medicaid program starts covering Wegovy and Zepbound for obesity, how much does use rise, and how fast? What do the first
withdrawals suggest?

- The event study (dynamic ATT by quarter since coverage began) is the answer to "how fast". The withdrawal figure is descriptive and preliminary.
- Utilization management (prior authorization, BMI thresholds) is reported as context from the coverage table, not estimated as a separate
  effect, because 10 treated states are too few.

## Unit and outcome

- Unit: state x quarter (50 states and DC).
- **Primary outcome:** `obesity_wz` prescriptions (FFSU + MCOU) per 1,000 Medicaid enrollees (`total_medicaid_enrollment`, item 8a), in levels,
  with suppressed cells handled by multiple imputation (below).
- **Secondary outcomes**, same design: (a) Saxenda (`obesity_saxenda`) prescriptions per 1,000; (b) `diabetes_glp1` prescriptions per 1,000,
  pre-specified as a **spillover outcome**, not a clean negative control. A negative estimate would be consistent with substitution from
  off-label diabetes products to covered obesity products; a positive one with spillover in prescribing. Neither can be distinguished from a
  design problem with this data alone, and the report says so.

## Treatment

- **Primary treated states (10):** CA, KS, MA, MI, MS, NC, PA, RI, SC, TN. Cohort = `first_treated_quarter`.
- **Comparison:** never-treated states; not-yet-treated states also serve as controls (`control_group = "notyettreated"`).
- **Excluded from the primary analysis entirely (7):** the sensitivity states DE, MN, MO, NH, UT, VA, WI (start quarter unknown and treated).
- Kansas is primary by decision (2021Q3); Mississippi and Tennessee are primary with `category_level_spa = true`; both are tested below.

## Window

- Primary: 2018 Q1 to 2025 Q3. This keeps treatment absorbing: the first withdrawal (North Carolina, end 2025-09-30) begins in 2025 Q4.
- Wegovy did not exist before 2021 Q2 (approved 2021-06-04, `label_events`), so the outcome is mechanically zero everywhere before then.
  Pre-trend tests and the event-study plot use only event times whose calendar quarter is 2021 Q2 or later; earlier leads are greyed or omitted and
  are never counted as evidence of parallel trends. This is stated in every figure note where it applies.

## Estimator

- `did::att_gt`: no covariates, `est_method = "reg"`, `base_period = "universal"`, `control_group = "notyettreated"`, clustered by state,
  `bstrap = TRUE`, `cband = TRUE`, 999 or more bootstrap draws (a seed is set and recorded for every bootstrap and imputation).
- Aggregations: overall ATT (`aggte` type `"simple"` and `"group"`) and the dynamic event study (`aggte` type `"dynamic"`), event times -8 to +12
  quarters. The number of cohorts contributing to each event time is reported; event times with fewer than 3 contributing states are marked.
- Unweighted (state as the unit) in the primary; weighted by mean 2019 Medicaid enrollment as a sensitivity (`weightsname`, a time-invariant weight).

## Inference

- **Primary:** the `did` multiplier bootstrap clustered by state, with simultaneous confidence bands.
- With about 10 treated states, cluster-robust inference is fragile, so also: (a) a TWFE Sun-Abraham event study (`fixest::sunab`) with state and
  quarter fixed effects and a wild cluster bootstrap by state (`fwildclusterboot`, Webb weights, 9,999 draws) for the post-period average;
  (b) a placebo-in-time test that pretends coverage began 4 quarters earlier, within the post-launch window only.
- **HonestDiD:** relative-magnitudes bounds (Mbar from 0 to 2) on the average of the first 4 post-period event times, using the post-launch
  pre-periods only.
- If `fwildclusterboot` does not install from CRAN it is installed from its r-universe repository, and the report says so. No other method is
  substituted silently.

## Suppression (primary method: multiple imputation)

- Cells come from `mart_sdud_cells_for_imputation`. Each suppressed cell holds a value from 0 to 10.
- Where `residual_usable` is true, the suppressed cells of that NDC x quarter x utilization type are drawn jointly so they sum to the national
  residual, each capped at 10 (multinomial over the cells; any draw exceeding a cap is redrawn; if the residual exceeds 10 x the number of cells,
  all cells are set to 10 and logged).
- Where `residual_usable` is false, each cell is drawn independently from a discrete uniform on 0 to 10.
- 20 imputations; re-aggregate to the panel; run the primary model on each; combine ATT estimates and standard errors with Rubin's rules and
  report the fraction of missing information.
- Bounds as sensitivity: all suppressed cells = 0 and all = 10 (the mart's `rx_upper_bound`).

## Pre-specified sensitivity analyses

Each is one row of a specification table and one point in a specification chart.

1. Without Kansas.
2. Without Mississippi and Tennessee (category-level SPA).
3. Control group = never-treated only.
4. Enrollment-weighted.
5. Suppression lower bound and upper bound.
6. Denominator = Medicaid + CHIP enrollment.
7. Excluding state-quarters flagged in step 0 as `not_reported` or `anomalous` (set to missing; unbalanced panel allowed for this run only).
8. Excluding state-quarters with `definition_caveat` = true (same handling).
9. Including the 7 sensitivity states with start = `start_quarter_earliest`, then with start = `start_quarter_latest`.
10. First-full-quarter timing (`first_full_quarter` as cohort instead of `first_treated_quarter`).
11. Window extended to 2025 Q4, with North Carolina excluded.
12. Fee-for-service only (FFSU prescriptions per FFS enrollee) where the managed-care share exists; states without it are dropped from this run and listed.

## Step 0: SDUD reporting completeness (warehouse fix, done before modelling)

The warehouse reads a state-quarter with no SDUD row as 0 prescriptions. `int_sdud__reporting` (from the full yearly files, all drugs) flags a
state x quarter x utilization type `not_reported` (zero rows across all drugs) or `anomalous` (all-drug prescriptions below 50% of the median
of the four nearest other quarters of that state and type). The flags are added to the panel as `sdud_reported_ffsu`, `sdud_reported_mcou`
and `sdud_anomalous` and used only in sensitivity analysis 7; no row is dropped from the primary run.
Because a state with no managed-care pharmacy data would show `not_reported` for MCOU for structural reasons (no managed-care pharmacy
benefit, or a programme change), the flagged list is reported as a list and is read before sensitivity 7 is interpreted.

## Withdrawal (descriptive only, labelled preliminary)

For California, Pennsylvania, South Carolina and North Carolina (and New Hampshire as a sensitivity state), the outcome for the four quarters
before and all quarters after coverage end through 2026 Q1, with the never-treated mean as reference. 2026 Q1 is preliminary SDUD data and
only one post-withdrawal quarter exists for most states: no model, no p-values, and the figure says so.

## What is not claimed

No health, cost or net-price effects; SDUD amounts are gross of rebates; the estimate is the change in Medicaid-paid prescriptions, not in
total use (patients may pay cash or use other coverage). Effects are described as the estimated change in prescriptions per 1,000
enrollees under this design, not as proven causal effects beyond what the design supports.

## Outputs

Descriptive (Checkpoint A): coverage timing map, adoption timeline, raw trends by cohort, group composition table, suppression share by
quarter, data-quality table. Models (Checkpoint B): event-study figure, overall ATT table (simple and group, imputation-combined, with the
Sun-Abraham wild-bootstrap result beside it), specification chart, HonestDiD figure, secondary-outcome event studies, placebo-in-time result,
withdrawal figure, group-time ATT table (CSV only).

**Hand-off to the budget model (Module E).** After Checkpoint B (not before), `analysis/outputs/tables/moduleC_for_budget_model.csv` is
saved with: the imputation-combined dynamic ATT at event times 0 to +8 with standard errors and 95% confidence intervals; the overall ATT; and
the never-treated mean outcome over the same quarters as the baseline. Module E uses these as its uptake input under coverage.

## Conventions

Figures: finding-as-title written after results (factual, matching the estimate), subtitle with population, outcome and window, caption with
source and "Gross of rebates; counts under 11 suppressed by CMS" where relevant; grey for context and one accent colour for the focal group
(treated = accent, comparison = grey); Okabe-Ito colours when more than two groups are needed; uncertainty always shown; key dates annotated
(Wegovy approval 2021-06-04, Zepbound approval 2023-11-08). Outputs are aggregated to state-quarter rates: no suppressed cell value and no
cell-level count under 11 is written to any committed file. Every number is reproducible by `Rscript analysis/run_all.R` from the warehouse.
