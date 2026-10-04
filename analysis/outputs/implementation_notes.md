# Module C implementation notes (choices made while coding, before any result was seen)

These fill gaps the plan left open. None changes the pre-specified specification.

1. **Pre-launch cells.** `did::att_gt` is run on the full window 2018 Q1 to 2025 Q3 as specified. Before aggregation, pre-treatment group-time cells whose
   calendar quarter is before 2021 Q2 (outcome mechanically zero) are removed from the group-time object (`R/prep.R`, `run_att`). The dynamic event study,
   its leads and the HonestDiD pre-periods therefore use post-launch quarters only. Post-treatment cells are never before launch (the earliest cohort,
   Kansas, starts in 2021 Q3). The simple and group aggregations are unaffected.
2. **Simultaneous bands after imputation.** Rubin's rules give pointwise estimates and CIs. The simultaneous band is the combined estimate plus or minus the
   mean of the 20 per-imputation critical values (`crit.val.egt`) times the Rubin standard error. With single-state cohorts `did` warns that the critical
   value may be unreliable; the warning is kept and reported.
3. **Imputation draws.** Suppressed cells are drawn per group (NDC x quarter x utilization type) over all jurisdictions' suppressed cells, because the
   national residual covers all jurisdictions; the panel states' cells are a random subset of the jointly drawn cells. Groups with residual above 10 x cells
   set all cells to 10 and are counted (`outputs/tables/imputation_log.csv`). Cell-level draws are never written to disk; only state x quarter x product
   group x utilization type sums are cached (git-ignored).
4. **FFS outcome (sensitivity 12).** The panel carries FFSU rates per FFS enrollee, not FFSU counts; the FFSU count is rebuilt as rate x assumed FFS enrollment / 1,000
   and the imputed FFSU cells are added before dividing again. States with no managed-care share or no FFS enrollees are dropped and listed in the table note.
5. **Sun-Abraham.** Estimated as the saturated cohort x event-time interaction regression with state and quarter fixed effects (see deviations.md), cells before
   2021 Q2 excluded, reference e = -1, never-treated states as the comparison, interaction weights = treated state-quarters per cell. The wild cluster bootstrap
   (Webb, 9,999 draws, seed SEED_BASE + 9000) is run once on the mean of the 20 imputed outcomes.
6. **Placebo in time.** Treated states keep only their actual pre-coverage quarters from 2021 Q2; cohort start moved 4 quarters earlier; cohorts whose placebo start
   leaves no post-launch base quarter (Kansas, Michigan) are excluded together with their states; never-treated states are the controls; unbalanced-panel mode.
7. **HonestDiD.** Pre-periods e = -8..-2, post-periods e = 0..3 averaged with equal weights; Rubin-combined vector and covariance (within covariance from the
   analytical influence function clustered by state, plus (1 + 1/M) x between-imputation covariance).
8. **Sensitivity 7 (Amendment 2).** The gap rule is applied literally (not reported although reported the previous quarter, or anomalous). The only
   in-window candidate, Wisconsin 2020 Q1 (managed-care data stop and never return), belongs to a sensitivity state that the primary run excludes, so
   the rule sets no state-quarter to missing in the primary sample.
9. **Seeds.** SEED_BASE = 20261004. Imputation m: SEED_BASE + m. Primary outcome k, imputation m: SEED_BASE + 1000k + m. Sensitivity s, imputation m:
   SEED_BASE + 5000 + 100s + m. Wild bootstrap: SEED_BASE + 9000. Placebo: SEED_BASE + 9100 + m.
