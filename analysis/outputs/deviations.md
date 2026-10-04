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
