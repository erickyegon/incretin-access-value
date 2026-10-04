# Module C step 4.5: HonestDiD relative-magnitudes sensitivity (Rambachan-Roth) on the average of the first 4 post-period event times (e = 0..3),
# using only the post-launch pre-period event times (e = -8..-2; e = -1 is the universal reference). Pre-treatment cells before 2021 Q2 were removed
# before aggregation (R/prep.R). Imputation handling: the event-time estimates and covariances are combined across the 20 imputations with Rubin's
# rules (mean vector; mean within-imputation covariance + (1 + 1/M) x between-imputation covariance). Within-imputation covariance = analytical
# influence-function covariance of the dynamic aggregation, clustered by state (each state is one unit).
source(here::here("R", "prep.R"))
library(HonestDiD)
fits <- readRDS(here::here("outputs", "cache", "primary_fits.rds"))$obesity_wz
ev <- c(-8:-2, 0:3); npre <- 7L; npost <- 4L

bm <- lapply(fits, function(f) {
  a <- f$dynamic; idx <- match(ev, a$egt)
  stopifnot(!anyNA(idx))
  infl <- a$inf[, idx, drop = FALSE]
  list(beta = a$att.egt[idx], S = crossprod(infl) / a$n_units^2)
})
B <- do.call(rbind, lapply(bm, `[[`, "beta"))
beta <- colMeans(B)
Sbar <- Reduce(`+`, lapply(bm, `[[`, "S")) / length(bm)
Sig <- Sbar + (1 + 1 / length(bm)) * cov(B)
cat("event times:", paste(ev, collapse = " "), "\nbeta:", paste(round(beta, 2), collapse = " "), "\nse:", paste(round(sqrt(diag(Sig)), 2), collapse = " "), "\n")

l_vec <- rep(1 / npost, npost)
orig <- constructOriginalCS(betahat = beta, sigma = Sig, numPrePeriods = npre, numPostPeriods = npost, l_vec = l_vec)
mgrid <- seq(0, 2, by = 0.25)
wide <- seq(0, 5, by = 0.25)
rf <- createSensitivityResults_relativeMagnitudes(betahat = beta, sigma = Sig, numPrePeriods = npre, numPostPeriods = npost, l_vec = l_vec, Mbarvec = wide, alpha = 0.05)
rm <- rf[rf$Mbar %in% mgrid, ]
inc <- rf$lb <= 0 & rf$ub >= 0
breakdown <- NA_real_
if (any(inc)) {                       # refine on a 0.05 grid between the last excluding and the first including value of the 0.25 grid
  hi <- min(rf$Mbar[inc]); lo <- max(0, hi - 0.25)
  if (hi > 0) {
    rr <- createSensitivityResults_relativeMagnitudes(betahat = beta, sigma = Sig, numPrePeriods = npre, numPostPeriods = npost, l_vec = l_vec, Mbarvec = seq(lo, hi, by = 0.05), alpha = 0.05)
    breakdown <- min(rr$Mbar[rr$lb <= 0 & rr$ub >= 0])
  } else breakdown <- 0
}
out <- list(original = orig, grid = as_tibble(rm), fine = as_tibble(rf), breakdown_Mbar = breakdown, beta = beta, sigma = Sig, ev = ev)
saveRDS(out, here::here("outputs", "cache", "honestdid.rds"))
print(orig); print(as_tibble(rm)); cat("breakdown Mbar (smallest value on a 0.05 grid up to 5 whose 95% robust CI includes 0):", breakdown, "\n")
