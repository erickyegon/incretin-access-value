# Module C step 4.3: the pre-specified sensitivity analyses (plan items 1-13, with Amendment 2's definition of 7 and the added 13).
# Each row: overall ATT (aggte "simple") for obesity_wz, imputation-combined with Rubin's rules (the two bound runs are single fits).
# Seeds: SEED_BASE + 5000 + 100 x spec number + imputation.
source(here::here("R", "prep.R"))
panel <- get_mart("mart_did_panel")
imps <- readRDS(here::here("outputs", "cache", "imputed_panels.rds"))
prim <- readRDS(here::here("outputs", "cache", "primary_fits.rds"))$obesity_wz

specs <- list(
  list(id = "0", name = "Primary", args = list()),
  list(id = "1", name = "Without Kansas", args = list(drop_states = "KS")),
  list(id = "2", name = "Without Mississippi and Tennessee", args = list(drop_states = c("MS", "TN"))),
  list(id = "3", name = "Never-treated controls only", args = list(), run = list(control = "nevertreated")),
  list(id = "4", name = "Enrollment-weighted", args = list(weight = TRUE), run = list(weighted = TRUE)),
  list(id = "5a", name = "Suppressed cells = 0 (lower bound)", args = list(bound = "lower"), single = TRUE),
  list(id = "5b", name = "Suppressed cells = 10 (upper bound)", args = list(bound = "upper"), single = TRUE),
  list(id = "6", name = "Denominator: Medicaid + CHIP", args = list(denominator = "medicaid_chip")),
  list(id = "7", name = "Reporting-gap state-quarters set to missing", args = list(drop_flagged = TRUE), run = list(unbalanced = TRUE)),
  list(id = "8", name = "Definition-caveat state-quarters set to missing", args = list(drop_caveat = TRUE), run = list(unbalanced = TRUE)),
  list(id = "9a", name = "Add sensitivity states, start = earliest quarter", args = list(include_sensitivity = "start_quarter_earliest")),
  list(id = "9b", name = "Add sensitivity states, start = latest quarter", args = list(include_sensitivity = "start_quarter_latest")),
  list(id = "10", name = "First-full-quarter timing", args = list(cohort_col = "first_full_quarter")),
  list(id = "11", name = "Window to 2025 Q4, without North Carolina", args = list(window_end = "2025Q4", drop_states = "NC")),
  list(id = "12", name = "Fee-for-service only (FFSU per FFS enrollee)", args = list(util = "FFSU", denominator = "ffs"), ffs = TRUE),
  list(id = "13", name = "Without Rhode Island", args = list(drop_states = "RI"))
)

rows <- list(); notes <- list(); fits_store <- list()
for (s in specs) {
  if (s$id == "0") { fits <- prim; dat1 <- build_data(panel, imp = imps[[1]]) }
  else {
    ms <- if (isTRUE(s$single)) 1L else seq_len(M_IMP)
    sn <- match(s$id, vapply(specs, `[[`, "", "id"))
    fits <- vector("list", length(ms))
    for (j in seq_along(ms)) {
      m <- ms[j]
      dat <- do.call(build_data, c(list(panel = panel, imp = imps[[m]]), s$args))
      if (isTRUE(s$ffs)) {
        bad <- dat |> group_by(state_code) |> summarise(any_na = any(is.na(y)), .groups = "drop") |> filter(any_na) |> pull(state_code)
        if (j == 1) notes[[s$id]] <- paste("dropped (no managed-care share or no FFS enrollees):", paste(bad, collapse = ", "))
        dat <- dat |> filter(!state_code %in% bad)
      }
      rr <- do.call(run_att, c(list(dat = dat, seed = SEED_BASE + 5000L + 100L * sn + m), s$run))
      fits[[j]] <- extract_fit(suppressWarnings(rr), dat)
      if (j == 1) dat1 <- dat
    }
  }
  fits_store[[s$id]] <- fits
  o <- combine_overall(fits, "simple"); g <- combine_overall(fits, "group")
  f1 <- fits[[1]]
  rows[[s$id]] <- tibble(spec = s$id, specification = s$name, att_simple = o$estimate, se_simple = o$se, ci_low = o$ci_low, ci_high = o$ci_high, fmi = o$fmi,
                         att_group = g$estimate, se_group = g$se, group_ci_low = g$ci_low, group_ci_high = g$ci_high,
                         states = f1$n_states, treated_states = f1$n_treated_states, never_treated_states = f1$n_never_states,
                         state_quarters = f1$n_state_quarters, imputations = length(fits))
  cat(sprintf("%-4s %-52s ATT %.2f (%.2f to %.2f) states %d sq %d\n", s$id, s$name, o$estimate, o$ci_low, o$ci_high, f1$n_states, f1$n_state_quarters))
}
tab <- bind_rows(rows)
tab$note <- vapply(tab$spec, function(i) if (is.null(notes[[i]])) NA_character_ else notes[[i]], "")
readr::write_csv(tab, here::here("outputs", "tables", "specification_table_raw.csv"))
saveRDS(fits_store, here::here("outputs", "cache", "sensitivity_fits.rds"))
# which gap state-quarters does sensitivity 7 set to missing, inside the primary window?
g7 <- build_data(panel, imp = imps[[1]], drop_flagged = TRUE)
cat("sensitivity 7: state-quarters set to missing in the primary window:", sum(is.na(g7$y)), "\n")
print(g7 |> filter(is.na(y)) |> select(state_code, quarter_label))
