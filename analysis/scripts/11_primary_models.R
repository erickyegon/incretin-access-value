# Module C step 4.2: primary model and secondary outcomes. For each of the 20 imputations: Callaway-Sant'Anna att_gt (plan specification) and its
# simple, group and dynamic aggregations; combined across imputations with Rubin's rules. Seeds: SEED_BASE + 1000 x outcome number + imputation.
source(here::here("R", "prep.R"))
panel <- get_mart("mart_did_panel")
imps <- readRDS(here::here("outputs", "cache", "imputed_panels.rds"))
outcomes <- c("obesity_wz", "obesity_saxenda", "diabetes_glp1")
res <- list()
for (k in seq_along(outcomes)) {
  o <- outcomes[k]
  fits <- vector("list", M_IMP)
  for (m in seq_len(M_IMP)) {
    dat <- build_data(panel, imp = imps[[m]], outcome = o)
    r <- suppressWarnings(run_att(dat, control = "notyettreated", seed = SEED_BASE + 1000L * k + m))
    fits[[m]] <- extract_fit(r, dat)
  }
  res[[o]] <- fits
  cat(o, ": simple ATT", sprintf("%.3f", combine_overall(fits, "simple")$estimate), "| group ATT", sprintf("%.3f", combine_overall(fits, "group")$estimate), "\n")
}
saveRDS(res, here::here("outputs", "cache", "primary_fits.rds"))
