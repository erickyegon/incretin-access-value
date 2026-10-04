# Deviations from analysis_plan_moduleC.md (including Amendment 2)

Each entry: what the plan said, what was done, why.

1. **Sun-Abraham estimator not called through `fixest::sunab()`.** Plan: "TWFE Sun-Abraham event study (`fixest::sunab`)". Done: the same saturated
   cohort x event-time interaction regression, built explicitly with `fixest::feols(y ~ i(cell, ref = "ref") | id + t)`, with interaction-weighted
   aggregation. Reason: the wild cluster bootstrap (`fwildclusterboot`) needs the interaction coefficients as an explicit linear combination, and the plan
   requires no lead before 2021 Q2 to count as evidence, which `sunab()` cannot restrict cell by cell. The estimand (interaction-weighted post-period
   average against never-treated states) is Sun and Abraham's.
2. **`fwildclusterboot`** installed from CRAN or the r-universe repository as recorded in `renv.lock` (see `analysis/README.md`); no other bootstrap method was used.
3. **Wild-bootstrap interval.** Plan: wild cluster bootstrap by state (Webb weights, 9,999 draws) for the post-period average. Done: the 9,999-draw Webb bootstrap
   (`fwildclusterboot`, R-lean engine, post-period average re-parameterised as one coefficient) gives the p-value; the engine returns no test-inversion
   interval, so the reported interval is the symmetric wild bootstrap-t interval: estimate +/- CRV1 standard error x the 95th percentile of the bootstrap |t*|.
   Reason: test inversion needs one 11-minute bootstrap per grid point. The p-value (0.0002) is at the floor of what 9,999 draws can give.

Changes requested at Checkpoint B approval (made after seeing results, so logged here):

4. **Estimator reconciliation table added** (`tables/estimator_reconciliation.csv`, `tables/estimator_cohort_weights.csv`, `tables/max_event_time_by_cohort.csv`; script 16). Not in
   the plan; added to explain why the Callaway-Sant'Anna simple ATT (12.2) differs from the Sun-Abraham post-period average (9.3). Nothing already estimated was changed.
5. **Event-study figure shows pointwise 95% CIs, not simultaneous bands.** Plan: "simultaneous confidence bands". Reason: singleton cohorts make the bootstrap critical value
   unreliable (did warns of this) and very large (17.9 on average over the imputations, versus 1.96 pointwise); the figure note reports it. The y-axis truncation was removed,
   and event times with fewer than 3 contributing states are greyed. The simultaneous critical values are still in `tables/event_study_primary.csv` (band_low, band_high).
6. **Sensitivity 12 (fee-for-service only) is reported as not estimable reliably** and left off the specification chart: FFS denominators are too small, and coverage operates
   mainly through MCOs in SC and RI. The raw fit stays in `tables/specification_table_raw.csv` and the row appears in `tables/specification_table.*` with its note.

Not deviations, recorded for completeness: the South Carolina coverage-source fields were corrected (the start date comes from the Milliman SFY 2026 capitation report, not from a
news report; delivery-system field changed; see `data/reference/medicaid_obesity_coverage.csv`); secondary-outcome ATTs with CIs were added to `tables/overall_att.*`; the withdrawal figure
now plots the normalised change; `tables/moduleC_for_budget_model.csv` was saved after approval.

Module B (set before results of that step; recorded because they differ from the plan text):
7. **HIQ032 coding.** Plan: "HIQ032D (Medicaid)" read as a yes/no item. The codebook codes the check-all-that-apply items HIQ032A-I with the item number when ticked (Medicaid = 4,
   Medicare = 2, CHIP = 5) and blank otherwise; the analysis uses `hiq032d == 4` for Medicaid and `hiq032b == 2` for Medicare, among adults with HIQ011 answered.
8. **Weights.** Plan: WTMEC2YR for the primary design. Estimates that use HbA1c use the phlebotomy weight WTPH2YR, as the GHB_L documentation instructs (the plan already says so); the NCHS
   SAS-missing code (about 5e-79) in weights is treated as weight 0.
9. **NHANES mart.** The mart `mart_nhanes_adults` now keeps adults 18 and over (it was 20 and over) and carries the insurance and condition variables Module B needs; its test was updated.
