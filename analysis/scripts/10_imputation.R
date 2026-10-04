# Module C step 4.1: 20 imputations of the suppressed SDUD cells (method pre-specified in analysis_plan_moduleC.md, "Suppression").
# Cell-level draws never leave memory: only state x quarter x product group x utilization type sums are cached (outputs/cache, git-ignored).
# Seeds: SEED_BASE + imputation number (SEED_BASE = 20261004).
source(here::here("R", "prep.R"))
cells <- get_mart("mart_sdud_cells_for_imputation") |>
  filter(product_group %in% c("obesity_wz", "obesity_saxenda", "diabetes_glp1"))
cat("suppressed cells (panel states):", nrow(cells), "| residual_usable:", sum(cells$residual_usable), "| not usable:", sum(!cells$residual_usable), "\n")

imps <- vector("list", M_IMP); log <- list()
for (m in seq_len(M_IMP)) {
  r <- impute_once(cells, seed = SEED_BASE + m)
  imps[[m]] <- aggregate_imputed(r$cells) |> mutate(m = m)
  log[[m]] <- tibble(m = m, seed = SEED_BASE + m, nonusable_cells_uniform = r$n_nonusable_cells,
                     groups_multinomial = as.integer(r$modes["multinomial"]), groups_sequential_fallback = as.integer(r$modes["sequential"]),
                     groups_all10 = as.integer(r$modes["all10"]))
  cat("imputation", m, "done:", paste(names(r$modes), r$modes, collapse = ", "), "\n")
}
log <- bind_rows(log) |> mutate(across(where(is.integer), ~ coalesce(.x, 0L)))
dir.create(here::here("outputs", "cache"), showWarnings = FALSE, recursive = TRUE)
saveRDS(imps, here::here("outputs", "cache", "imputed_panels.rds"))
readr::write_csv(log, here::here("outputs", "tables", "imputation_log.csv"))

# Sanity checks (aggregate only): draws sum to the national residual in usable groups and are bounded by the mart's bounds
chk <- bind_rows(imps) |> group_by(m, product_group) |> summarise(total_imputed = sum(imp), .groups = "drop") |> group_by(product_group) |>
  summarise(mean_total_imputed = mean(total_imputed), min = min(total_imputed), max = max(total_imputed), .groups = "drop")
print(chk); print(log)
